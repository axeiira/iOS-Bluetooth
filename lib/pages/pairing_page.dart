import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import 'qr_scanner_page.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  List<Map<String, dynamic>> _unsyncedPairings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnsyncedPairings();
  }

  Future<void> _loadUnsyncedPairings() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getUnsyncedPairings();
    if (mounted) {
      setState(() {
        _unsyncedPairings = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _startNewPairingSession() async {
    // scan device QR
    final deviceQrResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage(instruction: "Scan the QR Code on the GPS Device")),
    );

    if (deviceQrResult == null) return;

    Map<String, dynamic> deviceData;
    try {
      deviceData = jsonDecode(deviceQrResult);
      if (deviceData['type'] != 'device' || deviceData['id'] == null) throw Exception();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Device QR Code.")));
      return;
    }

    // scan worker QR
    final workerQrResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage(instruction: "Scan the Worker's ID QR Code")),
    );

    if (workerQrResult == null) return;
    Map<String, dynamic> workerData;
    try {
      workerData = jsonDecode(workerQrResult);
      if (workerData['type'] != 'worker' || workerData['id'] == null) throw Exception();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Worker QR Code.")));
      return;
    }
    
    // confirm and save pairing
    final deviceId = deviceData['id'].toString();
    final workerId = workerData['id'].toString();
    final workerName = workerData['name']?.toString() ?? 'Unknown';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Pairing"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Device ID: $deviceId"),
            Text("Worker: $workerName (ID: $workerId)"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      )
    );

    if (confirm == true) {
      await DatabaseHelper.instance.insertPairing({
        'device_id': deviceId,
        'worker_id': workerId,
        'worker_name': workerName,
        'timestamp': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });
      _loadUnsyncedPairings(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Device & Worker Pairing"),
        // TODO: letakkan tombol sync
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUnsyncedPairings,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text("Start New Pairing Session"),
                      onPressed: _startNewPairingSession,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Unsynced Pairings:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: _unsyncedPairings.isEmpty
                        ? const Center(child: Text("No unsynced pairings found."))
                        : ListView.builder(
                            itemCount: _unsyncedPairings.length,
                            itemBuilder: (context, index) {
                              final pairing = _unsyncedPairings[index];
                              final timestamp = DateTime.parse(pairing['timestamp']);
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.link),
                                  title: Text("Device ${pairing['device_id']} » ${pairing['worker_name']}"),
                                  subtitle: Text("Paired on: ${DateFormat.yMd().add_jm().format(timestamp)}"),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}