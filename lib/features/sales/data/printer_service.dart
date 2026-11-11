import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

/// Tipo de conexão com a impressora térmica.
enum PrinterConnection { bluetooth, wifi, usb }

extension PrinterConnectionLabel on PrinterConnection {
  String get label => switch (this) {
        PrinterConnection.bluetooth => 'Bluetooth',
        PrinterConnection.wifi => 'Wi-Fi',
        PrinterConnection.usb => 'USB',
      };
}

/// Impressora Bluetooth pareada no sistema.
class BtPrinter {
  final String name;
  final String mac;
  const BtPrinter(this.name, this.mac);
}

/// Abstração de impressão térmica (ESC/POS).
abstract class PrinterService {
  bool get isAvailable;

  /// Último erro de impressão (null se o último envio deu certo).
  String? get lastError;

  /// Envia os bytes ESC/POS pela conexão escolhida. Para Wi-Fi, [host]/[port]
  /// indicam a impressora de rede. Para Bluetooth, [btMac] é o endereço da
  /// impressora pareada. Retorna true em sucesso.
  Future<bool> printBytes(
    Uint8List bytes, {
    PrinterConnection connection = PrinterConnection.bluetooth,
    String? host,
    int? port,
    String? btMac,
  });

  /// Bluetooth está ligado no aparelho.
  Future<bool> bluetoothEnabled();

  /// Impressoras Bluetooth já pareadas no sistema.
  Future<List<BtPrinter>> pairedBluetoothPrinters();
}

/// Impressão térmica ESC/POS.
/// - **Wi-Fi: REAL** — envia os bytes por socket TCP (porta padrão 9100,
///   "raw"/JetDirect), que é como impressoras de rede recebem ESC/POS.
/// - **Bluetooth: REAL** — conecta na impressora pareada e escreve os bytes
///   (via print_bluetooth_thermal; Android/iOS).
/// - USB: simulado por enquanto (depende de plugin nativo).
class ThermalPrinterService implements PrinterService {
  String? _lastError;

  @override
  bool get isAvailable => true;

  @override
  String? get lastError => _lastError;

  /// Garante as permissões de Bluetooth em runtime (Android 12+).
  Future<bool> _ensureBtPermissions() async {
    if (!Platform.isAndroid) return true;
    final res = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    return res.values.every((s) => s.isGranted || s.isLimited);
  }

  @override
  Future<bool> bluetoothEnabled() async {
    try {
      if (!await _ensureBtPermissions()) {
        _lastError = 'Permissão de Bluetooth negada';
        return false;
      }
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BtPrinter>> pairedBluetoothPrinters() async {
    try {
      if (!await _ensureBtPermissions()) {
        _lastError = 'Permissão de Bluetooth negada';
        return const [];
      }
      final list = await PrintBluetoothThermal.pairedBluetooths;
      return list
          .map((b) => BtPrinter(b.name, b.macAdress))
          .toList(growable: false);
    } catch (e) {
      _lastError = e.toString();
      return const [];
    }
  }

  @override
  Future<bool> printBytes(
    Uint8List bytes, {
    PrinterConnection connection = PrinterConnection.bluetooth,
    String? host,
    int? port,
    String? btMac,
  }) async {
    _lastError = null;
    switch (connection) {
      case PrinterConnection.wifi:
        return _printWifi(bytes, host, port ?? 9100);
      case PrinterConnection.bluetooth:
        return _printBluetooth(bytes, btMac);
      case PrinterConnection.usb:
        debugPrint('[PrinterService] ${bytes.length} bytes via USB (simulado).');
        return true;
    }
  }

  /// Impressão real em impressora Bluetooth (ESC/POS).
  Future<bool> _printBluetooth(Uint8List bytes, String? mac) async {
    if (mac == null || mac.trim().isEmpty) {
      _lastError = 'Impressora Bluetooth não selecionada';
      return false;
    }
    try {
      final connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        final ok =
            await PrintBluetoothThermal.connect(macPrinterAddress: mac.trim());
        if (!ok) {
          _lastError = 'Não foi possível conectar à impressora Bluetooth';
          return false;
        }
      }
      final sent = await PrintBluetoothThermal.writeBytes(bytes.toList());
      if (!sent) {
        _lastError = 'Falha ao enviar para a impressora Bluetooth';
        return false;
      }
      debugPrint('[PrinterService] DANFE enviado via Bluetooth ($mac).');
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[PrinterService] falha Bluetooth $mac -> $e');
      return false;
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
