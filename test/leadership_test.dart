import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safety_lens_ai/repositories/leadership_repository.dart';
import 'package:safety_lens_ai/repositories/safety_repository.dart';
import 'package:safety_lens_ai/models/leadership.dart';
import 'package:safety_lens_ai/models/safety.dart';
import 'package:safety_lens_ai/services/voice_assistant_service.dart';

void main() {
  late Database db;
  late LeadershipRepository repo;
  late SafetyRepository old;
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE events(id TEXT PRIMARY KEY,timestamp TEXT NOT NULL,data TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE zones(id TEXT PRIMARY KEY,data TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE settings(id TEXT PRIMARY KEY,data TEXT NOT NULL)',
    );
    old = SafetyRepository(db);
    repo = LeadershipRepository(db);
  });
  tearDown(() async => db.close());
  SafetyEvent hazard(String id) => SafetyEvent(
    id: id,
    type: 'hazard_report',
    title: 'خطر',
    description: 'صوت',
    severity: Severity.high,
    timestamp: DateTime.now(),
    source: 'voice',
    status: 'open',
    transcript: 'يوجد خطر',
  );
  LeadershipTask task(String id) => LeadershipTask(
    id: id,
    title: 'دخول منطقة الصيانة',
    description: 'تأكد من السلامة',
    priority: TaskPriority.high,
    status: TaskStatus.pending,
    createdAt: DateTime.now(),
  );
  test(
    'additive migration preserves old event JSON, zones and settings',
    () async {
      final legacy = hazard('old').toJson()
        ..remove('source')
        ..remove('status')
        ..remove('transcript');
      await db.insert('events', {
        'id': 'old',
        'timestamp': DateTime.now().toIso8601String(),
        'data': jsonEncode(legacy),
      });
      await old.saveSettings(const SafetySettings(threshold: .7));
      await old.saveZone(
        SafetyZone(
          id: 'z',
          name: 'Work',
          type: ZoneType.work,
          latitude: 24,
          longitude: 46,
          radius: 30,
          createdAt: DateTime.now(),
        ),
      );
      await LeadershipRepository.migrate(db);
      expect((await old.events()).single.source, isNull);
      expect((await old.zones()).single.name, 'Work');
      expect((await old.settings()).threshold, .7);
      expect(await repo.tasks(), isEmpty);
    },
  );
  test('voice hazard and history commit atomically, with real KPI', () async {
    await LeadershipRepository.migrate(db);
    await repo.saveVoice(
      id: 'v',
      transcript: 'يوجد خطر',
      intent: VoiceIntent.report_hazard,
      reply: 'تم',
      severity: 'high',
      event: hazard('h'),
    );
    expect((await old.events()).single.transcript, 'يوجد خطر');
    expect((await repo.facts())['open_hazards'], 1);
    expect((await repo.facts())['voice_reports'], 1);
    await expectLater(
      repo.saveVoice(
        id: 'v',
        transcript: 'duplicate',
        intent: VoiceIntent.report_hazard,
        reply: 'تم',
        severity: 'high',
        event: hazard('must-rollback'),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect((await old.events()).length, 1);
    expect((await repo.voices()).length, 1);
  });
  test(
    'mission enforces order, persists progress and completes exactly once',
    () async {
      await LeadershipRepository.migrate(db);
      await repo.createTask(task('t'), mission: true);
      var steps = await repo.steps('t');
      expect(steps.length, 5);
      await expectLater(repo.completeStep('t', steps[1].id), throwsStateError);
      await expectLater(repo.completeTask('t'), throwsStateError);
      await repo.completeStep('t', steps[0].id);
      expect((await repo.steps('t')).where((s) => s.completed).length, 1);
      for (final s in steps.skip(1)) {
        await repo.completeStep('t', s.id);
      }
      await repo.completeStep('t', steps.last.id);
      expect((await repo.tasks()).single.status, TaskStatus.completed);
      expect((await old.events()).single.type, 'mission_completed');
      expect((await repo.facts())['completed_tasks'], 1);
    },
  );
  test(
    'standalone task and analyzed frame counts reflect stored records',
    () async {
      await LeadershipRepository.migrate(db);
      await repo.createTask(task('t'), mission: false);
      await repo.startTask('t');
      expect((await repo.tasks()).single.status, TaskStatus.inProgress);
      await repo.completeTask('t');
      await repo.completeTask('t');
      await repo.saveVoice(
        id: 'f',
        transcript: 'التقط فريم',
        intent: VoiceIntent.capture_frame,
        reply: 'غير واضح',
        severity: 'info',
        analysis: 'غير واضح',
      );
      final facts = await repo.facts();
      expect(facts['analyzed_frames'], 1);
      expect(facts['open_hazards'], 0);
      expect(facts['events_total'], 1);
      expect((await old.events()).length, 1);
      await repo.saveBrief('ملخص', facts);
      expect((await repo.latestBrief())!['summary'], 'ملخص');
    },
  );
  test(
    'camera gate accepts natural visual requests and rejects negation and quoted commands',
    () {
      for (final s in [
        'SafetyLens التقط فريم',
        'التقط فريم',
        'صور اللي قدامي',
        'افحص اللي أمامي',
        'شوف قدامي',
        'ماذا أمامي؟',
        'ماالذي أمامي الآن',
        'مالذي امامي',
        'وش قدامي',
        'وش تشوف قدامي',
        'ايش قدامي',
        'حلل المشهد',
        'صف لي ما أمامي',
        'أرني ما حولي',
        'خذ لي صورة للمشهد',
        'التقط لي لقطة',
        'هل يوجد خطر أمامي؟',
        'هل فيه عامل قدامي',
      ]) {
        expect(explicitCameraCommand(s), true, reason: s);
      }
      for (final s in [
        'لا تلتقط صورة',
        'لا تصور اللي قدامي',
        'اشرح معنى التقط فريم',
        'يوجد خطر هنا',
        "don't take a photo",
      ]) {
        expect(explicitCameraCommand(s), false, reason: s);
      }
    },
  );
  test('malformed model flags cannot authorize additional action', () {
    expect(
      () => VoiceDecision.fromJson({
        'intent': 'safety_question',
        'reply': 'x',
        'severity': 'info',
        'capture_frame': true,
        'create_event': false,
      }),
      throwsFormatException,
    );
    expect(
      () => VoiceDecision.fromJson({
        'intent': 'delete_database',
        'reply': 'x',
        'severity': 'info',
        'capture_frame': false,
        'create_event': false,
      }),
      throwsArgumentError,
    );
  });
}
