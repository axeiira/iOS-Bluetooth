import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_page.dart';
import 'dart:async';

class ScanPage extends StatefulWidget {
  final Function(int) navigateToTab;
  const ScanPage({super.key, required this.navigateToTab});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _scanResults = results);
    });
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) setState(() => _isScanning = state);
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _animationController.dispose();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    HapticFeedback.lightImpact();
    _animationController.reset();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }
  
  void _stopScan() {
    HapticFeedback.lightImpact();
    FlutterBluePlus.stopScan();
  }

  void _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    showDialog(context: context, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context);

      final bool syncCompleted = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DevicePage(device: device)),
      ) ?? false;

      if (syncCompleted && mounted) {
        widget.navigateToTab(3); // Pindah ke tab History (index 3)
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Failed: $e")));
    }
  }

  Widget _buildRssiIndicator(int rssi) {
    IconData icon;
    Color color;
    if (rssi > -65) {
      icon = Icons.signal_cellular_alt_rounded;
      color = Colors.green;
    } else if (rssi > -80) {
      icon = Icons.signal_cellular_alt_2_bar_rounded;
      color = Colors.orange;
    } else {
      icon = Icons.signal_cellular_alt_1_bar_rounded;
      color = Colors.red.shade400;
    }
    return Icon(icon, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Devices")),
      body: RefreshIndicator(onRefresh: _startScan, child: _buildDeviceList()),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        shape: const CircleBorder(),
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }

  Widget _buildDeviceList() {
    final gpsResults = _scanResults
        .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("GPS"))
        .toList();

    if (gpsResults.isNotEmpty) {
      _animationController.forward();
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
                Text("Tap the scan button to start.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
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
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.bluetooth)),
                title: Text(result.device.platformName),
                subtitle: Text(result.device.remoteId.str),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRssiIndicator(result.rssi),
                    const SizedBox(width: 8),
                    Text("${result.rssi} dBm", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                onTap: () => _connectToDevice(result.device),
              ),
            ),
          ),
        );
      },
    );
  }
}