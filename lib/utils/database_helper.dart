import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:csv/csv.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  static const _dbVersion = 6;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'telemetry.db');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE gps_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL NOT NULL,
        num_satellite INTEGER NOT NULL,
        battery_percentage INTEGER NOT NULL,
        tag_button INTEGER NOT NULL,
        geofence_status INTEGER NOT NULL,
        speed INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE pairings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        worker_id TEXT NOT NULL,
        worker_name TEXT,
        assignment_reason TEXT,
        timestamp TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE gps_data ADD COLUMN speed INTEGER NOT NULL DEFAULT 0;');
    }
  }

  Future<int> insertGpsData(Map<String, dynamic> row) async {
    Database db = await instance.database;
    if (row.containsKey('tag_button') && row['tag_button'] is bool) {
      row['tag_button'] = row['tag_button'] ? 1 : 0;
    }
    if (row.containsKey('geofence_status') && row['geofence_status'] is bool) {
      row['geofence_status'] = row['geofence_status'] ? 1 : 0;
    }
    final id = await db.insert('gps_data', row);
    return id;
  }
  
  Future<int> insertPairing(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('pairings', row);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPairings() async {
    Database db = await instance.database;
    return await db.query('pairings', where: 'is_synced = 0', orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedGpsData() async {
    Database db = await instance.database;
    return await db.query('gps_data', where: 'is_synced = 0');
  }

  Future<int> countUnsyncedGpsData() async {
    Database db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM gps_data WHERE is_synced = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedGpsDataSummary() async {
    Database db = await instance.database;
    return await db.rawQuery('''
      SELECT device_id, COUNT(*) as total_unsynced
      FROM gps_data
      WHERE is_synced = 0
      GROUP BY device_id
    ''');
  }

  Future<int> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return 0;
    Database db = await instance.database;
    final batch = db.batch();
    for (int id in ids) {
      batch.update('gps_data', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    final results = await batch.commit();
    return results.where((r) => r is int && r > 0).length;
  }

  Future<List<Map<String, dynamic>>> getAllGpsData({int? limit}) async { 
    Database db = await instance.database;
    return await db.query('gps_data', orderBy: 'timestamp DESC', limit: limit);
  }

  Future<void> deleteAllData() async {
    Database db = await instance.database;
    await db.delete('gps_data');
    await db.delete('pairings');
    await db.execute('VACUUM');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedGpsDataForDevice(String deviceId) async {
    Database db = await instance.database;
    return await db.query('gps_data', where: 'is_synced = 0 AND device_id = ?', whereArgs: [deviceId]);
  }

  Future<List<String>> getUniqueDeviceIds() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.query(
      'gps_data',
      distinct: true,
      columns: ['device_id'],
      orderBy: 'timestamp DESC',
    );
    return result.map((row) => row['device_id'] as String).toList();
  }

  Future<double> getDatabaseSize() async {
    final path = join(await getDatabasesPath(), 'telemetry.db');
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.length();
      return bytes / (1024 * 1024);
    }
    return 0.0;
  }

  Future<String> exportToCsv() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> allData = await db.query('gps_data');
    if (allData.isEmpty) return "";
    List<String> headers = allData.first.keys.toList();
    List<List<dynamic>> rows = [headers];
    for (var row in allData) {
      rows.add(headers.map((header) => row[header]).toList());
    }
    return const ListToCsvConverter().convert(rows);
  }

  Future<List<Map<String, dynamic>>> getDataSummaryByDevice() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT device_id, COUNT(*) as record_count
      FROM gps_data
      GROUP BY device_id
      ORDER BY record_count DESC
    ''');
  }

  Future<String> exportDeviceToCsv(String deviceId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> deviceData = await db.query('gps_data', where: 'device_id = ?', whereArgs: [deviceId]);
    if (deviceData.isEmpty) return "";
    List<String> headers = deviceData.first.keys.toList();
    List<List<dynamic>> rows = [headers];
    for (var row in deviceData) {
      rows.add(headers.map((header) => row[header]).toList());
    }
    return const ListToCsvConverter().convert(rows);
  }

  Future<int> deleteOldData() async {
    final db = await instance.database;
    const int retentionDays = 7;
    final cutoffDate = DateTime.now().subtract(const Duration(days: retentionDays));
    final timestampString = cutoffDate.toIso8601String();
    final count = await db.delete('gps_data', where: 'is_synced = 1 AND timestamp < ?', whereArgs: [timestampString]);
    if (count > 0) {
      print("REAL: Auto-deleted $count synced records older than $retentionDays days.");
    }
    return count;
  }

  Future<int> markPairingsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return 0;
    Database db = await instance.database;
    final batch = db.batch();
    for (int id in ids) {
      batch.update('pairings', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    final results = await batch.commit();
    return results.length;
  }

  Future<List<String>> getActiveDatesLocal() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT DISTINCT date(timestamp) as active_date 
      FROM gps_data 
      ORDER BY timestamp DESC
    ''');
    return result.map((row) => row['active_date'] as String).where((d) => d != null).toList();
  }

  Future<List<Map<String, dynamic>>> getDailySummaryLocal(String date) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> queryResults = await db.rawQuery('''
      SELECT
        device_id,
        COUNT(*) as recordCount,
        MIN(timestamp) as startTime,
        MAX(timestamp) as endTime
      FROM gps_data
      WHERE date(timestamp) = ?
      GROUP BY device_id
    ''', [date]);


    final List<Map<String, dynamic>> summaries = List<Map<String, dynamic>>.from(queryResults);

    for (var i = 0; i < summaries.length; i++) {
      final summary = summaries[i];
      final deviceId = summary['device_id'];
      
      final endOfDay = DateTime.parse(date).add(const Duration(days: 1)).toIso8601String();
      final pairingResult = await db.query(
        'pairings',
        columns: ['worker_name'],
        where: 'device_id = ? AND timestamp < ?',
        whereArgs: [deviceId, endOfDay],
        orderBy: 'timestamp DESC',
        limit: 1,
      );

      final mutableSummary = Map<String, dynamic>.from(summary);
      if (pairingResult.isNotEmpty) {
        mutableSummary['workerName'] = pairingResult.first['worker_name'];
      } else {
        mutableSummary['workerName'] = 'Unassigned';
      }

      final taggedCountResult = await db.rawQuery('''
        SELECT COUNT(*) 
        FROM gps_data 
        WHERE date(timestamp) = ? AND device_id = ? AND tag_button = 1
      ''', [date, deviceId]);
      mutableSummary['taggedEventsCount'] = Sqflite.firstIntValue(taggedCountResult) ?? 0;
      
      summaries[i] = mutableSummary;
    }
    
    return summaries;
  }

  Future<List<Map<String, dynamic>>> getRouteDetailsLocal(String deviceId, String date) async {
    final db = await instance.database;
    return await db.query(
      'gps_data',
      where: 'device_id = ? AND date(timestamp) = ?',
      whereArgs: [deviceId, date],
      orderBy: 'timestamp ASC',
    );
  }
}
