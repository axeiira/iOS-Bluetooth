import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_page.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  Timer? _debounceTimer;
  List<ScanResult> _latestScanResultsFromStream = [];

  @override
  void initState() {
    super.initState();
    print("LOG: HomePage initState called.");

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      print("LOG: Scan results received from FlutterBluePlus. Total: ${results.length}");
      _latestScanResultsFromStream = results;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        print("LOG: Debounce timer fired. Calling setState.");
        if (mounted) {
          setState(() {
            _scanResults = _latestScanResultsFromStream;
            final fmcResults = _scanResults
                .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("FMC"))
                .toList();

            if (fmcResults.isNotEmpty) {
              final firstResult = fmcResults.first;
              print("LOG: --- FMC DEVICE DETECTED (MANUAL DEBOUNCED) ---");
              print("LOG: Nama Perangkat: '${firstResult.device.platformName}'");
              print("LOG: ID Remote: ${firstResult.device.remoteId.str}"); 
              print("LOG: RSSI: ${firstResult.rssi}");
              print("LOG: Data Advertisement: ${firstResult.advertisementData}");
              print("LOG: ---------------------------------");
            } else {
              print("LOG: No FMC devices found after filter in debounced results.");
            }
          });
        }
      });
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      print("LOG: isScanning state changed to: $state");
      if (mounted) {
        setState(() {
          _isScanning = state;
        });
      }
    });

    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      print("LOG: Adapter state changed to: $state");
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
      }
    });
  }

  @override
  void dispose() {
    print("LOG: HomePage dispose called.");
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void startScan() async {
    print("LOG: startScan called.");
    if (_adapterState != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth is not ON. Please turn it on in your device settings.")),
      );
      print("LOG: Bluetooth is off, scan aborted.");
      return;
    }

    FlutterBluePlus.stopScan();
    print("LOG: FlutterBluePlus.stopScan() called.");
    setState(() {
      _scanResults = [];
      _latestScanResultsFromStream = [];
    });
    print("LOG: Starting scan for 10 seconds.");
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10)); 
  }

  void connectToDevice(BluetoothDevice device) async {
    print("LOG: Attempting to connect to device: ${device.platformName} (${device.remoteId.str})");
    await FlutterBluePlus.stopScan();
    print("LOG: Scan stopped before connection attempt.");
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
      print("LOG: Device connected successfully!");
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => DevicePage(device: device)));
    } catch (e) {
      print("LOG: Connection Failed: $e");
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    print("LOG: HomePage build method called. Current _isScanning: $_isScanning, _adapterState: $_adapterState");
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Data Collector (Scan)'),
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: _isScanning ? Colors.blue.shade50 : Colors.grey.shade100,
              elevation: 0,
              child: ListTile(
                leading: _isScanning
                    ? const CircularProgressIndicator()
                    : Icon(
                        _adapterState == BluetoothAdapterState.on ? Icons.info_outline_rounded : Icons.bluetooth_disabled,
                        color: _adapterState == BluetoothAdapterState.on ? null : Colors.red,
                      ),
                title: Text(_isScanning
                    ? "Scanning in Progress..."
                    : _adapterState == BluetoothAdapterState.on
                        ? "Ready to Scan"
                        : "Bluetooth is OFF"),
                subtitle: Text(_isScanning
                    ? "Looking for FMC devices."
                    : _adapterState == BluetoothAdapterState.on
                        ? "Pull down or use the button to scan."
                        : "Please turn on Bluetooth to scan."),
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                startScan();
                return Future.delayed(const Duration(seconds: 5));
              },
              child: _buildResultsView(),
            ),
          ),
        ],
      ),
      floatingActionButton: _isScanning
          ? FloatingActionButton(
              onPressed: () {
                FlutterBluePlus.stopScan();
                print("LOG: Stop Scan button pressed.");
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop, color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: _adapterState == BluetoothAdapterState.on ? startScan : null,
              backgroundColor: _adapterState == BluetoothAdapterState.on ? Theme.of(context).colorScheme.primary : Colors.grey,
              child: const Icon(Icons.search, color: Colors.white),
            ),
    );
  }

  Widget _buildResultsView() {
    print("LOG: _buildResultsView called.");
    final fmcResults = _scanResults
        .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("FMC"))
        .toList();

    print("LOG: _buildResultsView - _scanResults count: ${_scanResults.length}");
    print("LOG: _buildResultsView - fmcResults count: ${fmcResults.length}");
    if (fmcResults.isNotEmpty) {
      print("LOG: _buildResultsView - First FMC device: ${fmcResults.first.device.platformName}");
    }


    if (_isScanning && fmcResults.isEmpty) {
      print("LOG: _buildResultsView - Showing 'Scanning...' message.");
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Text("Scanning...", style: TextStyle(fontSize: 18, color: Colors.grey)),
        ),
      );
    }
    if (!_isScanning && fmcResults.isEmpty) {
      print("LOG: _buildResultsView - Showing 'No device' message.");
      return _buildNoDeviceMessage();
    }

    print("LOG: _buildResultsView - Building SIMPLE COLORED ListView with ${fmcResults.length} items.");
    return ListView.builder(
      itemCount: fmcResults.length,
      itemBuilder: (context, index) {
        final result = fmcResults[index];
        print("LOG: Building a simple colored Container for device: ${result.device.platformName}");
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(15),
          color: Colors.deepOrange.shade100, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "NAMA: ${result.device.platformName.isNotEmpty ? result.device.platformName : "Unknown Device"}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
              ),
              Text(
                "ID: ${result.device.remoteId.str}",
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              Text(
                "RSSI: ${result.rssi}",
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              ElevatedButton(
                onPressed: () => connectToDevice(result.device),
                child: const Text("Connect"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDeviceMessage() {
    print("LOG: _buildNoDeviceMessage called. Adapter state: $_adapterState");
    if (_adapterState != BluetoothAdapterState.on) {
      return Container(
        padding: const EdgeInsets.all(48.0),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 80, color: Colors.red.shade400),
            const SizedBox(height: 20),
            const Text("Bluetooth is OFF", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 10),
            Text("Please turn on Bluetooth in your device settings to scan for devices.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(48.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          const Text("No FMC Devices Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Pull down to scan again.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}