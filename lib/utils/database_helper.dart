import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE telemetry_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        speed INTEGER NOT NULL,
        heading INTEGER NOT NULL,
        fuel REAL NOT NULL,
        engine_hours REAL NOT NULL,
        ignition_status INTEGER NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertTelemetry(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert('telemetry_data', row);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedTelemetry() async {
    Database db = await instance.database;
    return await db.query('telemetry_data', where: 'is_synced = 0');
  }

  Future<int> markAsSynced(int id) async {
    Database db = await instance.database;
    return await db.update(
      'telemetry_data',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countUnsynced() async {
    Database db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM telemetry_data WHERE is_synced = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getAllTelemetry() async {
    Database db = await instance.database;
    return await db.query('telemetry_data', orderBy: 'id DESC');
  }
}