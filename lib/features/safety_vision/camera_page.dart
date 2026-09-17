import '../../core/arabic.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../models/safety.dart';
import '../../services/device_services.dart';
import '../../services/live_frame.dart';
import '../../services/safety_engines.dart';
import '../../widgets/common.dart';

class CameraPage extends ConsumerStatefulWidget {
  final bool ppeMode;
  final VoidCallback onExit;
  const CameraPage({super.key, required this.ppeMode, required this.onExit});
  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  final camera = CameraService();
  final localPpe = LocalPPEService();
  final frameGate = LiveFrameGate();
  final frameClock = Stopwatch()..start();
  LiveFrame? latestSnapshotFrame;
  bool initializing = true, running = false, disposed = false;
  int generation = 0;
  String? error, aiError;
  InferenceResult? result;
  Future<void>? activeRequest;
  late AppController app;
  @override
  void initState() {
    super.initState();
    app = ref.read(appProvider);
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    if (disposed) {
      return;
    }
    setState(() {
      initializing = true;
      error = null;
    });
    try {
      await camera.initialize();
      if (disposed) {
        await camera.dispose();
        return;
      }
      app.snapshotCapture = () async {
        final frame = latestSnapshotFrame;
        return app.settings.snapshots && frame != null
            ? localPpe.snapshot(frame)
            : null;
      };
      await camera.startStream(_onFrame);
      if (!widget.ppeMode) {
        await app.startMonitoring();
      }
    } catch (e) {
      error = e is CameraException
          ? 'تعذر الوصول للكاميرا. اسمح باستخدامها من إعدادات الجهاز.'
          : 'Camera unavailable. A physical device is required.';
    }
    if (mounted) {
      setState(() => initializing = false);
      if (widget.ppeMode && error == null && !running) _toggle();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pause();
    } else if (state == AppLifecycleState.resumed &&
        camera.controller == null &&
        !initializing) {
      _resume();
    }
  }

  Future<void> _pause() async {
    generation++;
    latestSnapshotFrame = null;
    running = false;
    await camera.dispose();
    if (mounted) {
      setState(() {
        initializing = false;
        result = null;
      });
    }
  }

  Future<void> _resume() async {
    await _pause();
    if (!disposed) {
      await _initialize();
    }
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    latestSnapshotFrame = null;
    app.snapshotCapture = null;
    WidgetsBinding.instance.removeObserver(this);
    localPpe.dispose();
    unawaited(camera.dispose());
    super.dispose();
  }

  void _toggle() {
    if (running) {
      generation++;
      latestSnapshotFrame = null;
      setState(() => running = false);
      return;
    }
    app.beginScan();
    setState(() {
      running = true;
      aiError = null;
      result = null;
    });
  }

  void _onFrame(LiveFrame frame) {
    if (disposed || camera.controller == null) return;
    // Retain only the latest raw buffer for optional event snapshots, never a queue.
    latestSnapshotFrame = app.settings.snapshots ? frame : null;
    if (!widget.ppeMode ||
        !running ||
        !frameGate.tryBegin(frameClock.elapsed)) {
      return;
    }
    activeRequest = _infer(frame);
  }

  Future<void> _infer(LiveFrame frame) async {
    final current = generation;
    try {
      final inference = await localPpe.inferFrame(frame, app.settings);
      if (disposed || current != generation) {
        return;
      }
      await app.processInference(
        inference,
        null,
        snapshotFrame: () => localPpe.snapshot(frame),
      );
      if (mounted && !disposed && current == generation) {
        setState(() {
          result = inference;
          aiError = null;
        });
      }
    } catch (e) {
      if (!disposed && current == generation) {
        app.invalidatePpe();
        if (mounted) {
          setState(() {
            result = null;
            aiError = e.toString().replaceFirst('Bad state: ', '');
          });
        }
      }
    } finally {
      frameGate.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), risk = app.risk;
    final color = severityColor(risk.severity);
    final c = camera.controller;
    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (c != null && c.value.isInitialized) ...[
            Center(
              child: AspectRatio(
                aspectRatio: result != null
                    ? result!.width / result!.height
                    : 1 / c.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(c),
                    if (widget.ppeMode && result != null)
                      CustomPaint(
                        painter: _Boxes(result!, app.settings.threshold),
                      ),
                  ],
                ),
              ),
            ),
          ] else
            Center(
              child: initializing
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(35),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.no_photography_outlined,
                            size: 52,
                            color: muted,
                          ),
                          const SizedBox(height: 20),
                          ArabicText(
                            error ?? 'Camera paused',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: muted),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: Geolocator.openAppSettings,
                            child: const ArabicText('Open device settings'),
                          ),
                          TextButton(
                            onPressed: _resume,
                            child: const ArabicText('Retry camera'),
                          ),
                        ],
                      ),
                    ),
            ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    canvas.withValues(alpha: .98),
                    Colors.transparent,
                    Colors.transparent,
                    canvas.withValues(alpha: .98),
                  ],
                  stops: const [0, .3, .6, 1],
                ),
              ),
            ),
          ),
          if (!widget.ppeMode && risk.severity == Severity.critical)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: red, width: 6),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'إغلاق الكاميرا',
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.close),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ArabicText(
                              widget.ppeMode ? 'PPE SCANNER' : 'SAFETY VISION',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ArabicText(
                              widget.ppeMode
                                  ? (localPpe.elapsedMs == null
                                        ? 'بث مباشر · تحليل على الآيفون'
                                        : 'محلي · ${localPpe.elapsedMs} ملّي ثانية')
                                  : 'GPS + COMPASS HUD',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 9,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        widget.ppeMode
                            ? (error != null
                                  ? 'غير متاح'
                                  : running
                                  ? 'LIVE'
                                  : 'جاهز محليًا')
                            : risk.severity.name.toUpperCase(),
                        color: widget.ppeMode
                            ? (error != null ? muted : green)
                            : color,
                      ),
                    ],
                  ),
                ),
                if (widget.ppeMode) ...[
                  if (aiError != null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Surface(
                        padding: const EdgeInsets.all(12),
                        child: ArabicText(
                          'تعذر تشغيل الفحص المحلي\n$aiError',
                          style: const TextStyle(color: orange, fontSize: 12),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: _ppePanel(app),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: running ? red : green,
                        ),
                        onPressed: c != null && c.value.isInitialized
                            ? _toggle
                            : null,
                        icon: Icon(
                          running
                              ? Icons.stop_circle_outlined
                              : Icons.document_scanner_outlined,
                        ),
                        label: ArabicText(
                          running ? 'إيقاف الفحص' : 'Start PPE check',
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Surface(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ArabicText(
                            app.zoneLabel,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ArabicText(
                            app.locationError ??
                                (!app.locationFresh
                                    ? 'Waiting for GPS signal'
                                    : app.heading == null
                                    ? 'Compass signal unavailable'
                                    : 'الاتجاه ${app.heading!.round()}° · دقة الموقع ±${app.position!.accuracy.round()} م'),
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                          if (app.currentReadings.any((r) => r.uncertain))
                            const ArabicText(
                              'Boundary position uncertain — verify surroundings',
                              style: TextStyle(color: orange, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final visible = app.currentReadings.take(5).toList();
                        if (visible.isEmpty) {
                          return Center(
                            child: ArabicText(
                              app.zones.isEmpty
                                  ? 'Add safety zones to activate the HUD'
                                  : 'Waiting for location signal',
                              style: const TextStyle(color: muted),
                            ),
                          );
                        }
                        if (app.heading == null) {
                          return const Center(
                            child: ArabicText(
                              'Compass unavailable\nDistances remain available below',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted),
                            ),
                          );
                        }
                        return Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.add,
                                size: 24,
                                color: Colors.white54,
                              ),
                            ),
                            ...visible.indexed.map((entry) {
                              final r = entry.$2;
                              final delta = ZoneService.headingDelta(
                                r.bearing,
                                app.heading!,
                              );
                              final x = ((delta / 70 + .5) * box.maxWidth - 75)
                                  .clamp(
                                    8.0,
                                    math.max(8.0, box.maxWidth - 158),
                                  );
                              return Positioned(
                                left: x.toDouble(),
                                top: 35.0 + entry.$1 * 70,
                                child: Container(
                                  width: 150,
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: const Color(0xE8142C36),
                                    border: Border.all(
                                      color: zoneColor(r.zone.type),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      ArabicText(
                                        '${delta.abs() > 35 ? (delta < 0 ? '← ' : '→ ') : ''}${r.zone.type == ZoneType.work
                                            ? 'WORK AREA'
                                            : r.zone.type == ZoneType.restricted
                                            ? 'RESTRICTED'
                                            : 'HIGH RISK'}',
                                        style: TextStyle(
                                          color: zoneColor(r.zone.type),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: .8,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      ArabicText(
                                        r.inside
                                            ? 'INSIDE'
                                            : '${r.boundaryDistance.round()} m',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 23,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      ArabicText(
                                        r.zone.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Surface(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ArabicText(
                            'NEAREST HAZARD',
                            style: TextStyle(
                              color: muted,
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (_) {
                              final hazard = app.currentReadings
                                  .where((r) => r.zone.type != ZoneType.work)
                                  .firstOrNull;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.radar_rounded,
                                    color: hazard == null
                                        ? muted
                                        : zoneColor(hazard.zone.type),
                                    size: 25,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ArabicText(
                                      hazard == null
                                          ? 'No hazard distance available'
                                          : hazard.zone.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (hazard != null)
                                    ArabicText(
                                      '${hazard.boundaryDistance.round()} m',
                                      style: TextStyle(
                                        color: zoneColor(hazard.zone.type),
                                        fontSize: 23,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          if (app.currentReadings.any(
                            (r) =>
                                r.zone.type == ZoneType.restricted &&
                                r.boundaryDistance <= 5,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: ArabicText(
                                app.currentReadings.any(
                                      (r) =>
                                          r.zone.type == ZoneType.restricted &&
                                          r.inside,
                                    )
                                    ? 'CRITICAL · RESTRICTED AREA ENTERED'
                                    : app.currentReadings.any(
                                        (r) =>
                                            r.zone.type ==
                                                ZoneType.restricted &&
                                            r.boundaryDistance <= 2,
                                      )
                                    ? 'DO NOT ENTER'
                                    : 'WARNING · RESTRICTED ZONE AHEAD',
                                style: const TextStyle(
                                  color: red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          const ArabicText(
                            'Approximate camera markers · not spatial anchors',
                            style: TextStyle(fontSize: 9, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ppePanel(AppController app) {
    final p = app.ppe;
    return Surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: ArabicText(
                  'PPE STATUS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: muted,
                  ),
                ),
              ),
              ArabicText(
                p?.compliance == null
                    ? 'NOT ASSESSED'
                    : '${p!.compliance!.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: p?.compliance == null
                      ? muted
                      : p!.missing.isNotEmpty
                      ? orange
                      : green,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: app.settings.requiredPPE.map((t) {
              final state = p?.states[t] ?? DetectionState.unknown;
              final tone = state == DetectionState.detected
                  ? green
                  : state == DetectionState.missing
                  ? orange
                  : muted;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tone.withValues(alpha: .25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state == DetectionState.detected
                          ? Icons.check_circle_rounded
                          : state == DetectionState.missing
                          ? Icons.error_outline
                          : Icons.more_horiz,
                      color: tone,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    ArabicText(t.label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
          if (result != null &&
              (p?.people ?? 0) != 1 &&
              result!.predictions.any(
                (v) => PPEEngine.normalize(v.label) != 'person',
              )) ...[
            const SizedBox(height: 12),
            const ArabicText(
              'معدات ظاهرة في البث · لم تكتمل مطابقة العامل',
              style: TextStyle(fontSize: 10, color: muted),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: result!.predictions
                  .where((v) => PPEEngine.normalize(v.label) != 'person')
                  .map((v) => v.label)
                  .toSet()
                  .take(5)
                  .map((v) => StatusChip(ar(v), color: green))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          ArabicText(
            p?.reason ??
                (app.settings.requiredPPE.isEmpty
                    ? 'Select required PPE in Settings'
                    : p?.compliance == null
                    ? 'Keep one worker fully visible for at least 2 seconds'
                    : p!.missing.isEmpty
                    ? 'PPE CHECK PASSED'
                    : 'PPE CHECK FAILED · Verify missing items'),
            style: TextStyle(
              fontSize: 10,
              color: p?.missing.isNotEmpty == true ? red : muted,
            ),
          ),
          if (!running && p != null)
            const ArabicText(
              'Last check result · start a new check for another worker',
              style: TextStyle(fontSize: 9, color: muted),
            ),
        ],
      ),
    );
  }
}

class _Boxes extends CustomPainter {
  final InferenceResult result;
  final double threshold;
  _Boxes(this.result, this.threshold);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in result.predictions.where(
      (p) => p.confidence >= threshold,
    )) {
      final rect = Rect.fromLTWH(
        (p.x - p.width / 2) / result.width * size.width,
        (p.y - p.height / 2) / result.height * size.height,
        p.width / result.width * size.width,
        p.height / result.height * size.height,
      );
      final color = PPEEngine.normalize(p.label).startsWith('no ')
          ? red
          : liveGreen;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final text = TextPainter(
        text: TextSpan(
          text: ' ${ar(p.label)} ${(p.confidence * 100).round()}% ',
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'PlexArabic',
            color: ink,
            backgroundColor: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: size.width);
      text.paint(
        canvas,
        Offset(
          rect.left.clamp(0, math.max(0, size.width - text.width)),
          math.max(0, rect.top - text.height),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Boxes oldDelegate) =>
      oldDelegate.result != result || oldDelegate.threshold != threshold;
}
