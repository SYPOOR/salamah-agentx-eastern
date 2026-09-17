import 'dart:math' as math;
import '../models/safety.dart';

class ZoneService {
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    const r = math.pi / 180;
    final a =
        math.pow(math.sin((lat2 - lat1) * r / 2), 2) +
        math.cos(lat1 * r) *
            math.cos(lat2 * r) *
            math.pow(math.sin((lon2 - lon1) * r / 2), 2);
    return 6371000 *
        2 *
        math.atan2(math.sqrt(a.clamp(0, 1)), math.sqrt((1 - a).clamp(0, 1)));
  }

  static double bearing(double lat1, double lon1, double lat2, double lon2) {
    const r = math.pi / 180;
    return (math.atan2(
                  math.sin((lon2 - lon1) * r) * math.cos(lat2 * r),
                  math.cos(lat1 * r) * math.sin(lat2 * r) -
                      math.sin(lat1 * r) *
                          math.cos(lat2 * r) *
                          math.cos((lon2 - lon1) * r),
                ) /
                r +
            360) %
        360;
  }

  static double headingDelta(double bearing, double heading) =>
      (bearing - heading + 540) % 360 - 180;
  // Site-sized polygons: project around the query point into local metres.
  static double polygonDistance(
    double lat,
    double lon,
    List<ZoneVertex> vertices,
  ) {
    final scale = math.cos(lat * math.pi / 180);
    final p = vertices
        .map(
          (v) => math.Point(
            (v.longitude - lon) * 111195 * scale,
            (v.latitude - lat) * 111195,
          ),
        )
        .toList();
    var inside = false;
    var nearest = double.infinity;
    for (var i = 0; i < p.length; i++) {
      final a = p[i], b = p[(i + 1) % p.length];
      final dx = b.x - a.x, dy = b.y - a.y, len = dx * dx + dy * dy;
      final t = len == 0 ? 0.0 : (-(a.x * dx + a.y * dy) / len).clamp(0.0, 1.0);
      nearest = math.min(
        nearest,
        math.sqrt(math.pow(a.x + t * dx, 2) + math.pow(a.y + t * dy, 2)),
      );
      if ((a.y > 0) != (b.y > 0) &&
          0 < (b.x - a.x) * (-a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return nearest < .001
        ? 0
        : inside
        ? -nearest
        : nearest;
  }

  static String? validatePolygon(List<ZoneVertex> v) {
    if (v.length < 3) return 'حدّد ثلاث زوايا على الأقل';
    if (v.length > 32) return 'الحد الأقصى ٣٢ زاوية';
    if (v.any(
      (p) =>
          !p.latitude.isFinite ||
          !p.longitude.isFinite ||
          p.latitude.abs() > 85 ||
          p.longitude.abs() > 180,
    )) {
      return 'موقع غير صالح';
    }
    final scale = math.cos(v.first.latitude * math.pi / 180);
    final p = v
        .map(
          (a) => math.Point(
            (a.longitude - v.first.longitude) * 111195 * scale,
            (a.latitude - v.first.latitude) * 111195,
          ),
        )
        .toList();
    double cross(
      math.Point<double> a,
      math.Point<double> b,
      math.Point<double> c,
    ) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    bool on(math.Point<double> a, math.Point<double> b, math.Point<double> c) =>
        cross(a, b, c).abs() < .001 &&
        c.x >= math.min(a.x, b.x) - .001 &&
        c.x <= math.max(a.x, b.x) + .001 &&
        c.y >= math.min(a.y, b.y) - .001 &&
        c.y <= math.max(a.y, b.y) + .001;
    for (var i = 0; i < p.length; i++) {
      if (p[i].distanceTo(p[(i + 1) % p.length]) < 1) {
        return 'اترك مترًا على الأقل بين الزوايا';
      }
      if (p[i].distanceTo(p.first) > 5000) {
        return 'قسّم الموقع إلى مناطق أصغر من ٥ كم';
      }
      for (var j = i + 1; j < p.length; j++) {
        if (j == i + 1 || (i == 0 && j == p.length - 1)) continue;
        final a = p[i],
            b = p[(i + 1) % p.length],
            c = p[j],
            d = p[(j + 1) % p.length];
        if ((cross(a, b, c) * cross(a, b, d) < 0 &&
                cross(c, d, a) * cross(c, d, b) < 0) ||
            on(a, b, c) ||
            on(a, b, d) ||
            on(c, d, a) ||
            on(c, d, b)) {
          return 'الحدود متقاطعة؛ تراجع وأعد تحديد الزوايا بالترتيب';
        }
      }
    }
    var area = 0.0;
    for (var i = 0; i < p.length; i++) {
      final a = p[i], b = p[(i + 1) % p.length];
      area += a.x * b.y - b.x * a.y;
    }
    return area.abs() < 8 ? 'مساحة المنطقة صغيرة جدًا' : null;
  }

  List<ZoneReading> evaluate(GeoPoint point, List<SafetyZone> zones) =>
      zones.where((z) => z.isActive).map((z) {
          final d = distance(
            point.latitude,
            point.longitude,
            z.latitude,
            z.longitude,
          );
          final signed = z.isPolygon
              ? polygonDistance(point.latitude, point.longitude, z.vertices)
              : d - z.radius;
          return ZoneReading(
            z,
            d,
            bearing(point.latitude, point.longitude, z.latitude, z.longitude),
            signed.abs() <= point.accuracy,
            signedBoundaryDistance: signed,
          );
        }).toList()
        ..sort((a, b) => a.boundaryDistance.compareTo(b.boundaryDistance));
}

class EventDebouncer {
  final Duration persistence, cooldown;
  final Map<String, DateTime> _first = {}, _last = {};
  final Set<String> _latched = {};
  EventDebouncer({
    this.persistence = const Duration(seconds: 2),
    this.cooldown = const Duration(seconds: 30),
  });
  bool update(String key, bool active, DateTime now) {
    if (!active) {
      _first.remove(key);
      _last.remove(key);
      _latched.remove(key);
      return false;
    }
    final first = _first.putIfAbsent(key, () => now);
    if (now.difference(first) < persistence || _latched.contains(key)) {
      return false;
    }
    if (_last[key] != null && now.difference(_last[key]!) < cooldown) {
      return false;
    }
    _last[key] = now;
    _latched.add(key);
    return true;
  }

  void reset() {
    _first.clear();
    _last.clear();
    _latched.clear();
  }
}

class PPEAssessment {
  final Map<PPEType, DetectionState> states;
  final String? reason;
  final int people;
  PPEAssessment(this.states, this.people, [this.reason]);
  Set<PPEType> get missing => states.entries
      .where((e) => e.value == DetectionState.missing)
      .map((e) => e.key)
      .toSet();
  double? get compliance =>
      states.isEmpty || states.values.contains(DetectionState.unknown)
      ? null
      : states.values.where((v) => v == DetectionState.detected).length /
            states.length *
            100;
}

class PPEEngine {
  static const aliases = <PPEType, Set<String>>{
    PPEType.helmet: {'helmet', 'hardhat', 'hard hat'},
    PPEType.vest: {'vest', 'safety vest', 'safetyvest'},
    PPEType.gloves: {'gloves', 'glove'},
    PPEType.goggles: {'goggles', 'safety glasses', 'glasses'},
    PPEType.mask: {'mask', 'face mask'},
  };
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ').trim();
  PPEAssessment assess(InferenceResult result, SafetySettings settings) {
    final predictions = result.predictions
        .where((p) => p.confidence >= settings.threshold)
        .toList();
    final people = predictions
        .where((p) => normalize(p.label) == 'person')
        .toList();
    // A single-worker scan prevents PPE belonging to another worker from producing a pass.
    if (people.length != 1) {
      return PPEAssessment(
        {for (final t in settings.requiredPPE) t: DetectionState.unknown},
        people.length,
        people.isEmpty
            ? 'Position one worker fully in the frame'
            : 'Scan one worker at a time',
      );
    }
    final person = people.single;
    final own = predictions.where(person.contains).toList();
    return PPEAssessment(
      {
        for (final type in settings.requiredPPE)
          type: !result.supported.contains(type)
              ? DetectionState.unknown
              : own.any(
                  (p) => aliases[type]!.any(
                    (a) =>
                        normalize(p.label) == 'no $a' ||
                        normalize(p.label) == 'missing $a',
                  ),
                )
              ? DetectionState.missing
              : own.any((p) => aliases[type]!.contains(normalize(p.label)))
              ? DetectionState.detected
              : DetectionState.missing,
      },
      1,
      settings.requiredPPE.any((t) => !result.supported.contains(t))
          ? 'Some required PPE is unsupported by this model'
          : null,
    );
  }
}

class RiskAssessment {
  final Severity severity;
  final int score;
  final List<String> reasons;
  const RiskAssessment(this.severity, this.score, this.reasons);
}

class SafetyRiskEngine {
  RiskAssessment evaluate({
    PPEAssessment? ppe,
    List<ZoneReading> zones = const [],
    bool locationKnown = false,
  }) {
    int penalty = 0;
    Severity severity = Severity.safe;
    final reasons = <String>[];
    for (final type in ppe?.missing ?? <PPEType>{}) {
      penalty += {
        PPEType.helmet: 30,
        PPEType.vest: 20,
        PPEType.gloves: 10,
        PPEType.goggles: 10,
        PPEType.mask: 10,
      }[type]!;
      severity =
          type == PPEType.helmet &&
              zones.any((z) => z.inside && z.zone.type == ZoneType.work)
          ? Severity.critical
          : severity == Severity.critical
          ? severity
          : Severity.warning;
      reasons.add('${type.label} not detected');
    }
    if (zones.any((z) => z.inside && z.zone.type == ZoneType.restricted)) {
      penalty += 50;
      severity = Severity.critical;
      reasons.add('Restricted area entered');
    } else if (zones.any(
      (z) => z.zone.type == ZoneType.restricted && z.boundaryDistance <= 5,
    )) {
      penalty += 20;
      if (severity != Severity.critical) {
        severity = Severity.warning;
      }
      reasons.add('Restricted zone ahead');
    }
    if (zones.any((z) => z.inside && z.zone.type == ZoneType.highRisk)) {
      penalty += 10;
      if (severity != Severity.critical) {
        severity = Severity.warning;
      }
      reasons.add('Inside high risk area');
    }
    if (locationKnown &&
        zones.any((z) => z.zone.type == ZoneType.work) &&
        !zones.any((z) => z.zone.type == ZoneType.work && z.inside)) {
      penalty += 10;
      if (severity != Severity.critical) {
        severity = Severity.warning;
      }
      reasons.add('Outside work area');
    }
    if (zones.any((z) => z.uncertain)) {
      if (severity != Severity.critical) {
        severity = Severity.warning;
      }
      reasons.add('GPS boundary uncertain');
    }
    if (reasons.isEmpty && (ppe?.compliance == null || !locationKnown)) {
      severity = Severity.info;
      reasons.add('Awaiting safety measurements');
    }
    return RiskAssessment(severity, (100 - penalty).clamp(0, 100), reasons);
  }
}

class DashboardAnalytics {
  final List<SafetyEvent> events;
  DashboardAnalytics(List<SafetyEvent> all, DateTime now)
    : events = all
          .where(
            (e) =>
                e.timestamp.year == now.year &&
                e.timestamp.month == now.month &&
                e.timestamp.day == now.day,
          )
          .toList();
  List<SafetyEvent> get scans =>
      events.where((e) => e.type == 'ppe_scan').toList();
  double? get compliance => scans.isEmpty
      ? null
      : scans.map((e) => e.compliance ?? 0).reduce((a, b) => a + b) /
            scans.length;
  int get missing => events.where((e) => e.type == 'ppe_violation').length;
  int get breaches => events.where((e) => e.type == 'zone_breach').length;
  int get critical =>
      events.where((e) => e.severity == Severity.critical).length;
  double? get score {
    if (events.isEmpty) {
      return null;
    }
    final zoneEvents = events.where((e) => e.type.startsWith('zone_')).toList();
    final zoneCompliance = zoneEvents.isEmpty
        ? 100.0
        : 100 *
              (1 -
                  zoneEvents.where((e) => e.type == 'zone_breach').length /
                      zoneEvents.length);
    return ((compliance ?? 100) * .65 +
            zoneCompliance * .35 -
            math.min(20, critical * 5) -
            math.min(10, missing * 2))
        .clamp(0, 100);
  }

  Map<String, int> get violations {
    final counts = <String, int>{};
    for (final e in events.where(
      (e) => e.type == 'ppe_violation' || e.type == 'zone_breach',
    )) {
      counts.update(e.title, (v) => v + 1, ifAbsent: () => 1);
    }
    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  List<double?> get hourlyTrend => List.generate(8, (i) {
    final group = scans.where((e) => e.timestamp.hour ~/ 3 == i).toList();
    return group.isEmpty
        ? null
        : group.map((e) => e.compliance!).reduce((a, b) => a + b) /
              group.length;
  });
}
