import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Tipo de conexão com a impressora térmica.
enum PrinterConnection { bluetooth, wifi, usb }

extension PrinterConnectionLabel on PrinterConnection {
  String get label => switch (this) {
        PrinterConnection.bluetooth => 'Bluetooth',
        PrinterConnection.wifi => 'Wi-Fi',
        PrinterConnection.usb => 'USB',
      };
}

/// Abstração de impressão térmica (ESC/POS).
abstract class PrinterService {
  bool get isAvailable;

  /// Último erro de impressão (null se o último envio deu certo).
  String? get lastError;

  /// Envia os bytes ESC/POS pela conexão escolhida. Para Wi-Fi, [host]/[port]
  /// indicam a impressora de rede. Retorna true em sucesso.
  Future<bool> printBytes(
    Uint8List bytes, {
    PrinterConnection connection = PrinterConnection.bluetooth,
    String? host,
    int? port,
  });
}

/// Impressão térmica ESC/POS.
/// - **Wi-Fi: REAL** — envia os bytes por socket TCP (porta padrão 9100,
///   "raw"/JetDirect), que é como impressoras de rede recebem ESC/POS.
/// - Bluetooth/USB: simulados por enquanto (dependem de plugin nativo).
class ThermalPrinterService implements PrinterService {
  String? _lastError;

  @override
  bool get isAvailable => true;

  @override
  String? get lastError => _lastError;

  @override
  Future<bool> printBytes(
    Uint8List bytes, {
    PrinterConnection connection = PrinterConnection.bluetooth,
    String? host,
    int? port,
  }) async {
    _lastError = null;
    switch (connection) {
      case PrinterConnection.wifi:
        return _printWifi(bytes, host, port ?? 9100);
      case PrinterConnection.bluetooth:
      case PrinterConnection.usb:
        debugPrint('[PrinterService] ${bytes.length} bytes via ${connection.label} (simulado).');
        return true;
    }
  }

  /// Impressão real em impressora de rede (ESC/POS sobre TCP).
  Future<bool> _printWifi(Uint8List bytes, String? host, int port) async {
    if (host == null || host.trim().isEmpty) {
      _lastError = 'IP da impressora não informado';
      return false;
    }
    Socket? socket;
    try {
      socket = await Socket.connect(host.trim(), port,
          timeout: const Duration(seconds: 6));
      socket.add(bytes);
      await socket.flush();
      // Dá tempo da impressora consumir os dados antes de fechar.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await socket.close();
      debugPrint('[PrinterService] DANFE enviado via Wi-Fi $host:$port.');
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[PrinterService] falha Wi-Fi $host:$port -> $e');
      return false;
    } finally {
      socket?.destroy();
    }
  }
}
