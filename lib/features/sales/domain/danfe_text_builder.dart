import 'danfe_escpos_builder.dart' show DanfeItem;

/// Gera uma versão em TEXTO (legível) do DANFE, para pré-visualização na tela
/// antes de enviar à impressora. Espelha o conteúdo do DANFE ESC/POS.
class DanfeTextBuilder {
  static String build({
    required String razaoSocial,
    required String cnpj,
    required List<DanfeItem> itens,
    required double valorTotal,
    required String formaPagamento,
    required String chaveAcesso,
    required int serie,
    required int numero,
    required bool isContingencia,
    String? protocolo,
  }) {
    const sep = '--------------------------------';
    final b = StringBuffer();
    b.writeln(razaoSocial);
    b.writeln('CNPJ: $cnpj');
    b.writeln(sep);
    b.writeln('COMPROVANTE DE VENDA');
    b.writeln('(documento nao fiscal)');
    b.writeln(sep);
    b.writeln('ITEM DESCRICAO           QTD   VL TOT');
    for (var i = 0; i < itens.length; i++) {
      final it = itens[i];
      b.writeln('${i + 1} ${it.sku} ${it.descricao}');
      b.writeln('   ${it.quantidade} x ${it.precoUnitario.toStringAsFixed(2)} = ${it.total.toStringAsFixed(2)}');
    }
    b.writeln(sep);
    b.writeln('VALOR TOTAL R\$: ${valorTotal.toStringAsFixed(2)}');
    b.writeln('PAGAMENTO: $formaPagamento');
    b.writeln(sep);
    if (chaveAcesso.trim().isNotEmpty) {
      b.writeln('NF-e 55 - Chave de Acesso:');
      b.writeln(_formatChave(chaveAcesso));
    } else {
      b.writeln('NF-e 55 emitida pelo sistema (PDF).');
    }
    return b.toString();
  }

  static String _formatChave(String chave) {
    final b = StringBuffer();
    for (var i = 0; i < chave.length; i += 4) {
      b.write(chave.substring(i, (i + 4).clamp(0, chave.length)));
      if (i + 4 < chave.length) b.write(' ');
    }
    return b.toString();
  }
}
