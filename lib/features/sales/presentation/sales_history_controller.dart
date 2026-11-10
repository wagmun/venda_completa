import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/security/secure_storage_service.dart';
import '../data/danfe_pdf_builder.dart';
import '../data/outbox_service.dart';
import '../domain/danfe_escpos_builder.dart';
import '../domain/fiscal_service.dart';

/// Uma venda registrada localmente (lida da Outbox), com seu status de
/// sincronização com o servidor central.
class SaleRecord {
  final String orderId;
  final DateTime createdAt;
  final double total;
  final String paymentMethod;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? fiscal; // {serie, numero, chave_acesso, tp_emis, modelo}
  final String status; // PENDENTE | CONCILIADO
  final int retryCount;
  final String? lastError;

  SaleRecord({
    required this.orderId,
    required this.createdAt,
    required this.total,
    required this.paymentMethod,
    required this.items,
    required this.fiscal,
    required this.status,
    required this.retryCount,
    required this.lastError,
  });

  bool get sincronizada => status == 'CONCILIADO';
  int get totalItens =>
      items.fold(0, (s, i) => s + ((i['quantidade'] as num?)?.toInt() ?? 0));
}

/// Controla a tela "Minhas vendas": lista as vendas gravadas no dispositivo,
/// mostra o que está pendente de envio, dispara a sincronização manual e
/// reimprime o DANFE de qualquer venda.
class SalesHistoryController extends ChangeNotifier {
  final AppDatabase _db;
  final SecureStorageService _storage;
  final OutboxService? _outboxService;

  SalesHistoryController({
    required AppDatabase db,
    required SecureStorageService storage,
    OutboxService? outboxService,
  })  : _db = db,
        _storage = storage,
        _outboxService = outboxService;

  List<SaleRecord> _sales = [];
  List<SaleRecord> get sales => List.unmodifiable(_sales);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  int get pendingCount => _sales.where((s) => !s.sincronizada).length;

  /// Carrega as vendas do banco local (mais recentes primeiro).
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    final rows = await (_db.select(_db.outbox)
          ..where((t) => t.eventType.equals('order.created'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    _sales = rows.map(_parse).whereType<SaleRecord>().toList();
    _isLoading = false;
    notifyListeners();
  }

  /// Força o envio dos pendentes ao servidor e recarrega a lista.
  Future<int> syncNow() async {
    if (_outboxService == null) return 0;
    _isSyncing = true;
    notifyListeners();
    int conciliados = 0;
    try {
      conciliados = await _outboxService.processPending();
    } catch (_) {
      conciliados = 0;
    }
    _isSyncing = false;
    await refresh();
    return conciliados;
  }

  /// Reconstrói o PDF do DANFE de uma venda a partir do payload gravado.
  Future<Uint8List?> buildDanfePdf(SaleRecord sale) async {
    final razao = await _storage.getRazaoSocial() ?? 'Empresa';
    final cnpj = await _storage.getCnpj() ?? '00000000000000';
    final f = sale.fiscal;
    if (f == null) return null;

    final itens = sale.items
        .map((i) => DanfeItem(
              sku: (i['sku'] ?? '').toString(),
              descricao: (i['descricao'] ?? '').toString(),
              quantidade: (i['quantidade'] as num?)?.toInt() ?? 1,
              precoUnitario: (i['preco_unitario'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();

    final fiscalResult = FiscalResult(
      serie: (f['serie'] as num?)?.toInt() ?? 1,
      numero: (f['numero'] as num?)?.toInt() ?? 0,
      chaveAcesso: (f['chave_acesso'] ?? '').toString(),
      tpEmis: (f['tp_emis'] ?? '9').toString(),
      modelo: (f['modelo'] ?? '65').toString(),
      danfeBytes: Uint8List(0),
      previewText: '',
      razaoSocial: razao,
      cnpj: cnpj,
      itens: itens,
      valorTotal: sale.total,
      formaPagamento: sale.paymentMethod,
    );

    return DanfePdfBuilder.build(fiscalResult);
  }

  SaleRecord? _parse(OutboxData row) {
    try {
      final map = jsonDecode(row.payload) as Map<String, dynamic>;
      return SaleRecord(
        orderId: (map['order_id'] ?? row.id).toString(),
        createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
            row.createdAt,
        total: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: (map['payment_method'] ?? '-').toString(),
        items: ((map['items'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        fiscal: map['fiscal'] == null
            ? null
            : Map<String, dynamic>.from(map['fiscal'] as Map),
        status: row.status,
        retryCount: row.retryCount,
        lastError: row.lastError,
      );
    } catch (_) {
      return null;
    }
  }
}
