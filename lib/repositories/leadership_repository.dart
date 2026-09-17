import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/leadership.dart';
import '../models/safety.dart';

class LeadershipRepository {
  final Database db;
  LeadershipRepository(this.db);
  static Future<void> migrate(DatabaseExecutor db) async {
    for (final sql in [
      'CREATE TABLE voice_commands (id TEXT PRIMARY KEY, transcript TEXT NOT NULL, intent TEXT NOT NULL, assistant_response TEXT NOT NULL, severity TEXT NOT NULL, created_at TEXT NOT NULL, event_id TEXT, has_image INTEGER NOT NULL DEFAULT 0)',
      'CREATE TABLE leadership_tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL, zone_id TEXT, priority TEXT NOT NULL, status TEXT NOT NULL, due_date TEXT, created_at TEXT NOT NULL, completed_at TEXT)',
      'CREATE TABLE safety_missions (id TEXT PRIMARY KEY, task_id TEXT NOT NULL UNIQUE, completed_at TEXT, outcome TEXT)',
      'CREATE TABLE mission_steps (id TEXT PRIMARY KEY, mission_id TEXT NOT NULL, title TEXT NOT NULL, ordinal INTEGER NOT NULL, completed INTEGER NOT NULL DEFAULT 0, UNIQUE(mission_id, ordinal))',
      'CREATE TABLE ai_safety_briefs (id TEXT PRIMARY KEY, summary TEXT NOT NULL, facts TEXT NOT NULL, created_at TEXT NOT NULL)',
      'CREATE TABLE analyzed_frames (id TEXT PRIMARY KEY, voice_command_id TEXT NOT NULL UNIQUE, analysis TEXT NOT NULL, created_at TEXT NOT NULL)',
      'CREATE INDEX voice_time ON voice_commands(created_at)',
    ]) {
      await db.execute(sql);
    }
  }

  Future<void> saveVoice({
    required String id,
    required String transcript,
    required VoiceIntent intent,
    required String reply,
    required String severity,
    SafetyEvent? event,
    String? analysis,
  }) async {
    await db.transaction((tx) async {
      final now = DateTime.now().toIso8601String();
      if (event != null) {
        await tx.insert('events', {
          'id': event.id,
          'timestamp': event.timestamp.toIso8601String(),
          'data': jsonEncode(event.toJson()),
        });
      }
      await tx.insert('voice_commands', {
        'id': id,
        'transcript': transcript,
        'intent': intent.name,
        'assistant_response': reply,
        'severity': severity,
        'created_at': now,
        'event_id': event?.id,
        'has_image': analysis == null ? 0 : 1,
      });
      if (analysis != null) {
        await tx.insert('analyzed_frames', {
          'id': id,
          'voice_command_id': id,
          'analysis': analysis,
          'created_at': now,
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> voices() =>
      db.query('voice_commands', orderBy: 'created_at DESC', limit: 20);
  Future<List<LeadershipTask>> tasks() async => (await db.query(
    'leadership_tasks',
    orderBy: 'created_at DESC',
  )).map(LeadershipTask.fromRow).toList();
  Future<List<MissionStep>> steps(String taskId) async => (await db.rawQuery(
    'SELECT s.* FROM mission_steps s JOIN safety_missions m ON m.id=s.mission_id WHERE m.task_id=? ORDER BY s.ordinal',
    [taskId],
  )).map(MissionStep.fromRow).toList();
  Future<void> createTask(LeadershipTask task, {required bool mission}) async {
    if (task.title.trim().isEmpty) throw ArgumentError('Task title required');
    await db.transaction((tx) async {
      await tx.insert('leadership_tasks', task.toRow());
      if (!mission) return;
      await tx.insert('safety_missions', {'id': task.id, 'task_id': task.id});
      const labels = [
        'إكمال فحص معدات الوقاية',
        'التوجه إلى منطقة العمل',
        'التأكد من تجنب المنطقة المحظورة',
        'تأكيد الدخول الآمن',
        'إنهاء المهمة',
      ];
      for (var i = 0; i < labels.length; i++) {
        await tx.insert('mission_steps', {
          'id': '${task.id}-$i',
          'mission_id': task.id,
          'title': labels[i],
          'ordinal': i,
          'completed': 0,
        });
      }
    });
  }

  Future<void> startTask(String id) => db.update(
    'leadership_tasks',
    {'status': 'inProgress'},
    where: 'id=? AND status=?',
    whereArgs: [id, 'pending'],
  );

  /// Sequential, atomic, idempotent: last step and completion event commit together.
  Future<void> completeStep(String taskId, String stepId) async {
    await db.transaction((tx) async {
      final rows = await tx.query(
        'mission_steps',
        where: 'mission_id=?',
        whereArgs: [taskId],
        orderBy: 'ordinal',
      );
      final pending = rows.where((r) => r['completed'] == 0).toList();
      if (pending.isEmpty) return;
      if (pending.first['id'] != stepId) {
        throw StateError('أكمل الخطوات بالترتيب');
      }
      await tx.update(
        'mission_steps',
        {'completed': 1},
        where: 'id=?',
        whereArgs: [stepId],
      );
      await tx.update(
        'leadership_tasks',
        {'status': 'inProgress'},
        where: 'id=?',
        whereArgs: [taskId],
      );
      if (pending.length == 1) await _finish(tx, taskId, true);
    });
  }

  Future<void> completeTask(String id) => db.transaction((tx) async {
    final missions = await tx.query(
      'safety_missions',
      where: 'task_id=?',
      whereArgs: [id],
    );
    if (missions.isNotEmpty) throw StateError('أكمل خطوات المهمة أولًا');
    await _finish(tx, id, false);
  });
  Future<void> _finish(Transaction tx, String id, bool mission) async {
    final now = DateTime.now();
    final rows = await tx.query(
      'leadership_tasks',
      where: 'id=?',
      whereArgs: [id],
    );
    if (rows.isEmpty || rows.first['status'] == 'completed') return;
    await tx.update(
      'leadership_tasks',
      {'status': 'completed', 'completed_at': now.toIso8601String()},
      where: 'id=?',
      whereArgs: [id],
    );
    if (mission) {
      await tx.update(
        'safety_missions',
        {'completed_at': now.toIso8601String()},
        where: 'task_id=?',
        whereArgs: [id],
      );
    }
    final event = SafetyEvent(
      id: 'task-complete-$id',
      type: mission ? 'mission_completed' : 'task_completed',
      title: mission ? 'اكتملت مهمة السلامة' : 'اكتملت المهمة',
      description: rows.first['title'] as String,
      severity: Severity.info,
      timestamp: now,
      source: 'leadership',
      zoneId: rows.first['zone_id'] as String?,
    );
    await tx.insert('events', {
      'id': event.id,
      'timestamp': now.toIso8601String(),
      'data': jsonEncode(event.toJson()),
    });
  }

  Future<Map<String, dynamic>> facts() async {
    // One database snapshot keeps KPIs and the brief input consistent.
    return db.transaction((tx) async {
      final events = (await tx.query('events', orderBy: 'timestamp DESC'))
          .map((r) => SafetyEvent.fromJson(jsonDecode(r['data'] as String)))
          .toList();
      final tasks = await tx.query(
        'leadership_tasks',
        orderBy: 'created_at DESC',
      );
      final hazards = events.where((e) => e.type == 'hazard_report').toList();
      Future<int> count(String table) async =>
          Sqflite.firstIntValue(
            await tx.rawQuery('SELECT COUNT(*) FROM $table'),
          ) ??
          0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return {
        'as_of': now.toIso8601String(),
        'period': 'all recorded local data; events_today is local calendar day',
        'open_hazards': hazards.where((e) => e.status == 'open').length,
        'critical_hazards': hazards
            .where((e) => e.status == 'open' && e.severity == Severity.critical)
            .length,
        'tasks': tasks.length,
        'completed_tasks': tasks
            .where((t) => t['status'] == 'completed')
            .length,
        'voice_reports': hazards.where((e) => e.source == 'voice').length,
        'analyzed_frames': await count('analyzed_frames'),
        'voice_commands': await count('voice_commands'),
        'events_total': events.length,
        'events_today': events
            .where((e) => !e.timestamp.isBefore(today))
            .length,
        'event_counts': {
          for (final type in events.map((e) => e.type).toSet())
            type: events.where((e) => e.type == type).length,
        },
        'recent_events': events
            .take(15)
            .map(
              (e) => {
                'type': e.type,
                'title': e.title,
                'severity': e.severity.name,
                'timestamp': e.timestamp.toIso8601String(),
              },
            )
            .toList(),
        'recent_voice_commands': (await tx.query(
          'voice_commands',
          columns: ['intent', 'created_at'],
          orderBy: 'created_at DESC',
          limit: 10,
        )),
        'recent_tasks': tasks.take(10).toList(),
      };
    });
  }

  Future<Map<String, Object?>?> latestBrief() async {
    final rows = await db.query(
      'ai_safety_briefs',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> saveBrief(String summary, Map<String, dynamic> facts) =>
      db.insert('ai_safety_briefs', {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'summary': summary,
        'facts': jsonEncode(facts),
        'created_at': DateTime.now().toIso8601String(),
      });
}
