import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/app_strings.dart';
import '../utils/http_manager.dart';
import 'map_view_page.dart';
import '../utils/database_helper.dart';
import 'package:shimmer/shimmer.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  final HttpManager _httpManager = HttpManager();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  Set<DateTime> _activeDates = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _dailySummaries = [];
  
  bool _isLoadingCalendar = true;
  bool _isLoadingSummary = false;
  String? _errorMessage;

  // State untuk menyimpan nilai filter
  String? _filterDeviceId;
  String? _filterEmployeeName;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    refreshPage();
  }

  Future<void> refreshPage() async {
    await _loadCalendarData();
    if (mounted) {
      await _loadSummaryForDay(_focusedDay);
    }
  }

  Future<void> _showFilterDialog() async {
    final deviceIdController = TextEditingController(text: _filterDeviceId);
    final employeeNameController = TextEditingController(text: _filterEmployeeName);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Riwayat'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: deviceIdController,
                  decoration: const InputDecoration(
                    labelText: 'Device ID',
                    hintText: 'enter device ID',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: employeeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Employee Name',
                    hintText: 'enter employee name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop({'deviceId': '', 'employeeName': ''});
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'deviceId': deviceIdController.text.trim(),
                  'employeeName': employeeNameController.text.trim(),
                });
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _filterDeviceId = result['deviceId'];
        _filterEmployeeName = result['employeeName'];
      });
      _loadSummaryForDay(_selectedDay ?? DateTime.now());
    }
  }

  Future<void> _loadCalendarData() async {
    if (mounted) setState(() => _isLoadingCalendar = true);
    
    try {
      final serverDatesFuture = _httpManager.getActiveDates();
      final localDatesFuture = _dbHelper.getActiveDatesLocal();

      final results = await Future.wait([serverDatesFuture, localDatesFuture]);
      final serverDateStrings = results[0];
      final localDateStrings = results[1];

      final combinedDateStrings = {...serverDateStrings, ...localDateStrings};

      final activeDates = combinedDateStrings.map((ds) {
        if (ds.isEmpty) return null;
        try {
          final date = DateTime.parse(ds);
          return DateTime.utc(date.year, date.month, date.day);
        } catch (e) {
          return null;
        }
      }).whereType<DateTime>().toSet();
      
      if (mounted) {
        setState(() {
          _activeDates = activeDates;
        });
      }
    } catch (e) {
      print("Error loading calendar data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalendar = false;
        });
      }
    }
  }

  Future<void> _loadSummaryForDay(DateTime day) async {
    if (mounted) {
      setState(() {
      _isLoadingSummary = true;
      _errorMessage = null;
    });
    }

    final dateString = DateFormat('yyyy-MM-dd').format(day);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final selectedUtc = DateTime.utc(day.year, day.month, day.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    
    List<Map<String, dynamic>> summaries = [];
    bool wasFetchedFromServer = false;

    try {
      if (selectedUtc.isAfter(sevenDaysAgo) || selectedUtc.isAtSameMomentAs(sevenDaysAgo)) {
        summaries = await _dbHelper.getDailySummaryLocal(
          dateString,
          deviceId: _filterDeviceId,
          employeeName: _filterEmployeeName,
        );
        if (summaries.isEmpty) {
          summaries = await _httpManager.getDailySummary(
            dateString,
            deviceId: _filterDeviceId,
            employeeName: _filterEmployeeName,
          );
          wasFetchedFromServer = true;
        }
      } else {
        summaries = await _httpManager.getDailySummary(
          dateString,
          deviceId: _filterDeviceId,
          employeeName: _filterEmployeeName,
        );
        wasFetchedFromServer = true;
      }

      final finalSummaries = summaries.map((s) {
        final newSummary = Map<String, dynamic>.from(s);
        newSummary['dataSource'] = wasFetchedFromServer ? 'server' : 'local';
        return newSummary;
      }).toList();

      if (mounted) {
        setState(() {
          _dailySummaries = finalSummaries;
          if (finalSummaries.isEmpty) {
            _errorMessage = "No activity recorded.";
          }
        });
      }
    } catch (e) {
      print("Error loading summary: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load summary.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _dailySummaries = [];
      });
      _loadSummaryForDay(selectedDay);
    }
  }

  Future<void> _navigateToMapView(dynamic deviceId, String workerName) async {
    if (_selectedDay == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final dateString = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final selectedUtc = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    
    final int deviceIdInt = int.tryParse(deviceId.toString()) ?? 0;
    if (deviceIdInt == 0) {
        if(mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Device ID.")));
        return;
    }

    List<Map<String, dynamic>> records = [];
    bool isLocalSource = false;

    try {
      if (selectedUtc.isAfter(sevenDaysAgo) || selectedUtc.isAtSameMomentAs(sevenDaysAgo)) {
        records = await _dbHelper.getRouteDetailsLocal(deviceId.toString(), dateString);
        isLocalSource = true;
        if (records.isEmpty) {
          records = await _httpManager.getRouteDetails(deviceIdInt, dateString);
          isLocalSource = false;
        }
      } else {
        records = await _httpManager.getRouteDetails(deviceIdInt, dateString);
        isLocalSource = false;
      }
    } catch(e) {
      print("Error fetching route details: $e");
    } finally {
       if (mounted) Navigator.pop(context);
    }
    
    if (mounted && records.isNotEmpty) {
      List<Map<String, dynamic>> normalizedRecords = records;
      if (isLocalSource) {
          normalizedRecords = records.map((record) {
              final newRecord = Map<String, dynamic>.from(record);
              newRecord['createdAt'] = newRecord['timestamp']; 
              newRecord['eventTagging'] = newRecord['tag_button'] == 1;
              return newRecord;
          }).toList();
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MapViewPage(records: normalizedRecords)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No route data found for this device on the selected date."))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFilterActive = (_filterDeviceId?.isNotEmpty ?? false) || (_filterEmployeeName?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.historyTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                Icons.filter_list,
                color: isFilterActive ? Theme.of(context).colorScheme.primary : Colors.grey,
              ),
              onPressed: _showFilterDialog,
              tooltip: 'Filter History',
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshPage,
        child: ListView(
          children: [
            _buildCalendar(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Divider(),
            ),
            _buildSummaryList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    if (_isLoadingCalendar) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(height: 350, color: Colors.white, margin: const EdgeInsets.all(12)),
      );
    }
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: _onDaySelected,
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
      eventLoader: (day) {
        final dayOnly = DateTime.utc(day.year, day.month, day.day);
        return _activeDates.contains(dayOnly) ? [Object()] : [];
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        markerSize: 5.0,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
    );
  }

  Widget _buildSummaryList() {
    if (_isLoadingSummary) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }
    if (_dailySummaries.isEmpty) {
       return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Select a date to see the summary.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _dailySummaries.length,
      itemBuilder: (context, index) {
        final summary = _dailySummaries[index];
        final deviceId = summary['deviceId'] ?? summary['device_id'];
        final workerName = summary['workerName'] ?? 'Unassigned';
        final recordCount = summary['recordCount'] ?? 0;
        final startTimeStr = summary['startTime'];
        final endTimeStr = summary['endTime'];
        final dataSource = summary['dataSource'] ?? 'local'; // Default ke lokal jika tidak ada

        String timeRange = "N/A";
        if (startTimeStr != null && endTimeStr != null) {
            try {
              final startTime = DateFormat.jm().format(DateTime.parse(startTimeStr).toLocal());
              final endTime = DateFormat.jm().format(DateTime.parse(endTimeStr).toLocal());
              timeRange = "$startTime - $endTime";
            } catch (e) { /* Abaikan jika format salah */ }
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _navigateToMapView(deviceId, workerName),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Device $deviceId",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Tooltip(
                        message: dataSource == 'server' ? 'Data from Server' : 'Data from Local Storage',
                        child: Icon(
                          dataSource == 'server' ? Icons.cloud_outlined : Icons.phone_android_outlined,
                          size: 20,
                          color: dataSource == 'server' ? Colors.blue.shade600 : Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(workerName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.watch_later_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(timeRange),
                      const SizedBox(width: 16),
                      Icon(Icons.format_list_numbered_rounded, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text("$recordCount Records"),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("View Route Details", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                      Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
