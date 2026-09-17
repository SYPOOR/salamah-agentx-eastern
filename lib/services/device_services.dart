import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/safety.dart';
import 'live_frame.dart';

class CameraService {
  CameraController? controller;
  // Serialize ownership across routes so two camera controllers never open together.
  static Future<void> _queue = Future.value();
  static Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return next;
  }

  Future<void> initialize() => _serial(() async {
    await controller?.dispose();
    controller = null;
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('Camera unavailable. Use a physical iPhone.');
    }
    final rear = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    final c = CameraController(
      rear.isNotEmpty ? rear.first : cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    try {
      await c.initialize();
      await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      controller = c;
    } catch (_) {
      await c.dispose();
      rethrow;
    }
  });
  Future<void> startStream(void Function(LiveFrame) onFrame) => _serial(
    () async {
      final c = controller;
      if (c == null || !c.value.isInitialized || c.value.isStreamingImages) {
        return;
      }
      await c.startImageStream((image) {
        if (image.format.group != ImageFormatGroup.bgra8888 ||
            image.planes.length != 1) {
          return;
        }
        final plane = image.planes.single;
        onFrame(
          LiveFrame(plane.bytes, image.width, image.height, plane.bytesPerRow),
        );
      });
    },
  );
  Future<void> dispose() => _serial(() async {
    final c = controller;
    controller = null;
    if (c?.value.isStreamingImages == true) await c!.stopImageStream();
    await c?.dispose();
  });
}

class LocalPPEService {
  static const channel = MethodChannel('ai.safetylens/local_ppe');
  int? elapsedMs;
  Future<InferenceResult> inferFrame(
    LiveFrame frame,
    SafetySettings settings,
  ) async {
    final raw = await channel.invokeMapMethod<String, dynamic>('inferFrame', {
      ...frame.toArguments(),
      'confidence': settings.threshold,
    });
    if (raw == null) throw StateError('Local inference returned no result');
    final size = Map<String, dynamic>.from(raw['image'] as Map);
    elapsedMs = (raw['elapsed_ms'] as num?)?.round();
    return InferenceResult(
      (raw['predictions'] as List)
          .map((p) => Prediction.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      (raw['supported_ppe'] as List)
          .map((s) => PPEType.values.byName(s))
          .toSet(),
      (size['width'] as num).toDouble(),
      (size['height'] as num).toDouble(),
    );
  }

  Future<Uint8List?> snapshot(LiveFrame frame) =>
      channel.invokeMethod<Uint8List>('snapshotFrame', frame.toArguments());

  void dispose() {}
}

class RoboflowService {
  final http.Client client;
  RoboflowService([http.Client? client]) : client = client ?? http.Client();
  static const storage = FlutterSecureStorage();
  Future<InferenceResult> infer(Uint8List jpeg, SafetySettings settings) async {
    if (!settings.cloudConsent) {
      throw StateError('Enable selected-frame cloud processing in Settings.');
    }
    final uri = Uri.tryParse(settings.proxyUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Configure an HTTPS inference proxy in Settings.');
    }
    final token = await storage.read(key: 'proxyToken');
    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'image': base64Encode(jpeg),
            'confidence': settings.threshold,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError(
        'PPE AI unavailable (${response.statusCode}). Check connection and proxy configuration.',
      );
    }
    final j = jsonDecode(response.body) as Map<String, dynamic>;
    final size = j['image'] as Map<String, dynamic>;
    final w = (size['width'] as num).toDouble(),
        h = (size['height'] as num).toDouble();
    if (w <= 0 || h <= 0) {
      throw const FormatException('Invalid inference image size');
    }
    return InferenceResult(
      (j['predictions'] as List)
          .map((p) => Prediction.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      (j['supported_ppe'] as List).map((s) => PPEType.values.byName(s)).toSet(),
      w,
      h,
    );
  }

  void dispose() => client.close();
}

class LocationService {
  Future<void> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'Location services are off. Open Settings to enable GPS.',
      );
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for safety zones.');
    }
  }

  Stream<GeoPoint> get positions =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      ).map(
        (p) => GeoPoint(
          p.latitude,
          p.longitude,
          accuracy: p.accuracy,
          timestamp: p.timestamp,
        ),
      );
}

class CompassService {
  Stream<double?> get headings =>
      FlutterCompass.events?.map(
        (e) => (e.headingForCameraMode != null && e.headingForCameraMode! >= 0)
            ? e.headingForCameraMode
            : (e.heading != null && e.heading! >= 0 ? e.heading : null),
      ) ??
      Stream.value(null);
}

class StorageService {
  Future<String> saveSnapshot(Uint8List bytes, String id) async {
    final root = await getApplicationSupportDirectory();
    final folder = await Directory(
      '${root.path}/snapshots',
    ).create(recursive: true);
    final file = File('${folder.path}/$id.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> clearSnapshots() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/snapshots');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

class NotificationService {
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  Future<void> initialize() async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    ready = true;
  }

  Future<void> requestPermission() async {
    await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: false, sound: true);
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> alert(SafetyEvent event, SafetySettings settings) async {
    if (settings.vibration) {
      if (event.severity == Severity.critical) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    }
    if (event.severity.index < Severity.warning.index) {
      return;
    }
    if (settings.sound) {
      await SystemSound.play(SystemSoundType.alert);
    }
    if (ready) {
      await plugin.show(
        id: event.id.hashCode & 0x7fffffff,
        title: event.title,
        body: event.description,
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: settings.sound,
          ),
          android: AndroidNotificationDetails(
            'safety_${settings.sound}_${settings.vibration}',
            'Safety alerts',
            importance: Importance.high,
            priority: Priority.high,
            playSound: settings.sound,
            enableVibration: settings.vibration,
          ),
        ),
      );
    }
  }
}
