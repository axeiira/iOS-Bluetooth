import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'telemetry.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // creating table
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
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    print("REAL: Database table 'gps_data' created with new schema.");

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
    print('REAL: Database table "pairings" created with new schema.');


  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE pairings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          worker_id TEXT NOT NULL,
          worker_name TEXT,
          timestamp TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE pairings ADD COLUMN assignment_reason TEXT');
    }
  }

  // Fungsi untuk menyimpan data GPS
  Future<int> insertGpsData(Map<String, dynamic> row) async {
    Database db = await instance.database;
    if (row.containsKey('tag_button') && row['tag_button'] is bool) {
      row['tag_button'] = row['tag_button'] ? 1 : 0;
    }
    if (row.containsKey('geofence_status') && row['geofence_status'] is bool) {
      row['geofence_status'] = row['geofence_status'] ? 1 : 0;
    }
    final id = await db.insert('gps_data', row);
    print("REAL: Inserted GPS data with ID: $id.");
    return id;
  }

  // Fungsi untuk menyimpan pairing
  Future<int> insertPairing(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('pairings', row);
  }

  // mendapatkan data pairing yang belum synced
  Future<List<Map<String, dynamic>>> getUnsyncedPairings() async {
    Database db = await instance.database;
    return await db.query('pairings', where: 'is_synced = 0', orderBy: 'timestamp DESC');
  }

  // Mengambil semua data yang belum disinkronkan dari SQLite
  Future<List<Map<String, dynamic>>> getUnsyncedGpsData() async {
    Database db = await instance.database;
    final unsynced = await db.query('gps_data', where: 'is_synced = 0');
    print("REAL: Fetched ${unsynced.length} unsynced GPS data records.");
    return unsynced;
  }

  // Menghitung jumlah data yang belum disinkronkan dari SQLite
  Future<int> countUnsyncedGpsData() async {
    Database db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM gps_data WHERE is_synced = 0');
    final count = Sqflite.firstIntValue(result) ?? 0;
    print("REAL: Counted $count unsynced GPS data records.");
    return count;
  }

  // Mengambil ringkasan data yang belum disinkronkan per perangkat dari SQLite
  Future<List<Map<String, dynamic>>> getUnsyncedGpsDataSummary() async {
    Database db = await instance.database;
    final summary = await db.rawQuery('''
      SELECT device_id, COUNT(*) as total_unsynced
      FROM gps_data
      WHERE is_synced = 0
      GROUP BY device_id
    ''');
    print("REAL: Fetched unsynced GPS data summary: $summary");
    return summary;
  }

  // Menandai data sebagai sudah disinkronkan di SQLite
  Future<int> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return 0;
    Database db = await instance.database;
    final batch = db.batch();
    for (int id in ids) {
      batch.update(
        'gps_data',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    final results = await batch.commit();
    final updatedCount = results.where((r) => r is int && r > 0).length;
    print("REAL: Marked $updatedCount records as synced.");
    return updatedCount;
  }

  // Menghapus data berdasarkan ID dari SQLite
  Future<int> deleteGpsData(List<int> ids) async {
    if (ids.isEmpty) return 0;
    Database db = await instance.database;
    final batch = db.batch();
    for (int id in ids) {
      batch.delete(
        'gps_data',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    final results = await batch.commit();
    final deletedCount = results.where((r) => r is int && r > 0).length;
    print("REAL: Deleted $deletedCount records.");
    return deletedCount;
  }

  // Mengambil semua data GPS dari SQLite (untuk log)
  Future<List<Map<String, dynamic>>> getAllGpsData({int? limit}) async { 
    Database db = await instance.database;
    final data = await db.query(
      'gps_data', 
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    print("REAL: Fetched ${data.length} all GPS data records.");
    return data;
  }

  // Mengambil history data per device per hari dari SQLite
  Future<Map<String, Map<String, List<Map<String, dynamic>>>>> getGpsDataHistoryGrouped() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> allData = await db.query('gps_data', orderBy: 'timestamp DESC');

    final Map<String, Map<String, List<Map<String, dynamic>>>> groupedData = {};

    for (var record in allData) {
      final String deviceId = record['device_id'];
      final DateTime timestamp = DateTime.parse(record['timestamp']);
      final String dateKey = DateFormat('yyyy-MM-dd').format(timestamp);

      if (!groupedData.containsKey(deviceId)) {
        groupedData[deviceId] = {};
      }
      if (!groupedData[deviceId]!.containsKey(dateKey)) {
        groupedData[deviceId]![dateKey] = [];
      }
      groupedData[deviceId]![dateKey]!.add(record);
    }
    print("REAL: Grouped GPS data history.");
    return groupedData;
  }

  // Menghapus semua data dari SQLite
  Future<void> deleteAllData() async {
    Database db = await instance.database;
    await db.delete('gps_data');
    await db.delete('pairings');
    await db.execute('VACUUM');
    print("REAL: All data deleted and database vacuumed.");
  }

  // Mengambil unsynced GPS data per perangkat
  Future<List<Map<String, dynamic>>> getUnsyncedGpsDataForDevice(String deviceId) async {
    Database db = await instance.database;
    final unsynced = await db.query(
      'gps_data',
      where: 'is_synced = 0 AND device_id = ?',
      whereArgs: [deviceId],
    );
    print("REAL: Fetched ${unsynced.length} unsynced GPS data records for device $deviceId.");
    return unsynced;
  }

  // mengambil data untuk recent activities
  Future<List<Map<String, dynamic>>> getRecentActivityHeaders({int limit = 100}) async {
    Database db = await instance.database;
    final headers = await db.query(
      'gps_data',
      columns: ['device_id', 'timestamp'],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return headers;
  }

  Future<int> countRecordsInSession(String deviceId, String initialTimestamp) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM gps_data
      WHERE device_id = ? AND
            strftime('%s', timestamp) - strftime('%s', ?) < 300 AND
            strftime('%s', timestamp) - strftime('%s', ?) >= 0
    ''', [deviceId, initialTimestamp]);
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // mengambil daftar device_id
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

  // Mendapatkan data terakhir dan jumlah untuk tiap perangkat
  Future<Map<String, dynamic>?> getLatestSessionInfoForDevice(String deviceId) async {
    final db = await instance.database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM gps_data WHERE device_id = ?',
      [deviceId],
    );
    final latestRecordResult = await db.query(
      'gps_data',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (latestRecordResult.isNotEmpty) {
      return {
        'count': Sqflite.firstIntValue(countResult) ?? 0,
        'latest_timestamp': latestRecordResult.first['timestamp'],
      };
    }
    return null;
  }

  // Mendapatkan path file database
  Future<String> getDatabasePath() async {
    return join(await getDatabasesPath(), 'telemetry.db');
  }

  // mendapatkan ukuran file database dalam MB
  Future<double> getDatabaseSize() async {
    final path = await getDatabasePath();
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.length();
      return bytes / (1024 * 1024); // bytes to megabytes
    }
    return 0.0;
  }

  // ekspor semua data menjadi string format CSV
  Future<String> exportToCsv() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> allData = await db.query('gps_data');

    if (allData.isEmpty) {
      return ""; // return string kosong jika tidak ada data
    }

    List<String> headers = allData.first.keys.toList();
    List<List<dynamic>> rows = [];
    rows.add(headers);

    for (var row in allData) {
      List<dynamic> rowValues = headers.map((header) => row[header]).toList();
      rows.add(rowValues);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // fungsi untuk mendapatkan data summary per device
  Future<List<Map<String, dynamic>>> getDataSummaryByDevice() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT device_id, COUNT(*) as record_count
      FROM gps_data
      GROUP BY device_id
      ORDER BY record_count DESC
    ''');
    return result;
  }

  // ekspor data untuk satu device spesifik
  Future<String> exportDeviceToCsv(String deviceId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> deviceData = await db.query(
      'gps_data',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    if (deviceData.isEmpty) return "";

    List<String> headers = deviceData.first.keys.toList();
    List<List<dynamic>> rows = [headers];

    for (var row in deviceData) {
      rows.add(headers.map((header) => row[header]).toList());
    }

    return const ListToCsvConverter().convert(rows);
  }

  // fungsi untuk menghapus data yang sudah lebih dari 30 hari
  Future<int> deleteOldData() async {
    final db = await instance.database;
    
    const int retentionDays = 7;  // hardcoded
    
    final cutoffDate = DateTime.now().subtract(const Duration(days: retentionDays));
    final timestampString = cutoffDate.toIso8601String();

    final count = await db.delete(
      'gps_data',
      where: 'is_synced = 1 AND timestamp < ?',
      whereArgs: [timestampString],
    );
    
    if (count > 0) {
      print("REAL: Auto-deleted $count synced records older than $retentionDays days.");
    }
    return count;
  }

  // menandai pairing yang sudah disinkronkan
  Future<int> markPairingsAsSynced(List<int> ids) async {
    if (ids.isEmpty) return 0;
    Database db = await instance.database;
    final batch = db.batch();
    for (int id in ids) {
      batch.update(
        'pairings',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    final results = await batch.commit();
    return results.length;
  }
}