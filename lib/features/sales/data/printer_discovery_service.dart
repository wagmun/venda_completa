import 'dart:io';

/// Impressora encontrada na rede.
class DiscoveredPrinter {
  final String host;
  final int port;
  DiscoveredPrinter(this.host, this.port);
}

/// Descobre impressoras de rede varrendo a sub-rede local na porta de impressão
/// (9100 = ESC/POS "raw"/JetDirect). Não exige permissão especial nem plugin:
/// tenta conectar em cada host; quem aceita na 9100 é candidato a impressora.
class PrinterDiscoveryService {
  Future<List<DiscoveredPrinter>> scan({
    int port = 9100,
    Duration timeout = const Duration(milliseconds: 350),
  }) async {
    final prefix = await _localSubnetPrefix();
    if (prefix == null) return [];

    final found = <DiscoveredPrinter>[];
    final futures = <Future<void>>[];
    for (var i = 1; i <= 254; i++) {
      final host = '$prefix.$i';
      futures.add(() async {
        try {
          final s = await Socket.connect(host, port, timeout: timeout);
          s.destroy();
          found.add(DiscoveredPrinter(host, port));
        } catch (_) {/* host sem impressora na porta */}
      }());
    }
    await Future.wait(futures);
    found.sort((a, b) => a.host.compareTo(b.host));
    return found;
  }

  /// Prefixo /24 da rede local (ex.: "192.168.0").
  Future<String?> _localSubnetPrefix() async {
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (!addr.isLoopback &&
            (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                ip.startsWith('172.'))) {
          final p = ip.split('.');
          return '${p[0]}.${p[1]}.${p[2]}';
        }
      }
    }
    return null;
  }
}
