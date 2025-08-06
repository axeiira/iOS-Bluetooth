import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/app_strings.dart';
import '../utils/auth_service.dart';
import 'local_storage_page.dart';
import 'login_page.dart';
import 'server_configuration_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // confirm logout dialog
  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text("Logout"),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      final authService = AuthService();
      await authService.logout();
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Fungsi untuk membersihkan cache dan file sementara
  Future<void> _clearAllCachesAndTempFiles(BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final appSupportDir = await getApplicationSupportDirectory();
      const cacheFolderName = 'mapCacheKey';

      final directoriesToCheck = [
        Directory(p.join(tempDir.path, cacheFolderName)),
        Directory(p.join(appSupportDir.path, cacheFolderName)),
        Directory(p.join(appSupportDir.path, 'libCachedImageData')),
      ];

      for (var dir in directoriesToCheck) {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
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
          // Bagian General
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

          // Bagian Data Management
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          _buildSectionHeader(context, "Account"),
          Card(
            child: Column(
              children: [
                _buildListTile(
                  context,
                  icon: Icons.logout_rounded,
                  iconColor: theme.colorScheme.error,
                  title: "Logout",
                  subtitle: "End your current session",
                  onTap: () => _showLogoutConfirmationDialog(context),
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
}