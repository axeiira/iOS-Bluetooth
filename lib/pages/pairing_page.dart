import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import 'qr_scanner_page.dart';
import '../utils/http_manager.dart';
import '../utils/app_strings.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  List<Map<String, dynamic>> _unsyncedPairings = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  int _currentStep = 0;
  Map<String, dynamic>? _scannedDeviceData;
  Map<String, dynamic>? _scannedWorkerData;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUnsyncedPairings();
  }

  Future<void> _loadUnsyncedPairings() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getUnsyncedPairings();
    if (mounted) {
      setState(() {
        _unsyncedPairings = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncPairings() async {
    if (_unsyncedPairings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No pairings to sync.")));
      return;
    }

    setState(() => _isSyncing = true);

    final List<Map<String, dynamic>> payloadList = _unsyncedPairings.map((pairing) {
      return {
        'deviceId': int.tryParse(pairing['device_id'] as String) ?? 0,
        'employeeId': int.tryParse(pairing['worker_id'] as String) ?? 0,
        'assignmentReason': pairing['assignment_reason'],
        'startDate': pairing['timestamp'],
      };
    }).toList();

    final result = await HttpManager().sendPairings(payloadList);

    if (result.success) {
      final List<int> idsToMark = _unsyncedPairings.map((p) => p['id'] as int).toList();
      await DatabaseHelper.instance.markPairingsAsSynced(idsToMark);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pairings synced successfully!")));
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync failed: ${result.message}")));
    }

    setState(() => _isSyncing = false);
    _loadUnsyncedPairings();
  }

  Future<void> _scanDevice() async {
    final deviceQrResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage(instruction: AppStrings.pairingStep1Subtitle)),
    );
    if (deviceQrResult == null || !mounted) return;

    try {
      final data = jsonDecode(deviceQrResult);
      if (data['type'] != 'device' || data['id'] == null) throw const FormatException("Invalid QR");
      setState(() {
        _scannedDeviceData = data;
        _currentStep = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Device QR Code.")));
    }
  }

  Future<void> _scanWorker() async {
    final workerQrResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage(instruction: AppStrings.pairingStep2Subtitle)),
    );
    if (workerQrResult == null || !mounted) return;

    try {
      final data = jsonDecode(workerQrResult);
      if (data['type'] != 'worker' || data['id'] == null) throw const FormatException("Invalid QR");
      setState(() {
        _scannedWorkerData = data;
        _currentStep = 2;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Worker QR Code.")));
    }
  }

  Future<void> _savePairing() async {
    if (_scannedDeviceData == null || _scannedWorkerData == null) return;
    
    await DatabaseHelper.instance.insertPairing({
      'device_id': _scannedDeviceData!['id'].toString(),
      'worker_id': _scannedWorkerData!['id'].toString(),
      'worker_name': _scannedWorkerData!['name']?.toString() ?? 'Unknown',
      'assignment_reason': _reasonController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
    
    _resetStepper();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pairing saved successfully!"), behavior: SnackBarBehavior.floating),
    );
    await _loadUnsyncedPairings();
  }
  
  void _onStepCancel() {
     if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  void _resetStepper() {
    setState(() {
      _currentStep = 0;
      _scannedDeviceData = null;
      _scannedWorkerData = null;
      _reasonController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.pairingTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUnsyncedPairings,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildStepper(),
            const Divider(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Unsynced Pairings",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_unsyncedPairings.isNotEmpty)
                  _isSyncing 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator())
                  : TextButton.icon(
                      onPressed: _syncPairings,
                      icon: Icon(Icons.sync, size: 20, color: Theme.of(context).colorScheme.primary),
                      label: Text("Sync", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _unsyncedPairings.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text("No unsynced pairings found.", style: TextStyle(color: Colors.grey)),
                      ))
                    : Card(
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _unsyncedPairings.length,
                          itemBuilder: (context, index) {
                            final pairing = _unsyncedPairings[index];
                            final timestamp = DateTime.parse(pairing['timestamp']);
                            return ListTile(
                              leading: const Icon(Icons.link),
                              title: Text("Device ${pairing['device_id']} » ${pairing['worker_name']}"),
                              subtitle: Text("Paired on: ${DateFormat.yMd().add_jm().format(timestamp)}"),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Stepper(
      currentStep: _currentStep,
      onStepCancel: _onStepCancel,
      onStepTapped: (step) => setState(() => _currentStep = step),
      controlsBuilder: (context, details) {
        return const SizedBox.shrink(); 
      },
      steps: [
        Step(
          title: const Text(AppStrings.pairingStep1Title),
          subtitle: const Text("Scan QR code on the GPS device"),
          isActive: _currentStep >= 0,
          state: _scannedDeviceData != null ? StepState.complete : StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_scannedDeviceData != null)
                Chip(
                  avatar: const Icon(Icons.gps_fixed_rounded),
                  label: Text("Device ID: ${_scannedDeviceData!['id']}"),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_scannedDeviceData != null ? "Rescan Device" : "Scan Device"),
                onPressed: _scanDevice,
              ),
            ],
          ),
        ),
        Step(
          title: const Text(AppStrings.pairingStep2Title),
          subtitle: const Text("Scan QR code on the worker's ID"),
          isActive: _currentStep >= 1,
           state: _scannedWorkerData != null ? StepState.complete : StepState.indexed,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               if (_scannedWorkerData != null)
                Chip(
                  avatar: const Icon(Icons.person_rounded),
                  label: Text("Worker: ${_scannedWorkerData!['name'] ?? 'N/A'}"),
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_scannedWorkerData != null ? "Rescan Worker" : "Scan Worker"),
                onPressed: _scanWorker,
              ),
            ],
          ),
        ),
        Step(
          title: const Text("Confirm & Save"),
          subtitle: const Text("Add a reason and save the pairing"),
          isActive: _currentStep >= 2,
          state: StepState.indexed,
          content: Column(
            children: [
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: "Assignment Reason (Optional)",
                  border: OutlineInputBorder(),
                  hintText: "e.g., Replacement device",
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: _resetStepper, child: const Text("Reset")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _savePairing,
                    child: const Text("Save Pairing"),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}