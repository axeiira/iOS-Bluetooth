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
    });

    final unsyncedData = await DatabaseHelper.instance.getUnsyncedTelemetry();
    if (unsyncedData.isEmpty) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "Semua data sudah sinkron!";
      });
      return;
    }

    int successCount = 0;
    for (var data in unsyncedData) {
      final Map<String, dynamic> payload = Map.from(data);
      final int id = payload.remove('id');
      payload.remove('is_synced');
      // Konversi ignition dari 1/0 ke true/false untuk JSON
      payload['ignition'] = (payload['ignition'] == 1);

      setState(() => _statusMessage = "Mengirim data ID: $id...");

      bool isSuccess = await _httpManager.sendData(payload);
      if (isSuccess) {
        await DatabaseHelper.instance.markAsSynced(id);
        successCount++;
        if (mounted) setState(() => _unsyncedCount = unsyncedData.length - successCount);
      } else {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _statusMessage = "Gagal mengirim data ID: $id. Cek koneksi internet atau server. Sinkronisasi dihentikan.";
          });
        }
        return;
      }
    }

    setState(() {
      _isSyncing = false;
      _statusMessage = "Sinkronisasi selesai. $successCount data berhasil dikirim.";
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
              Text(_statusMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}