import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/safety.dart';
import '../repositories/safety_repository.dart';
import '../services/device_services.dart';
import '../services/event_service.dart';
import '../services/safety_engines.dart';

final appProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw UnimplementedError(),
);

class AppController extends ChangeNotifier {
  final SafetyRepository repository;
  final notification = NotificationService();
  final storage = StorageService();
  late final eventService = EventService(repository, notification);
  final zoneService = ZoneService();
  final ppeEngine = PPEEngine();
  final riskEngine = SafetyRiskEngine();
  final debounce = EventDebouncer();
  SafetySettings settings = const SafetySettings();
  List<SafetyZone> zones = [];
  List<SafetyEvent> events = [];
  List<ZoneReading> readings = [];
  PPEAssessment? ppe;
  GeoPoint? position;
  double? heading;
  String? locationError, feedbackError;
  bool monitoring = false;
  DateTime? lastPpeAt;
  StreamSubscription<GeoPoint>? _location;
  StreamSubscription<double?>? _compass;
  Timer? _freshness;
  final Map<String, String> _zoneStates = {};
  bool _scanLogged = false, _zoneBusy = false;
  Future<Uint8List?> Function()? snapshotCapture;
  AppController(this.repository);
  Future<void> reloadEvents() async {
    events = await repository.events();
    notifyListeners();
  }

  Future<void> initialize() async {
    zones = await repository.zones();
    events = await repository.events();
    settings = await repository.settings();
    await repository.saveSettings(settings);
    try {
      await notification.initialize();
    } catch (_) {
      feedbackError = 'Notifications unavailable; in-app alerts remain active.';
    }
    _freshness = Timer.periodic(const Duration(seconds: 3), (_) {
      if (lastPpeAt != null &&
          DateTime.now().difference(lastPpeAt!).inSeconds > 15) {
        ppe = null;
        lastPpeAt = null;
        debounce.reset();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  bool get locationFresh =>
      monitoring &&
      position != null &&
      DateTime.now().difference(position!.timestamp).inSeconds < 15 &&
      locationError == null;
  List<ZoneReading> get currentReadings => locationFresh ? readings : [];
  RiskAssessment get risk => riskEngine.evaluate(
    ppe: ppe,
    zones: currentReadings,
    locationKnown: locationFresh,
  );
  DashboardAnalytics get analytics =>
      DashboardAnalytics(events, DateTime.now());
  ZoneStatus get zoneStatus {
    final r = currentReadings;
    if (r.any((z) => z.inside && z.zone.type == ZoneType.restricted)) {
      return ZoneStatus.insideRestricted;
    }
    if (r.any(
      (z) => z.zone.type == ZoneType.restricted && z.boundaryDistance <= 5,
    )) {
      return ZoneStatus.nearRestricted;
    }
    if (r.any((z) => z.inside && z.zone.type == ZoneType.highRisk)) {
      return ZoneStatus.insideHighRisk;
    }
    if (r.any((z) => z.inside && z.zone.type == ZoneType.work)) {
      return ZoneStatus.insideWork;
    }
    return ZoneStatus.outside;
  }

  String get zoneLabel {
    if (!locationFresh) {
      return 'Location signal unavailable';
    }
    final inside = readings.where((r) => r.inside).toList()
      ..sort(
        (a, b) => (b.zone.type == ZoneType.restricted ? 3 : b.zone.type.index)
            .compareTo(
              a.zone.type == ZoneType.restricted ? 3 : a.zone.type.index,
            ),
      );
    return inside.isEmpty ? 'Outside saved zones' : inside.first.zone.name;
  }

  Future<void> startMonitoring() async {
    if (monitoring) {
      return;
    }
    try {
      final service = LocationService();
      await service.request();
      monitoring = true;
      locationError = null;
      _location = service.positions.listen(
        (p) async {
          position = p;
          locationError = null;
          readings = zoneService.evaluate(p, zones);
          notifyListeners();
          if (!_zoneBusy) {
            _zoneBusy = true;
            try {
              await _processZones();
            } catch (_) {
              feedbackError =
                  'Could not save a zone event. Check device storage.';
            } finally {
              _zoneBusy = false;
              notifyListeners();
            }
          }
        },
        onError: (Object e) {
          locationError = 'Location signal unavailable';
          notifyListeners();
        },
      );
      _compass = CompassService().headings.listen(
        (h) {
          heading = h;
          notifyListeners();
        },
        onError: (Object e) {
          heading = null;
          notifyListeners();
        },
      );
      try {
        await notification.requestPermission();
      } catch (_) {
        feedbackError = 'Notification permission unavailable.';
      }
    } catch (e) {
      locationError = e.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> stopMonitoring() async {
    await _location?.cancel();
    await _compass?.cancel();
    _location = null;
    _compass = null;
    monitoring = false;
    position = null;
    heading = null;
    readings = [];
    _zoneStates.clear();
    notifyListeners();
  }

  Future<void> _processZones() async {
    if (!locationFresh) {
      return;
    }
    final point = position!;
    for (final r in List<ZoneReading>.of(readings)) {
      // An uncertainty band preserves the last classification and prevents GPS jitter duplicates.
      if (r.uncertain && _zoneStates.containsKey(r.zone.id)) {
        continue;
      }
      final state = r.inside
          ? 'inside'
          : r.zone.type == ZoneType.restricted && r.boundaryDistance <= 5
          ? 'near'
          : 'outside';
      if (_zoneStates[r.zone.id] == state) {
        continue;
      }
      if (state == 'outside') {
        _zoneStates[r.zone.id] = state;
        continue;
      }
      final critical = state == 'inside' && r.zone.type == ZoneType.restricted;
      final severity = critical
          ? Severity.critical
          : state == 'near' || r.zone.type == ZoneType.highRisk
          ? Severity.warning
          : Severity.safe;
      final title = critical
          ? 'Restricted area entered'
          : state == 'near'
          ? 'Restricted zone ahead'
          : r.zone.type == ZoneType.work
          ? 'Work zone entered'
          : 'High risk zone entered';
      final id = _id();
      String? snapshot;
      if (critical && settings.snapshots && snapshotCapture != null) {
        try {
          final bytes = await snapshotCapture!();
          if (bytes != null) {
            snapshot = await storage.saveSnapshot(bytes, id);
          }
        } catch (_) {
          feedbackError = 'Event saved without a snapshot.';
        }
      }
      final event = SafetyEvent(
        id: id,
        type: critical
            ? 'zone_breach'
            : state == 'near'
            ? 'zone_warning'
            : 'zone_entry',
        title: title,
        description:
            '${r.zone.name} • ${r.boundaryDistance.round()} m from boundary. GPS accuracy ±${point.accuracy.round()} m.${r.uncertain ? " Boundary position uncertain." : ""}',
        severity: severity,
        timestamp: DateTime.now(),
        latitude: point.latitude,
        longitude: point.longitude,
        zoneId: r.zone.id,
        snapshotPath: snapshot,
      );
      await record([event]);
      _zoneStates[r.zone.id] = state;
    }
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}_${events.length}';
  Future<void> record(List<SafetyEvent> batch) async {
    await eventService.persist(batch);
    events = [...batch.reversed, ...events];
    notifyListeners();
    if (!await eventService.feedback(batch, settings)) {
      feedbackError = 'Event saved; device feedback unavailable.';
      notifyListeners();
    }
  }

  void beginScan() {
    _scanLogged = false;
    ppe = null;
    debounce.reset();
    notifyListeners();
  }

  void invalidatePpe() {
    ppe = null;
    lastPpeAt = null;
    debounce.reset();
    notifyListeners();
  }

  Future<void> processInference(
    InferenceResult result,
    Uint8List? image, {
    Future<Uint8List?> Function()? snapshotFrame,
  }) async {
    final now = DateTime.now();
    ppe = ppeEngine.assess(result, settings);
    lastPpeAt = now;
    notifyListeners();
    if (ppe!.compliance == null) {
      debounce.reset();
      return;
    }
    final violations = <PPEType>[];
    for (final t in settings.requiredPPE) {
      if (debounce.update(t.name, ppe!.missing.contains(t), now)) {
        violations.add(t);
      }
    }
    final safeStable = debounce.update('passed', ppe!.missing.isEmpty, now);
    if (violations.isEmpty && !safeStable) {
      return;
    }
    final batch = <SafetyEvent>[];
    final id = _id();
    String? snapshot;
    if (settings.snapshots && violations.isNotEmpty) {
      try {
        final bytes = image ?? await snapshotFrame?.call();
        if (bytes != null) snapshot = await storage.saveSnapshot(bytes, id);
      } catch (_) {
        feedbackError = 'Snapshot could not be saved.';
      }
    }
    if (!_scanLogged) {
      batch.add(
        SafetyEvent(
          id: '${id}_scan',
          type: 'ppe_scan',
          title: ppe!.missing.isEmpty ? 'PPE check passed' : 'PPE check failed',
          description:
              'Single-worker check • ${ppe!.compliance!.toStringAsFixed(1)}% compliance',
          severity: ppe!.missing.isEmpty ? Severity.safe : Severity.warning,
          timestamp: now,
          compliance: ppe!.compliance,
          latitude: locationFresh ? position!.latitude : null,
          longitude: locationFresh ? position!.longitude : null,
        ),
      );
    }
    for (final t in violations) {
      batch.add(
        SafetyEvent(
          id: '${id}_${t.name}',
          type: 'ppe_violation',
          title: '${t.label} missing',
          description:
              'Required ${t.label.toLowerCase()} was not detected for at least 2 seconds. Verify visually.',
          severity:
              t == PPEType.helmet &&
                  currentReadings.any(
                    (r) => r.inside && r.zone.type == ZoneType.work,
                  )
              ? Severity.critical
              : Severity.warning,
          timestamp: now,
          ppeType: t,
          snapshotPath: snapshot,
          latitude: locationFresh ? position!.latitude : null,
          longitude: locationFresh ? position!.longitude : null,
          zoneId: currentReadings.where((r) => r.inside).firstOrNull?.zone.id,
        ),
      );
    }
    if (batch.isNotEmpty) {
      try {
        await record(batch);
        _scanLogged = true;
      } catch (_) {
        debounce.reset();
        rethrow;
      }
    }
  }

  Future<void> saveZone(SafetyZone z) async {
    await repository.saveZone(z);
    zones = await repository.zones();
    _zoneStates.remove(z.id);
    if (position != null) {
      readings = zoneService.evaluate(position!, zones);
    }
    notifyListeners();
  }

  Future<void> deleteZone(String id) async {
    await repository.deleteZone(id);
    zones = zones.where((z) => z.id != id).toList();
    readings = readings.where((r) => r.zone.id != id).toList();
    _zoneStates.remove(id);
    notifyListeners();
  }

  Future<void> saveSettings(SafetySettings s) async {
    await repository.saveSettings(s);
    settings = s;
    invalidatePpe();
  }

  Future<void> clearHistory() async {
    await repository.clearEvents();
    events = [];
    await storage.clearSnapshots();
    notifyListeners();
  }

  @override
  void dispose() {
    _location?.cancel();
    _compass?.cancel();
    _freshness?.cancel();
    super.dispose();
  }
}
