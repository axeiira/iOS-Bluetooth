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
  int _unsyncedCount = 0;
  bool _isSyncing = false;
  String _statusMessage = "Ready to sync.";
  Color _statusColor = Colors.black87;
  String _currentJsonPayload = "";

  @override
  void initState() {
    super.initState();
    _checkUnsyncedData();
  }

  Future<void> _checkUnsyncedData() async {
    final count = await DatabaseHelper.instance.countUnsynced();
    if (mounted) setState(() => _unsyncedCount = count);
  }

  Future<void> _startSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _statusMessage = "Fetching data from local database...";
      _statusColor = Colors.blue;
      _currentJsonPayload = "";
    });

    final unsyncedData = await DatabaseHelper.instance.getUnsyncedTelemetry();
    if (unsyncedData.isEmpty) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "All data is already synced!";
        _statusColor = Colors.green;
      });
      return;
    }

    int successCount = 0;
    for (var data in unsyncedData) {
      final Map<String, dynamic> payload = Map.from(data);
      final int id = payload.remove('id');
      payload.remove('is_synced');
      payload['ignition'] = (payload['ignition_status'] == 1); // Sesuaikan key jika diperlukan
      payload.remove('ignition_status'); // Hapus yang lama jika diganti

      setState(() {
        _statusMessage = "Sending data with ID: $id...";
        _currentJsonPayload = const JsonEncoder.withIndent(' ').convert(payload);
      });

      SendResult result = await _httpManager.sendData(payload);
      if (result.success) {
        await DatabaseHelper.instance.markAsSynced(id);
        successCount++;
        if (mounted) setState(() => _unsyncedCount = unsyncedData.length - successCount);
      } else {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _statusMessage = "FAILED!\nError Message:\n${result.message}";
            _statusColor = Colors.red;
          });
        }
        return;
      }
    }

    setState(() {
      _isSyncing = false;
      _statusMessage = "Sync complete. $successCount records were sent successfully.";
      _currentJsonPayload = "";
      _statusColor = Colors.green;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Data Synchronization")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text("Unsynced Records", style: TextStyle(fontSize: 18, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Text("$_unsyncedCount", style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Sync Button
            if (_isSyncing)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton.icon(
                icon: const Icon(Icons.sync_rounded),
                label: const Text("Start Synchronization"),
                onPressed: _unsyncedCount > 0 ? _startSync : null,
              ),
            const SizedBox(height: 24),
            // Status Message Area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: _statusColor, fontWeight: FontWeight.w500),
              ),
            ),
            if (_isSyncing && _currentJsonPayload.isNotEmpty)
              Expanded(
                child: Padding(
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
              ),
          ],
        ),
      ),
    );
  }
}