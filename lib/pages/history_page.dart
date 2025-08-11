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

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    refreshPage();
  }

  Future<void> refreshPage() async {
    await _loadCalendarData();
    await _loadSummaryForDay(_focusedDay);
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
        final date = DateTime.parse(ds);
        return DateTime.utc(date.year, date.month, date.day);
      }).toSet();
      
      if (mounted) {
        setState(() {
          _activeDates = activeDates;
        });
      }
    } catch (e) {
      print("Error loading calendar data: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load server data.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCalendar = false;
        });
      }
    }
  }

  Future<void> _loadSummaryForDay(DateTime day) async {
    if (mounted) setState(() {
      _isLoadingSummary = true;
      _errorMessage = null;
    });

    final dateString = DateFormat('yyyy-MM-dd').format(day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    
    List<Map<String, dynamic>> summaries;

    try {
      if (!day.isBefore(sevenDaysAgo)) {
        print("Fetching summary from LOCAL for $dateString");
        summaries = await _dbHelper.getDailySummaryLocal(dateString);
      } else {
        print("Fetching summary from SERVER for $dateString");
        summaries = await _httpManager.getDailySummary(dateString);
      }

      if (mounted) {
        setState(() {
          _dailySummaries = summaries;
          if (summaries.isEmpty) {
            _errorMessage = "No activity recorded on this date.";
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
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));

    List<Map<String, dynamic>> records;
    bool isLocal = !_selectedDay!.isBefore(sevenDaysAgo);

    if (isLocal) {
       print("Fetching route details from LOCAL for $dateString");
      records = await _dbHelper.getRouteDetailsLocal(deviceId.toString(), dateString);
    } else {
       print("Fetching route details from SERVER for $dateString");
      records = await _httpManager.getRouteDetails(deviceId as int, dateString);
    }

    if (mounted) {
      Navigator.pop(context);
      if (records.isNotEmpty) {
        
        List<Map<String, dynamic>> normalizedRecords = records;
        if (isLocal) {
            normalizedRecords = records.map((record) {
                final newRecord = Map<String, dynamic>.from(record);
                newRecord['createdAt'] = newRecord['timestamp']; 
                newRecord['eventTagging'] = newRecord['tag_button'] == 1; 
                newRecord.remove('timestamp');
                newRecord.remove('tag_button');
                return newRecord;
            }).toList();
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MapViewPage(records: normalizedRecords)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not fetch route details."))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.historyTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Divider(),
          ),
          Expanded(
            child: _buildSummaryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    if (_isLoadingCalendar) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(height: 400, color: Colors.white, margin: const EdgeInsets.all(12)),
      );
    }
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: _onDaySelected,
      eventLoader: (day) {
        final dayOnly = DateTime.utc(day.year, day.month, day.day);
        return _activeDates.contains(dayOnly) ? [true] : [];
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
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
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
    if (_dailySummaries.isEmpty) {
      return Center(child: Text(_errorMessage ?? "Select a date to see the summary."));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _dailySummaries.length,
      itemBuilder: (context, index) {
        final summary = _dailySummaries[index];
        final deviceId = summary['deviceId'] ?? summary['device_id'];
        final workerName = summary['workerName'] ?? 'Unassigned';
        final recordCount = summary['recordCount'];
        final startTime = DateFormat.jm().format(DateTime.parse(summary['startTime']).toLocal());
        final endTime = DateFormat.jm().format(DateTime.parse(summary['endTime']).toLocal());

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            onTap: () => _navigateToMapView(deviceId, workerName),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Device $deviceId",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(workerName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.watch_later_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text("$startTime - $endTime"),
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
                      Text("View Route Details", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
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
