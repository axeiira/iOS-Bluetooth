import 'dart:async';
import 'dart:convert'; // Pastikan ini di-import
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/database_helper.dart';

class DevicePage extends StatefulWidget {
  final BluetoothDevice device;
  const DevicePage({super.key, required this.device});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<int>>? _dataSubscription;
  Map<String, dynamic>? _lastReceivedData;
  int _savedDataCount = 0; // Tidak terpakai di sini, tapi dipertahankan
  BluetoothConnectionState _connectionState = BluetoothConnectionState.connecting;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
        if (state == BluetoothConnectionState.connected) {
          _discoverServicesAndSubscribe();
        }
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  // FUNGSI BARU UNTUK DISCONNECT MANUAL
  Future<void> _disconnectDevice() async {
    _dataSubscription?.cancel(); // Hentikan langganan data dulu
    _stateSubscription?.cancel(); // Hentikan langganan state
    await widget.device.disconnect();
    if(mounted) {
      // Kembali ke halaman sebelumnya setelah disconnect
      Navigator.of(context).pop();
    }
  }

  // Fungsi ini perlu diisi atau diimplementasikan agar dapat digunakan
  void _discoverServicesAndSubscribe() async {
    // Implementasi untuk menemukan layanan dan karakteristik
    // Kemudian berlangganan karakteristik yang mengirim data.
    // Contoh:
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (BluetoothService service in services) {
        // Cari service yang relevan (misal, service UUID tertentu)
        // dan karakteristik di dalamnya
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            await characteristic.setNotifyValue(true);
            _dataSubscription = characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                // Asumsikan data adalah string JSON
                try {
                  String dataString = utf8.decode(value);
                  _onDataReceived(dataString);
                } catch (e) {
                  print("Error decoding data: $e");
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print("Error discovering services: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to discover services: $e")));
      }
    }
  }

  void _onDataReceived(String dataString) async {
    try {
      final Map<String, dynamic> jsonData = jsonDecode(dataString);
      // Contoh validasi data (sesuaikan dengan format data ESP32 Anda)
      if (jsonData.containsKey('latitude') &&
          jsonData.containsKey('longitude') &&
          jsonData.containsKey('speed') &&
          jsonData.containsKey('heading') &&
          jsonData.containsKey('fuel') &&
          jsonData.containsKey('engine_hours') &&
          jsonData.containsKey('ignition_status')) {

        // Siapkan data untuk disimpan ke database
        final dataToSave = {
          'device_id': widget.device.remoteId.toString(),
          'timestamp': DateTime.now().toIso8601String(),
          'latitude': jsonData['latitude'],
          'longitude': jsonData['longitude'],
          'speed': jsonData['speed'],
          'heading': jsonData['heading'],
          'fuel': jsonData['fuel'],
          'engine_hours': jsonData['engine_hours'],
          'ignition_status': jsonData['ignition_status'],
        };

        await DatabaseHelper.instance.insertTelemetry(dataToSave);
        if (mounted) {
          setState(() {
            _lastReceivedData = jsonData;
            _savedDataCount++; // Update count, meskipun tidak ditampilkan
          });
        }
        print("Data saved: $jsonData");
      } else {
        print("Received incomplete or invalid JSON data: $dataString");
      }
    } catch (e) {
      print("Error processing data: $e | Data String: $dataString");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Mencegah pengguna menekan tombol kembali bawaan
      onWillPop: () async {
        // Tampilkan dialog konfirmasi
        bool shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Disconnect?"),
            content: const Text("Are you sure you want to disconnect from this device?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text("Disconnect"),
              ),
            ],
          ),
        ) ?? false; // Jika dialog ditutup tanpa pilihan, anggap 'false'
        if (shouldPop) {
          await _disconnectDevice();
        }
        return false; // Mencegah pop otomatis
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName.isNotEmpty ? widget.device.platformName : "Device Data"),
          // TOMBOL DISCONNECT EKSPLISIT
          actions: [
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnectDevice,
              tooltip: "Disconnect",
            )
          ],
        ),
        body: _buildContentView(),
      ),
    );
  }

  Widget _buildContentView() {
    switch (_connectionState) {
      case BluetoothConnectionState.connected:
        return _buildDataView();
      case BluetoothConnectionState.disconnected:
        return _buildDisconnectedView();
      default:
        return _buildConnectingView();
    }
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text("Status: ${_connectionState.toString().split('.').last}", style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          const Text("Device Disconnected", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Back to Scan Page"),
          )
        ],
      ),
    );
  }

  Widget _buildDataView() {
    if (_lastReceivedData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for first data point...', style: TextStyle(fontSize: 18)),
          ],
        ));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _lastReceivedData!.entries.map((entry) {
        return Card(
          child: ListTile(
            title: Text(entry.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(entry.value.toString(), style: const TextStyle(fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }
}