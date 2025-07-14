import 'package:flutter/material.dart';
import '../utils/database_helper.dart';

class DataLogPage extends StatefulWidget {
  const DataLogPage({super.key});

  @override
  State<DataLogPage> createState() => _DataLogPageState();
}

class _DataLogPageState extends State<DataLogPage> {
  List<Map<String, dynamic>> _telemetryData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    final data = await DatabaseHelper.instance.getAllTelemetry();
    setState(() {
      _telemetryData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Data Tersimpan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _telemetryData.isEmpty
              ? const Center(child: Text('Database masih kosong.'))
              : ListView.builder(
                  itemCount: _telemetryData.length,
                  itemBuilder: (context, index) {
                    final item = _telemetryData[index];
                    final bool isSynced = item['is_synced'] == 1;
                    return Card(
                      color: isSynced ? Colors.green.shade50 : Colors.orange.shade50,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSynced ? Colors.green : Colors.orange,
                          child: Icon(
                            isSynced ? Icons.cloud_done : Icons.cloud_off,
                            color: Colors.white,
                          ),
                        ),
                        title: Text('ID: ${item['id']} - Device: ${item['device_id']}'),
                        subtitle: Text('Timestamp: ${item['timestamp']}'),
                      ),
                    );
                  },
                ),
    );
  }
}
