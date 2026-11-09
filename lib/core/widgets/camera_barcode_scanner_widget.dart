import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Widget de câmera para leitura visual de códigos de barras (Mobile)
class CameraBarcodeScannerWidget extends StatelessWidget {
  final Function(String ean) onEanScanned;

  const CameraBarcodeScannerWidget({
    Key? key,
    required this.onEanScanned,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            onEanScanned(barcode.rawValue!);
            break;
          }
        }
      },
    );
  }
}