import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_page.dart';
import 'dart:async';

class ScanPage extends StatefulWidget {
  final Function(int) navigateToTab;

  const ScanPage({super.key, required this.navigateToTab});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _scanResults = results);
    });
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) setState(() => _isScanning = state);
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  void _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    // Tampilkan dialog loading
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog loading

      final bool syncCompleted = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DevicePage(device: device)),
      ) ?? false;

      if (syncCompleted && mounted) {
        widget.navigateToTab(2); // Pindah ke tab History (index 2)
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Devices"),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop_circle_outlined : Icons.replay_circle_filled_outlined),
            onPressed: _isScanning ? () => FlutterBluePlus.stopScan() : _startScan,
            tooltip: _isScanning ? "Stop Scan" : "Rescan",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _startScan,
        child: _buildDeviceList(),
      ),
    );
  }

  Widget _buildDeviceList() {
    final gpsResults = _scanResults
        .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("GPS"))
        .toList();

    if (_isScanning && gpsResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (gpsResults.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.devices_other, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                const Text("No Devices Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text("Pull down to refresh or tap the icon above.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: gpsResults.length,
      itemBuilder: (context, index) {
        final result = gpsResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.bluetooth)),
            title: Text(result.device.platformName),
            subtitle: Text(result.device.remoteId.str),
            trailing: Text("${result.rssi} dBm"),
            onTap: () => _connectToDevice(result.device),
          ),
        );
      },
    );
  }
}