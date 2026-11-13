import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/fiscal_service.dart';

/// Gera o PDF de um COMPROVANTE DE VENDA (não fiscal) em formato cupom (80mm),
/// para impressão via sistema. O documento fiscal é a NF-e 55 (PDF do Bling).
class DanfePdfBuilder {
  static Future<Uint8List> build(FiscalResult f, {String? protocolo}) async {
    final doc = pw.Document();
    final chave = f.chaveAcesso;
    final chaveFmt = _formatarChave(chave);

    pw.Widget sep() => pw.Divider(height: 6, thickness: 0.5);
    pw.TextStyle small = const pw.TextStyle(fontSize: 8);
    pw.TextStyle bold = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
            marginAll: 4 * PdfPageFormat.mm),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Center(child: pw.Text(f.razaoSocial, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('CNPJ: ${f.cnpj}', style: small)),
              sep(),
              pw.Center(child: pw.Text('COMPROVANTE DE VENDA', style: bold)),
              pw.Center(child: pw.Text('(documento nao fiscal)', style: small)),
              sep(),
              pw.Row(children: [
                pw.Expanded(flex: 5, child: pw.Text('DESCRICAO', style: bold)),
                pw.Expanded(flex: 2, child: pw.Text('QTD', style: bold)),
                pw.Expanded(flex: 3, child: pw.Text('VL TOT', style: bold, textAlign: pw.TextAlign.right)),
              ]),
              ...f.itens.map((it) => pw.Row(children: [
                    pw.Expanded(flex: 5, child: pw.Text('${it.sku} ${it.descricao}', style: small)),
                    pw.Expanded(flex: 2, child: pw.Text('${it.quantidade}', style: small)),
                    pw.Expanded(flex: 3, child: pw.Text(it.total.toStringAsFixed(2), style: small, textAlign: pw.TextAlign.right)),
                  ])),
              sep(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL R\$', style: bold),
                pw.Text(f.valorTotal.toStringAsFixed(2), style: bold),
              ]),
              pw.Text('PAGAMENTO: ${f.formaPagamento}', style: small),
              sep(),
              if (chave.trim().isNotEmpty) ...[
                pw.Center(child: pw.Text('NF-e 55 - Chave de Acesso:', style: bold)),
                pw.Center(child: pw.Text(chaveFmt, style: small, textAlign: pw.TextAlign.center)),
              ] else
                pw.Center(child: pw.Text('NF-e 55 emitida pelo sistema (PDF).', style: small)),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Obrigado pela preferencia!', style: small)),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  static String _formatarChave(String chave) {
    final b = StringBuffer();
    for (var i = 0; i < chave.length; i += 4) {
      b.write(chave.substring(i, (i + 4).clamp(0, chave.length)));
      if (i + 4 < chave.length) b.write(' ');
    }
    return b.toString();
  }
}
