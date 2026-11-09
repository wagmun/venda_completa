import 'package:flutter/services.dart';

/// Captura a digitação ultrarrápida de leitores ópticos físicos USB/Bluetooth (HID)
class PhysicalBarcodeScannerListener {
  final StringBuffer _buffer = StringBuffer();

  void handleKeyEvent(KeyEvent event, Function(String ean) onScanned) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final code = _buffer.toString().trim();
        if (code.isNotEmpty) {
          onScanned(code); // Dispara a busca do produto pelo EAN
          _buffer.clear();
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        _buffer.write(event.character);
      }
    }
  }
}