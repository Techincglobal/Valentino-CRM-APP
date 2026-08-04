import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class NotesRepository {
  static const MethodChannel _channel = MethodChannel('crm_caller_nxtgen/native_overlay');
  
  Database? _db;

  Future<Database?> get database async {
    if (_db != null) return _db;
    _db = await _initDb();
    return _db;
  }

  Future<Database?> _initDb() async {
    try {
      final String dbPath = await _channel.invokeMethod('getDatabasePath');
      if (!await databaseExists(dbPath)) {
        return null;
      }
      // Open the db in read-only mode, as Kotlin is the primary writer
      return await openDatabase(dbPath, readOnly: true);
    } catch (e) {
      debugPrint('Could not securely connect to local CRM database: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLatestNotes() async {
    final db = await database;
    if (db == null) return [];
    
    // We fetch notes created from the overlay
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'timestamp DESC',
      limit: 50,
    );
    return maps;
  }
}
