import '../../core/arabic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../models/safety.dart';
import '../../widgets/common.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider), s = app.settings;
    Future<void> save(SafetySettings next) async {
      try {
        await app.saveSettings(next);
      } catch (e) {
        if (context.mounted) {
          showError(context, e);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const ArabicText('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
        children: [
          const SectionTitle('Required PPE', trailing: 'SITE CONFIGURATION'),
          const ArabicText(
            'Only enabled items count toward compliance. Unsupported model classes remain unknown.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          Surface(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: PPEType.values
                  .map(
                    (t) => SwitchListTile(
                      title: ArabicText(
                        t.label,
                        style: const TextStyle(fontSize: 14),
                      ),
                      value: s.requiredPPE.contains(t),
                      onChanged: (v) {
                        final set = {...s.requiredPPE};
                        v ? set.add(t) : set.remove(t);
                        save(s.copyWith(requiredPPE: set));
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SectionTitle('Detection confidence'),
          Surface(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(child: ArabicText('Minimum confidence')),
                    StatusChip('${(s.threshold * 100).round()}%'),
                  ],
                ),
                Slider(
                  value: s.threshold,
                  min: .3,
                  max: .95,
                  divisions: 13,
                  label: '${(s.threshold * 100).round()}%',
                  onChanged: (v) => save(s.copyWith(threshold: v)),
                ),
                const ArabicText(
                  'Low-confidence results are excluded from detection and rules.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SectionTitle('Worker feedback'),
          Surface(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                SwitchListTile(
                  title: const ArabicText('Alert sounds'),
                  value: s.sound,
                  onChanged: (v) => save(s.copyWith(sound: v)),
                ),
                SwitchListTile(
                  title: const ArabicText('Vibration'),
                  value: s.vibration,
                  onChanged: (v) => save(s.copyWith(vibration: v)),
                ),
                ListTile(
                  title: const ArabicText('Notification permission'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      await app.notification.requestPermission();
                    } catch (e) {
                      if (context.mounted) {
                        showError(context, e);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SectionTitle('المعالجة على الجهاز'),
          const Surface(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.memory_rounded, color: green),
              title: ArabicText('Core ML · PPE v2'),
              subtitle: ArabicText(
                'يعمل على الآيفون دون إنترنت. تبقى صور الكاميرا على جهازك.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ),
          const SectionTitle('Privacy & storage'),
          Surface(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                SwitchListTile(
                  title: const ArabicText('Save event snapshots'),
                  subtitle: const ArabicText(
                    'Store selected violation images locally on this device.',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                  value: s.snapshots,
                  onChanged: (v) => save(s.copyWith(snapshots: v)),
                ),
                ListTile(
                  title: const ArabicText('Privacy information'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                ),
                ListTile(
                  title: const ArabicText(
                    'Delete event history',
                    style: TextStyle(color: red),
                  ),
                  subtitle: const ArabicText(
                    'Includes all saved snapshots',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  onTap: () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const ArabicText('Delete all event history?'),
                        content: const ArabicText(
                          'Events and snapshots will be permanently removed from this device. Zones and settings will remain.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const ArabicText('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const ArabicText('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true) {
                      try {
                        await app.clearHistory();
                      } catch (e) {
                        if (context.mounted) {
                          showError(context, e);
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ArabicText(
            'SafetyLens AI · 1.1\nمعالجة محلية · لا تسجيل دخول · لا تعرف على الوجوه',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ArabicText('Privacy information')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        ArabicText(
          'Your site. Your data.',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 20),
        ArabicText(
          'الكاميرا\nيتم تحليل الصور داخل الآيفون باستخدام Core ML. لا يرسل فحص المعدات صورًا للسحابة ولا يسجل الصوت.\n\nالموقع والبوصلة\nيستخدمان أثناء فتح التطبيق لعرض المناطق والمسافات والتنبيهات.\n\nبياناتك\nالمناطق والأحداث والإعدادات محفوظة محليًا. حفظ لقطات الأحداث اختياري ويمكن حذفها من الإعدادات.\n\nالخريطة\nتستخدم خرائط OpenStreetMap عبر الإنترنت. تبقى حسابات المناطق المحفوظة متاحة دون اتصال.\n\nدقة التقييم\nالنتائج تقديرية وتتأثر بالإضاءة والزاوية وبعد العامل. المعدات غير الظاهرة لا تعني بالضرورة أنها مفقودة.\n\nالنموذج\nSafetyVision YOLOv8s PPE v2 — Ayush Gupta. أوزان النموذج مرخصة AGPL-3.0. تفاصيل المصدر والترخيص في ملفات المشروع.',
          style: TextStyle(color: muted, height: 1.7),
        ),
      ],
    ),
  );
}
