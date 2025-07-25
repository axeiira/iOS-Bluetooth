// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import '../utils/database_helper.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _unsyncedCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDataSummary();
  }

  Future<void> _loadDataSummary() async {
    final unsynced = await DatabaseHelper.instance.countUnsyncedGpsData();
    final allData = await DatabaseHelper.instance.getAllGpsData();
    if (mounted) {
      setState(() {
        _unsyncedCount = unsynced;
        _totalCount = allData.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', height: 32),
            const SizedBox(width: 12),
            const Text("GeoTrack", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDataSummary,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text("Welcome Back!", style: theme.textTheme.headlineSmall),
            Text("Here is your data summary.", style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            _buildSummaryCard(theme),
            const SizedBox(height: 24),
            Text("Recent Activity", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildRecentActivityPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Card(
      elevation: 4,
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusMetric("Total Records", _totalCount.toString(), Colors.white),
            Container(width: 1, height: 50, color: Colors.white.withOpacity(0.5)),
            _buildStatusMetric("Unsynced", _unsyncedCount.toString(), Colors.white, isWarning: _unsyncedCount > 0),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMetric(String title, String value, Color color, {bool isWarning = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (isWarning)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Icon(Icons.warning_amber_rounded, color: Colors.yellow.shade600, size: 16),
              ),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivityPlaceholder() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.add_location_alt)),
            title: const Text("GPS-001 - Data Received"),
            subtitle: Text("10 minutes ago"),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.add_location_alt)),
            title: const Text("GPS-002 - Data Received"),
            subtitle: Text("12 minutes ago"),
          ),
           const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: const Icon(Icons.cloud_done, color: Colors.green)),
            title: const Text("Sync Completed"),
            subtitle: Text("1 hour ago"),
          ),
        ],
      ),
    );
  }
}