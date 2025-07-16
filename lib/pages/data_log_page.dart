import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'package:intl/intl.dart';

class DataLogPage extends StatefulWidget {
  const DataLogPage({super.key});

  @override
  State<DataLogPage> createState() => _DataLogPageState();
}

class _DataLogPageState extends State<DataLogPage> {
  // Gunakan FutureBuilder untuk memuat data secara asynchronous
  late Future<List<Map<String, dynamic>>> _telemetryData;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _telemetryData = DatabaseHelper.instance.getAllTelemetry();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Data Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _telemetryData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.data_object_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 20),
                  const Text('No Data Stored', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   Text('Data from devices will appear here.', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final data = snapshot.data!;

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final bool isSynced = item['is_synced'] == 1;

              // Parsing timestamp
              DateTime timestamp;
              try {
                timestamp = DateTime.parse(item['timestamp']);
              } catch (e) {
                timestamp = DateTime.now(); // Fallback
              }
              final formattedDate = DateFormat('dd MMM yyyy, HH:mm:ss').format(timestamp);


              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSynced ? Colors.green.shade100 : Colors.orange.shade100,
                    child: Icon(
                      isSynced ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                      color: isSynced ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text('ID: ${item['id']} - ${item['device_id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Timestamp: $formattedDate\nSpeed: ${item['speed']} km/h, Fuel: ${item['fuel']} L'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}