import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_strings.dart';
import '../utils/database_helper.dart';
import 'dart:io';

class ScanPage extends StatefulWidget {
  final Function(int) navigateToTab;
  const ScanPage({super.key, required this.navigateToTab});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _scanResults = results);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) setState(() => _isScanning = state);
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      Map<Permission, PermissionStatus> statuses;

      if (deviceInfo.version.sdkInt >= 31) {
        statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
      } else {
        statuses = await [
          Permission.location,
        ].request();
      }
      return statuses.values.every((status) => status.isGranted);
    }
    return true;
  }

  Future<void> _startScan() async {
    bool permissionsGranted = await _requestPermissions(); // minta izin

    if (!permissionsGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bluetooth and Location permissions are required to scan for devices.")),
        );
      }
      return;
    }

    // mulai scan
    HapticFeedback.lightImpact();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  void _stopScan() {
    HapticFeedback.lightImpact();
    FlutterBluePlus.stopScan();
  }
  
  void _showDeviceSyncPanel(BluetoothDevice device) {
    _stopScan();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DeviceSyncPanel(
        device: device,
        onSyncComplete: (bool didSync) {
          if (didSync && mounted) {
            Navigator.pop(context);
            widget.navigateToTab(3);
          } else if (mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.scanPageTitle),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: RefreshIndicator(
        onRefresh: _startScan,
        child: _buildDeviceList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? _stopScan : _startScan,
        shape: const CircleBorder(),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(child: child, scale: animation),
          child: _isScanning
              ? Icon(Icons.stop, key: UniqueKey())
              : Icon(Icons.search, key: UniqueKey()),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    final gpsResults = _scanResults
        .where((r) => r.device.platformName.isNotEmpty && r.device.platformName.startsWith("GPS"))
        .toList();

    if (gpsResults.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bluetooth_searching, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                const Text(
                  AppStrings.scanNoDevicesFound,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.scanTapToStart,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: gpsResults.length,
      itemBuilder: (context, index) {
        final result = gpsResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.bluetooth)),
            title: Text(result.device.platformName),
            subtitle: Text(result.device.remoteId.str),
            trailing: Text("${result.rssi} dBm"),
            onTap: () => _showDeviceSyncPanel(result.device),
          ),
        );
      },
    );
  }
}


class DeviceSyncPanel extends StatefulWidget {
  final BluetoothDevice device;
  final Function(bool) onSyncComplete;

  const DeviceSyncPanel({super.key, required this.device, required this.onSyncComplete});

  @override
  State<DeviceSyncPanel> createState() => _DeviceSyncPanelState();
}

class _DeviceSyncPanelState extends State<DeviceSyncPanel> {
  StreamSubscription<BluetoothConnectionState>? _stateSubscription;
  StreamSubscription<List<int>>? _dataSubscription;

  BluetoothConnectionState _connectionState = BluetoothConnectionState.connecting;
  String _statusMessage = AppStrings.deviceConnecting;
  int _recordsReceivedCount = 0;
  bool _isSyncing = false;
  bool _syncCompleted = false;

  @override
  void initState() {
    super.initState();
    _connectAndSync();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    if (widget.device.isConnected) {
      widget.device.disconnect();
    }
    super.dispose();
  }

  Future<void> _connectAndSync() async {
    _stateSubscription = widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
        if (state == BluetoothConnectionState.disconnected) {
           if (!_syncCompleted) {
            setState(() => _statusMessage = "Device disconnected unexpectedly.");
           }
        }
      }
    });

    try {
      await widget.device.connect(timeout: const Duration(seconds: 15));
      
      if (mounted && Platform.isAndroid) {
        await widget.device.requestMtu(512);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (mounted) {
        _discoverServicesAndInitiateSync();
      }
    } catch (e) {
      if(mounted) {
        setState(() => _statusMessage = AppStrings.deviceConnectionFailed);
      }
    }
  }

  Future<void> _discoverServicesAndInitiateSync() async {
    const String serviceUuid = "a4776da1-39a6-4672-bf52-36f7bde4933f";
    const String characteristicUuid = "a4776da2-39a6-4672-bf52-36f7bde4933f";

    setState(() {
      _isSyncing = true;
      _statusMessage = "Discovering services...";
    });

    try {
      List<BluetoothService> services = await widget.device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;
      for (var s in services) {
        if (s.uuid.str.toLowerCase() == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid.str.toLowerCase() == characteristicUuid) {
              targetCharacteristic = c;
              break;
            }
          }
        }
      }

      if (targetCharacteristic != null) {
        await targetCharacteristic.setNotifyValue(true);
        _dataSubscription = targetCharacteristic.value.listen(_onDataReceived, onError: (e) {
            if (mounted) setState(() => _statusMessage = "Error on data stream: $e");
        });
        setState(() => _statusMessage = "Requesting data from device...");
        await targetCharacteristic.write(utf8.encode("APP"), withoutResponse: true);
      } else {
        setState(() {
          _isSyncing = false;
          _statusMessage = AppStrings.deviceIncompatible;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = "Error: ${e.toString()}");
    }
  }

  void _onDataReceived(List<int> value) {
    if (value.isEmpty) return;
    String completeLine = utf8.decode(value, allowMalformed: true).trim();
    _processCompleteLine(completeLine);
  }

  void _processCompleteLine(String line) {
    if (line.startsWith("END:")) {
      HapticFeedback.mediumImpact();
      final parts = line.split(':');
      final int sentCount = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      final bool isComplete = (sentCount == _recordsReceivedCount);
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncCompleted = true;
          if (isComplete) {
            _statusMessage = "${AppStrings.deviceSyncComplete}\n$sentCount records received.";
          } else {
            _statusMessage = "${AppStrings.deviceSyncFailed}\nReceived $_recordsReceivedCount of $sentCount records.";
          }
        });
      }
      return;
    }
    
    final parts = line.split(',');
    // --- PERBAIKAN LOGIKA PARSING DI SINI ---
    // Terima data dengan 9 kolom (tanpa speed) atau 10 kolom (dengan speed)
    if (parts.length == 9 || parts.length == 10) {
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
        // Jika ada 10 kolom, ambil data speed. Jika tidak, beri nilai default 0.
        'speed': parts.length == 10 ? (int.tryParse(parts[9]) ?? 0) : 0,
      };
      DatabaseHelper.instance.insertGpsData(dataToSave);
      if (mounted) {
        setState(() {
          _recordsReceivedCount++;
          _statusMessage = AppStrings.deviceSyncingData;
        });
      }
    } else {
      print("Ignoring malformed or incomplete line: $line");
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData statusIcon = Icons.bluetooth_searching;
    Color iconColor = theme.colorScheme.primary;

    if (_syncCompleted) {
      statusIcon = Icons.check_circle_outline;
      iconColor = const Color(0xFF00796B); 
    } else if (_connectionState == BluetoothConnectionState.disconnected && !_syncCompleted) {
      statusIcon = Icons.error_outline;
      iconColor = theme.colorScheme.error;
    } else if (_isSyncing) {
       statusIcon = Icons.downloading_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(
            widget.device.platformName,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          if (_isSyncing)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 16),
                Text(
                  "$_recordsReceivedCount ${AppStrings.deviceRecordsReceived}",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                )
              ],
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => widget.onSyncComplete(_syncCompleted),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
