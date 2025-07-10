import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'secondary.dart'; // Import the correct SecondaryPage
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? connectedDevice;
  List<BluetoothService> services = [];
  final ValueNotifier<String> receivedDataNotifier = ValueNotifier('');
  StreamSubscription<List<int>>? _dataSubscription;

  void startScan() {
    flutterBlue.startScan(timeout: const Duration(seconds: 4));
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    if (!mounted) return;
    setState(() {
      connectedDevice = device;
    });
    services = await device.discoverServices();
    listenToData();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecondaryPage(
          receivedDataNotifier: receivedDataNotifier,
          onDispose: cancelDataSubscription,
        ),
      ),
    );
  }

  void listenToData() {
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          characteristic.setNotifyValue(true);
          _dataSubscription = characteristic.value.listen((value) {
            final data = String.fromCharCodes(value);
            receivedDataNotifier.value = data;
          });
        }
      }
    }
  }

  void cancelDataSubscription() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE ESP32 Connect')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startScan,
            child: const Text('Scan for Devices'),
          ),
          StreamBuilder<List<ScanResult>>(
            stream: flutterBlue.scanResults,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              var results = snapshot.data!;
              return Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    var result = results[index];
                    return ListTile(
                      title: Text(result.device.name.isNotEmpty ? result.device.name : result.device.id.id),
                      subtitle: Text(result.device.id.id),
                      onTap: () => connectToDevice(result.device),
                    );
                  },
                ),
              );
            },
          ),
          if (connectedDevice != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Connected to: ${connectedDevice!.name}'),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String>(
                    valueListenable: receivedDataNotifier,
                    builder: (context, value, child) {
                      return Text('Received Data: $value');
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
