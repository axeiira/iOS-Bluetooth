import 'package:flutter/material.dart';
import '../utils/database_helper.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.dns_outlined),
            title: Text("Server Configuration"),
            subtitle: Text("Set endpoint URLs"),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text("Local Storage"),
            subtitle: Text("Manage saved data"),
          ),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: Colors.red.shade700),
            title: Text("Delete All Local Data", style: TextStyle(color: Colors.red.shade700)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Delete All Data?"),
                  content: const Text("This action cannot be undone and will permanently delete all logs from your device."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete All")),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await DatabaseHelper.instance.deleteAllData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All local data has been deleted."))
                );
              }
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("About GeoTrack"),
            subtitle: Text("Version 2.0.0"),
          ),
        ],
      ),
    );
  }
}