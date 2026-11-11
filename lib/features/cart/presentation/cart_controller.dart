import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:venda_completa/core/database/app_database.dart';
import 'package:venda_completa/features/sales/data/danfe_pdf_builder.dart';
import 'package:venda_completa/core/security/secure_storage_service.dart';
import 'package:venda_completa/features/cart/data/cart_repository.dart';
import 'package:venda_completa/features/cart/domain/cart_item.dart';
import 'package:venda_completa/features/sales/data/outbox_service.dart';
import 'package:venda_completa/features/sales/data/printer_service.dart';
import 'package:venda_completa/features/sales/domain/danfe_escpos_builder.dart';
import 'package:venda_completa/features/sales/domain/fiscal_service.dart';

class CartController extends ChangeNotifier {
  final CartRepository _cartRepository;
  final SecureStorageService _storage;
  final OutboxService? _outboxService;
  final FiscalService? _fiscalService;
  final PrinterService? _printerService;

  FiscalResult? _lastFiscal;
  FiscalResult? get lastFiscal => _lastFiscal;

  /// Há impressora disponível para imprimir o DANFE?
  bool get printerAvailable => _printerService?.isAvailable ?? false;

  /// Último erro de impressão (para feedback).
  String? get printerError => _printerService?.lastError;

  // Venda em preparação (pré-visualização, ainda NÃO efetivada).
  FiscalResult? _pendingFiscal;
  String? _pendingPayment;
  FiscalResult? get pendingFiscal => _pendingFiscal;

  // Retorno da emissão da NF-e 55 (via Bling) da última venda.
  String _transmissionStatus = '';
  String get transmissionStatus => _transmissionStatus;
  bool get lastSaleAuthorized => _transmissionStatus.contains('AUTORIZADA');

  // Chave de acesso e link do DANFE da NF-e 55 emitida no servidor.
  String? _lastChaveNfe;
  String? _lastDanfeLink;
  String? get lastChaveNfe => _lastChaveNfe;
  String? get lastDanfeLink => _lastDanfeLink;

  // DANFE a exibir: versão autorizada (c/ protocolo) se já autorizada; senão a prévia.
  String? _authorizedPreview;
  String get danfePreview => _authorizedPreview ?? _lastFiscal?.previewText ?? 'Venda concluída.';

  String? _lastProtocolo;

  /// Gera o PDF do comprovante da última venda (para impressão via sistema).
  Future<Uint8List?> buildLastDanfePdf() async {
    final f = _lastFiscal;
    if (f == null) return null;
    return DanfePdfBuilder.build(f, protocolo: _lastProtocolo);
  }

  /// Baixa o PDF do DANFE da NF-e 55 (link do Bling), para abrir/imprimir.
  Future<Uint8List?> fetchDanfePdfFromLink() async {
    final link = _lastDanfeLink;
    if (link == null || link.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(link));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  final List<CartItem> _items = [];
  bool _isProcessing = false;
  String? _lastOrderSummary;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isProcessing => _isProcessing;
  String? get lastOrderSummary => _lastOrderSummary;

  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.total);

  int get totalItems =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  CartController({
    required CartRepository cartRepository,
    required SecureStorageService storage,
    OutboxService? outboxService,
    FiscalService? fiscalService,
    PrinterService? printerService,
  })  : _cartRepository = cartRepository,
        _storage = storage,
        _outboxService = outboxService,
        _fiscalService = fiscalService,
        _printerService = printerService;

  void addProduct(LocalInventoryData product, {int quantity = 1}) {
    if (quantity <= 0) return;
    final index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void updateQuantity(String productId, int delta) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      _items[index].quantity += delta;
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _lastOrderSummary = null;
    notifyListeners();
  }

  /// FASE 1: monta a prévia da NFC-e para conferência. NÃO efetiva a venda
  /// (não baixa estoque, não consome número fiscal). Retorna a prévia.
  Future<FiscalResult?> prepareSale(String paymentMethod) async {
    if (_items.isEmpty) return null;
    _pendingPayment = paymentMethod;
    _pendingFiscal = null;
    if (_fiscalService != null) {
      _pendingFiscal = await _fiscalService.montarPrevia(
        itens: _items
            .map((i) => DanfeItem(
                  sku: i.product.sku,
                  descricao: i.product.descricao,
                  quantidade: i.quantity,
                  precoUnitario: i.product.precoVenda,
                ))
            .toList(),
        valorTotal: totalAmount,
        formaPagamento: paymentMethod,
      );
    }
    notifyListeners();
    return _pendingFiscal;
  }

  /// FASE 2: efetiva a venda preparada — consome o número fiscal, baixa o
  /// estoque, grava na Outbox e sincroniza.
  Future<bool> confirmSale() async {
    if (_items.isEmpty || _pendingPayment == null) return false;

    _isProcessing = true;
    _transmissionStatus = '';
    _authorizedPreview = null;
    _lastProtocolo = null;
    notifyListeners();

    final tenantId = await _storage.getTenantId() ?? '';

    if (_pendingFiscal != null && _fiscalService != null) {
      await _fiscalService.confirmarNumero(_pendingFiscal!.numero);
    }

    final orderId = await _cartRepository.processCheckout(
      tenantId: tenantId,
      items: _items,
      totalAmount: totalAmount,
      paymentMethod: _pendingPayment!,
      fiscal: _pendingFiscal?.toPayload(),
    );
    final success = orderId != null;

    if (success) {
      _lastFiscal = _pendingFiscal;
      _generateReceiptText(_pendingPayment!);
      _items.clear();
      // Emite a NF-e 55 pelo Bling (no servidor) e consulta o status.
      _transmissionStatus = 'Emitindo NF-e 55 pelo Bling...';
      _lastChaveNfe = null;
      _lastDanfeLink = null;
      try {
        await _outboxService?.processPending();
        final st = await _outboxService?.fetchFiscalStatus(orderId);
        final status = st?['status_sefaz'];
        _lastChaveNfe = (st?['chave_acesso'])?.toString();
        _lastDanfeLink = (st?['link_danfe'])?.toString();
        if (status == 'AUTORIZADO') {
          _lastProtocolo = st!['chave_acesso']?.toString();
          _transmissionStatus = 'NF-e 55 AUTORIZADA';
        } else if (status == 'REJEITADO') {
          _transmissionStatus =
              'NF-e 55 REJEITADA${st?['motivo'] != null && '${st!['motivo']}'.isNotEmpty ? ' · ${st['motivo']}' : ''}';
        } else if (status == 'ERRO') {
          _transmissionStatus =
              'Falha ao emitir no Bling${st?['motivo'] != null && '${st!['motivo']}'.isNotEmpty ? ' · ${st['motivo']}' : ''}';
        } else if (status == 'PROCESSANDO') {
          _transmissionStatus = 'NF-e 55 em processamento na SEFAZ';
        } else {
          _transmissionStatus = 'Pendente — será emitida ao reconectar';
        }
      } catch (_) {
        _transmissionStatus = 'Pendente — sem conexão com o servidor';
      }
    }

    _pendingFiscal = null;
    _pendingPayment = null;
    _isProcessing = false;
    notifyListeners();
    return success;
  }

  /// Descarta a venda em preparação (botão Cancelar na prévia). Sem efeitos:
  /// estoque intacto, número fiscal não consumido, carrinho preservado.
  void discardSale() {
    _pendingFiscal = null;
    _pendingPayment = null;
    notifyListeners();
  }

  /// Envia o DANFE da última venda para a impressora, pela conexão escolhida.
  Future<bool> printLastDanfe({
    PrinterConnection connection = PrinterConnection.bluetooth,
    String? host,
    int? port,
    String? btMac,
  }) async {
    final fiscal = _lastFiscal;
    if (fiscal == null || _printerService == null) return false;
    return _printerService.printBytes(
      fiscal.danfeBytes,
      connection: connection,
      host: host,
      port: port,
      btMac: btMac,
    );
  }

  /// Bluetooth ligado no aparelho.
  Future<bool> bluetoothEnabled() async =>
      _printerService?.bluetoothEnabled() ?? Future.value(false);

  /// Impressoras Bluetooth pareadas no sistema.
  Future<List<BtPrinter>> pairedBluetoothPrinters() async =>
      _printerService?.pairedBluetoothPrinters() ?? Future.value(const []);

  void _generateReceiptText(String paymentMethod) {
    final buffer = StringBuffer();
    buffer.writeln('================================');
    buffer.writeln('       COMPROVANTE DE VENDA     ');
    buffer.writeln('================================');
    buffer.writeln('Data: ${DateTime.now().toString().split('.').first}');
    buffer.writeln('Forma de Pagamento: $paymentMethod');
    buffer.writeln('--------------------------------');
    for (final item in _items) {
      buffer.writeln('${item.product.descricao}');
      buffer.writeln('  ${item.quantity} UN x R\$ ${item.product.precoVenda.toStringAsFixed(2)} = R\$ ${item.total.toStringAsFixed(2)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('TOTAL: R\$ ${totalAmount.toStringAsFixed(2)}');
    buffer.writeln('================================');
    if (_lastFiscal != null) {
      buffer.writeln('NFC-e Serie ${_lastFiscal!.serie}  No ${_lastFiscal!.numero}');
      buffer.writeln('Emitida em CONTINGENCIA (tpEmis=9)');
      buffer.writeln('Chave: ${_lastFiscal!.chaveAcesso}');
      buffer.writeln('================================');
    }
    buffer.writeln('    Venda gravada no Outbox     ');
    buffer.writeln('   Sincronização pendente...    ');
    buffer.writeln('================================');
    _lastOrderSummary = buffer.toString();
  }
}
