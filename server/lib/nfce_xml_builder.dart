/// Monta o XML da NFC-e (modelo 65, layout 4.00) a partir dos dados da venda.
///
/// IMPORTANTE: é um XML estruturalmente representativo, NÃO assinado com
/// Certificado A1 e com alguns campos de endereço/município como placeholder.
/// A assinatura (XMLDSig) e a validação de schema entram com a integração real
/// (RealSefazService + certificado da empresa).
class NfceXmlBuilder {
  static String build({
    required String chave, // 44 dígitos
    required String razaoSocial,
    required String cnpj,
    required String inscricaoEstadual,
    required String uf,
    required int serie,
    required int numero,
    required String tpEmis,
    required List<Map<String, dynamic>> itens,
    required double valorTotal,
    required String formaPagamento,
  }) {
    final cUF = chave.substring(0, 2);
    final aamm = chave.substring(2, 6);
    final cNF = chave.substring(35, 43);
    final cDV = chave.substring(43, 44);
    final ano = '20${aamm.substring(0, 2)}';
    final mes = aamm.substring(2, 4);
    final dhEmi = '$ano-$mes-01T12:00:00-03:00';

    final b = StringBuffer();
    b.write('<?xml version="1.0" encoding="UTF-8"?>');
    b.write('<NFe xmlns="http://www.portalfiscal.inf.br/nfe">');
    b.write('<infNFe versao="4.00" Id="NFe$chave">');

    // ide
    b.write('<ide>');
    b.write('<cUF>$cUF</cUF><cNF>$cNF</cNF>');
    b.write('<natOp>VENDA AO CONSUMIDOR</natOp>');
    b.write('<mod>65</mod><serie>$serie</serie><nNF>$numero</nNF>');
    b.write('<dhEmi>$dhEmi</dhEmi><tpNF>1</tpNF><idDest>1</idDest>');
    b.write('<cMunFG>3550308</cMunFG>'); // placeholder (IBGE município)
    b.write('<tpImp>4</tpImp><tpEmis>$tpEmis</tpEmis><cDV>$cDV</cDV>');
    b.write('<tpAmb>2</tpAmb>'); // 2 = homologação
    b.write('<finNFe>1</finNFe><indFinal>1</indFinal><indPres>1</indPres>');
    b.write('<procEmi>0</procEmi><verProc>venda_completa-1.0</verProc>');
    b.write('</ide>');

    // emit
    b.write('<emit>');
    b.write('<CNPJ>${_d(cnpj)}</CNPJ>');
    b.write('<xNome>${_esc(razaoSocial)}</xNome>');
    b.write('<enderEmit>');
    b.write('<xLgr>Nao informado</xLgr><nro>S/N</nro><xBairro>Centro</xBairro>');
    b.write('<cMun>3550308</cMun><xMun>Nao informado</xMun><UF>$uf</UF>');
    b.write('<CEP>00000000</CEP><cPais>1058</cPais><xPais>BRASIL</xPais>');
    b.write('</enderEmit>');
    b.write('<IE>${_d(inscricaoEstadual)}</IE><CRT>1</CRT>'); // CRT 1 = Simples Nacional
    b.write('</emit>');

    // det (itens)
    var vTotal = 0.0;
    for (var i = 0; i < itens.length; i++) {
      final it = itens[i];
      final qtd = _toDouble(it['quantidade']);
      final vUn = _toDouble(it['preco_unitario']);
      final vProd = _toDouble(it['total']) != 0 ? _toDouble(it['total']) : qtd * vUn;
      vTotal += vProd;
      final ean = (it['codigo_ean'] ?? '').toString();
      final eanTag = ean.isEmpty ? 'SEM GTIN' : ean;
      b.write('<det nItem="${i + 1}">');
      b.write('<prod>');
      b.write('<cProd>${_esc((it['sku'] ?? '').toString())}</cProd>');
      b.write('<cEAN>$eanTag</cEAN>');
      b.write('<xProd>${_esc((it['descricao'] ?? '').toString())}</xProd>');
      b.write('<NCM>${(it['ncm'] ?? '00000000').toString()}</NCM>');
      b.write('<CFOP>5102</CFOP>');
      b.write('<uCom>${_esc((it['unidade_medida'] ?? 'UN').toString())}</uCom>');
      b.write('<qCom>${qtd.toStringAsFixed(4)}</qCom>');
      b.write('<vUnCom>${vUn.toStringAsFixed(2)}</vUnCom>');
      b.write('<vProd>${vProd.toStringAsFixed(2)}</vProd>');
      b.write('<cEANTrib>$eanTag</cEANTrib>');
      b.write('<uTrib>${_esc((it['unidade_medida'] ?? 'UN').toString())}</uTrib>');
      b.write('<qTrib>${qtd.toStringAsFixed(4)}</qTrib>');
      b.write('<vUnTrib>${vUn.toStringAsFixed(2)}</vUnTrib>');
      b.write('<indTot>1</indTot>');
      b.write('</prod>');
      // imposto — Simples Nacional (ICMSSN102: sem permissão de crédito)
      b.write('<imposto><ICMS><ICMSSN102>');
      b.write('<orig>0</orig><CSOSN>102</CSOSN>');
      b.write('</ICMSSN102></ICMS></imposto>');
      b.write('</det>');
    }

    // total
    b.write('<total><ICMSTot>');
    b.write('<vBC>0.00</vBC><vICMS>0.00</vICMS><vProd>${vTotal.toStringAsFixed(2)}</vProd>');
    b.write('<vNF>${vTotal.toStringAsFixed(2)}</vNF>');
    b.write('</ICMSTot></total>');

    // transp
    b.write('<transp><modFrete>9</modFrete></transp>');

    // pag
    b.write('<pag><detPag>');
    b.write('<tPag>${_tPag(formaPagamento)}</tPag>');
    b.write('<vPag>${valorTotal.toStringAsFixed(2)}</vPag>');
    b.write('</detPag></pag>');

    b.write('</infNFe>');
    // Assinatura entraria aqui (<Signature>...). Pendente de certificado A1.
    b.write('</NFe>');
    return b.toString();
  }

  static String _tPag(String forma) {
    switch (forma.toUpperCase()) {
      case 'DINHEIRO':
        return '01';
      case 'CARTAO_CREDITO':
        return '03';
      case 'CARTAO_DEBITO':
        return '04';
      case 'PIX':
        return '17';
      default:
        return '99';
    }
  }

  static String _d(String s) => s.replaceAll(RegExp(r'\D'), '');

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
