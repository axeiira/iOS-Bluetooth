import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/http_manager.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final HttpManager _httpManager = HttpManager();
  List<Map<String, dynamic>> _unsyncedSummaries = [];
  bool _isSyncing = false;
  String _statusMessage = "Ready to sync.";

  @override
  void initState() {
    super.initState();
    _checkUnsyncedData();
  }

  Future<void> _checkUnsyncedData() async {
    final summaries = await DatabaseHelper.instance.getUnsyncedGpsDataSummary();
    if (mounted) setState(() => _unsyncedSummaries = summaries);
  }

  // Fungsi sinkronisasi menggunakan batch
  Future<void> _startBatchSync() async {
    if (_isSyncing) return;

    final stopwatch = Stopwatch()..start();
    setState(() {
      _isSyncing = true;
      _statusMessage = "Preparing to send batch data...";
    });

    // ambil semua data yang belum disync
    final allUnsyncedData = await DatabaseHelper.instance.getUnsyncedGpsData();
    if (allUnsyncedData.isEmpty) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "All data is already synced!";
      });
      return;
    }

    setState(() {
      _statusMessage = "Sending ${allUnsyncedData.length} records in one batch...";
    });

    // siapkan payload dalam bentuk List
    final List<Map<String, dynamic>> payloadList = allUnsyncedData.map((data) {
      return {
        'deviceId': int.tryParse(data['device_id'] as String) ?? 0, 
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'altitude': data['altitude'],
        'createdAt': data['timestamp'],
        'nSatellite': data['num_satellite'],
        'batteryPercentage': data['battery_percentage'],
        'eventTagging': data['tag_button'] == 1,
        'geofenceStatus': data['geofence_status'] == 1,
      };
    }).toList();

    // send http req
    SendResult result = await _httpManager.sendBulkData(payloadList);

    // mark as synced jika berhasil
    if (result.success) {
      final List<int> idsToMark = allUnsyncedData.map((e) => e['id'] as int).toList();
      await DatabaseHelper.instance.markAsSynced(idsToMark);
    }
    
    stopwatch.stop();
    final duration = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);

    setState(() {
      _isSyncing = false;
      if (result.success) {
        _statusMessage = "Success! ${result.count} records sent in $duration seconds.";
      } else {
        _statusMessage = "Failed. ${result.message}";
      }
    });

    _checkUnsyncedData();
  }
  
  @override
  Widget build(BuildContext context) {
    final int totalUnsynced = _unsyncedSummaries.fold(0, (sum, item) => sum + (item['total_unsynced'] as int));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Synchronization"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text("Total Unsynced Records", style: TextStyle(fontSize: 18, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(
                      totalUnsynced.toString(),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isSyncing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) : const Icon(Icons.cloud_upload),
              label: Text(_isSyncing ? "Sending..." : "Sync All Data (Batch)"),
              onPressed: totalUnsynced > 0 && !_isSyncing ? _startBatchSync : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Text(_statusMessage)),
            const SizedBox(height: 24),
            const Text("Unsynced Data Per Device:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _unsyncedSummaries.isEmpty
                  ? const Center(child: Text("No unsynced data found."))
                  : ListView.builder(
                      itemCount: _unsyncedSummaries.length,
                      itemBuilder: (context, index) {
                        final summary = _unsyncedSummaries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.devices_other, color: Theme.of(context).colorScheme.secondary),
                            title: Text("Device ID: ${summary['device_id']}"),
                            subtitle: Text("Unsynced Records: ${summary['total_unsynced']}"),
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