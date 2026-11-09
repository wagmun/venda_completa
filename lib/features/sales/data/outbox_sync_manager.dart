import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'outbox_service.dart';

/// Coordena o replay automático da fila Outbox:
/// - dispara uma vez ao iniciar;
/// - dispara sempre que a conexão volta (connectivity_plus);
/// - e periodicamente, como rede de segurança.
/// O [OutboxService] já ignora quando não há sessão/servidor (modo demo).
class OutboxSyncManager {
  final OutboxService outboxService;
  final Duration interval;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _running = false;

  OutboxSyncManager({
    required this.outboxService,
    this.interval = const Duration(seconds: 20),
  });

  void start() {
    _flush(); // tenta já no início (sincroniza vendas de sessões anteriores)

    _timer ??= Timer.periodic(interval, (_) => _flush());

    _connSub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) _flush();
    });
  }

  /// Executa uma rodada de sincronização, evitando sobreposição.
  Future<void> _flush() async {
    if (_running) return;
    _running = true;
    try {
      await outboxService.processPending();
    } catch (_) {
      // Falhas ficam registradas na própria Outbox (retry_count/last_error).
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _connSub?.cancel();
    _timer = null;
    _connSub = null;
  }
}
