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
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription; // Tambahkan ini
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown; // Tambahkan ini

  @override
  void initState() {
    super.initState();

    // Langganan untuk hasil scan
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        try {
          setState(() {
            _scanResults = results;
            final fmcResults = results
                .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("FMC"))
                .toList();

            if (fmcResults.isNotEmpty) {
              final firstResult = fmcResults.first;
              print("--- [DEBUG] FMC DEVICE DETECTED ---");
              print("Nama Perangkat: 'irstResult.device.platformName}'");
              print("ID Remote: irstResult.device.remoteId");
              print("RSSI: irstResult.rssi");
              print("Data Advertisement: irstResult.advertisementData");
              print("---------------------------------");
            }
          });
        } catch (e, stack) {
          print('[ERROR] Exception in scanResults listener: $e');
          print(stack);
          // Optionally show a snackbar or error widget
        }
      }
    });

    // Langganan untuk status scanning
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {
          _isScanning = state;
        });
      }
    });

    // Langganan untuk status adapter Bluetooth (penting!)
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _adapterState = state;
        });
        // Jika Bluetooth sudah hidup, dan kita tidak sedang scanning, mulai scan otomatis
        if (state == BluetoothAdapterState.on && !_isScanning) {
          // Hanya start scan otomatis jika tidak ada hasil sebelumnya
          // atau jika ini adalah scan pertama kali setelah aplikasi dibuka.
          // Pertimbangkan logika yang lebih canggih jika perlu.
          // Untuk saat ini, kita akan selalu mencoba startScan() jika adapter ON.
          // Ini mungkin menyebabkan scan berulang jika HomePage selalu di-rebuild
          // tetapi biasanya initState hanya dipanggil sekali.
          // startScan(); // Opsional: jika ingin otomatis scan ketika bluetooth ON
        }
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _adapterStateSubscription?.cancel(); // Pastikan ini juga di-cancel
    super.dispose();
  }

  // Modifikasi startScan untuk memeriksa status adapter
  void startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      // Tampilkan pesan ke pengguna bahwa Bluetooth tidak aktif
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth is not ON. Please turn it on in your device settings.")),
      );
      return; // Hentikan fungsi jika Bluetooth tidak aktif
    }

    FlutterBluePlus.stopScan();
    setState(() {
      _scanResults = [];
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  void connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    bool dialogShown = false;
    try {
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
      dialogShown = true;
      print("[DEBUG] Attempting to connect to device: ${device.remoteId}");
      await device.connect(timeout: const Duration(seconds: 15));
      print("[DEBUG] Device connected, navigating to DevicePage");
      if (!mounted) {
        if (dialogShown) Navigator.pop(context);
        return;
      }
      if (dialogShown) Navigator.pop(context);
      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DevicePage(device: device)),
        );
      } catch (navError) {
        print("[ERROR] Navigation to DevicePage failed: $navError");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Navigation Failed: $navError")),
        );
      }
    } catch (e) {
      print("[ERROR] Connection failed: $e");
      if (dialogShown && mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection Failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Scanner'),
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: () {
          startScan();
          return Future.delayed(const Duration(seconds: 5)); // Pertimbangkan durasi ini
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
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
                            : "Bluetooth is OFF"), // Tampilkan status Bluetooth
                    subtitle: Text(_isScanning
                        ? "Looking for FMC devices."
                        : _adapterState == BluetoothAdapterState.on
                            ? "Pull down or use the button to scan."
                            : "Please turn on Bluetooth to scan."), // Instruksi berdasarkan status
                  ),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              _buildResultsView(),
            ],
          ),
        ),
      ),
      floatingActionButton: _isScanning
          ? FloatingActionButton(
              onPressed: () => FlutterBluePlus.stopScan(),
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop, color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: _adapterState == BluetoothAdapterState.on ? startScan : null, // Disable jika Bluetooth OFF
              backgroundColor: _adapterState == BluetoothAdapterState.on ? Theme.of(context).primaryColor : Colors.grey,
              child: const Icon(Icons.search, color: Colors.white),
            ),
    );
  }

  // ... (metode _buildResultsView, _buildRssiIcon, _buildDeviceTile, _buildNoDeviceMessage tetap sama)
  Widget _buildResultsView() {
    final fmcResults = _scanResults
        .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("FMC"))
        .toList();

    // --- TAMBAHKAN INI ---
    // Batasi jumlah perangkat yang ditampilkan untuk debugging
    final int maxDisplayCount = 5; // Tampilkan hanya 5 perangkat pertama
    final List<ScanResult> displayedFmcResults = fmcResults.take(maxDisplayCount).toList();
    // --- AKHIR TAMBAH ---

    if (_isScanning && displayedFmcResults.isEmpty) { // Ubah fmcResults menjadi displayedFmcResults
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Text("Scanning..."),
        ),
      );
    }
    if (!_isScanning && displayedFmcResults.isEmpty) { // Ubah fmcResults menjadi displayedFmcResults
      return _buildNoDeviceMessage();
    }
    return ListView.builder(
      itemCount: displayedFmcResults.length, // Ubah fmcResults menjadi displayedFmcResults
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => _buildDeviceTile(displayedFmcResults[index]), // Ubah fmcResults menjadi displayedFmcResults
    );
  }

  Widget _buildRssiIcon(int rssi) {
    IconData iconData;
    if (rssi > -65) iconData = Icons.network_wifi;
    else if (rssi > -80) iconData = Icons.network_wifi_3_bar;
    else if (rssi > -95) iconData = Icons.network_wifi_2_bar;
    else iconData = Icons.network_wifi_1_bar;
    return Icon(iconData, color: Theme.of(context).colorScheme.primary);
  }

  Widget _buildDeviceTile(ScanResult result) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: _buildRssiIcon(result.rssi),
      title: const Text("FMC Device Found", style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(result.device.remoteId.toString()),
      trailing: ElevatedButton(
        onPressed: () => connectToDevice(result.device),
        child: const Text("Connect"),
      ),
    );
  }

  Widget _buildNoDeviceMessage() {
    // Tampilkan pesan yang lebih informatif jika Bluetooth OFF
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