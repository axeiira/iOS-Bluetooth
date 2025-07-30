import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  final String instruction;
  const QrScannerPage({super.key, required this.instruction});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _isScanProcessed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (!_isScanProcessed && mounted) {
                  setState(() {
                    _isScanProcessed = true;
                  });

                  final barcode = capture.barcodes.firstOrNull;
                  if (barcode?.rawValue != null) {
                    Navigator.pop(context, barcode!.rawValue);
                  } else {
                     setState(() {
                      _isScanProcessed = false;
                    });
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(widget.instruction, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}