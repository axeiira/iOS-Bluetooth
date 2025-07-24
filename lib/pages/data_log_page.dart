import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'package:intl/intl.dart';

class DataLogPage extends StatefulWidget {
  const DataLogPage({super.key});

  @override
  State<DataLogPage> createState() => _DataLogPageState();
}

class _DataLogPageState extends State<DataLogPage> {
  Map<String, Map<String, List<Map<String, dynamic>>>> _groupedData = {};
  bool _isLoading = true;
  Set<int> _selectedRecordIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadDataHistory();
  }

  Future<void> _loadDataHistory() async {
    setState(() {
      _isLoading = true;
      _selectedRecordIds.clear();
      _isSelectionMode = false;
    });
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

  void _toggleRecordSelection(int recordId) {
    setState(() {
      if (_selectedRecordIds.contains(recordId)) {
        _selectedRecordIds.remove(recordId);
      } else {
        _selectedRecordIds.add(recordId);
      }
      _updateSelectionModeState();
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

  IconData _getDataIcon(String key) {
    switch (key) {
      case 'company': return Icons.business;
      case 'device_id': return Icons.devices;
      case 'timestamp': return Icons.access_time;
      case 'latitude': return Icons.location_on;
      case 'longitude': return Icons.location_on;
      case 'altitude': return Icons.height;
      case 'num_satellite': return Icons.satellite_alt;
      case 'battery_percentage': return Icons.battery_full;
      case 'tag_button': return Icons.touch_app;
      case 'geofence_status': return Icons.map;
      case 'is_synced': return Icons.cloud_done;
      default: return Icons.info_outline;
    }
  }

  String _formatValue(String key, dynamic value) {
    if (key == 'timestamp') {
      try {
        final dateTime = DateTime.parse(value);
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
      } catch (e) {
        return value.toString();
      }
    }
    if (key == 'latitude' || key == 'longitude') {
      return '${value.toStringAsFixed(6)}°';
    }
    if (key == 'altitude') {
      return '${value.toStringAsFixed(2)} m';
    }
    if (key == 'num_satellite') {
      return '$value satelit';
    }
    if (key == 'battery_percentage') {
      return '$value%';
    }
    if (key == 'tag_button') {
      return (value == 1) ? 'Ditekan' : 'Tidak Ditekan';
    }
    if (key == 'geofence_status') { // Atribut baru
      return (value == 1) ? 'Di Dalam Geofence' : 'Di Luar Geofence';
    }
    if (key == 'is_synced') {
      return (value == 1) ? 'Sudah Sinkron' : 'Belum Sinkron';
    }
    if (key == 'id') return value.toString();
    return value.toString();
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
              icon: Icon(Icons.select_all),
              onPressed: _toggleSelectionMode,
              tooltip: "Select Data",
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadDataHistory,
              tooltip: "Refresh Data",
            ),
            IconButton(
              icon: Icon(Icons.delete_sweep),
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
                          if (!_isSelectionMode) {
                            _toggleSelectionMode();
                          }
                          _toggleDeviceSelection(deviceId);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: isDeviceFullySelected ? Colors.blue.shade100 : Colors.transparent,
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
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    onTap: _isSelectionMode
                                        ? () => _toggleDateSelection(deviceId, dateKey)
                                        : null,
                                    onLongPress: () {
                                      if (!_isSelectionMode) {
                                        _toggleSelectionMode();
                                      }
                                      _toggleDateSelection(deviceId, dateKey);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      color: isDateFullySelected ? Colors.lightBlue.shade50 : Colors.transparent,
                                      child: ExpansionTile(
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
                                        children: dailyRecords.map((record) {
                                          final recordId = record['id'] as int;
                                          final isSelected = _selectedRecordIds.contains(recordId);

                                          return InkWell(
                                            onTap: _isSelectionMode
                                                ? () => _toggleRecordSelection(recordId)
                                                : null,
                                            onLongPress: () {
                                              if (!_isSelectionMode) {
                                                _toggleSelectionMode();
                                                _toggleRecordSelection(recordId);
                                              }
                                            },
                                            child: Container(
                                              color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                              child: Row(
                                                children: [
                                                  if (_isSelectionMode)
                                                    Checkbox(
                                                      value: isSelected,
                                                      onChanged: (bool? value) {
                                                        _toggleRecordSelection(recordId);
                                                      },
                                                    ),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: record.entries.map((entry) {
                                                        if (entry.key == 'id') return const SizedBox.shrink();

                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                          child: Row(
                                                            children: [
                                                              Icon(_getDataIcon(entry.key), size: 18, color: Colors.grey.shade600),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                "${entry.key.replaceAll('_', ' ').toUpperCase()}: ",
                                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  _formatValue(entry.key, entry.value),
                                                                  style: const TextStyle(fontSize: 14),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
