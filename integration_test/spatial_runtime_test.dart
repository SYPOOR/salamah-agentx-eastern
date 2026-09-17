import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safety_lens_ai/widgets/site_map.dart';
import 'package:safety_lens_ai/models/safety.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Apple MapKit and ARKit start on the physical iPhone', (
    tester,
  ) async {
    final controller = SiteMapController();
    final zone = SafetyZone(
      id: 'runtime-fixture',
      name: 'Runtime fixture',
      type: ZoneType.restricted,
      latitude: 24.7136,
      longitude: 46.6753,
      radius: 8,
      createdAt: DateTime(2026),
      vertices: const [
        ZoneVertex(24.7136, 46.6753),
        ZoneVertex(24.7137, 46.6753),
        ZoneVertex(24.7137, 46.6754),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiteMap(
            controller: controller,
            center: const ZoneVertex(24.7136, 46.6753),
            zones: [zone],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 2));
    await controller.move(const ZoneVertex(24.71365, 46.67535));
    await controller.zoom(true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    MethodChannel? channel;
    var samples = 0;
    var supported = false;
    final errors = <String>[];
    final states = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UiKitView(
            viewType: 'ai.safetylens/ar',
            onPlatformViewCreated: (id) async {
              channel = MethodChannel('ai.safetylens/ar/$id');
              channel!.setMethodCallHandler((call) async {
                final a = Map<String, dynamic>.from(call.arguments as Map);
                if (call.method == 'state' && a['error'] != null) {
                  errors.add(a['error'] as String);
                }
                if (call.method == 'projection') {
                  samples++;
                  states.add(a['tracking'] as String);
                }
              });
              final result = await channel!.invokeMapMethod<String, dynamic>(
                'start',
              );
              supported = result?['supported'] == true;
              await channel!.invokeMethod('update', {
                'fresh': true,
                'latitude': 24.7136,
                'longitude': 46.6753,
                'accuracy': 5.0,
                'zones': [zone.toJson()],
                'selected': zone.id,
              });
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 8));
    try {
      expect(supported, isTrue);
      expect(samples, greaterThan(10));
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        ...binding.reportData ?? {},
        'arkitProjectionUpdates': samples,
        'arkitTrackingStates': states.toList(),
        'arkitErrors': errors,
      };
    } finally {
      await channel?.invokeMethod('dispose');
      channel?.setMethodCallHandler(null);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
