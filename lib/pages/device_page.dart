import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import '../utils/database_helper.dart';

class DevicePage extends StatefulWidget {
  final BluetoothDevice? device;

  const DevicePage({super.key, this.device});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  StreamSubscription<BluetoothDeviceState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _dataSubscription;
  Map<String, dynamic>? _lastReceivedData;
  int _savedDataCount = 0;
  bool get _isSimulationMode => widget.device == null;

  @override
  void initState() {
    super.initState();
    if (!_isSimulationMode) {
      _connectionStateSubscription = widget.device!.state.listen((state) { 
        if (state == BluetoothDeviceState.connected) {
          _discoverServicesAndSubscribe();
        }
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _dataSubscription?.cancel();
    if (!_isSimulationMode) {
      widget.device!.disconnect(); 
    }
    super.dispose();
  }

  void _discoverServicesAndSubscribe() async {
    try {
      final services = await widget.device!.discoverServices(); 
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.notify) {
            await characteristic.setNotifyValue(true);
            
            _dataSubscription = characteristic.value.listen((value) {
              final dataString = String.fromCharCodes(value);
              _onDataReceived(dataString);
            });

            return;
          }
        }
      }
    } catch (e) {
      print("Error discovering services: $e");
    }
  }

  void _onDataReceived(String dataString) async {
    if (dataString.isEmpty) return;

    final parts = dataString.split(',');
    if (parts.length >= 8) {
      final dataMap = {
        'device_id': parts[0],
        'timestamp': parts[1],
        'latitude': double.tryParse(parts[2]) ?? 0.0,
        'longitude': double.tryParse(parts[3]) ?? 0.0,
        'speed': double.tryParse(parts[4]) ?? 0.0,
        'fuel': double.tryParse(parts[5]) ?? 0.0,
        'engine_hours': double.tryParse(parts[6]) ?? 0.0,
        'ignition': (parts[7] == '1' ? 1 : 0),
      };

      await DatabaseHelper.instance.insertTelemetry(dataMap);
      if (mounted) {
        setState(() {
          _lastReceivedData = dataMap;
          _savedDataCount++;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Data point berhasil disimpan!"),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green));
      }
    }
  }

  void _generateAndProcessFakeData() {
    final random = Random();
    final now = DateTime.now();
    
    String fakeCsv = [
      "FMC_SIM_001",
      now.toIso8601String(),
      (-6.0 + random.nextDouble()).toStringAsFixed(6),
      (106.0 + random.nextDouble()).toStringAsFixed(6),
      random.nextInt(100).toString(),
      (30.0 + random.nextDouble() * 20).toStringAsFixed(1),
      (1500.0 + random.nextDouble() * 100).toStringAsFixed(1),
      random.nextBool() ? "1" : "0"
    ].join(',');

    print("Generated Fake Data: $fakeCsv");
    _onDataReceived(fakeCsv);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSimulationMode ? "Mode Simulasi Data" : widget.device!.name), 
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 16.0), child: Text("Tersimpan: $_savedDataCount")))
        ],
      ),
      floatingActionButton: (kDebugMode && _isSimulationMode)
          ? FloatingActionButton.extended(
              onPressed: _generateAndProcessFakeData,
              label: const Text("Generate Data"),
              icon: const Icon(Icons.add_circle),
            )
          : null,
      body: _isSimulationMode ? _buildDataView() : _buildRealDeviceView(),
    );
  }
  
  Widget _buildRealDeviceView() {
    return StreamBuilder<BluetoothDeviceState>(
        stream: widget.device!.state,
        initialData: BluetoothDeviceState.connecting,
        builder: (c, snapshot) {
          if (snapshot.data == BluetoothDeviceState.connected) {
            return _buildDataView();
          }
          return Center(child: Text("Status: ${snapshot.data.toString().split('.').last}"));
        },
      );
  }
  
  Widget _buildDataView() {
    if (_lastReceivedData == null) {
      return Center(child: Text(
        _isSimulationMode ? 'Tekan tombol "Generate Data" untuk memulai.' : 'Menunggu data dari perangkat...', 
        style: const TextStyle(fontSize: 18)
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