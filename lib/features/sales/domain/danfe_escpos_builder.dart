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

/// Monta a sequência de comandos ESC/POS de um COMPROVANTE DE VENDA (não fiscal)
/// para impressoras térmicas de 58/80mm (Bluetooth SPP). O documento fiscal é a
/// NF-e modelo 55 (emitida pelo Bling, em PDF A4) — este cupom é só um recibo.
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
    _text('COMPROVANTE DE VENDA', align: _alignCenter, bold: true);
    _text('(documento nao fiscal)', align: _alignCenter);
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

    if (chaveAcesso.trim().isNotEmpty) {
      _text('NF-e 55 - Chave de Acesso:', align: _alignCenter, bold: true);
      _text(_formatChave(chaveAcesso), align: _alignCenter);
    } else {
      _text('NF-e 55 emitida pelo sistema (PDF).', align: _alignCenter);
    }
    _text('\nObrigado pela preferencia!', align: _alignCenter);
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
}
