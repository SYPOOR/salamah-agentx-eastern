import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/arabic.dart';
import '../../models/safety.dart';
import '../../widgets/common.dart';
import '../alerts/alerts_page.dart';

class DashboardPage extends ConsumerWidget {
  final ValueChanged<int> onNavigate;
  const DashboardPage({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), a = app.analytics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            tooltip: 'سجل الأحداث',
            onPressed: () => onNavigate(4),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 17, color: muted),
                SizedBox(width: 8),
                Text('اليوم', style: TextStyle(color: ink)),
                Spacer(),
                StatusChip('من أحداث الموقع'),
              ],
            ),
            const SizedBox(height: 20),
            Surface(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مؤشر السلامة اليوم',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          a.score == null
                              ? 'بانتظار أول فحص أو حدث منطقة'
                              : 'محسوب من الالتزام والمخالفات المسجلة',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    a.score == null ? '—' : '${a.score!.round()}٪',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: a.score == null
                          ? muted
                          : a.score! >= 80
                          ? green
                          : a.score! >= 50
                          ? orange
                          : red,
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle('ملخص السلامة'),
            LayoutBuilder(
              builder: (_, box) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric(
                    box.maxWidth,
                    'التزام المعدات',
                    a.compliance == null ? '—' : '${a.compliance!.round()}٪',
                    Icons.verified_user_outlined,
                    green,
                  ),
                  _metric(
                    box.maxWidth,
                    'عمليات الفحص',
                    '${a.scans.length}',
                    Icons.center_focus_strong,
                    ink,
                  ),
                  _metric(
                    box.maxWidth,
                    'مخالفات المعدات',
                    '${a.missing}',
                    Icons.warning_amber_rounded,
                    orange,
                  ),
                  _metric(
                    box.maxWidth,
                    'اختراق المناطق',
                    '${a.breaches}',
                    Icons.radar_rounded,
                    red,
                  ),
                ],
              ),
            ),
            const SectionTitle('الالتزام خلال اليوم', trailing: 'كل ٣ ساعات'),
            Surface(
              child: Column(
                children: [
                  if (a.scans.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Text(
                        'ستظهر أول قراءة هنا بعد اكتمال الفحص',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: CustomPaint(painter: _TrendPainter(a.hourlyTrend)),
                  ),
                  const SizedBox(height: 14),
                  const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '00:00',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                        Text(
                          '09:00',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                        Text(
                          '21:00',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle('حالة الأحداث'),
            Surface(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _eventCount(
                    'آمن',
                    a.events.where((e) => e.severity == Severity.safe).length,
                    green,
                  ),
                  _eventCount(
                    'تحذير',
                    a.events
                        .where(
                          (e) => [
                            Severity.warning,
                            Severity.high,
                          ].contains(e.severity),
                        )
                        .length,
                    orange,
                  ),
                  _eventCount('حرج', a.critical, red),
                ],
              ),
            ),
            if (a.violations.isNotEmpty) ...[
              const SectionTitle('أكثر المخالفات تكرارًا'),
              Surface(
                child: Column(
                  children: a.violations.entries
                      .take(4)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ArabicText(
                                      e.key,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    '${e.value}',
                                    style: const TextStyle(color: orange),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              LinearProgressIndicator(
                                value:
                                    e.value /
                                    a.violations.values.reduce(math.max),
                                color: orange,
                                backgroundColor: line,
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            Row(
              children: [
                const Expanded(child: SectionTitle('آخر الأحداث')),
                TextButton(
                  onPressed: () => onNavigate(4),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            if (app.events.isEmpty)
              const Surface(
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'لا أحداث حتى الآن',
                  description: 'كل فحص وتنبيه يُحفظ هنا لتراجع سلامة موقعك.',
                ),
              )
            else
              ...app.events
                  .take(4)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: EventTile(e),
                    ),
                  ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'راقب  ·  افهم  ·  احمِ',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    double width,
    String title,
    String value,
    IconData icon,
    Color color,
  ) => SizedBox(
    width: (width - 12) / 2,
    child: Surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    ),
  );
  Widget _eventCount(String label, int value, Color color) => Column(
    children: [
      Text(
        '$value',
        style: TextStyle(
          color: color,
          fontSize: 27,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}

class _TrendPainter extends CustomPainter {
  final List<double?> values;
  _TrendPainter(this.values);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final y = i * size.height / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = line
          ..strokeWidth = 1,
      );
    }
    Offset? prev;
    for (var i = 0; i < values.length; i++) {
      if (values[i] == null) {
        prev = null;
        continue;
      }
      final p = Offset(
        i * size.width / 7,
        size.height * (1 - values[i]! / 100),
      );
      if (prev != null) {
        canvas.drawLine(
          prev,
          p,
          Paint()
            ..color = green
            ..strokeWidth = 3,
        );
      }
      canvas.drawCircle(p, 4, Paint()..color = green);
      prev = p;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values;
}
