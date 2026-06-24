import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('crm_cache.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE api_cache (
        endpoint TEXT PRIMARY KEY,
        response_body TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE action_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        body TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  // --- GET Cache Methods ---

  static Future<void> cacheResponse(String endpoint, String responseBody) async {
    final db = await database;
    await db.insert(
      'api_cache',
      {
        'endpoint': endpoint,
        'response_body': responseBody,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getCachedResponse(String endpoint) async {
    final db = await database;
    final maps = await db.query(
      'api_cache',
      columns: ['response_body'],
      where: 'endpoint = ?',
      whereArgs: [endpoint],
    );

    if (maps.isNotEmpty) {
      return maps.first['response_body'] as String;
    }
    return null;
  }

  // --- POST/PUT Queue Methods ---

  static Future<void> queueAction(String method, String endpoint, Map<dynamic, dynamic> body) async {
    final db = await database;
    await db.insert('action_queue', {
      'method': method,
      'endpoint': endpoint,
      'body': jsonEncode(body),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> getQueuedActions() async {
    final db = await database;
    return await db.query('action_queue', orderBy: 'timestamp ASC');
  }

  static Future<void> removeQueuedAction(int id) async {
    final db = await database;
    await db.delete(
      'action_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('api_cache');
    await db.delete('action_queue');
  }
}
