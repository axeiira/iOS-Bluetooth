import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_page.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onSyncComplete;

  const HomePage({super.key, required this.onSyncComplete});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  String _networkType = 'Unknown';
  String _networkStatus = 'Disconnected';
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _scanResults = results);
    });
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) setState(() => _isScanning = state);
    });
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) setState(() => _adapterState = state);
    });
    _updateNetworkInfo();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateNetworkInfo(results.first);
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateNetworkInfo([ConnectivityResult? result]) async {
    try {
      final ConnectivityResult connectivityResult = result ?? (await _connectivity.checkConnectivity()).first;
      String type = 'Unknown';
      String status = 'Disconnected';

      if (connectivityResult == ConnectivityResult.wifi) {
        type = 'WiFi';
        status = 'Connected';
      } else if (connectivityResult == ConnectivityResult.mobile) {
        type = 'Mobile Data';
        status = 'Connected';
      } else {
        type = connectivityResult.toString().split('.').last;
        status = 'Disconnected';
      }

      if (mounted) {
        setState(() {
          _networkType = type;
          _networkStatus = status;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _networkType = 'Error';
          _networkStatus = 'Disconnected';
        });
      }
    }
  }

  void startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth is not ON.")),
      );
      return;
    }
    await FlutterBluePlus.stopScan();
    setState(() => _scanResults = []);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  void connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Connecting...")],
        ),
      ),
    );
    try {
      await device.connect(timeout: const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog koneksi

      final bool syncCompleted = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DevicePage(device: device)),
      ) ?? false;

      if (syncCompleted) {
        widget.onSyncComplete();
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
        title: const Text('IoT Device Scanner'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: () {
          startScan();
          return Future.delayed(const Duration(seconds: 5));
        },
        child: Column(
          children: [
            _buildStatusRow(),
            const Divider(indent: 16, endIndent: 16),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                "Available Devices",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _buildDeviceList(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: _isScanning
          ? FloatingActionButton.extended(
              onPressed: () => FlutterBluePlus.stopScan(),
              label: const Text("Stop Scan"),
              icon: const Icon(Icons.stop),
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            )
          : FloatingActionButton.extended(
              onPressed: _adapterState == BluetoothAdapterState.on ? startScan : null,
              label: const Text("Scan Devices"),
              icon: const Icon(Icons.search),
              backgroundColor: _adapterState == BluetoothAdapterState.on ? Colors.indigo : Colors.grey,
              foregroundColor: Colors.white,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatusRow() {
    // bt status
    IconData btIcon;
    String btText;
    Color btColor;

    if (_adapterState == BluetoothAdapterState.on) {
      btIcon = Icons.bluetooth;
      btText = "ON";
      btColor = Colors.blue.shade700;
    } else {
      btIcon = Icons.bluetooth_disabled;
      btText = "OFF";
      btColor = Colors.grey.shade600;
    }

    // internet status
    IconData netIcon;
    String netText;
    Color netColor;

    if (_networkStatus == 'Connected') {
      netIcon = _networkType == 'WiFi' ? Icons.wifi : Icons.signal_cellular_alt;
      netText = _networkType;
      netColor = Colors.green.shade700;
    } else {
      netIcon = Icons.signal_cellular_off;
      netText = "Offline";
      netColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              Icon(btIcon, color: btColor),
              const SizedBox(width: 8),
              Text("Bluetooth: $btText", style: TextStyle(fontSize: 14, color: btColor, fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            children: [
              Icon(netIcon, color: netColor),
              const SizedBox(width: 8),
              Text("Network: $netText", style: TextStyle(fontSize: 14, color: netColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    final gpsResults = _scanResults
        .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("GPS"))
        .toList();

    if (_adapterState != BluetoothAdapterState.on) {
      return _buildInfoMessage(
        icon: Icons.bluetooth_disabled,
        message: "Bluetooth is OFF",
        subMessage: "Please turn on Bluetooth in your device settings.",
      );
    }

    if (_isScanning) {
       return _buildInfoMessage(
        icon: Icons.search,
        message: "Scanning for Devices...",
        subMessage: "Please wait.",
        showProgress: true,
      );
    }
    
    if (gpsResults.isEmpty) {
      return _buildInfoMessage(
        icon: Icons.devices_other,
        message: "No GPS Devices Found",
        subMessage: "Pull down to scan again.",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      itemCount: gpsResults.length,
      itemBuilder: (context, index) {
        final result = gpsResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: _buildRssiIcon(result.rssi),
            title: Text(
              result.device.platformName.isNotEmpty ? result.device.platformName : "Unknown Device",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("ID: ${result.device.remoteId.str}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => connectToDevice(result.device),
          ),
        );
      },
    );
  }

  Widget _buildRssiIcon(int rssi) {
    IconData iconData;
    if (rssi > -65) {
      iconData = Icons.signal_cellular_alt;
    } else if (rssi > -80) {
      iconData = Icons.signal_cellular_alt_2_bar;
    } else {
      iconData = Icons.signal_cellular_alt_1_bar;
    }
    return Icon(iconData, color: Theme.of(context).colorScheme.primary, size: 36);
  }

  Widget _buildInfoMessage({
    required IconData icon,
    required String message,
    required String subMessage,
    bool showProgress = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if(showProgress) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
          ] else ...[
            Icon(icon, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 20),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}