import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/arabic.dart';
import '../../models/safety.dart';
import '../../services/safety_engines.dart';
import '../zones/zone_drawing_page.dart';
import 'ar_label_layout.dart';

class ARVisionPage extends ConsumerStatefulWidget {
  final VoidCallback onExit;
  const ARVisionPage({super.key, required this.onExit});
  @override
  ConsumerState<ARVisionPage> createState() => _ARVisionPageState();
}

class _ARVisionPageState extends ConsumerState<ARVisionPage>
    with WidgetsBindingObserver {
  MethodChannel? channel;
  late AppController app;
  String? selected, error, lastPayload;
  bool ground = false, calibrated = false, visible = false;
  String tracking = 'initializing';
  List<ARLabelTarget> projections = [];
  bool sending = false;
  @override
  void initState() {
    super.initState();
    app = ref.read(appProvider);
    app.addListener(sync);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(app.startMonitoring);
  }

  List<ZoneReading> get nearby => app.currentReadings
      .where((r) => r.boundaryDistance <= 200)
      .take(12)
      .toList();
  void sync() {
    if (!mounted || channel == null || sending) return;
    unawaited(send());
  }

  Future<void> send() async {
    final p = app.position;
    final payload = <String, Object?>{
      'latitude': p?.latitude,
      'longitude': p?.longitude,
      'accuracy': p?.accuracy,
      'fresh': app.locationFresh,
      'selected': selected,
      'zones': nearby.map((r) => r.zone.toJson()).toList(),
    };
    final signature = jsonEncode(payload);
    if (signature == lastPayload) return;
    sending = true;
    try {
      await channel?.invokeMethod('update', payload);
      lastPayload = signature;
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      sending = false;
    }
  }

  Future<void> created(int id) async {
    channel = MethodChannel('ai.safetylens/ar/$id');
    channel!.setMethodCallHandler((call) async {
      if (!mounted) return;
      final a = Map<String, dynamic>.from(call.arguments as Map);
      setState(() {
        if (call.method == 'state') {
          error = a['error'] as String?;
          visible = false;
          projections = [];
          return;
        }
        tracking = a['tracking'] as String;
        ground = a['ground'] == true;
        calibrated = a['calibrated'] == true;
        visible = a['visible'] == true;
        projections = (a['markers'] as List)
            .map(
              (m) => ARLabelTarget(
                m['id'] as String,
                Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
              ),
            )
            .toList();
      });
    });
    try {
      await channel!.invokeMethod('start');
      await send();
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      channel?.invokeMethod('pause');
    } else if (state == AppLifecycleState.resumed) {
      lastPayload = null;
      channel?.invokeMethod('reset');
      sync();
    }
  }

  @override
  void dispose() {
    app.removeListener(sync);
    WidgetsBinding.instance.removeObserver(this);
    channel?.setMethodCallHandler(null);
    channel?.invokeMethod('dispose');
    super.dispose();
  }

  String get guidance {
    if (error != null) return error!;
    if (!app.locationFresh) {
      return app.locationError ?? 'بانتظار موقعك لربط المناطق';
    }
    if (app.position!.accuracy > 20) {
      return 'إشارة الموقع ضعيفة؛ انتقل لمكان مفتوح';
    }
    if (!calibrated) return 'جارٍ تحديد اتجاه المناطق';
    if (tracking == 'motion') return 'حرّك الآيفون ببطء لتثبيت الحدود';
    if (tracking == 'features') return 'وجّه الكاميرا إلى أرضية واضحة الإضاءة';
    if (!ground) return 'حرّك الكاميرا نحو الأرض لاكتشاف سطحها';
    if (tracking != 'normal') return 'جارٍ تثبيت المشهد';
    if (nearby.isEmpty) return 'لا توجد مناطق محفوظة ضمن ٢٠٠ متر';
    return 'اختر منطقة لتمييز حدودها في المشهد';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appProvider);
    final readings = nearby;
    final current = readings.where((r) => r.zone.id == selected).firstOrNull;
    final color = severityColor(app.risk.severity);
    final targets = [...projections]
      ..sort((a, b) {
        if (a.id == selected) return -1;
        if (b.id == selected) return 1;
        return readings
            .indexWhere((r) => r.zone.id == a.id)
            .compareTo(readings.indexWhere((r) => r.zone.id == b.id));
      });
    return Scaffold(
      backgroundColor: ink,
      body: LayoutBuilder(
        builder: (context, box) {
          final labels = visible
              ? placeARLabels(
                  targets,
                  box.biggest,
                  top: MediaQuery.paddingOf(context).top + 190,
                  bottom: 215,
                )
              : <ARLabelPlacement>[];
          return Stack(
            fit: StackFit.expand,
            children: [
              if (Platform.isIOS)
                UiKitView(
                  viewType: 'ai.safetylens/ar',
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: created,
                )
              else
                const Center(
                  child: Text(
                    'الواقع المعزز متاح على الآيفون',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xA6142C36),
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xF0142C36),
                      ],
                      stops: [0, .3, .65, 1],
                    ),
                  ),
                ),
              ),
              IgnorePointer(child: CustomPaint(painter: _Leaders(labels))),
              ...labels.map((p) {
                final r = readings
                    .where((r) => r.zone.id == p.target.id)
                    .firstOrNull;
                if (r == null) return const SizedBox();
                final tone = zoneColor(r.zone.type);
                return Positioned.fromRect(
                  rect: p.rect,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      selected = r.zone.id;
                      lastPayload = null;
                      sync();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: .86),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tone,
                          width: r.zone.id == selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            r.zone.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            r.inside
                                ? 'داخل المنطقة'
                                : '${r.boundaryDistance.round()} م',
                            style: TextStyle(
                              color: r.zone.type == ZoneType.work
                                  ? liveGreen
                                  : tone,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: widget.onExit,
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'اكتشف محيطك',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'حدود المناطق في الواقع المعزز',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'إعادة المعايرة',
                            onPressed: () async {
                              setState(() {
                                error = null;
                                lastPayload = null;
                                ground = false;
                              });
                              await channel?.invokeMethod('reset');
                              sync();
                            },
                            icon: const Icon(
                              Icons.center_focus_strong,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          guidance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (readings.isNotEmpty)
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          scrollDirection: Axis.horizontal,
                          itemCount: readings.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final r = readings[i];
                            return ChoiceChip(
                              label: Text(
                                '${r.zone.name} · ${r.boundaryDistance.round()} م',
                              ),
                              selected: selected == r.zone.id,
                              onSelected: (_) => setState(() {
                                selected = r.zone.id;
                                lastPayload = null;
                                sync();
                              }),
                              avatar: CircleAvatar(
                                radius: 5,
                                backgroundColor: zoneColor(r.zone.type),
                              ),
                            );
                          },
                        ),
                      ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: color.withValues(alpha: .55),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_outlined, color: color),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ArabicText(
                                    app.zoneLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${readings.length} مناطق',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if (current != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${zoneTypeName(current.zone.type)} · ${current.zone.name}${app.heading == null ? '' : ' · ${ZoneService.headingDelta(current.bearing, app.heading!).abs() < 35
                                            ? 'أمامك'
                                            : ZoneService.headingDelta(current.bearing, app.heading!) < 0
                                            ? 'إلى اليسار'
                                            : 'إلى اليمين'}'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'الحدود تقريبية${app.position == null ? '' : ' · دقة GPS ±${app.position!.accuracy.round()} م'}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: red,
                                  minimumSize: const Size(0, 44),
                                ),
                                onPressed: widget.onExit,
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: const Text('إيقاف الرؤية'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Leaders extends CustomPainter {
  final List<ARLabelPlacement> labels;
  _Leaders(this.labels);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (final p in labels) {
      final end = Offset(
        p.target.anchor.dx * size.width,
        p.target.anchor.dy * size.height,
      );
      canvas.drawLine(p.rect.center, end, paint);
      canvas.drawCircle(end, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Leaders old) => old.labels != labels;
}
