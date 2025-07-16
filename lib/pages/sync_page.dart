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
  String _statusMessage = "Siap untuk sinkronisasi.";
  Color _statusColor = Colors.black; 

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
      _statusMessage = "Mengambil data dari database...";
      _statusColor = Colors.blue;
    });

    final unsyncedData = await DatabaseHelper.instance.getUnsyncedTelemetry();
    if (unsyncedData.isEmpty) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "Semua data sudah sinkron!";
        _statusColor = Colors.green;
      });
      return;
    }

    int successCount = 0;
    for (var data in unsyncedData) {
      final Map<String, dynamic> payload = Map.from(data);
      final int id = payload.remove('id');
      payload.remove('is_synced');
      payload['ignition_status'] = (payload['ignition_status'] == 1);

      print("Data dari DB (ID: $id) sebelum dikirim: $payload");

      setState(() => _statusMessage = "Mengirim data ID: $id...");

      SendResult result = await _httpManager.sendData(payload);

      if (result.success) {
        await DatabaseHelper.instance.markAsSynced(id);
        successCount++;
        if (mounted) setState(() => _unsyncedCount = unsyncedData.length - successCount);
      } else {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _statusMessage = "GAGAL!\nPesan Error:\n${result.message}";
            _statusColor = Colors.red; 
          });
        }
        return;
      }
    }

    setState(() {
      _isSyncing = false;
      _statusMessage = "Sinkronisasi selesai. $successCount data berhasil dikirim.";
      _statusColor = Colors.green;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sinkronisasi Data")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Data yang belum dikirim:", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text("$_unsyncedCount", style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              if (_isSyncing)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text("Mulai Sinkronisasi"),
                  onPressed: _unsyncedCount > 0 ? _startSync : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              const SizedBox(height: 20),
              Card(
                color: _statusColor.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _statusMessage, 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _statusColor, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}