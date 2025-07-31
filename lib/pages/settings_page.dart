import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import '../utils/app_strings.dart';
import 'local_storage_page.dart';
import 'server_configuration_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.settingsTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, "General"),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.dns_rounded,
                  title: AppStrings.settingsServerConfig,
                  subtitle: AppStrings.settingsServerSubtitle,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ServerConfigurationPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(context, "Data Management"),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.storage_rounded,
                  title: AppStrings.settingsLocalStorage,
                  subtitle: AppStrings.settingsStorageSubtitle,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LocalStoragePage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                 _buildListTile(
                  context,
                  icon: Icons.delete_sweep_rounded,
                  iconColor: theme.colorScheme.error,
                  title: "Clear All Local Data",
                  subtitle: "Delete all records from this device",
                  onTap: () => _showDeleteConfirmationDialog(context),
                ),
              ],
            ),
          ),
           const SizedBox(height: 24),
          
           _buildSectionHeader(context, "About"),
           Card(
            child: Column(
              children: [
                 _buildListTile(
                  context,
                  icon: Icons.info_rounded,
                  title: "About ${AppStrings.appName}",
                  subtitle: "Version 2.0.0 (Development Version)",
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: (iconColor ?? theme.colorScheme.primary).withOpacity(0.1),
        child: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      onTap: onTap,
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete All Data?"),
          content: const Text("This action cannot be undone and will permanently delete all logs from your device."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text("Delete All"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      await DatabaseHelper.instance.deleteAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All local data has been deleted."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("About ${AppStrings.appName}"),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Version: Development Version"),
                SizedBox(height: 8),
                Text("Developed by: PT Mioto Agung Mobilitas"),
                SizedBox(height: 8),
                Text("An IoT data collector application for agricultural industry needs."),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}