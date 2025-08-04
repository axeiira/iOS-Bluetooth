import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/database_helper.dart';
import '../utils/app_strings.dart';
import 'map_view_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _selectedDayEvents = [];
  bool _isLoading = true;

  final List<Color> _markerColors = [
    const Color(0xFF006FDD),
    const Color(0xFFFFA000),
    Colors.teal.shade700,
    Colors.grey.shade700,
    const Color(0xFFC2185B),
    const Color(0xFF512DA8),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDataForCalendar();
  }

  Future<void> refreshData() async {
    await _loadDataForCalendar();
  }

  Future<void> _loadDataForCalendar() async {
    if (mounted) setState(() => _isLoading = true);
    
    final allData = await DatabaseHelper.instance.getAllGpsData();
    final Map<DateTime, List<Map<String, dynamic>>> eventSource = {};
    for (var record in allData) {
      final timestamp = DateTime.parse(record['timestamp'] as String);
      final dayOnly = DateTime(timestamp.year, timestamp.month, timestamp.day);
      eventSource.putIfAbsent(dayOnly, () => []).add(record);
    }
    
    if (mounted) {
      setState(() {
        _events = eventSource;
        _onDaySelected(_selectedDay!, _focusedDay);
        _isLoading = false;
      });
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedDayEvents = _events[DateTime(selectedDay.year, selectedDay.month, selectedDay.day)] ?? [];
      });
    }
  }

  Color _getColorForDeviceId(String deviceId) {
    final index = deviceId.hashCode % _markerColors.length;
    return _markerColors[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.historyTitle, style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _isLoading 
        ? _buildLoadingSkeleton() 
        : Column(
            children: [
              _buildCalendar(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Divider(),
              ),
              Expanded(
                child: _buildEventList(),
              ),
            ],
          ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: _onDaySelected,
      eventLoader: (day) => _events[DateTime(day.year, day.month, day.day)] ?? [],
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isNotEmpty) {
            final deviceIds = events
                .map((e) => (e as Map<String, dynamic>)['device_id'] as String)
                .toSet()
                .toList();
            
            return Positioned(
              right: 1,
              left: 1,
              bottom: 5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: deviceIds.take(4).map((deviceId) {
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getColorForDeviceId(deviceId),
                    ),
                  );
                }).toList(),
              ),
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _buildEventList() {
    if (_selectedDayEvents.isEmpty) {
      return const Center(child: Text(AppStrings.historyNoDataForDay));
    }

    final Map<String, List<Map<String, dynamic>>> groupedByDevice = {};
    for (var event in _selectedDayEvents) {
      final deviceId = event['device_id'] as String;
      groupedByDevice.putIfAbsent(deviceId, () => []).add(event);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: groupedByDevice.entries.map((entry) {
        final deviceId = entry.key;
        final records = entry.value;
        
        records.sort((a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String));
        final startTime = DateFormat.jm().format(DateTime.parse(records.first['timestamp']!));
        final endTime = DateFormat.jm().format(DateTime.parse(records.last['timestamp']!));

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MapViewPage(records: records)),
              );
            },
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.watch_later_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text("$startTime - $endTime", style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(width: 16),
                      Icon(Icons.format_list_numbered_rounded, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text("${records.length} Records", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      _buildMiniMapPlaceholder(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text("Route Summary", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                             Text("Data for ${DateFormat('d MMMM yyyy').format(_selectedDay!)}", style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        )
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildMiniMapPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.route_rounded, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), size: 40),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          Container(height: 400, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
          const SizedBox(height: 24),
          Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
           const SizedBox(height: 12),
           Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
        ],
      ),
    );
  }
}