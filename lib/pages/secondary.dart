import 'package:flutter/material.dart';

class SecondaryPage extends StatefulWidget {
  final ValueNotifier<String> receivedDataNotifier;
  final VoidCallback onDispose;
  const SecondaryPage({super.key, required this.receivedDataNotifier, required this.onDispose});

  @override
  State<SecondaryPage> createState() => _SecondaryPageState();
}

class _SecondaryPageState extends State<SecondaryPage> {
  Map<String, String>? parsedData;

  @override
  void initState() {
    super.initState();
    widget.receivedDataNotifier.addListener(_parseData);
    _parseData();
  }

  @override
  void dispose() {
    widget.receivedDataNotifier.removeListener(_parseData);
    widget.onDispose();
    super.dispose();
  }

  void _parseData() {
    final data = widget.receivedDataNotifier.value;
    final parts = data.split(',');
    if (parts.length >= 8) {
      setState(() {
        parsedData = {
          'ID': parts[0],
          'Timestamp': parts[1],
          'Latitude': parts[2],
          'Longitude': parts[3],
          'Speed': parts[4],
          'Heading': parts[5],
          'Fuel': parts[6],
          'Engine Hours': parts[7],
          'Ignition': parts.length > 8 ? parts[8] : '',
        };
      });
    } else {
      setState(() {
        parsedData = null;
      });
    }
  }

  Widget _buildDataCard(String label, String value, IconData icon, {Color? color}) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blue, size: 32),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Telemetry'), backgroundColor: theme.colorScheme.primary),
      body: Center(
        child: parsedData == null
            ? const Text('Waiting for data...', style: TextStyle(fontSize: 18))
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  _buildDataCard('ID', parsedData!['ID'] ?? '', Icons.confirmation_number, color: Colors.indigo),
                  _buildDataCard('Timestamp', parsedData!['Timestamp'] ?? '', Icons.access_time, color: Colors.deepPurple),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _buildDataCard('Latitude', parsedData!['Latitude'] ?? '', Icons.place, color: Colors.green)),
                      Expanded(child: _buildDataCard('Longitude', parsedData!['Longitude'] ?? '', Icons.place_outlined, color: Colors.green)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _buildDataCard('Speed (km/h)', parsedData!['Speed'] ?? '', Icons.speed, color: Colors.orange)),
                      Expanded(child: _buildDataCard('Heading', parsedData!['Heading'] ?? '', Icons.navigation, color: Colors.teal)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _buildDataCard('Fuel (L)', parsedData!['Fuel'] ?? '', Icons.local_gas_station, color: Colors.red)),
                      Expanded(child: _buildDataCard('Engine Hours', parsedData!['Engine Hours'] ?? '', Icons.engineering, color: Colors.brown)),
                    ],
                  ),
                  _buildDataCard('Ignition', parsedData!['Ignition'] == '1' ? 'On' : 'Off', Icons.power_settings_new, color: parsedData!['Ignition'] == '1' ? Colors.green : Colors.grey),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to Home'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
