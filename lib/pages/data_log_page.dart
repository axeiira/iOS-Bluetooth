import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'package:intl/intl.dart';
import 'map_view_page.dart';

class DataLogPage extends StatefulWidget {
  const DataLogPage({super.key});

  @override
  State<DataLogPage> createState() => DataLogPageState();
}

class DataLogPageState extends State<DataLogPage> {
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupedData = {};
  bool _isLoading = true;
  Set<int> _selectedRecordIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadDataHistory();
  }

  Future<void> refreshData() async {
    await _loadDataHistory();
  }

  Future<void> _loadDataHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _selectedRecordIds.clear();
        _isSelectionMode = false;
      });
    }
    final data = await DatabaseHelper.instance.getGpsDataHistoryGrouped();
    if (mounted) {
      setState(() {
        _groupedData = data;
        _isLoading = false;
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedRecordIds.clear();
      }
    });
  }

  void _toggleDateSelection(String deviceId, String dateKey) {
    final dailyRecords = _groupedData[deviceId]![dateKey]!;
    bool allSelected = _isDateFullySelected(deviceId, dateKey);

    setState(() {
      if (allSelected) {
        for (var record in dailyRecords) {
          _selectedRecordIds.remove(record['id'] as int);
        }
      } else {
        for (var record in dailyRecords) {
          _selectedRecordIds.add(record['id'] as int);
        }
      }
      _updateSelectionModeState();
    });
  }

  void _toggleDeviceSelection(String deviceId) {
    final deviceDataByDate = _groupedData[deviceId]!;
    bool allSelected = _isDeviceFullySelected(deviceId);

    setState(() {
      if (allSelected) {
        for (var dateKey in deviceDataByDate.keys) {
          for (var record in deviceDataByDate[dateKey]!) {
            _selectedRecordIds.remove(record['id'] as int);
          }
        }
      } else {
        for (var dateKey in deviceDataByDate.keys) {
          for (var record in deviceDataByDate[dateKey]!) {
            _selectedRecordIds.add(record['id'] as int);
          }
        }
      }
      _updateSelectionModeState();
    });
  }
  
  void _updateSelectionModeState() {
    if (_selectedRecordIds.isEmpty && _isSelectionMode) {
      _isSelectionMode = false;
    } else if (_selectedRecordIds.isNotEmpty && !_isSelectionMode) {
      _isSelectionMode = true;
    }
  }

  bool _isDateFullySelected(String deviceId, String dateKey) {
    final dailyRecords = _groupedData[deviceId]![dateKey]!;
    if (dailyRecords.isEmpty) return false;
    return dailyRecords.every((record) => _selectedRecordIds.contains(record['id'] as int));
  }

  bool _isDeviceFullySelected(String deviceId) {
    final deviceDataByDate = _groupedData[deviceId]!;
    if (deviceDataByDate.values.every((dailyRecords) => dailyRecords.isEmpty)) return false;
    return deviceDataByDate.values.every((dailyRecords) =>
        dailyRecords.every((record) => _selectedRecordIds.contains(record['id'] as int)));
  }

  Future<void> _deleteSelectedData() async {
    if (_selectedRecordIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No records selected for deletion.")),
      );
      return;
    }

    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Selected Data?"),
        content: Text("Are you sure you want to delete ${_selectedRecordIds.length} selected records? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Delete")),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final deletedCount = await DatabaseHelper.instance.deleteGpsData(_selectedRecordIds.toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$deletedCount selected records deleted.")),
      );
      _loadDataHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text("${_selectedRecordIds.length} Selected")
            : const Text("Data Log History"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
                tooltip: "Cancel Selection",
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedRecordIds.isNotEmpty ? _deleteSelectedData : null,
              tooltip: "Delete Selected",
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _toggleSelectionMode,
              tooltip: "Select Data",
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDataHistory,
              tooltip: "Refresh Data",
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final bool confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Delete All Data?"),
                    content: const Text("Are you sure you want to delete all local data? This action cannot be undone."),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
                      TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Delete All")),
                    ],
                  ),
                ) ?? false;
                if (confirm) {
                  await DatabaseHelper.instance.deleteAllData();
                  _loadDataHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All local data deleted.")),
                  );
                }
              },
              tooltip: "Delete All Local Data",
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedData.isEmpty
              ? Center(
                  child: Text(
                    "No data logged yet.",
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _groupedData.keys.length,
                  itemBuilder: (context, deviceIndex) {
                    final deviceId = _groupedData.keys.elementAt(deviceIndex);
                    final deviceDataByDate = _groupedData[deviceId]!;
                    final bool isDeviceFullySelected = _isDeviceFullySelected(deviceId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        onTap: _isSelectionMode
                            ? () => _toggleDeviceSelection(deviceId)
                            : null,
                        onLongPress: () {
                          if (!_isSelectionMode) _toggleSelectionMode();
                          _toggleDeviceSelection(deviceId);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: isDeviceFullySelected,
                                  onChanged: (bool? value) {
                                    _toggleDeviceSelection(deviceId);
                                  },
                                )
                              : Icon(Icons.devices_other, color: Theme.of(context).colorScheme.primary),
                          title: Text("Device ID: $deviceId"),
                          subtitle: Text("${deviceDataByDate.keys.length} days of data"),
                          children: deviceDataByDate.keys.map((dateKey) {
                            final dailyRecords = deviceDataByDate[dateKey]!;
                            final totalDailyRecords = dailyRecords.length;
                            final syncedDailyRecords = dailyRecords.where((r) => r['is_synced'] == 1).length;
                            final bool isDateFullySelected = _isDateFullySelected(deviceId, dateKey);

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                color: isDateFullySelected ? Colors.blue.shade50 : Colors.white,
                                child: ListTile(
                                  leading: _isSelectionMode
                                      ? Checkbox(
                                          value: isDateFullySelected,
                                          onChanged: (bool? value) {
                                            _toggleDateSelection(deviceId, dateKey);
                                          },
                                        )
                                      : Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.secondary),
                                  title: Text("Date: $dateKey"),
                                  subtitle: Text("Total: $totalDailyRecords, Synced: $syncedDailyRecords"),
                                  onTap: () {
                                    if (!_isSelectionMode) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MapViewPage(records: dailyRecords),
                                        ),
                                      );
                                    } else {
                                      _toggleDateSelection(deviceId, dateKey);
                                    }
                                  },
                                  onLongPress: () {
                                    if (!_isSelectionMode) _toggleSelectionMode();
                                    _toggleDateSelection(deviceId, dateKey);
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}