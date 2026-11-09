import 'dart:typed_data';
import '../../../core/security/secure_storage_service.dart';
import 'danfe_escpos_builder.dart';
import 'danfe_text_builder.dart';
import 'fiscal_key_generator.dart';

/// Resultado da emissão fiscal (contingência offline).
class FiscalResult {
  final int serie;
  final int numero;
  final String chaveAcesso;
  final String tpEmis; // '9' = contingência offline
  final String modelo; // '65' = NFC-e
  final Uint8List danfeBytes;
  final String previewText; // DANFE legível p/ conferência na tela
  final String razaoSocial;
  final String cnpj;
  final List<DanfeItem> itens;
  final double valorTotal;
  final String formaPagamento;

  FiscalResult({
    required this.serie,
    required this.numero,
    required this.chaveAcesso,
    required this.tpEmis,
    required this.modelo,
    required this.danfeBytes,
    required this.previewText,
    required this.razaoSocial,
    required this.cnpj,
    required this.itens,
    required this.valorTotal,
    required this.formaPagamento,
  });

  /// Bloco enviado ao backend junto da venda (gravado em fiscal_invoices).
  Map<String, dynamic> toPayload() => {
        'modelo': modelo,
        'serie': serie,
        'numero': numero,
        'chave_acesso': chaveAcesso,
        'tp_emis': tpEmis,
      };
}

/// Emite a NFC-e localmente em contingência (tpEmis=9): aloca série/número,
/// gera a chave de acesso e monta o DANFE. A transmissão à SEFAZ (ou via API
/// fiscal) é uma etapa posterior — aqui a nota nasce OFFLINE.
class FiscalService {
  final SecureStorageService storage;
  static const int serieNfce = 1;
  static const int modeloNfce = 65;

  FiscalService(this.storage);

  /// Código IBGE da UF (cUF) para a chave de acesso.
  static const Map<String, int> _cUF = {
    'RO': 11, 'AC': 12, 'AM': 13, 'RR': 14, 'PA': 15, 'AP': 16, 'TO': 17,
    'MA': 21, 'PI': 22, 'CE': 23, 'RN': 24, 'PB': 25, 'PE': 26, 'AL': 27,
    'SE': 28, 'BA': 29, 'MG': 31, 'ES': 32, 'RJ': 33, 'SP': 35, 'PR': 41,
    'SC': 42, 'RS': 43, 'MS': 50, 'MT': 51, 'GO': 52, 'DF': 53,
  };

  /// Monta a prévia da NFC-e em contingência SEM consumir o número fiscal.
  /// A confirmação definitiva (consumo do número) é feita em [confirmarNumero].
  Future<FiscalResult> montarPrevia({
    required List<DanfeItem> itens,
    required double valorTotal,
    required String formaPagamento,
  }) async {
    final cnpj = await storage.getCnpj() ?? '00000000000000';
    final uf = await storage.getUf() ?? 'SP';
    final razao = await storage.getRazaoSocial() ?? 'Empresa';
    final numero = await storage.peekNfceNumero();
    final cUF = _cUF[uf] ?? 35;

    final chave = FiscalKeyGenerator.generate(
      cUF: cUF,
      dataEmissao: DateTime.now(),
      cnpj: cnpj,
      modelo: modeloNfce,
      serie: serieNfce,
      numero: numero,
      tpEmis: 9,
    );

    final danfe = DanfeEscPosBuilder().build(
      razaoSocial: razao,
      cnpj: cnpj,
      itens: itens,
      valorTotal: valorTotal,
      formaPagamento: formaPagamento,
      chaveAcesso: chave,
      serie: serieNfce,
      numero: numero,
      isContingencia: true,
    );

    final preview = DanfeTextBuilder.build(
      razaoSocial: razao,
      cnpj: cnpj,
      itens: itens,
      valorTotal: valorTotal,
      formaPagamento: formaPagamento,
      chaveAcesso: chave,
      serie: serieNfce,
      numero: numero,
      isContingencia: true,
    );

    return FiscalResult(
      serie: serieNfce,
      numero: numero,
      chaveAcesso: chave,
      tpEmis: '9',
      modelo: '65',
      danfeBytes: danfe,
      previewText: preview,
      razaoSocial: razao,
      cnpj: cnpj,
      itens: itens,
      valorTotal: valorTotal,
      formaPagamento: formaPagamento,
    );
  }

  /// Consome definitivamente o número fiscal (ao confirmar a venda).
  Future<void> confirmarNumero(int numero) async {
    await storage.commitNfceNumero(numero);
  }
}
