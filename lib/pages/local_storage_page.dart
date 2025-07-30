// lib/pages/local_storage_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pie_chart/pie_chart.dart';
import '../utils/database_helper.dart';

class DeviceStorageSummary {
  final String deviceId;
  final int recordCount;
  final double estimatedSizeMb;

  DeviceStorageSummary({
    required this.deviceId,
    required this.recordCount,
    required this.estimatedSizeMb,
  });
}

class LocalStoragePage extends StatefulWidget {
  const LocalStoragePage({super.key});

  @override
  State<LocalStoragePage> createState() => _LocalStoragePageState();
}

class _LocalStoragePageState extends State<LocalStoragePage> {
  double _dbSize = 0.0;
  List<DeviceStorageSummary> _deviceSummaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _isLoading = true);
    
    final size = await DatabaseHelper.instance.getDatabaseSize();
    final summariesData = await DatabaseHelper.instance.getDataSummaryByDevice();
    final totalRecords = summariesData.fold<int>(0, (sum, item) => sum + (item['record_count'] as int));
    
    final double avgSizePerRecord = totalRecords > 0 ? size / totalRecords : 0;

    final summaries = summariesData.map((data) {
      final recordCount = data['record_count'] as int;
      return DeviceStorageSummary(
        deviceId: data['device_id'] as String,
        recordCount: recordCount,
        estimatedSizeMb: recordCount * avgSizePerRecord,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _dbSize = size;
        _deviceSummaries = summaries;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportDeviceData(String deviceId) async {
    final csvData = await DatabaseHelper.instance.exportDeviceToCsv(deviceId);
    if (csvData.isEmpty) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export.")));
      return;
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/people_mobility_export_$deviceId.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'People Mobility Data Export for Device $deviceId');
  }

  // FUNGSI UNTUK EKSPOR DATA DIKEMBALIKAN
  Future<void> _exportData() async {
    final csvData = await DatabaseHelper.instance.exportToCsv();
    if (csvData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No data to export.")),
        );
      }
      return;
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/people_mobility_export.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'People Mobility Data Export');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Local Storage"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStorageInfo,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  if (_deviceSummaries.isNotEmpty) ...[
                    const Text("Data Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildPieChart(),
                    const SizedBox(height: 24),
                  ],
                  const Text("Breakdown by Device", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildDeviceSummaryList(),
                  const Divider(height: 48),
                  // TOMBOL EKSPOR DIKEMBALIKAN
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share_outlined),
                    label: const Text("Export All Data as CSV"),
                    onPressed: _exportData,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.storage_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
              title: const Text("Total Storage Used"),
              subtitle: Text(
                "${_dbSize.toStringAsFixed(2)} MB",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.policy_outlined, color: Colors.blue),
              title: Text("Data Retention Policy"),
              subtitle: Text("Local data older than 30 days is automatically deleted."),
            ),
          ],
        ),
      )
    );
  }

  Widget _buildPieChart() {
    Map<String, double> dataMap = {
      for (var summary in _deviceSummaries)
        "Device ${summary.deviceId}": summary.recordCount.toDouble(),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PieChart(
          dataMap: dataMap,
          animationDuration: const Duration(milliseconds: 800),
          chartLegendSpacing: 32,
          chartRadius: MediaQuery.of(context).size.width / 3.2,
          legendOptions: const LegendOptions(
            showLegendsInRow: false,
            legendPosition: LegendPosition.right,
            showLegends: true,
            legendTextStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
          chartValuesOptions: const ChartValuesOptions(
            showChartValueBackground: true,
            showChartValues: true,
            showChartValuesInPercentage: true,
            showChartValuesOutside: false,
            decimalPlaces: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceSummaryList() {
    if (_deviceSummaries.isEmpty) {
      return const Center(child: Text("No data stored yet."));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _deviceSummaries.length,
      itemBuilder: (context, index) {
        final summary = _deviceSummaries[index];
        String sizeText = summary.estimatedSizeMb < 0.1 
            ? "${(summary.estimatedSizeMb * 1024).toStringAsFixed(1)} KB"
            : "${summary.estimatedSizeMb.toStringAsFixed(2)} MB";

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(sizeText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            title: Text("Device ${summary.deviceId}"),
            subtitle: Text("${summary.recordCount} records stored"),
            trailing: IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _exportDeviceData(summary.deviceId),
              tooltip: "Export Data for this Device",
            ),
          ),
        );
      },
    );
  }
}