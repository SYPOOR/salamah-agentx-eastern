import 'dart:async';
import 'dart:typed_data';
import 'device_services.dart';
import 'live_frame.dart';

/// One explicit command, one in-memory video frame, one JPEG. No file or queue.
class CameraCommandService {
  final camera = CameraService();
  bool _busy = false;
  Future<Uint8List> capture(bool Function() stillActive) async {
    if (_busy) throw StateError('Camera command already running');
    _busy = true;
    try {
      if (!stillActive()) throw StateError('Cancelled');
      await camera.initialize();
      if (!stillActive()) throw StateError('Cancelled');
      final frame = Completer<LiveFrame>();
      await camera.startStream((f) {
        if (!frame.isCompleted) frame.complete(f);
      });
      final latest = await frame.future.timeout(const Duration(seconds: 8));
      await camera.dispose();
      if (!stillActive()) throw StateError('Cancelled');
      final jpeg = await LocalPPEService().snapshot(latest);
      if (jpeg == null) throw StateError('Frame encoding failed');
      return jpeg;
    } finally {
      await camera.dispose();
      _busy = false;
    }
  }
}
