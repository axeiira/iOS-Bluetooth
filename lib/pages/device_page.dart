import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/database_helper.dart';
import 'package:intl/intl.dart';

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
    print("REAL: DevicePage initState. Listening to real BLE data.");
    _stateSubscription = widget.device.connectionState.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
        print("REAL: Connection state changed to: $state");
        if (state == BluetoothConnectionState.connected) {
          _discoverServicesAndSubscribe();
        }
      }
    });
  }

  @override
  void dispose() {
    print("REAL: DevicePage dispose. Cancelling BLE subscriptions.");
    _stateSubscription?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _disconnectDevice() async {
    print("REAL: Disconnecting from device: ${widget.device.platformName}.");
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    await widget.device.disconnect();
    if(mounted) {
      Navigator.of(context).pop();
    }
  }

  void _discoverServicesAndSubscribe() async {
    if (_dataSubscription != null) {
      print("REAL: Data subscription already active, skipping _discoverServicesAndSubscribe call.");
      return;
    }
    
    try {
      print("REAL: Discovering services for ${widget.device.platformName}...");
      List<BluetoothService> services = await widget.device.discoverServices();
      bool subscribed = false;
      if (services.isEmpty) {
        print("REAL: No services found for ${widget.device.platformName}.");
      }
      for (BluetoothService service in services) {
        print("REAL: Found service: ${service.uuid.str}");
        if (service.uuid.str.toLowerCase() == "6e400001-b5a3-f393-e0a9-e50e24dcca9e") {
          print("REAL: Found target UART service: ${service.uuid.str}");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            print("REAL: Found characteristic: ${characteristic.uuid.str} (Properties: ${characteristic.properties})");
            if (characteristic.uuid.str.toLowerCase() == "6e400003-b5a3-f393-e0a9-e50e24dcca9e" &&
                characteristic.properties.notify) {
              print("REAL: Found target RX characteristic: ${characteristic.uuid.str}. Subscribing...");
              await characteristic.setNotifyValue(true);
              _dataSubscription = characteristic.value.listen((value) {
                print("REAL: Raw data received (bytes): $value");
                if (value.isNotEmpty) {
                  try {
                    String dataString = utf8.decode(value);
                    print("REAL: Decoded data string: '$dataString'");
                    _onDataReceived(dataString);
                  } catch (e) {
                    print("REAL: Error decoding data (UTF8): $e for bytes: $value");
                  }
                } else {
                  print("REAL: Received empty data value.");
                }
              }, onError: (e) {
                print("REAL: Error on characteristic value stream: $e");
              });
              subscribed = true;
              break;
            } else if (characteristic.uuid.str.toLowerCase() == "6e400003-b5a3-f393-e0a9-e50e24dcca9e" && !characteristic.properties.notify) {
              print("REAL: Found target RX characteristic but NOTIFY property is not enabled.");
            }
          }
          if (subscribed) break;
        }
      }
      if (!subscribed) {
        print("REAL: No suitable notification characteristic found for UART service (6e400001-b5a3-f393-e0a9-e50e24dcca9e) with RX characteristic (6e400003-b5a3-f393-e0a9-e50e24dcca9e) and NOTIFY property.");
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No suitable characteristic for data reception found. Check ESP32 firmware.")),
          );
        }
      }
    } catch (e) {
      print("REAL: Error discovering services: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to discover services: $e")));
      }
    }
  }

  void _onDataReceived(String dataString) async {
    print("REAL: _onDataReceived processing: '$dataString'");
    try {
      final String trimmedDataString = dataString.trim();
      
      if (!trimmedDataString.startsWith('{') || !trimmedDataString.endsWith('}')) {
        print("REAL: Received data is not a valid JSON string. Data: '$trimmedDataString'");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Received non-JSON data: '$trimmedDataString'")),
        );
        return;
      }

      final Map<String, dynamic> jsonData = jsonDecode(trimmedDataString);

      final String company = jsonData['company'] as String;
      final String deviceId = jsonData['device_id'] as String;
      final String createdAt = jsonData['created_at'] as String;
      final double latitude = (jsonData['latitude'] as num).toDouble();
      final double longitude = (jsonData['longitude'] as num).toDouble();
      final double altitude = (jsonData['altitude'] as num).toDouble();
      final int nSatellite = (jsonData['n_satellite'] as num).toInt();
      final int batteryPercentage = (jsonData['battery_percentage'] as num).toInt();
      final bool eventTagging = jsonData['event_tagging'] as bool;
      final bool geofenceStatus = jsonData['geofence_status'] as bool;

      final Map<String, dynamic> parsedData = {
        'company': company,
        'device_id': deviceId,
        'created_at': createdAt,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'n_satellite': nSatellite,
        'battery_percentage': batteryPercentage,
        'event_tagging': eventTagging,
        'geofence_status': geofenceStatus,
      };

      final dataToSave = {
        'company': company,
        'device_id': deviceId,
        'timestamp': createdAt,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'num_satellite': nSatellite,
        'battery_percentage': batteryPercentage,
        'tag_button': eventTagging,
        'geofence_status': geofenceStatus,
      };
      await DatabaseHelper.instance.insertGpsData(dataToSave);

      if (mounted) {
        setState(() {
          _lastReceivedData = parsedData;
          _savedDataCount++;
        });
      }
      print("REAL: Data parsed and UI updated: $parsedData");
    } catch (e) {
      print("REAL: Error parsing data: $e | Data String: '$dataString'");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error parsing data: $e")),
      );
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
          title: Text(
            widget.device.platformName.isNotEmpty ? widget.device.platformName : "Device Data",
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled_outlined),
              onPressed: _disconnectDevice,
              tooltip: "Disconnect",
            )
          ],
        ),
        body: _buildContentView(_connectionState),
      ),
    );
  }

  Widget _buildContentView(BluetoothConnectionState connectionState) {
    switch (connectionState) {
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
          Text("Status: Connecting...", style: const TextStyle(fontSize: 18)),
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

    IconData _getDataIcon(String key) {
      switch (key) {
        case 'company': return Icons.business;
        case 'device_id': return Icons.devices;
        case 'created_at': return Icons.access_time;
        case 'latitude': return Icons.location_on;
        case 'longitude': return Icons.location_on;
        case 'altitude': return Icons.height;
        case 'n_satellite': return Icons.satellite_alt;
        case 'battery_percentage': return Icons.battery_full;
        case 'event_tagging': return Icons.touch_app;
        case 'geofence_status': return Icons.map;
        default: return Icons.info_outline;
      }
    }

    String _formatValue(String key, dynamic value) {
      if (key == 'created_at') {
        try {
          final dateTime = DateTime.parse(value);
          return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
        } catch (e) {
          return value.toString();
        }
      }
      if (key == 'latitude' || key == 'longitude') {
        return '${value.toStringAsFixed(6)}°';
      }
      if (key == 'altitude') {
        return '${value.toStringAsFixed(2)} m';
      }
      if (key == 'n_satellite') {
        return '$value satelit';
      }
      if (key == 'battery_percentage') {
        return '$value%';
      }
      if (key == 'event_tagging') {
        return value ? 'Ditekan' : 'Tidak Ditekan';
      }
      if (key == 'geofence_status') {
        return value ? 'Di Dalam Geofence' : 'Di Luar Geofence';
      }
      return value.toString();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _lastReceivedData!.entries.map((entry) {
        if (entry.key == 'company' || entry.key == 'device_id') {
          return const SizedBox.shrink();
        }
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_getDataIcon(entry.key), size: 30, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatValue(entry.key, entry.value),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
