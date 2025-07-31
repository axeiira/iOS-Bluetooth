import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'sync_page.dart';
import '../utils/sync_status_service.dart';
import '../utils/app_strings.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _unsyncedCount = 0;
  int _totalCount = 0;
  int _devicesTodayCount = 0;
  DateTime? _lastSyncTime;
  
  @override
  void initState() {
    super.initState();
    _refreshData();
    SyncStatusService.instance.addListener(_onSyncStatusChanged);
  }

  @override
  void dispose() {
    SyncStatusService.instance.removeListener(_onSyncStatusChanged);
    super.dispose();
  }

  void _onSyncStatusChanged() {
    // Refresh data when sync status changes to reflect new counts
    if (SyncStatusService.instance.value == SyncStatus.completed) {
      Future.delayed(const Duration(seconds: 1), _refreshData);
      setState(() {
        _lastSyncTime = DateTime.now();
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _refreshData() async {
    final unsynced = await DatabaseHelper.instance.countUnsyncedGpsData();
    final total = await DatabaseHelper.instance.getAllGpsData();
    final uniqueDevices = await DatabaseHelper.instance.getUniqueDeviceIds();

    if (mounted) {
      setState(() {
        _unsyncedCount = unsynced;
        _totalCount = total.length;
        _devicesTodayCount = uniqueDevices.length; 
      });
    }
  }
  
  String _formatTimeAgo(DateTime? time) {
    if (time == null) return "Never";
    final duration = DateTime.now().difference(time);
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
        title: const Text(AppStrings.dashboardTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          children: [
            const Text(AppStrings.welcomeBack, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(AppStrings.dataSummary, style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            _buildSyncStatusCard(context),
            const SizedBox(height: 24),
            _buildMetricsGrid(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<SyncStatus>(
          valueListenable: SyncStatusService.instance,
          builder: (context, status, child) {
            IconData icon;
            String title;
            String subtitle;
            Color iconColor;

            switch (status) {
              case SyncStatus.syncing:
                icon = Icons.sync_rounded;
                title = "Syncing in Progress...";
                subtitle = "Please keep the app open.";
                iconColor = theme.colorScheme.secondary;
                break;
              case SyncStatus.completed:
                icon = Icons.cloud_done_rounded;
                title = "All Data is Up to Date";
                subtitle = "${AppStrings.lastSync}: ${_formatTimeAgo(_lastSyncTime)}";
                iconColor = theme.colorScheme.primary;
                break;
              case SyncStatus.error:
                icon = Icons.error_outline_rounded;
                title = "Sync Failed";
                subtitle = "Please check your connection and try again.";
                iconColor = theme.colorScheme.error;
                break;
              default:
                icon = Icons.cloud_upload_rounded;
                title = "Ready to Sync";
                subtitle = "$_unsyncedCount records waiting to be sent.";
                iconColor = theme.colorScheme.secondary;
            }

            return Row(
              children: [
                if (status == SyncStatus.syncing)
                  const CircularProgressIndicator()
                else
                  Icon(icon, size: 40, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildMetricCard(
          context: context,
          icon: Icons.error_outline_rounded,
          label: AppStrings.unsyncedRecords,
          value: _unsyncedCount.toString(),
          color: Theme.of(context).colorScheme.secondary,
          onTap: () async {
             await Navigator.push(context, MaterialPageRoute(builder: (context) => const SyncPage()));
             _refreshData();
          }
        ),
        _buildMetricCard(
          context: context,
          icon: Icons.storage_rounded,
          label: AppStrings.totalRecords,
          value: _totalCount.toString(),
          color: Theme.of(context).colorScheme.primary,
        ),
        _buildMetricCard(
          context: context,
          icon: Icons.devices_other_rounded,
          label: "Devices Today",
          value: _devicesTodayCount.toString(),
          color: Colors.blue.shade700,
        ),
        _buildMetricCard(
          context: context,
          icon: Icons.timer_rounded,
          label: AppStrings.lastSync,
          value: _formatTimeAgo(_lastSyncTime),
          color: Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: color),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color.withOpacity(0.9))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}