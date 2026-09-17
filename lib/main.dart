import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_controller.dart';
import 'core/theme.dart';
import 'repositories/safety_repository.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/home/home_page.dart';
import 'features/zones/zones_map_page.dart';
import 'features/alerts/alerts_page.dart';
import 'features/safety_vision/camera_page.dart';
import 'features/safety_vision/ar_vision_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  Intl.defaultLocale = 'ar';
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    final repository = await SafetyRepository.open();
    final controller = AppController(repository);
    await controller.initialize();
    runApp(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => controller)],
        child: const SafetyLensApp(),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        theme: safetyTheme(),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'تعذر فتح التخزين المحلي.\nوفر مساحة على الجهاز وأعد تشغيل التطبيق.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SafetyLensApp extends StatelessWidget {
  const SafetyLensApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SafetyLens AI',
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: safetyTheme(),
    home: const SafetyShell(),
  );
}

class SafetyShell extends ConsumerStatefulWidget {
  const SafetyShell({super.key});
  @override
  ConsumerState<SafetyShell> createState() => _SafetyShellState();
}

class _SafetyShellState extends ConsumerState<SafetyShell>
    with WidgetsBindingObserver {
  int index = 0;
  bool resumeMonitoring = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final app = ref.read(appProvider);
    if (state == AppLifecycleState.paused) {
      resumeMonitoring = app.monitoring;
      app.stopMonitoring();
    } else if (state == AppLifecycleState.resumed && resumeMonitoring) {
      app.startMonitoring();
      resumeMonitoring = false;
    }
  }

  void navigate(int i) => setState(() => index = i);
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return Scaffold(
      body: switch (index) {
        0 => HomePage(onNavigate: navigate),
        1 => const ZonesMapPage(),
        2 => CameraPage(
          key: const ValueKey('ppe'),
          ppeMode: true,
          onExit: () => navigate(0),
        ),
        3 => DashboardPage(
          onNavigate: (i) {
            if (i == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertsPage()),
              );
            } else {
              navigate(i == 1 ? 4 : i);
            }
          },
        ),
        _ => ARVisionPage(
          key: const ValueKey('vision'),
          onExit: () => navigate(0),
        ),
      },
      bottomNavigationBar: index == 4
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: navigate,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  label: 'المناطق',
                ),
                NavigationDestination(
                  icon: Icon(Icons.center_focus_strong),
                  label: 'الفحص',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'التقارير',
                ),
              ],
            ),
      persistentFooterButtons: app.feedbackError == null
          ? null
          : [
              Text(
                app.feedbackError!,
                style: const TextStyle(color: orange, fontSize: 10),
              ),
            ],
    );
  }
}
