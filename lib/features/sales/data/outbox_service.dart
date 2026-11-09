import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import '../../../core/database/app_database.dart';
import '../../../core/security/secure_storage_service.dart';

/// Worker de sincronização da fila Outbox: lê os eventos pendentes gravados
/// localmente (ex.: vendas) e os reenvia ao backend central em ordem
/// cronológica. Idempotente via X-Idempotency-Key (o id do evento).
class OutboxService {
  final AppDatabase db;
  final http.Client client;
  final SecureStorageService storage;
  final String apiBaseUrl;

  OutboxService({
    required this.db,
    required this.client,
    required this.storage,
    required this.apiBaseUrl,
  });

  /// Processa a fila: envia cada pendente para o servidor. Retorna a
  /// quantidade conciliada com sucesso nesta rodada.
  Future<int> processPending() async {
    final token = await storage.getToken();
    if (token == null || token == 'token_demo_offline') {
      // Sem servidor/sessão real (modo demo) — nada a sincronizar.
      return 0;
    }

    final pendentes = await (db.select(db.outbox)
          ..where((t) => t.status.equals('PENDENTE'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    var conciliados = 0;
    for (final item in pendentes) {
      final ok = await _enviar(item, token);
      if (ok) conciliados++;
    }
    return conciliados;
  }

  Future<bool> _enviar(OutboxData item, String token) async {
    final endpoint = _endpointFor(item.eventType);
    if (endpoint == null) return false;

    try {
      final res = await client.post(
        Uri.parse('$apiBaseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Idempotency-Key': item.id,
        },
        body: item.payload,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        await (db.update(db.outbox)..where((t) => t.id.equals(item.id)))
            .write(const OutboxCompanion(status: Value('CONCILIADO')));
        return true;
      } else {
        await _registrarErro(item, 'HTTP ${res.statusCode}: ${res.body}');
        return false;
      }
    } catch (e) {
      await _registrarErro(item, e.toString());
      return false;
    }
  }

  /// Consulta o status fiscal (SEFAZ) de um pedido no backend.
  /// Retorna o mapa {status_sefaz, protocolo, chave_acesso} ou null.
  Future<Map<String, dynamic>?> fetchFiscalStatus(String orderId) async {
    final token = await storage.getToken();
    if (token == null || token == 'token_demo_offline') return null;
    try {
      final res = await client.get(
        Uri.parse('$apiBaseUrl/fiscal/status/$orderId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Mapeia o tipo de evento para a rota do backend.
  String? _endpointFor(String eventType) {
    switch (eventType) {
      case 'order.created':
        return '/sync/vendas';
      default:
        return null;
    }
  }

  Future<void> _registrarErro(OutboxData item, String msg) async {
    await (db.update(db.outbox)..where((t) => t.id.equals(item.id))).write(
      OutboxCompanion(
        retryCount: Value(item.retryCount + 1),
        lastError: Value(msg),
      ),
    );
  }
}
