import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'device_services.dart';
import 'live_frame.dart';

/// Keeps a local live preview open. A remote request can only receive one
/// copied frame after [captureFrame] is called explicitly by the voice flow.
class VoiceCameraService extends ChangeNotifier {
  final CameraService camera = CameraService();
  CameraController? get controller => camera.controller;
  bool ready = false, starting = false;
  String? error;
  Completer<LiveFrame>? _nextCapture;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed || ready || starting) return;
    starting = true;
    error = null;
    _notify();
    try {
      await camera.initialize();
      if (_disposed) {
        await camera.dispose();
        return;
      }
      await camera.startStream((frame) {
        final waiter = _nextCapture;
        if (waiter == null || waiter.isCompleted) return;
        _nextCapture = null;
        waiter.complete(
          LiveFrame(
            Uint8List.fromList(frame.bytes),
            frame.width,
            frame.height,
            frame.bytesPerRow,
          ),
        );
      });
      ready = true;
    } catch (_) {
      error = 'تعذر فتح الكاميرا. اسمح بالصلاحية من إعدادات الآيفون.';
      await camera.dispose();
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<Uint8List> captureFrame(bool Function() stillActive) async {
    if (!ready) await start();
    if (!ready || !stillActive()) {
      throw StateError('Camera is not available');
    }
    if (_nextCapture != null) throw StateError('Capture already in progress');
    final waiter = Completer<LiveFrame>();
    _nextCapture = waiter;
    try {
      final frame = await waiter.future.timeout(const Duration(seconds: 5));
      if (!stillActive()) throw StateError('Capture cancelled');
      final jpeg = await LocalPPEService().snapshot(frame);
      if (jpeg == null || jpeg.isEmpty) {
        throw StateError('Frame encoding failed');
      }
      return jpeg;
    } finally {
      if (identical(_nextCapture, waiter)) _nextCapture = null;
    }
  }

  Future<void> stop() async {
    final waiter = _nextCapture;
    _nextCapture = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(StateError('Camera stopped'));
    }
    ready = false;
    starting = false;
    await camera.dispose();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
