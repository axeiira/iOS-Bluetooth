import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/database_helper.dart';
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
    final allData = await DatabaseHelper.instance.getAllGpsData();
    final Map<DateTime, List<Map<String, dynamic>>> eventSource = {};

    for (var record in allData) {
      final timestamp = DateTime.parse(record['timestamp'] as String);
      final dayOnly = DateTime(timestamp.year, timestamp.month, timestamp.day);
      if (eventSource[dayOnly] == null) {
        eventSource[dayOnly] = [];
      }
      eventSource[dayOnly]!.add(record);
    }
    
    if (mounted) {
      setState(() {
        _events = eventSource;
        _onDaySelected(_selectedDay!, _focusedDay); // Refresh events for selected day
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data History"),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              eventLoader: (day) => _events[DateTime(day.year, day.month, day.day)] ?? [],
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: Colors.indigoAccent, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(),
          ),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    if (_selectedDayEvents.isEmpty) {
      return const Center(child: Text("No data for this day."));
    }

    // Group events by device ID for the selected day
    final Map<String, List<Map<String, dynamic>>> groupedByDevice = {};
    for (var event in _selectedDayEvents) {
      final deviceId = event['device_id'] as String;
      if (groupedByDevice[deviceId] == null) {
        groupedByDevice[deviceId] = [];
      }
      groupedByDevice[deviceId]!.add(event);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: groupedByDevice.entries.map((entry) {
        final deviceId = entry.key;
        final records = entry.value;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text("${records.length}"),
            ),
            title: Text("Device ID: $deviceId"),
            subtitle: Text("${records.length} records on this day"),
            trailing: const Icon(Icons.map_outlined),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapViewPage(records: records),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}