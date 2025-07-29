import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/database_helper.dart';

class DevicePage extends StatefulWidget {
  final BluetoothDevice? device;
  final bool isSimulation;

  const DevicePage({super.key, this.device, this.isSimulation = false})
      : assert(device != null || isSimulation, 'Device must be provided if not in simulation mode');

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  static const String serviceUuid = "a4776da1-39a6-4672-bf52-36f7bde4933f";
  static const String characteristicUuid = "a4776da2-39a6-4672-bf52-36f7bde4933f";

  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<int>>? _dataSubscription;
  Timer? _simulationTimer;

  BluetoothConnectionState _connectionState = BluetoothConnectionState.connecting;
  String _syncStatusMessage = "Initializing...";
  int _recordsReceivedCount = 0;
  bool _isSyncing = false;
  bool _syncCompleted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isSimulation) {
      _startSimulation();
    } else {
      _stateSubscription = widget.device!.connectionState.listen((state) {
        if (mounted) {
          setState(() => _connectionState = state);
          if (state == BluetoothConnectionState.connected) {
            _discoverServicesAndInitiateSync();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    setState(() {
      _connectionState = BluetoothConnectionState.connected;
      _isSyncing = true;
      _syncCompleted = false;
      _recordsReceivedCount = 0;
      _syncStatusMessage = "Running Simulation...";
    });

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final random = Random();
      final lat = -6.2 + (random.nextDouble() * 0.1);
      final lon = 106.8 + (random.nextDouble() * 0.1);
      final alt = 50.0 + (random.nextDouble() * 50.0);

      final fakeJson = {
        "device_id": "SIM-DEVICE-01",
        "created_at": DateTime.now().toIso8601String(),
        "latitude": lat,
        "longitude": lon,
        "altitude": alt,
        "n_satellite": 8 + random.nextInt(5),
        "battery_percentage": 70 + random.nextInt(31),
        "event_tagging": random.nextBool(),
        "geofence_status": random.nextBool(),
      };
      
      _onDataReceived(utf8.encode(jsonEncode(fakeJson)));
      
      if (_recordsReceivedCount >= 10) {
        timer.cancel();
        _onDataReceived(utf8.encode("END:10"));
      }
    });
  }

  Future<void> _disconnectAndPop() async {
    _simulationTimer?.cancel();
    if (widget.device != null && widget.device!.isConnected) {
        await widget.device!.disconnect();
    }
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
      List<BluetoothService> services = await widget.device!.discoverServices();
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
    
    if (!dataString.contains(',')) {
      if (dataString.startsWith("END:")) {
        HapticFeedback.mediumImpact();

        final parts = dataString.split(':');
        final int sentCount = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        final bool isComplete = (sentCount == _recordsReceivedCount);

        setState(() {
          _isSyncing = false;
          _syncCompleted = true;
          if (isComplete) {
            _syncStatusMessage = "Success! All $sentCount records received.";
          } else {
            _syncStatusMessage = "Failed! Received $_recordsReceivedCount of $sentCount records. Please resync.";
          }
        });

      } else {
        print("REAL: Ignoring non-data message: '$dataString'");
      }
      return;
    }
    
    final parts = dataString.split(',');
    if (parts.length >= 9) {
      final dataToSave = {
        'device_id': parts[0].trim(),
        'timestamp': parts[1].trim(),
        'latitude': double.tryParse(parts[2]) ?? 0.0,
        'longitude': double.tryParse(parts[3]) ?? 0.0,
        'altitude': double.tryParse(parts[4]) ?? 0.0,
        'num_satellite': int.tryParse(parts[5]) ?? 0,
        'battery_percentage': int.tryParse(parts[6]) ?? 0,
        'tag_button': parts[7] == 'true',
        'geofence_status': parts[8] == 'true',
      };

      DatabaseHelper.instance.insertGpsData(dataToSave);

      if (mounted) {
        setState(() {
          _recordsReceivedCount++;
          if (_isSyncing) {
            _syncStatusMessage = "Receiving Data... ($_recordsReceivedCount)";
          }
        });
      }
    } else {
      print("REAL: Ignoring malformed CSV data: '$dataString'");
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
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isSimulation 
            ? "Device Simulation" 
            : widget.device?.platformName ?? "Device Sync"),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _disconnectAndPop,
          ),
        ),
        body: _buildContentView(),
      ),
    );
  }

  Widget _buildContentView() {
    if (_connectionState == BluetoothConnectionState.disconnected && !widget.isSimulation) {
      return _buildDisconnectedView();
    }
    if (_connectionState == BluetoothConnectionState.connecting && !widget.isSimulation) {
      return _buildConnectingView();
    }
    return _buildSyncView();
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
            if (!_isSyncing)
              ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Finish & Go Back"),
                  onPressed: _disconnectAndPop,
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