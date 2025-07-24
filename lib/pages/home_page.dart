import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_page.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

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
    print("REAL: HomePage initState called.");

    // Langganan untuk hasil scan nyata
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      print("REAL: Scan results received from FlutterBluePlus. Total: ${results.length}");
      if (mounted) {
        setState(() {
          _scanResults = results; // Update dengan hasil scan nyata
        });
        // Logging perangkat FMC yang terdeteksi secara real-time
        final fmcResults = results
            .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("FMC"))
            .toList();
        if (fmcResults.isNotEmpty) {
          final firstResult = fmcResults.first;
          print("REAL: --- FMC DEVICE DETECTED ---");
          print("REAL: Nama Perangkat: '${firstResult.device.platformName}'");
          print("REAL: ID Remote: ${firstResult.device.remoteId.str}");
          print("REAL: RSSI: ${firstResult.rssi}");
          print("REAL: Data Advertisement: ${firstResult.advertisementData}");
          print("REAL: ---------------------------------");
        }
      }
    });

    // Langganan untuk status scanning nyata
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      print("REAL: isScanning state changed to: $state");
      if (mounted) {
        setState(() {
          _isScanning = state;
        });
      }
    });

    // Langganan untuk status adapter Bluetooth nyata
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      print("REAL: Adapter state changed to: $state");
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
      }
    });

    // Inisialisasi dan mulai pembaruan info jaringan
    _updateNetworkInfo();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateNetworkInfo(results.first);
    });
  }

  @override
  void dispose() {
    print("REAL: HomePage dispose called.");
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
      } else if (connectivityResult == ConnectivityResult.none) {
        type = 'None';
        status = 'Disconnected';
      } else {
        type = connectivityResult.toString().split('.').last;
        status = 'Connected';
      }

      if (mounted) {
        setState(() {
          _networkType = type;
          _networkStatus = status;
        });
      }
    } catch (e) {
      print("REAL: Error getting network info: $e");
      if (mounted) {
        setState(() {
          _networkType = 'Error';
          _networkStatus = 'Disconnected';
        });
      }
    }
  }

  // Fungsi startScan akan memicu scan Bluetooth nyata
  void startScan() async {
    print("REAL: startScan called. Initiating real BLE scan.");
    if (_adapterState != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth is not ON. Please turn it on in your device settings.")),
      );
      print("REAL: Bluetooth is off, scan aborted.");
      return;
    }

    FlutterBluePlus.stopScan(); // Pastikan scan sebelumnya berhenti
    print("REAL: FlutterBluePlus.stopScan() called.");
    setState(() {
      _scanResults = []; // Kosongkan hasil sebelumnya
    });
    print("REAL: Starting real BLE scan for 10 seconds.");
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  // Fungsi connectToDevice akan mencoba koneksi Bluetooth nyata
  void connectToDevice(BluetoothDevice device) async {
    print("REAL: Attempting to connect to device: ${device.platformName} (${device.remoteId.str})");
    await FlutterBluePlus.stopScan(); // Hentikan scan sebelum koneksi
    print("REAL: Scan stopped before connection attempt.");
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
      print("REAL: Device connected successfully!");
      if (!mounted) return;
      Navigator.pop(context); // Tutup dialog koneksi
      Navigator.push(context, MaterialPageRoute(builder: (context) => DevicePage(device: device)));
    } catch (e) {
      print("REAL: Connection Failed: $e");
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    print("REAL: HomePage build method called. Current _isScanning: $_isScanning, _adapterState: $_adapterState");
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
            _buildScanStatusCard(context),
            _buildNetworkStatusCard(context),
            const Divider(indent: 16, endIndent: 16),
            Expanded(
              child: _buildDeviceList(),
            ),
            SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: _isScanning
          ? FloatingActionButton.extended(
              onPressed: () {
                FlutterBluePlus.stopScan();
                print("REAL: Stop Scan button pressed.");
              },
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

  Widget _buildScanStatusCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: _isScanning ? Colors.blue.shade50 : (_adapterState == BluetoothAdapterState.on ? Colors.green.shade50 : Colors.red.shade50),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isScanning ? const CircularProgressIndicator(strokeWidth: 2) : Icon(
                    _adapterState == BluetoothAdapterState.on ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isScanning ? "Scanning in Progress..." :
                    _adapterState == BluetoothAdapterState.on ? "Bluetooth Ready" : "Bluetooth OFF",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isScanning ? Theme.of(context).colorScheme.primary : (_adapterState == BluetoothAdapterState.on ? Colors.green.shade800 : Colors.red.shade800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isScanning ? "Looking for FMC devices." :
                _adapterState == BluetoothAdapterState.on ? "Pull down to scan or tap the button below." : "Please enable Bluetooth in your device settings.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkStatusCard(BuildContext context) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (_networkStatus == 'Connected') {
      icon = Icons.signal_cellular_alt;
      color = Colors.green.shade50;
      title = 'Network Connected';
      subtitle = 'Type: $_networkType';
    } else {
      icon = Icons.signal_cellular_off;
      color = Colors.red.shade50;
      title = 'Network Disconnected';
      subtitle = 'Status: $_networkStatus';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: color,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _networkStatus == 'Connected' ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    print("REAL: _buildDeviceList called.");
    final fmcResults = _scanResults
        .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("FMC"))
        .toList();

    print("REAL: _buildDeviceList - _scanResults count: ${_scanResults.length}");
    print("REAL: _buildDeviceList - fmcResults count: ${fmcResults.length}");
    if (fmcResults.isNotEmpty) {
      print("REAL: _buildDeviceList - First FMC device: ${fmcResults.first.device.platformName}");
    }

    if (_adapterState != BluetoothAdapterState.on) {
      print("REAL: _buildDeviceList - Bluetooth OFF message.");
      return _buildNoDeviceMessage(
        icon: Icons.bluetooth_disabled,
        message: "Bluetooth is OFF",
        subMessage: "Please turn on Bluetooth in your device settings.",
        iconColor: Colors.red.shade400,
        messageColor: Colors.red,
      );
    }

    if (_isScanning && fmcResults.isEmpty) {
      print("REAL: _buildDeviceList - Showing 'Searching...' message.");
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.indigo),
            SizedBox(height: 16),
            Text("Searching for FMC devices...", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    if (!_isScanning && fmcResults.isEmpty) {
      print("REAL: _buildDeviceList - Showing 'No device' message.");
      return _buildNoDeviceMessage(
        icon: Icons.bluetooth,
        message: "No FMC Devices Found",
        subMessage: "Pull down to scan again.",
        iconColor: Colors.grey.shade400,
        messageColor: Colors.black,
      );
    }

    print("REAL: _buildDeviceList - Building ListView with ${fmcResults.length} items.");
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      itemCount: fmcResults.length,
      itemBuilder: (context, index) {
        final result = fmcResults[index];
        print("REAL: Building device card for: ${result.device.platformName}");
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: InkWell(
            onTap: () => connectToDevice(result.device),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildRssiIcon(result.rssi),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.device.platformName.isNotEmpty ? result.device.platformName : "Unknown Device",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "ID: ${result.device.remoteId.str}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        Text(
                          "RSSI: ${result.rssi} dBm",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRssiIcon(int rssi) {
    IconData iconData;
    Color iconColor;
    if (rssi > -65) {
      iconData = Icons.signal_wifi_4_bar_rounded;
      iconColor = Colors.green;
    } else if (rssi > -80) {
      iconData = Icons.network_wifi_3_bar_rounded;
      iconColor = Colors.orange;
    } else if (rssi > -95) {
      iconData = Icons.wifi_2_bar;
      iconColor = Colors.red.shade300;
    } else {
      iconData = Icons.wifi_1_bar;
      iconColor = Colors.red.shade700;
    }
    return Icon(iconData, color: iconColor, size: 36);
  }

  Widget _buildNoDeviceMessage({
    required IconData icon,
    required String message,
    required String subMessage,
    required Color iconColor,
    required Color messageColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: iconColor),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: messageColor),
          ),
          const SizedBox(height: 10),
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
