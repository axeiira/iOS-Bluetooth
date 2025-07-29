import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'sync_page.dart';

class ActivityLog {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  ActivityLog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
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
    final recentHeaders = await DatabaseHelper.instance.getRecentActivityHeaders(limit: 100);
    if (!mounted || recentHeaders.isEmpty) {
      setState(() => _recentActivities = []);
      return;
    }

    final List<List<Map<String, dynamic>>> sessions = [];
    if (recentHeaders.isNotEmpty) {
      List<Map<String, dynamic>> currentSession = [recentHeaders.first];
      for (int i = 1; i < recentHeaders.length; i++) {
        final prev = recentHeaders[i - 1];
        final current = recentHeaders[i];
        final prevTime = DateTime.parse(prev['timestamp'] as String);
        final currentTime = DateTime.parse(current['timestamp'] as String);

        if (current['device_id'] != prev['device_id'] || prevTime.difference(currentTime).inMinutes >= 5) {
          sessions.add(currentSession);
          currentSession = [current];
        } else {
          currentSession.add(current);
        }
      }
      sessions.add(currentSession);
    }

    final List<ActivityLog> batchActivities = [];
    for (var session in sessions) {
      final firstRecord = session.first;
      final deviceId = firstRecord['device_id'] as String;
      final timestamp = DateTime.parse(firstRecord['timestamp'] as String);
      final allDbRecords = await DatabaseHelper.instance.getAllGpsData();
      final sessionRecords = allDbRecords.where((rec) => rec['device_id'] == deviceId).length;

      batchActivities.add(ActivityLog(
        icon: Icons.add_location_alt_outlined,
        iconColor: Colors.blue.shade700,
        title: _formatActivityTitle(deviceId),
        subtitle: "${sessionRecords} records • ${_formatTimeAgo(timestamp)}",
      ));
    }

    if (mounted) {
      setState(() {
        _recentActivities = batchActivities.take(5).toList();
      });
    }
  }

  ActivityLog _createActivityLogFromSession(List<Map<String, dynamic>> session) {
    final firstRecord = session.first;
    final deviceId = firstRecord['device_id'] as String;
    final timestamp = DateTime.parse(firstRecord['timestamp'] as String);

    return ActivityLog(
      icon: Icons.add_location_alt_outlined,
      iconColor: Colors.blue.shade700,
      title: _formatActivityTitle(deviceId),
      subtitle: "${session.length} records • ${_formatTimeAgo(timestamp)}",
    );
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