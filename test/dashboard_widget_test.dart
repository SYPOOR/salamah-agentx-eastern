import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:safety_lens_ai/core/app_controller.dart';
import 'package:safety_lens_ai/core/theme.dart';
import 'package:safety_lens_ai/features/dashboard/dashboard_page.dart';
import 'package:safety_lens_ai/repositories/safety_repository.dart';

void main() {
  testWidgets('empty dashboard renders honestly on a small iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    sqfliteFfiInit();
    final db = await tester.runAsync(
      () => databaseFactoryFfi.openDatabase(inMemoryDatabasePath),
    );
    final app = AppController(SafetyRepository(db!));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => app)],
        child: MaterialApp(
          theme: safetyTheme(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: DashboardPage(onNavigate: (_) {}),
          ),
        ),
      ),
    );
    expect(find.text('التقارير'), findsOneWidget);
    expect(find.text('التزام المعدات'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => db.close());
  });
}
