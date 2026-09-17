import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safety_lens_ai/repositories/safety_repository.dart';
import 'package:safety_lens_ai/models/safety.dart';
import 'package:safety_lens_ai/services/event_service.dart';
import 'package:safety_lens_ai/services/device_services.dart';

void main() {
  late SafetyRepository repo;
  setUp(() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onCreate: (db, v) async {
          await db.execute(
            'CREATE TABLE zones (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE events (id TEXT PRIMARY KEY, timestamp TEXT NOT NULL, data TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
        },
        version: 1,
      ),
    );
    repo = SafetyRepository(db);
  });
  tearDown(() async {
    await repo.db.close();
  });
  test('notification failure cannot discard a persisted event', () async {
    final service = EventService(repo, _FailingNotifications());
    final e = SafetyEvent(
      id: 'feedback-test',
      type: 'zone_breach',
      title: 'Restricted area entered',
      description: 'Test',
      severity: Severity.critical,
      timestamp: DateTime.now(),
    );
    await service.persist([e]);
    expect(await service.feedback([e], const SafetySettings()), false);
    expect((await repo.events()).single.id, 'feedback-test');
  });
  test('zones create, edit, reload and delete', () async {
    final z = SafetyZone(
      id: 'z',
      name: 'Work',
      type: ZoneType.work,
      latitude: 24,
      longitude: 46,
      radius: 30,
      createdAt: DateTime.now(),
    );
    await repo.saveZone(z);
    expect((await repo.zones()).single.name, 'Work');
    await repo.saveZone(
      SafetyZone(
        id: 'z',
        name: 'Restricted',
        type: ZoneType.restricted,
        latitude: 24,
        longitude: 46,
        radius: 40,
        createdAt: z.createdAt,
      ),
    );
    expect((await repo.zones()).single.radius, 40);
    await repo.deleteZone('z');
    expect(await repo.zones(), isEmpty);
  });
  test('event batch atomicity and settings survive history deletion', () async {
    final e = SafetyEvent(
      id: 'e',
      type: 'ppe_scan',
      title: 'Passed',
      description: 'Test',
      severity: Severity.safe,
      timestamp: DateTime.now(),
      compliance: 100,
    );
    await repo.addEvents([e]);
    expect((await repo.events()).single.compliance, 100);
    await expectLater(
      repo.addEvents([
        SafetyEvent(
          id: 'new',
          type: 'x',
          title: 'x',
          description: 'x',
          severity: Severity.info,
          timestamp: DateTime.now(),
        ),
        e,
      ]),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repo.events()).length, 1);
    await repo.saveSettings(const SafetySettings(threshold: .8));
    await repo.clearEvents();
    expect(await repo.events(), isEmpty);
    expect((await repo.settings()).threshold, .8);
  });
}

class _FailingNotifications extends NotificationService {
  @override
  Future<void> alert(SafetyEvent event, SafetySettings settings) async {
    throw StateError('Unavailable device feedback');
  }
}
