import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'sync_page.dart';
import '../utils/sync_status_service.dart';

class ActivityLog {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  ActivityLog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  int _unsyncedCount = 0;
  int _totalCount = 0;
  List<ActivityLog> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    refreshData();
    SyncStatusService.instance.addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    SyncStatusService.instance.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    setState(() {
    });
  }


  Future<void> refreshData() async {
    await _loadDataSummary();
    await _loadRecentActivities();
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

  Future<void> _loadRecentActivities() async {
    if (!mounted) return;

    // 1. Dapatkan daftar semua perangkat unik
    final deviceIds = await DatabaseHelper.instance.getUniqueDeviceIds();
    
    final List<ActivityLog> batchActivities = [];

    // 2. Untuk setiap perangkat, dapatkan info sesi terakhirnya
    for (String deviceId in deviceIds) {
      final sessionInfo = await DatabaseHelper.instance.getLatestSessionInfoForDevice(deviceId);
      if (sessionInfo != null) {
        final timestamp = DateTime.parse(sessionInfo['latest_timestamp'] as String);
        batchActivities.add(ActivityLog(
          icon: Icons.add_location_alt_outlined,
          iconColor: Colors.blue.shade700,
          title: "Device $deviceId",
          subtitle: "${sessionInfo['count']} records • ${_formatTimeAgo(timestamp)}",
          timestamp: timestamp,
        ));
      }
    }

    // 3. Urutkan berdasarkan waktu aktivitas terakhir
    batchActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (mounted) {
      setState(() {
        _recentActivities = batchActivities.take(5).toList();
      });
    }
  }
  
  String _formatActivityTitle(String deviceId) {
    return "Device $deviceId";
  }

  String _formatTimeAgo(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
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
            const Text("People Mobility", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ValueListenableBuilder<SyncStatus>(
              valueListenable: SyncStatusService.instance,
              builder: (context, status, child) {
                switch (status) {
                  case SyncStatus.syncing:
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    );
                  case SyncStatus.completed:
                    return const Icon(Icons.cloud_done_outlined, color: Colors.green);
                  case SyncStatus.error:
                    return const Icon(Icons.cloud_off_outlined, color: Colors.red);
                  default: // idle
                    return const Icon(Icons.cloud_outlined, color: Colors.grey);
                }
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
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
            _buildRecentActivityList(),
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
            InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const SyncPage()));
                refreshData();
              },
              child: _buildStatusMetric("Unsynced", _unsyncedCount.toString(), Colors.white, isWarning: _unsyncedCount > 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMetric(String title, String value, Color color, {bool isWarning = false}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Row(
          children: [
            if (isWarning)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Icon(Icons.warning_amber_rounded, color: Colors.yellow.shade600, size: 16),
              ),
            Text(title, style: TextStyle(fontSize: 14, color: color.withOpacity(0.8))),
          ],
        ),
      ],
    );
  }

 Widget _buildRecentActivityList() {
    if (_recentActivities.isEmpty) {
      return const Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(Icons.info_outline)),
          title: Text("No Recent Activity"),
          subtitle: Text("Data received from devices will appear here."),
        ),
      );
    }
    return Card(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _recentActivities.length,
        itemBuilder: (context, index) {
          final activity = _recentActivities[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: activity.iconColor.withOpacity(0.1),
              child: Icon(activity.icon, color: activity.iconColor),
            ),
            title: Text(activity.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(activity.subtitle),
          );
        },
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
      ),
    );
  }
}