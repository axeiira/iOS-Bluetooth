import 'package:flutter/material.dart';
import '../utils/app_strings.dart';
import 'local_storage_page.dart';
import 'server_configuration_page.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/database_helper.dart';
import 'package:path/path.dart' as p;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
              onPressed: () {
                 DatabaseHelper.instance.deleteAllData();
                 Navigator.of(context).pop(true);
              }
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All local data has been deleted."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Fungsi untuk membersihkan cache dan file sementara
  Future<void> _clearAllCachesAndTempFiles(BuildContext context) async {
    try {
      // Dapatkan path ke semua directory yang relevan
      final tempDir = await getTemporaryDirectory();
      final appSupportDir = await getApplicationSupportDirectory();

      // debug
      print("--- STORAGE DIAGNOSTICS ---");
      print("Temporary Directory Path: ${tempDir.path}");
      print("Application Support Directory Path: ${appSupportDir.path}");
      print("---------------------------");

      const cacheFolderName = 'mapCacheKey';

      // list directories yang akan dihapus
      final directoriesToCheck = [
        Directory(p.join(tempDir.path, cacheFolderName)),
        Directory(p.join(appSupportDir.path, cacheFolderName)),
        Directory(p.join(appSupportDir.path, 'libCachedImageData')),
      ];

      // Hapus semua direktori cache yang ditemukan
      for (var dir in directoriesToCheck) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          print("Deleted cache directory: ${dir.path}");
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All caches and temporary files have been cleared."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("Error clearing caches: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to clear caches."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
          // General Settings Section
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

          // Data Management Section
          _buildSectionHeader(context, "Data Management"),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.cleaning_services_rounded,
                  title: "Clear Caches & Temp Files",
                  subtitle: "Free up space from map and export files",
                  onTap: () => _clearAllCachesAndTempFiles(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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
                  subtitle: "Delete all records from the database",
                  onTap: () => _showDeleteConfirmationDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // About Section
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


  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("About ${AppStrings.appName}"),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Version: 2.0.0 (Development Version)"),
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