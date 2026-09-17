import 'dart:math' as math;

enum Severity { safe, info, warning, high, critical }

enum ZoneType { work, restricted, highRisk }

enum ZoneStatus {
  outside,
  insideWork,
  nearRestricted,
  insideRestricted,
  insideHighRisk,
}

enum PPEType { helmet, vest, gloves, goggles, mask }

enum DetectionState { detected, missing, unknown }

extension PPELabel on PPEType {
  String get label =>
      ['Helmet', 'Safety Vest', 'Gloves', 'Safety Glasses', 'Mask'][index];
}

class PPERequirement {
  final PPEType type;
  final bool required;
  const PPERequirement(this.type, this.required);
  String get id => type.name;
  String get name => type.label;
}

class PPEDetection {
  final PPEType type;
  final DetectionState state;
  final double confidence;
  final DateTime timestamp;
  PPEDetection(this.type, this.state, this.confidence, this.timestamp);
  bool get detected => state == DetectionState.detected;
}

class ZoneVertex {
  final double latitude, longitude;
  const ZoneVertex(this.latitude, this.longitude);
  Map<String, double> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
  factory ZoneVertex.fromJson(Map<String, dynamic> j) => ZoneVertex(
    (j['latitude'] as num).toDouble(),
    (j['longitude'] as num).toDouble(),
  );
}

class SafetyZone {
  final String id, name;
  final ZoneType type;
  final double latitude, longitude, radius;
  final bool isActive;
  final DateTime createdAt;
  final List<ZoneVertex> vertices;
  bool get isPolygon => vertices.length >= 3;
  const SafetyZone({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.createdAt,
    this.isActive = true,
    this.vertices = const [],
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'vertices': vertices.map((v) => v.toJson()).toList(),
  };
  factory SafetyZone.fromJson(Map<String, dynamic> j) => SafetyZone(
    id: j['id'],
    name: j['name'],
    type: ZoneType.values.byName(j['type']),
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    radius: (j['radius'] as num).toDouble(),
    isActive: j['isActive'],
    createdAt: DateTime.parse(j['createdAt']),
    vertices: (j['vertices'] as List? ?? [])
        .map((v) => ZoneVertex.fromJson(Map<String, dynamic>.from(v)))
        .toList(),
  );
}

class SafetyEvent {
  final String? source, transcript, status;
  final String id, type, title, description;
  final Severity severity;
  final DateTime timestamp;
  final double? latitude, longitude, compliance;
  final String? zoneId, snapshotPath;
  final PPEType? ppeType;
  const SafetyEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.zoneId,
    this.ppeType,
    this.snapshotPath,
    this.compliance,
    this.source,
    this.transcript,
    this.status,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'description': description,
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'zoneId': zoneId,
    'ppeType': ppeType?.name,
    'snapshotPath': snapshotPath,
    'compliance': compliance,
    'source': source,
    'transcript': transcript,
    'status': status,
  };
  factory SafetyEvent.fromJson(Map<String, dynamic> j) => SafetyEvent(
    id: j['id'],
    type: j['type'],
    title: j['title'],
    description: j['description'],
    severity: Severity.values.byName(j['severity']),
    timestamp: DateTime.parse(j['timestamp']),
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    zoneId: j['zoneId'],
    ppeType: j['ppeType'] == null ? null : PPEType.values.byName(j['ppeType']),
    snapshotPath: j['snapshotPath'],
    compliance: (j['compliance'] as num?)?.toDouble(),
    source: j['source'],
    transcript: j['transcript'],
    status: j['status'],
  );
}

class SafetySettings {
  final Set<PPEType> requiredPPE;
  final double threshold;
  final bool sound, vibration, snapshots, cloudConsent;
  final String proxyUrl;
  const SafetySettings({
    this.requiredPPE = const {PPEType.helmet, PPEType.vest, PPEType.gloves},
    this.threshold = .4,
    this.sound = true,
    this.vibration = true,
    this.snapshots = false,
    this.cloudConsent = false,
    this.proxyUrl = '',
  });
  SafetySettings copyWith({
    Set<PPEType>? requiredPPE,
    double? threshold,
    bool? sound,
    bool? vibration,
    bool? snapshots,
    bool? cloudConsent,
    String? proxyUrl,
  }) => SafetySettings(
    requiredPPE: requiredPPE ?? this.requiredPPE,
    threshold: threshold ?? this.threshold,
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    snapshots: snapshots ?? this.snapshots,
    cloudConsent: cloudConsent ?? this.cloudConsent,
    proxyUrl: proxyUrl ?? this.proxyUrl,
  );
  Map<String, dynamic> toJson() => {
    'required': requiredPPE.map((e) => e.name).toList(),
    'threshold': threshold,
    'inferenceVersion': 2,
    'sound': sound,
    'vibration': vibration,
    'snapshots': snapshots,
    'cloudConsent': cloudConsent,
    'proxyUrl': proxyUrl,
  };
  factory SafetySettings.fromJson(Map<String, dynamic> j) => SafetySettings(
    requiredPPE: (j['required'] as List)
        .map((e) => PPEType.values.byName(e))
        .toSet(),
    threshold: j['inferenceVersion'] == 2
        ? (j['threshold'] as num).toDouble()
        : .4,
    sound: j['sound'],
    vibration: j['vibration'],
    snapshots: j['snapshots'],
    cloudConsent: j['cloudConsent'] ?? false,
    proxyUrl: j['proxyUrl'] ?? '',
  );
}

class GeoPoint {
  final double latitude, longitude, accuracy;
  final DateTime timestamp;
  GeoPoint(
    this.latitude,
    this.longitude, {
    this.accuracy = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ZoneReading {
  final SafetyZone zone;
  final double distance, bearing;
  final bool uncertain;
  final double? signedBoundaryDistance;
  const ZoneReading(
    this.zone,
    this.distance,
    this.bearing,
    this.uncertain, {
    this.signedBoundaryDistance,
  });
  double get boundaryDistance =>
      math.max(0, signedBoundaryDistance ?? distance - zone.radius);
  bool get inside => (signedBoundaryDistance ?? distance - zone.radius) <= 0;
}

class Prediction {
  final String label;
  final double confidence, x, y, width, height;
  const Prediction(
    this.label,
    this.confidence,
    this.x,
    this.y,
    this.width,
    this.height,
  );
  factory Prediction.fromJson(Map<String, dynamic> j) => Prediction(
    j['class'],
    (j['confidence'] as num).toDouble(),
    (j['x'] as num).toDouble(),
    (j['y'] as num).toDouble(),
    (j['width'] as num).toDouble(),
    (j['height'] as num).toDouble(),
  );
  bool contains(Prediction other) =>
      (x - other.x).abs() <= width / 2 && (y - other.y).abs() <= height / 2;
}

class InferenceResult {
  final List<Prediction> predictions;
  final Set<PPEType> supported;
  final double width, height;
  const InferenceResult(
    this.predictions,
    this.supported,
    this.width,
    this.height,
  );
}
