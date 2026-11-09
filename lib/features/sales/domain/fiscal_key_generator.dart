import 'dart:math';

/// Gera a Chave de Acesso de 44 dígitos da NFC-e/NF-e (layout SEFAZ) e seu
/// dígito verificador (módulo 11). Peça pura e determinística — a transmissão
/// à SEFAZ (ou via API fiscal) é uma etapa posterior.
///
/// Composição (43 dígitos + DV):
/// cUF(2) AAMM(4) CNPJ(14) mod(2) série(3) nNF(9) tpEmis(1) cNF(8) + cDV(1)
class FiscalKeyGenerator {
  /// Gera a chave completa (44 dígitos).
  static String generate({
    required int cUF,
    required DateTime dataEmissao,
    required String cnpj,
    required int modelo,
    required int serie,
    required int numero,
    required int tpEmis,
    int? cNF,
  }) {
    final cnpjDigits = cnpj.replaceAll(RegExp(r'\D'), '').padLeft(14, '0');
    final aa = (dataEmissao.year % 100).toString().padLeft(2, '0');
    final mm = dataEmissao.month.toString().padLeft(2, '0');
    final codigo = (cNF ?? _randomCNF()).toString().padLeft(8, '0');

    final base = cUF.toString().padLeft(2, '0') +
        aa + mm +
        cnpjDigits +
        modelo.toString().padLeft(2, '0') +
        serie.toString().padLeft(3, '0') +
        numero.toString().padLeft(9, '0') +
        tpEmis.toString() +
        codigo;

    assert(base.length == 43, 'Base da chave deve ter 43 dígitos, tem ${base.length}');
    return base + calcularDV(base).toString();
  }

  /// Dígito verificador por módulo 11 (pesos 2..9 da direita p/ esquerda).
  static int calcularDV(String base) {
    var soma = 0;
    var peso = 2;
    for (var i = base.length - 1; i >= 0; i--) {
      soma += int.parse(base[i]) * peso;
      peso = peso == 9 ? 2 : peso + 1;
    }
    final resto = soma % 11;
    final dv = 11 - resto;
    return (dv >= 10) ? 0 : dv;
  }

  static int _randomCNF() => Random().nextInt(100000000); // 0..99.999.999
}
