import 'dart:typed_data';

/// Item de linha do DANFE.
class DanfeItem {
  final String sku;
  final String descricao;
  final num quantidade;
  final double precoUnitario;
  const DanfeItem({
    required this.sku,
    required this.descricao,
    required this.quantidade,
    required this.precoUnitario,
  });
  double get total => precoUnitario * quantidade;
}

/// Monta a sequência de comandos ESC/POS do DANFE NFC-e Simplificado para
/// impressoras térmicas de 58/80mm (Bluetooth SPP). Peça pura: devolve bytes;
/// o envio à impressora é feito por um serviço de impressão separado.
class DanfeEscPosBuilder {
  final List<int> _bytes = [];

  static const List<int> _init = [0x1B, 0x40];
  static const List<int> _alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> _alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> _boldOn = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];
  static const List<int> _feedCut = [0x1D, 0x56, 0x42, 0x00];

  void _text(String text, {List<int>? align, bool bold = false}) {
    if (align != null) _bytes.addAll(align);
    if (bold) _bytes.addAll(_boldOn);
    _bytes.addAll(text.codeUnits);
    _bytes.add(0x0A);
    if (bold) _bytes.addAll(_boldOff);
  }

  void _separator() =>
      _text('------------------------------------------------', align: _alignCenter);

  Uint8List build({
    required String razaoSocial,
    required String cnpj,
    required List<DanfeItem> itens,
    required double valorTotal,
    required String formaPagamento,
    required String chaveAcesso,
    required int serie,
    required int numero,
    required bool isContingencia,
  }) {
    _bytes.clear();
    _bytes.addAll(_init);

    _text(razaoSocial, align: _alignCenter, bold: true);
    _text('CNPJ: $cnpj', align: _alignCenter);
    _separator();
    _text('DANFE NFC-e - Documento Auxiliar', align: _alignCenter, bold: true);
    _text('Nota Fiscal de Consumidor Eletronica', align: _alignCenter);

    if (isContingencia) {
      _separator();
      _text('EMITIDA EM CONTINGENCIA OFFLINE', align: _alignCenter, bold: true);
      _text('Transmitir em ate 24h para a SEFAZ', align: _alignCenter);
    }
    _separator();

    _text('ITEM  DESCRICAO           QTD   VL TOT', align: _alignLeft, bold: true);
    for (var i = 0; i < itens.length; i++) {
      final it = itens[i];
      _text('${i + 1} ${it.sku} ${it.descricao}', align: _alignLeft);
      _text('   ${it.quantidade} x ${it.precoUnitario.toStringAsFixed(2)} = ${it.total.toStringAsFixed(2)}',
          align: _alignLeft);
    }

    _separator();
    _text('VALOR TOTAL R\$: ${valorTotal.toStringAsFixed(2)}', align: _alignLeft, bold: true);
    _text('PAGAMENTO: $formaPagamento', align: _alignLeft);
    _separator();

    _text('NFC-e Serie: $serie  Numero: $numero', align: _alignCenter);
    _text('Chave de Acesso:', align: _alignCenter, bold: true);
    _text(_formatChave(chaveAcesso), align: _alignCenter);
    _separator();

    _appendQrCode('chave=$chaveAcesso');
    _text('\nConsulta via QR Code ou Chave de Acesso', align: _alignCenter);
    _bytes.addAll(_feedCut);

    return Uint8List.fromList(_bytes);
  }

  /// Agrupa a chave em blocos de 4 para leitura humana.
  String _formatChave(String chave) {
    final b = StringBuffer();
    for (var i = 0; i < chave.length; i += 4) {
      b.write(chave.substring(i, (i + 4).clamp(0, chave.length)));
      if (i + 4 < chave.length) b.write(' ');
    }
    return b.toString();
  }

  /// Comandos ESC/POS (modelo 2) para renderizar o QR Code da SEFAZ.
  void _appendQrCode(String data) {
    _bytes.addAll(_alignCenter);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x08]); // tamanho
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30]); // correção
    final qr = data.codeUnits;
    final storeLen = qr.length + 3;
    _bytes.addAll([0x1D, 0x28, 0x6B, storeLen % 256, storeLen ~/ 256, 0x31, 0x50, 0x30]);
    _bytes.addAll(qr);
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]); // imprime
  }
}
