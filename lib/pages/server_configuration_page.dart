import 'package:flutter/material.dart';
import '../utils/settings_service.dart';

class ServerConfigurationPage extends StatefulWidget {
  const ServerConfigurationPage({super.key});

  @override
  State<ServerConfigurationPage> createState() => _ServerConfigurationPageState();
}

class _ServerConfigurationPageState extends State<ServerConfigurationPage> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();

  late TextEditingController _baseUrlController;
  late TextEditingController _notificationUrlController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _notificationUrlController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final baseUrl = await _settingsService.getBaseUrl();
    final notificationUrl = await _settingsService.getNotificationUrl();
    if (mounted) {
      setState(() {
        _baseUrlController.text = baseUrl;
        _notificationUrlController.text = notificationUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await _settingsService.setBaseUrl(_baseUrlController.text.trim());
      await _settingsService.setNotificationUrl(_notificationUrlController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings saved successfully!")),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _notificationUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Server Configuration"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: "Telemetry Server URL",
                      border: OutlineInputBorder(),
                      hintText: "http://your-server.com/telemetry",
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || !Uri.parse(value).isAbsolute) {
                        return 'Please enter a valid URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _notificationUrlController,
                    decoration: const InputDecoration(
                      labelText: "Notification Server URL",
                      border: OutlineInputBorder(),
                      hintText: "http://your-server.com/notification",
                    ),
                     validator: (value) {
                      if (value == null || value.isEmpty || !Uri.parse(value).isAbsolute) {
                        return 'Please enter a valid URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: const Text("Save Settings"),
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}