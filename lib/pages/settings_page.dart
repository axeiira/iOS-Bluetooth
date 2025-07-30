import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'local_storage_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete All Data?"),
          content: const Text(
              "This action cannot be undone and will permanently delete all logs from your device."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
              child: const Text("Delete All"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    // Jika pengguna mengonfirmasi, hapus data dan tampilkan notifikasi
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

  // Helper untuk menampilkan dialog "About"
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("About People Mobility"),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Version: Development Version"),
                SizedBox(height: 8),
                Text("Developed by: PT Mioto Agung Mobilitas"),
                SizedBox(height: 8),
                Text(
                    "An IoT data collector application for agricultural industry needs."),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text("Server Configuration"),
            subtitle: const Text("Set endpoint URLs (coming soon)"),
            onTap: () {
              // TODO
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text("Local Storage"),
            subtitle: const Text("View details and export data"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LocalStoragePage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About People Mobility"),
            subtitle: const Text("Version 2.0.0"),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }
}