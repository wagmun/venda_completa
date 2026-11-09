/// Resultado da transmissão de uma NFC-e à SEFAZ.
class SefazResult {
  final String status; // AUTORIZADO | REJEITADO | OFFLINE
  final String? protocolo;
  final String? motivo;
  SefazResult({required this.status, this.protocolo, this.motivo});
}

/// Contrato de transmissão fiscal. Troque a implementação injetada para migrar
/// do mock para a SEFAZ real (ou um provedor como Focus NFe/PlugNotas) —
/// sem mexer na regra de negócio.
abstract class SefazService {
  Future<SefazResult> transmitir({
    required String chaveAcesso,
    required String modelo,
    required int serie,
    required int numero,
    required String tpEmis,
  });
}

/// MOCK (apenas desenvolvimento/demonstração): autoriza sempre e devolve um
/// protocolo simulado. NÃO assina com A1 nem fala com a SEFAZ real.
/// Para produção, implementar `RealSefazService` e trocar a injeção.
class FakeSefazService implements SefazService {
  @override
  Future<SefazResult> transmitir({
    required String chaveAcesso,
    required String modelo,
    required int serie,
    required int numero,
    required String tpEmis,
  }) async {
    final base = DateTime.now().microsecondsSinceEpoch.toString();
    final protocolo = ('135$base').padRight(15, '0').substring(0, 15);
    return SefazResult(status: 'AUTORIZADO', protocolo: protocolo);
  }
}
