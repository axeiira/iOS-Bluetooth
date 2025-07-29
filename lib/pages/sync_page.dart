import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/http_manager.dart';
import '../utils/sync_status_service.dart';

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
  double _syncProgress = 0.0;
  String? _syncingDeviceId;

  @override
  void initState() {
    super.initState();
    _checkUnsyncedData();
  }

  Future<void> _checkUnsyncedData() async {
    final summaries = await DatabaseHelper.instance.getUnsyncedGpsDataSummary();
    if (mounted) setState(() => _unsyncedSummaries = summaries);
  }

  Future<void> _performBatchSync(Future<List<Map<String, dynamic>>> dataFetcher, String syncTargetName) async {
    if (_isSyncing) return;

    SyncStatusService.instance.updateStatus(SyncStatus.syncing); 

    final stopwatch = Stopwatch()..start();
    setState(() {
      _isSyncing = true;
      _statusMessage = "Preparing to sync for $syncTargetName...";
      _syncProgress = 0.0;
    });

    final List<Map<String, dynamic>> allDataToSync = await dataFetcher;
    if (allDataToSync.isEmpty) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "No unsynced data found for $syncTargetName.";
        _syncingDeviceId = null;
      });
      return;
    }

    const int chunkSize = 400; // jumlah record per chunk
    int totalRecordsSent = 0;
    bool anyChunkFailed = false;
    String finalErrorMessage = "";

    for (int i = 0; i < allDataToSync.length; i += chunkSize) {
      final int end = (i + chunkSize > allDataToSync.length) ? allDataToSync.length : i + chunkSize;
      final List<Map<String, dynamic>> chunk = allDataToSync.sublist(i, end);

      setState(() {
        _statusMessage = "Sending chunk ${i ~/ chunkSize + 1} of ${(allDataToSync.length / chunkSize).ceil()}... (${chunk.length} records)";
      });
      
      final List<Map<String, dynamic>> payloadList = chunk.map((data) {
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

      SendResult result = await _httpManager.sendBulkData(payloadList);

      if (result.success) {
        final List<int> idsToMark = chunk.map((e) => e['id'] as int).toList();
        await DatabaseHelper.instance.markAsSynced(idsToMark);
        totalRecordsSent += chunk.length;
      } else {
        anyChunkFailed = true;
        finalErrorMessage = result.message;
        break; // jika ada chunk yang gagal, hentikan proses
      }
      
      setState(() {
        _syncProgress = totalRecordsSent / allDataToSync.length;
      });
    }

    stopwatch.stop();
    final duration = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2);

    setState(() {
      _isSyncing = false;
      _syncingDeviceId = null;
      if (!anyChunkFailed) {
        _statusMessage = "Success! $totalRecordsSent records sent in $duration seconds.";
        SyncStatusService.instance.updateStatus(SyncStatus.completed);
      } else {
        _statusMessage = "Sync failed. $totalRecordsSent records were sent before error: $finalErrorMessage";
        SyncStatusService.instance.updateStatus(SyncStatus.error);
      }
    });

    _checkUnsyncedData();
  }

  void _syncAll() {
    setState(() => _syncingDeviceId = "all");
    _performBatchSync(DatabaseHelper.instance.getUnsyncedGpsData(), "All Devices");
  }

  void _syncDevice(String deviceId) {
    setState(() => _syncingDeviceId = deviceId);
    _performBatchSync(DatabaseHelper.instance.getUnsyncedGpsDataForDevice(deviceId), "Device $deviceId");
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
                    if (_isSyncing) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: _syncProgress),
                      const SizedBox(height: 8),
                      Text("${(_syncProgress * 100).toStringAsFixed(1)}% Completed"),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _isSyncing && _syncingDeviceId == "all" 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                  : const Icon(Icons.cloud_upload),
              label: Text(_isSyncing && _syncingDeviceId == "all" ? "Sending..." : "Sync All Devices"),
              onPressed: totalUnsynced > 0 && !_isSyncing ? _syncAll : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Text(_statusMessage, textAlign: TextAlign.center)),
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
                        final deviceId = summary['device_id'] as String;
                        final isCurrentlySyncing = _isSyncing && _syncingDeviceId == deviceId;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(Icons.devices_other, color: Theme.of(context).colorScheme.secondary),
                            title: Text("Device ID: $deviceId"),
                            subtitle: Text("Unsynced Records: ${summary['total_unsynced']}"),
                            trailing: isCurrentlySyncing
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                                : ElevatedButton(
                                    onPressed: _isSyncing ? null : () => _syncDevice(deviceId),
                                    child: const Text("Sync"),
                                  ),
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