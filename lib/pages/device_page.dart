import 'dart:async';
import 'dart:convert';
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
  int _savedDataCount = 0;
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

  Future<void> _disconnectDevice() async {
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    await widget.device.disconnect();
    if(mounted) {
      Navigator.of(context).pop();
    }
  }

  void _discoverServicesAndSubscribe() async {
    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      for (BluetoothService service in services) {
        // Asumsi service UUID yang relevan adalah 6e400001-b5a3-f393-e0a9-e50e24dcca9e
        // Dan characteristic yang mengirim notifikasi adalah 6e400003-b5a3-f393-e0a9-e50e24dcca9e (RX Characteristic)
        // Ini sesuai dengan log Anda
        if (service.uuid.str.toLowerCase() == "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.str.toLowerCase() == "6e400003-b5a3-f393-e0a9-e50e24dcca9e" &&
                characteristic.properties.notify) {
              await characteristic.setNotifyValue(true);
              _dataSubscription = characteristic.value.listen((value) {
                if (value.isNotEmpty) {
                  try {
                    String dataString = utf8.decode(value);
                    _onDataReceived(dataString);
                  } catch (e) {
                    print("Error decoding data (UTF8): $e");
                  }
                }
              });
              return; // Langsung keluar setelah menemukan dan subscribe characteristic yang benar
            }
          }
        }
      }
      print("LOG: No suitable notification characteristic found.");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No suitable characteristic for data reception found.")),
        );
      }
    } catch (e) {
      print("LOG: Error discovering services: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to discover services: $e")));
      }
    }
  }


  // --- MODIFIKASI FUNGSI INI ---
  void _onDataReceived(String dataString) async {
    print("LOG: _onDataReceived received: $dataString");
    try {
      // Data format: FMC650_001,2025-07-09T10:30:40,-6.197700,106.820166,58,189,37.2,3962,0
      final List<String> parts = dataString.split(',');

      if (parts.length == 9) { // Pastikan jumlah bagian sesuai
        final String deviceName = parts[0];
        final String timestamp = parts[1];
        final double latitude = double.parse(parts[2]);
        final double longitude = double.parse(parts[3]);
        final int speed = int.parse(parts[4]);
        final int heading = int.parse(parts[5]);
        final double fuel = double.parse(parts[6]);
        final double engineHours = double.parse(parts[7]);
        final int ignitionStatus = int.parse(parts[8]);

        final Map<String, dynamic> parsedData = {
          'device_name': deviceName,
          'timestamp': timestamp,
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'heading': heading,
          'fuel': fuel,
          'engine_hours': engineHours,
          'ignition_status': ignitionStatus,
        };

        // Siapkan data untuk disimpan ke database
        final dataToSave = {
          'device_id': widget.device.remoteId.str, // Gunakan remoteId.str
          'timestamp': timestamp,
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'heading': heading,
          'fuel': fuel,
          'engine_hours': engineHours,
          'ignition_status': ignitionStatus,
        };

        await DatabaseHelper.instance.insertTelemetry(dataToSave);
        if (mounted) {
          setState(() {
            _lastReceivedData = parsedData; // Gunakan parsedData untuk tampilan
            _savedDataCount++; // Update count, meskipun tidak ditampilkan
          });
        }
        print("LOG: Data saved and UI updated: $parsedData");
      } else {
        print("LOG: Received data has incorrect number of parts: $dataString");
      }
    } catch (e) {
      print("LOG: Error parsing data: $e | Data String: $dataString");
    }
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
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
        ) ?? false;
        if (shouldPop) {
          await _disconnectDevice();
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName.isNotEmpty ? widget.device.platformName : "Device Data"),
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
        String displayValue = entry.value.toString();
        if (entry.key == 'ignition_status') {
          displayValue = entry.value == 1 ? 'ON' : 'OFF';
        }
        return Card(
          child: ListTile(
            title: Text(entry.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(displayValue, style: const TextStyle(fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }
}