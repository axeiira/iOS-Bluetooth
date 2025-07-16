import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'device_page.dart';
import 'data_log_page.dart';
import 'sync_page.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  final ValueNotifier<String> receivedDataNotifier = ValueNotifier('');

  void startScan() {
    setState(() {});
    flutterBlue.startScan(timeout: const Duration(seconds: 5));
  }

  void connectToDevice(BluetoothDevice device) async {
    flutterBlue.stopScan();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Menghubungkan...")],
        ),
      ),
    );
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DevicePage(device: device),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal terhubung: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IoT Data Collector')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                if (kDebugMode)
                  TextButton.icon(
                    icon: const Icon(Icons.bug_report),
                    label: const Text("Masuk Mode Simulasi"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DevicePage()),
                      );
                    },
                  ),
                StreamBuilder<bool>(
                  stream: flutterBlue.isScanning,
                  initialData: false,
                  builder: (c, snapshot) {
                    bool isScanning = snapshot.data ?? false;
                    return ElevatedButton.icon(
                      icon: isScanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.search),
                      label: Text(isScanning ? 'Mencari...' : 'Pindai Perangkat'),
                      onPressed: isScanning ? null : startScan,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: isScanning ? Colors.grey : Colors.blue, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 16)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.storage_rounded),
                  label: const Text("Lihat Log Data Tersimpan"),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DataLogPage())),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), textStyle: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text("Sinkronisasi ke Server"),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SyncPage())),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.green, foregroundColor: Colors.white, textStyle: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          const Divider(thickness: 1),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Perangkat Ditemukan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: flutterBlue.scanResults,
              initialData: const [],
              builder: (context, snapshot) {
                var results = snapshot.data!.where((r) => r.device.name.startsWith("FMC")).toList();
                return StreamBuilder<bool>(
                  stream: flutterBlue.isScanning,
                  initialData: false,
                  builder: (c, scanningSnapshot) {
                    bool isScanning = scanningSnapshot.data ?? false;
                    if (isScanning && results.isEmpty) return const Center(child: Text("Mencari perangkat FMC..."));
                    if (!isScanning && results.isEmpty) return _buildNoDeviceMessage();
                    return ListView.builder(itemCount: results.length, itemBuilder: (context, index) => _buildDeviceTile(results[index]));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRssiIcon(int rssi) {
    IconData iconData;
    Color iconColor;
    if (rssi > -65) {
      iconData = Icons.network_wifi;
      iconColor = Colors.green;
    } else if (rssi > -80) {
      iconData = Icons.network_wifi_3_bar;
      iconColor = Colors.lightGreen;
    } else if (rssi > -95) {
      iconData = Icons.network_wifi_2_bar;
      iconColor = Colors.orange;
    } else {
      iconData = Icons.network_wifi_1_bar;
      iconColor = Colors.red;
    }
    return Icon(iconData, color: iconColor);
  }

  Widget _buildDeviceTile(ScanResult result) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            _buildRssiIcon(result.rssi),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(result.device.id.id, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(onPressed: () => connectToDevice(result.device), child: const Text("Connect")),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDeviceMessage() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("Tidak Ada Perangkat Ditemukan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text("Tips:\n• Pastikan perangkat FMC Anda menyala.\n• Pastikan Bluetooth di ponsel Anda aktif.\n• Dekatkan ponsel ke perangkat.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}