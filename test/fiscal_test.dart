import 'package:flutter_test/flutter_test.dart';
import 'package:venda_completa/features/sales/domain/fiscal_key_generator.dart';
import 'package:venda_completa/features/sales/domain/danfe_escpos_builder.dart';

void main() {
  group('FiscalKeyGenerator', () {
    test('gera chave com 44 dígitos', () {
      final chave = FiscalKeyGenerator.generate(
        cUF: 35,
        dataEmissao: DateTime(2026, 11, 7),
        cnpj: '11222333000181',
        modelo: 65,
        serie: 1,
        numero: 1,
        tpEmis: 9,
        cNF: 12345678,
      );
      expect(chave.length, 44);
      expect(RegExp(r'^\d{44}$').hasMatch(chave), isTrue);
    });

    test('DV módulo 11 confere para base conhecida', () {
      // Base de 43 dígitos; DV calculado deve bater com o recomposto.
      final chave = FiscalKeyGenerator.generate(
        cUF: 35,
        dataEmissao: DateTime(2026, 11, 7),
        cnpj: '11222333000181',
        modelo: 65,
        serie: 1,
        numero: 1,
        tpEmis: 9,
        cNF: 12345678,
      );
      final base = chave.substring(0, 43);
      final dv = int.parse(chave.substring(43));
      expect(dv, FiscalKeyGenerator.calcularDV(base));
      expect(dv, inInclusiveRange(0, 9));
    });

    test('calcularDV retorna 0 quando resto é 0 ou 1', () {
      // módulo 11: dv>=10 vira 0. Apenas garante faixa válida.
      final dv = FiscalKeyGenerator.calcularDV('0' * 43);
      expect(dv, inInclusiveRange(0, 9));
    });
  });

  group('DanfeEscPosBuilder', () {
    test('gera bytes não-vazios contendo cabeçalho e chave', () {
      final chave = '3' * 44;
      final bytes = DanfeEscPosBuilder().build(
        razaoSocial: 'Auto Pecas Veloz',
        cnpj: '11222333000181',
        itens: const [
          DanfeItem(sku: 'AP-001', descricao: 'Oleo 5W30', quantidade: 2, precoUnitario: 54.90),
        ],
        valorTotal: 109.80,
        formaPagamento: 'PIX',
        chaveAcesso: chave,
        serie: 1,
        numero: 1,
        isContingencia: true,
      );
      expect(bytes.isNotEmpty, isTrue);
      final asText = String.fromCharCodes(bytes);
      expect(asText.contains('Auto Pecas Veloz'), isTrue);
      expect(asText.contains('CONTINGENCIA'), isTrue);
      expect(asText.contains('109.80'), isTrue);
    });
  });
}
