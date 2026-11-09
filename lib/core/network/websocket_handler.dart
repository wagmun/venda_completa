import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../database/app_database.dart';
import '../security/secure_storage_service.dart';

/// Mantém a conexão WebSocket com o backend e aplica no banco local os
/// eventos de estoque (`inventory.updated`) emitidos quando OUTRO vendedor
/// da mesma empresa conclui uma venda. Reconecta automaticamente.
class WebSocketHandler {
  final AppDatabase db;
  final SecureStorageService storage;

  /// Base ws:// do servidor (ex.: ws://localhost:3000).
  final String wsBaseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  WebSocketHandler({
    required this.db,
    required this.storage,
    required this.wsBaseUrl,
  });

  /// Conecta usando o JWT salvo. Ignora no modo demo (sem sessão real).
  Future<void> connect() async {
    final token = await storage.getToken();
    if (token == null || token == 'token_demo_offline') return;
    _open(token);
  }

  void _open(String token) {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsBaseUrl/ws?token=$token'),
      );
      _sub = _channel!.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      final token = await storage.getToken();
      if (token != null && token != 'token_demo_offline') _open(token);
    });
  }

  Future<void> _onMessage(dynamic raw) async {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      if (data['event_type'] != 'inventory.updated') return;

      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      for (final it in items) {
        final productId = it['product_id']?.toString();
        if (productId == null) continue;
        final qtdFisica = (it['qtd_fisica'] as num?)?.toDouble();
        final qtdReservada = (it['qtd_reservada'] as num?)?.toDouble();

        await (db.update(db.localInventory)
              ..where((t) => t.id.equals(productId)))
            .write(
          LocalInventoryCompanion(
            qtdFisica:
                qtdFisica != null ? Value(qtdFisica) : const Value.absent(),
            qtdReservada: qtdReservada != null
                ? Value(qtdReservada)
                : const Value.absent(),
          ),
        );
      }
    } catch (_) {
      // Mensagem malformada — ignora.
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    disconnect();
  }
}
