import 'package:flutter_test/flutter_test.dart';
import 'package:safety_lens_ai/models/safety.dart';
import 'package:safety_lens_ai/services/safety_engines.dart';

void main() {
  final now = DateTime(2026, 9, 14, 10);
  SafetyZone zone(ZoneType type, {double radius = 30}) => SafetyZone(
    id: type.name,
    name: 'Test zone',
    type: type,
    latitude: 24,
    longitude: 46,
    radius: radius,
    createdAt: now,
  );
  InferenceResult frame(
    List<Prediction> predictions, {
    Set<PPEType> supported = const {
      PPEType.helmet,
      PPEType.vest,
      PPEType.gloves,
    },
  }) => InferenceResult(predictions, supported, 640, 480);
  const person = Prediction('Person', .95, 320, 240, 300, 460);
  const helmet = Prediction('Hardhat', .94, 320, 70, 70, 50);
  const vest = Prediction('Safety-Vest', .91, 320, 240, 140, 130);
  test('required PPE denominator only; two of three = 66.7', () {
    final a = PPEEngine().assess(
      frame([person, helmet, vest]),
      const SafetySettings(),
    );
    expect(a.compliance, closeTo(66.6667, .001));
    expect(a.missing, {PPEType.gloves});
  });
  test('unsupported class is unknown, never a fabricated missing result', () {
    final a = PPEEngine().assess(
      frame([person, helmet, vest], supported: {PPEType.helmet, PPEType.vest}),
      const SafetySettings(),
    );
    expect(a.states[PPEType.gloves], DetectionState.unknown);
    expect(a.compliance, isNull);
    expect(a.missing, isEmpty);
  });
  test('no people and multiple workers cannot pass', () {
    for (final detections in [
      <Prediction>[],
      [person, person, helmet, vest],
    ]) {
      final a = PPEEngine().assess(frame(detections), const SafetySettings());
      expect(a.compliance, isNull);
    }
  });
  test('PPE outside worker box does not count', () {
    final a = PPEEngine().assess(
      frame([person, const Prediction('Hardhat', .99, 10, 10, 5, 5)]),
      const SafetySettings(requiredPPE: {PPEType.helmet}),
    );
    expect(a.missing, {PPEType.helmet});
  });
  test('low confidence excluded and explicit negative takes precedence', () {
    final a = PPEEngine().assess(
      frame([person, const Prediction('Hardhat', .39, 320, 70, 70, 50)]),
      const SafetySettings(requiredPPE: {PPEType.helmet}),
    );
    expect(a.missing, {PPEType.helmet});
    final b = PPEEngine().assess(
      frame([
        person,
        helmet,
        const Prediction('NO-Hardhat', .9, 320, 70, 70, 50),
      ]),
      const SafetySettings(requiredPPE: {PPEType.helmet}),
    );
    expect(b.missing, {PPEType.helmet});
  });
  test('no required equipment is unassessed', () {
    expect(
      PPEEngine()
          .assess(frame([person]), const SafetySettings(requiredPPE: {}))
          .compliance,
      isNull,
    );
  });
  test(
    'debouncing waits two seconds; continuous violation logs once even after cooldown',
    () {
      final d = EventDebouncer();
      expect(d.update('helmet', true, now), false);
      expect(
        d.update('helmet', true, now.add(const Duration(seconds: 1))),
        false,
      );
      expect(
        d.update('helmet', true, now.add(const Duration(seconds: 2))),
        true,
      );
      expect(
        d.update('helmet', true, now.add(const Duration(seconds: 40))),
        false,
      );
      expect(
        d.update('helmet', false, now.add(const Duration(seconds: 41))),
        false,
      );
      expect(
        d.update('helmet', true, now.add(const Duration(seconds: 42))),
        false,
      );
      expect(
        d.update('helmet', true, now.add(const Duration(seconds: 44))),
        true,
      );
    },
  );
  test('interrupted violation does not accumulate persistence', () {
    final d = EventDebouncer();
    d.update('x', true, now);
    d.update('x', false, now.add(const Duration(seconds: 1)));
    expect(d.update('x', true, now.add(const Duration(seconds: 2))), false);
  });
  test('distance and compass wraparound', () {
    expect(ZoneService.distance(0, 0, 0, 1), closeTo(111195, 5));
    expect(ZoneService.bearing(0, 0, 0, 1), closeTo(90, .001));
    expect(ZoneService.headingDelta(1, 359), 2);
    expect(ZoneService.headingDelta(359, 1), -2);
  });
  test('zone distance is measured from circle boundary', () {
    final r = ZoneService().evaluate(GeoPoint(24, 46.0004, accuracy: 5), [
      zone(ZoneType.restricted),
    ]).single;
    expect(r.boundaryDistance, closeTo(r.distance - 30, .01));
    expect(r.inside, false);
  });
  test('GPS uncertainty is visible at boundary', () {
    final r = ZoneService().evaluate(GeoPoint(24, 46.0003, accuracy: 20), [
      zone(ZoneType.work),
    ]).single;
    expect(r.uncertain, true);
  });
  test('restricted zone is always critical and scores clamp', () {
    final p = PPEAssessment({
      for (final t in PPEType.values) t: DetectionState.missing,
    }, 1);
    final risk = SafetyRiskEngine().evaluate(
      ppe: p,
      zones: [ZoneReading(zone(ZoneType.restricted), 0, 0, false)],
      locationKnown: true,
    );
    expect(risk.severity, Severity.critical);
    expect(risk.score, 0);
  });
  test('missing helmet in work zone escalates to critical', () {
    final risk = SafetyRiskEngine().evaluate(
      ppe: PPEAssessment({PPEType.helmet: DetectionState.missing}, 1),
      zones: [ZoneReading(zone(ZoneType.work), 0, 0, false)],
      locationKnown: true,
    );
    expect(risk.severity, Severity.critical);
  });
  test('unknown data must not be presented as safe', () {
    expect(SafetyRiskEngine().evaluate().severity, Severity.info);
  });
  test('dashboard today filter, scans and violation counts are separate', () {
    SafetyEvent event(
      String id,
      String type,
      DateTime at, {
      double? compliance,
      Severity severity = Severity.warning,
    }) => SafetyEvent(
      id: id,
      type: type,
      title: 'Gloves missing',
      description: 'Test',
      severity: severity,
      timestamp: at,
      compliance: compliance,
    );
    final a = DashboardAnalytics([
      event('1', 'ppe_scan', now, compliance: 66.7),
      event('2', 'ppe_violation', now),
      event('3', 'zone_breach', now, severity: Severity.critical),
      event(
        '4',
        'ppe_scan',
        now.subtract(const Duration(days: 1)),
        compliance: 100,
      ),
    ], now);
    expect(a.scans.length, 1);
    expect(a.compliance, 66.7);
    expect(a.missing, 1);
    expect(a.breaches, 1);
    expect(a.critical, 1);
    expect(a.hourlyTrend[3], 66.7);
    expect(a.hourlyTrend[0], isNull);
  });
  test('empty dashboard shows no invented score', () {
    final a = DashboardAnalytics([], now);
    expect(a.score, isNull);
    expect(a.compliance, isNull);
  });
}
