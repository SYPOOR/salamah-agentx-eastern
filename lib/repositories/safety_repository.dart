import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/safety.dart';
import 'leadership_repository.dart';

class SafetyRepository {
  final Database db;
  SafetyRepository(this.db);
  static Future<SafetyRepository> open() async => SafetyRepository(
    await openDatabase(
      p.join(await getDatabasesPath(), 'safetylens.db'),
      version: 2,
      onUpgrade: (db, old, next) async {
        if (old < 2) await LeadershipRepository.migrate(db);
      },
      onCreate: (db, v) async {
        await db.execute(
          'CREATE TABLE zones (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE events (id TEXT PRIMARY KEY, timestamp TEXT NOT NULL, data TEXT NOT NULL)',
        );
        await db.execute('CREATE INDEX events_time ON events(timestamp)');
        await db.execute(
          'CREATE TABLE settings (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        );
        await LeadershipRepository.migrate(db);
      },
    ),
  );
  Future<List<SafetyZone>> zones() async => (await db.query(
    'zones',
  )).map((r) => SafetyZone.fromJson(jsonDecode(r['data'] as String))).toList();
  Future<List<SafetyEvent>> events() async => (await db.query(
    'events',
    orderBy: 'timestamp DESC',
  )).map((r) => SafetyEvent.fromJson(jsonDecode(r['data'] as String))).toList();
  Future<SafetySettings> settings() async {
    final rows = await db.query(
      'settings',
      where: 'id = ?',
      whereArgs: ['main'],
    );
    return rows.isEmpty
        ? const SafetySettings()
        : SafetySettings.fromJson(jsonDecode(rows.first['data'] as String));
  }

  Future<void> saveZone(SafetyZone z) async {
    await db.insert('zones', {
      'id': z.id,
      'data': jsonEncode(z.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteZone(String id) async {
    await db.delete('zones', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addEvents(List<SafetyEvent> events) async {
    await db.transaction((txn) async {
      for (final e in events) {
        await txn.insert('events', {
          'id': e.id,
          'timestamp': e.timestamp.toIso8601String(),
          'data': jsonEncode(e.toJson()),
        });
      }
    });
  }

  Future<void> saveSettings(SafetySettings s) async {
    await db.insert('settings', {
      'id': 'main',
      'data': jsonEncode(s.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearEvents() async {
    await db.delete('events');
  }
}
