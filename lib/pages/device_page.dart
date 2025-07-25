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
  static const String serviceUuid = "a4776da1-39a6-4672-bf52-36f7bde4933f";
  static const String characteristicUuid = "a4776da2-39a6-4672-bf52-36f7bde4933f";

  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<int>>? _dataSubscription;

  BluetoothConnectionState _connectionState = BluetoothConnectionState.connecting;
  
  String _syncStatusMessage = "Connecting to device...";
  int _recordsReceivedCount = 0;
  bool _isSyncing = false;
  bool _syncCompleted = false;

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
        if (state == BluetoothConnectionState.connected) {
          _discoverServicesAndInitiateSync();
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

  Future<void> _disconnectAndPop() async {
    await widget.device.disconnect();
    if (mounted) {
      Navigator.of(context).pop(_syncCompleted);
    }
  }

  void _discoverServicesAndInitiateSync() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncCompleted = false;
      _recordsReceivedCount = 0;
      _syncStatusMessage = "Discovering services...";
    });

    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      for (BluetoothService service in services) {
        if (service.uuid.str.toLowerCase() == serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.str.toLowerCase() == characteristicUuid) {
              targetCharacteristic = characteristic;
              break;
            }
          }
        }
        if (targetCharacteristic != null) break;
      }

      if (targetCharacteristic != null) {
        await targetCharacteristic.setNotifyValue(true);
        _dataSubscription = targetCharacteristic.value.listen(_onDataReceived, onError: (e) {
            setState(() {
              _isSyncing = false;
              _syncStatusMessage = "Error on data stream: $e";
            });
        });
        
        setState(() => _syncStatusMessage = "Sending 'READY' command...");
        await targetCharacteristic.write(utf8.encode("READY"), withoutResponse: true);

      } else {
        setState(() {
          _isSyncing = false;
          _syncStatusMessage = "Target BLE service/characteristic not found.";
        });
      }
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncStatusMessage = "Error during service discovery: $e";
      });
    }
  }

  void _onDataReceived(List<int> value) {
    if (value.isEmpty) return;

    try {
      String dataString = utf8.decode(value).trim();
      
      if (!dataString.startsWith('{') || !dataString.endsWith('}')) {
        if (dataString.startsWith("END:")) {
          setState(() {
            _isSyncing = false;
            _syncCompleted = true;
            _syncStatusMessage = "Sync Complete!";
          });
        } else {
          print("REAL: Ignoring non-JSON data: '$dataString'");
        }
        return;
      }
      
      final Map<String, dynamic> jsonData = jsonDecode(dataString);
      
      final dataToSave = {
        'device_id': jsonData['device_id'],
        'timestamp': jsonData['created_at'],
        'latitude': jsonData['latitude'],
        'longitude': jsonData['longitude'],
        'altitude': jsonData['altitude'],
        'num_satellite': jsonData['n_satellite'],
        'battery_percentage': jsonData['battery_percentage'],
        'tag_button': jsonData['event_tagging'],
        'geofence_status': jsonData['geofence_status'],
      };

      DatabaseHelper.instance.insertGpsData(dataToSave);

      if (mounted) {
        setState(() {
          _recordsReceivedCount++;
          _syncStatusMessage = "Receiving Data...";
        });
      }
    } catch (e) {
      print("REAL: Error parsing data: $e | Raw data string: '${utf8.decode(value).trim()}'");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _disconnectAndPop();
        return false; // Mencegah pop otomatis, karena kita sudah handle manual
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName.isNotEmpty ? widget.device.platformName : "Device Sync"),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _disconnectAndPop,
          ),
        ),
        body: _buildContentView(_connectionState),
      ),
    );
  }

  Widget _buildContentView(BluetoothConnectionState connectionState) {
    switch (connectionState) {
      case BluetoothConnectionState.connected:
        return _buildSyncView();
      case BluetoothConnectionState.disconnected:
        return _buildDisconnectedView();
      default:
        return _buildConnectingView();
    }
  }
  
  Widget _buildSyncView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSyncing)
              const CircularProgressIndicator()
            else
              Icon(
                _syncCompleted ? Icons.check_circle_outline : Icons.info_outline,
                color: _syncCompleted ? Colors.green : Colors.blue,
                size: 80,
              ),
            const SizedBox(height: 20),
            Text(
              _syncStatusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                child: Column(
                  children: [
                    Text(
                      _recordsReceivedCount.toString(),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _syncCompleted ? "Total Records Received" : "Records Received",
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_syncCompleted)
              ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Back to Scan Page"),
                  onPressed: _disconnectAndPop,
              )
            else if (!_isSyncing)
              ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text("Resync Data"),
                  onPressed: _discoverServicesAndInitiateSync,
              )
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_syncStatusMessage, style: const TextStyle(fontSize: 18)),
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
            onPressed: () => Navigator.of(context).pop(_syncCompleted),
            child: const Text("Back to Scan Page"),
          )
        ],
      ),
    );
  }
}