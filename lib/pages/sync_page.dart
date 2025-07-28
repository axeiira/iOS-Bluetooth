import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/http_manager.dart';
import 'package:intl/intl.dart';

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
  Color _statusColor = Colors.black87;
  String _currentJsonPayload = "";
  double _syncProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkUnsyncedData();
  }

  Future<void> _checkUnsyncedData() async {
    final summaries = await DatabaseHelper.instance.getUnsyncedGpsDataSummary();
    if (mounted) setState(() => _unsyncedSummaries = summaries);
  }

  Future<void> _startSyncAll() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _statusMessage = "Starting synchronization for all devices...";
      _statusColor = Colors.blue;
      _syncProgress = 0.0;
    });

    final allUnsyncedData = await DatabaseHelper.instance.getUnsyncedGpsData();
    
    if (allUnsyncedData.isEmpty) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "All data is already synced!";
        _statusColor = Colors.green;
      });
      return;
    }
    
    int totalRecordsSent = 0;
    final int totalRecordsToSync = allUnsyncedData.length;

    for (var data in allUnsyncedData) {
      final Map<String, dynamic> payload = {
        // Server mengharapkan nama key ini
        'deviceId': data['device_id'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'altitude': data['altitude'],
        'createdAt': data['timestamp'],
        'nSatellite': data['num_satellite'],
        'batteryPercentage': data['battery_percentage'],
        'eventTagging': data['tag_button'] == 1, 
        'geofenceStatus': data['geofence_status'] == 1,
      };
      
      final int id = data['id'];

      setState(() {
        _statusMessage = "Sending data for ${data['device_id']} (ID: $id)...";
        _currentJsonPayload = const JsonEncoder.withIndent(' ').convert(payload);
      });

      SendResult result = await _httpManager.sendData(payload);
      if (result.success) {
        await DatabaseHelper.instance.markAsSynced([id]);
        totalRecordsSent++;
      } else {
        print("REAL: Failed to send data ID $id for device ${data['device_id']}: ${result.message}");
      }

      setState(() {
        _syncProgress = totalRecordsSent / totalRecordsToSync;
      });
    }

    final String finalStatus = totalRecordsSent == totalRecordsToSync ? "success" : "partial_failure";
    final String? finalErrorMessage = totalRecordsSent == totalRecordsToSync ? null : "${totalRecordsToSync - totalRecordsSent} records failed.";

    await _httpManager.sendNotificationToDashboard(
      deviceId: "All Devices",
      totalRecordsSent: totalRecordsSent,
      status: finalStatus,
      errorMessage: finalErrorMessage,
    );

    setState(() {
      _isSyncing = false;
      _statusMessage = "Sync complete. $totalRecordsSent of $totalRecordsToSync records sent successfully.";
      _currentJsonPayload = "";
      _statusColor = totalRecordsSent == totalRecordsToSync ? Colors.green : Colors.orange;
      _syncProgress = 1.0;
    });
    _checkUnsyncedData();
  }

  Future<void> _resendAllUnsynced() async {
    if (_isSyncing) return;
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resend All Unsynced Data?"),
        content: const Text("Are you sure you want to resend all unsynced data?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Resend")),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await _startSyncAll();
    }
  }

  Future<void> _deleteAllUnsynced() async {
    if (_isSyncing) return;
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete All Unsynced Data?"),
        content: const Text("This action cannot be undone. All unsynced data will be permanently deleted from local storage."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Delete")),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        _statusMessage = "Deleting unsynced data...";
        _statusColor = Colors.orange;
      });
      final unsyncedData = await DatabaseHelper.instance.getUnsyncedGpsData();
      final List<int> idsToDelete = unsyncedData.map<int>((e) => e['id'] as int).toList();
      final deletedCount = await DatabaseHelper.instance.deleteGpsData(idsToDelete);
      setState(() {
        _statusMessage = "$deletedCount records deleted successfully.";
        _statusColor = Colors.green;
      });
      _checkUnsyncedData();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Synchronization"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text("Total Unsynced Records", style: TextStyle(fontSize: 18, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text(
                      _unsyncedSummaries.fold<int>(0, (sum, item) => sum + (item['total_unsynced'] as int)).toString(),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _syncProgress,
                      backgroundColor: Colors.grey.shade200,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${(_syncProgress * 100).toStringAsFixed(1)}% Completed",
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isSyncing)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(_statusMessage, textAlign: TextAlign.center, style: TextStyle(color: _statusColor, fontWeight: FontWeight.w500)),
                    if (_currentJsonPayload.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Sending Payload:", style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                width: double.infinity,
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                                child: SelectableText(_currentJsonPayload, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text("Start Synchronization (All Devices)"),
                    onPressed: _unsyncedSummaries.isNotEmpty ? _startSyncAll : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Resend All Unsynced"),
                    onPressed: _unsyncedSummaries.isNotEmpty ? _resendAllUnsynced : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade800),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Delete All Unsynced"),
                    onPressed: _unsyncedSummaries.isNotEmpty ? _deleteAllUnsynced : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: Colors.red.shade800,
                      side: BorderSide(color: Colors.red.shade800),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            const Text("Unsynced Data Per Device:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: _unsyncedSummaries.isEmpty
                  ? Center(
                      child: Text(
                        "No unsynced data found.",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _unsyncedSummaries.length,
                      itemBuilder: (context, deviceIndex) {
                        final summary = _unsyncedSummaries[deviceIndex];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: Icon(Icons.device_hub, color: Theme.of(context).colorScheme.secondary),
                            title: Text("Device ID: ${summary['device_id']}"),
                            subtitle: Text("Total Unsynced: ${summary['total_unsynced']}"),
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
