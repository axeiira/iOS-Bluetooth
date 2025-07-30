import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import 'qr_scanner_page.dart';
import '../utils/http_manager.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  List<Map<String, dynamic>> _unsyncedPairings = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadUnsyncedPairings();
  }

  Future<void> _syncPairings() async {
    if (_unsyncedPairings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No pairings to sync.")));
      return;
    }

    setState(() => _isSyncing = true);

    final List<Map<String, dynamic>> payloadList = _unsyncedPairings.map((pairing) {
      return {
        'deviceId': int.tryParse(pairing['device_id'] as String) ?? 0,
        'employeeId': int.tryParse(pairing['worker_id'] as String) ?? 0, 
        'assignmentReason': pairing['assignment_reason'],
        'startDate': pairing['timestamp'],
      };
    }).toList();

    // Debugging output
    print("=================== PAYLOAD TO SERVER ===================");
    print(jsonEncode(payloadList));
    print("=========================================================");

    final result = await HttpManager().sendPairings(payloadList);

    if (result.success) {
      final List<int> idsToMark = _unsyncedPairings.map((p) => p['id'] as int).toList();
      await DatabaseHelper.instance.markPairingsAsSynced(idsToMark);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pairings synced successfully!")));
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync failed: ${result.message}")));
    }

    setState(() => _isSyncing = false);
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

    if (deviceQrResult == null || !mounted) return;

    Map<String, dynamic> deviceData;
    try {
      deviceData = jsonDecode(deviceQrResult);
      if (deviceData['type'] != 'device' || deviceData['id'] == null) throw const FormatException("Invalid type");
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Device QR Code.")));
      return;
    }

    if (!mounted) return;
    final bool? continueToWorkerScan = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Device Detected"),
        content: Text("Device ID: ${deviceData['id']} found.\n\nContinue to scan worker?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Continue")),
        ],
      )
    );

    if (continueToWorkerScan != true || !mounted) return;

    // scan worker QR
    final workerQrResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage(instruction: "Scan the Worker's ID QR Code")),
    );

    if (workerQrResult == null || !mounted) return;

    Map<String, dynamic> workerData;
    try {
      workerData = jsonDecode(workerQrResult);
      if (workerData['type'] != 'worker' || workerData['id'] == null) throw const FormatException("Invalid type");
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Worker QR Code.")));
      return;
    }
    
    // confirm and save pairing
    final deviceId = deviceData['id'].toString();
    final workerId = workerData['id'].toString();
    final workerName = workerData['name']?.toString() ?? 'Unknown';
    final TextEditingController reasonController = TextEditingController();

    if (!mounted) return;
    final bool? confirmSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Pairing"),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text("Device ID: $deviceId"),
              Text("Worker: $workerName (ID: $workerId)"),
              const SizedBox(height: 24),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Assignment Reason (Optional)",
                  border: OutlineInputBorder(),
                  hintText: "e.g., Perangkat pengganti",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      )
    );

    if (confirmSave == true) {
      await DatabaseHelper.instance.insertPairing({
        'device_id': deviceId,
        'worker_id': workerId,
        'worker_name': workerName,
        'assignment_reason': reasonController.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });
      await _loadUnsyncedPairings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Device & Worker Pairing"),
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isSyncing
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)))
                  : IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: _unsyncedPairings.isNotEmpty ? _syncPairings : null,
                      tooltip: "Sync Pairings",
                    ),
            )
        ],
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