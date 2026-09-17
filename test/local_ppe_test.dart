import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safety_lens_ai/models/safety.dart';
import 'package:safety_lens_ai/services/live_frame.dart';
import 'package:safety_lens_ai/services/device_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.safetylens/local_ppe');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'PPE uses native inference without cloud consent, URL, or token',
    () async {
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            called = true;
            expect(call.method, 'inferFrame');
            expect(call.arguments['pixels'], [255, 216, 255, 217]);
            expect(call.arguments['confidence'], .4);
            return {
              'predictions': [
                {
                  'class': 'Hardhat',
                  'confidence': .73,
                  'x': 100.0,
                  'y': 80.0,
                  'width': 45.0,
                  'height': 30.0,
                },
              ],
              'image': {'width': 640.0, 'height': 480.0},
              'supported_ppe': ['helmet', 'vest', 'gloves', 'goggles', 'mask'],
              'elapsed_ms': 85.2,
            };
          });
      final service = LocalPPEService();
      final result = await service.inferFrame(
        LiveFrame(Uint8List.fromList([255, 216, 255, 217]), 1, 1, 4),
        const SafetySettings(),
      );
      expect(called, isTrue);
      expect(result.predictions.single.label, 'Hardhat');
      expect(result.predictions.single.confidence, .73);
      expect(result.supported, contains(PPEType.gloves));
      expect(service.elapsedMs, 85);
    },
  );
  test(
    'native model failure stays an error rather than an empty safe scan',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(
              code: 'LOCAL_PPE',
              message: 'Model unavailable',
            ),
          );
      expect(
        () => LocalPPEService().inferFrame(
          LiveFrame(Uint8List(4), 1, 1, 4),
          const SafetySettings(),
        ),
        throwsA(isA<PlatformException>()),
      );
    },
  );
  test('local threshold migration retains later user choices', () {
    final legacy = const SafetySettings(threshold: .6).toJson()
      ..remove('inferenceVersion');
    expect(SafetySettings.fromJson(legacy).threshold, .4);
    expect(
      SafetySettings.fromJson(
        const SafetySettings(threshold: .75).toJson(),
      ).threshold,
      .75,
    );
  });
}
