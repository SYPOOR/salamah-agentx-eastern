import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safety_lens_ai/models/safety.dart';
import 'package:safety_lens_ai/services/device_services.dart';
import 'package:safety_lens_ai/services/live_frame.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real iPhone live preview and raw frame inference stay active', (
    tester,
  ) async {
    final camera = CameraService(),
        engine = LocalPPEService(),
        gate = LiveFrameGate();
    final clock = Stopwatch()..start();
    var received = 0, analyzed = 0, concurrent = 0, peak = 0;
    final errors = <String>[];
    Future<void>? active;
    bool ending = false;
    await camera.initialize();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CameraPreview(camera.controller!))),
    );
    Future<void> analyze(LiveFrame frame) async {
      concurrent++;
      if (concurrent > peak) peak = concurrent;
      try {
        final result = await engine.inferFrame(frame, const SafetySettings());
        expect(result.width, frame.width.toDouble());
        expect(result.height, frame.height.toDouble());
        analyzed++;
      } catch (e) {
        errors.add(e.toString());
      } finally {
        concurrent--;
        gate.complete();
      }
    }

    try {
      await camera.startStream((frame) {
        received++;
        if (!ending && gate.tryBegin(clock.elapsed)) active = analyze(frame);
      });
      await Future<void>.delayed(const Duration(seconds: 8));
      ending = true;
      await active;
      expect(received, greaterThan(30));
      expect(analyzed, greaterThanOrEqualTo(3));
      expect(peak, 1);
      expect(errors, isEmpty);
      expect(camera.controller!.value.isStreamingImages, isTrue);
      binding.reportData = {
        'framesReceived': received,
        'framesAnalyzed': analyzed,
        'peakConcurrent': peak,
        'durationMs': clock.elapsedMilliseconds,
        'lastNativeMs': engine.elapsedMs,
        'errors': errors,
      };
      // Stop/reopen catches lifecycle races after a completed live analysis.
      await camera.dispose();
      await camera.initialize();
      var resumed = 0;
      await camera.startStream((_) => resumed++);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(resumed, greaterThan(0));
    } finally {
      ending = true;
      await active;
      await camera.dispose();
      engine.dispose();
    }
  });
}
