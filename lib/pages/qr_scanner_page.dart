import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatelessWidget {
  final String instruction;
  const QrScannerPage({super.key, required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  Navigator.pop(context, barcodes.first.rawValue);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(instruction, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}