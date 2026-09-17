import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safety_lens_ai/services/voice_camera_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('voice page camera streams and captures exactly on request', (
    tester,
  ) async {
    final camera = VoiceCameraService();
    addTearDown(camera.dispose);

    await camera.start();
    expect(camera.ready, isTrue, reason: camera.error);
    expect(camera.controller?.value.isStreamingImages, isTrue);

    final jpeg = await camera.captureFrame(() => true);
    expect(jpeg.length, greaterThan(1000));
    expect(jpeg.take(3), orderedEquals([0xFF, 0xD8, 0xFF]));
    expect(camera.controller?.value.isStreamingImages, isTrue);

    await camera.stop();
    expect(camera.ready, isFalse);
    await camera.start();
    expect(camera.ready, isTrue, reason: camera.error);
  });
}
