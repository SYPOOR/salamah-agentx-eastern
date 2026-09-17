import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../settings/settings_page.dart';
import '../alerts/alerts_page.dart';
import '../voice/voice_page.dart';
import '../leadership/leadership_page.dart';

class HomePage extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomePage({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: MediaQuery.paddingOf(context).top + 450,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/safety-hero.png',
                fit: BoxFit.cover,
                alignment: const Alignment(-.25, .4),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xDDF3F6F8),
                      Color(0x20F3F6F8),
                      Color(0x00F3F6F8),
                      canvas,
                    ],
                    stops: [0, .25, .7, 1],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/brand-mark.png',
                              width: 44,
                              height: 44,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سلامة',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'SafetyLens AI',
                                  style: TextStyle(fontSize: 11, color: green),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'التنبيهات',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AlertsPage(),
                              ),
                            ),
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                          IconButton(
                            tooltip: 'الإعدادات',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            ),
                            icon: const Icon(Icons.menu_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 38),
                      const Text(
                        'معًا\nلموقع عمل\nأكثر أمانًا',
                        style: TextStyle(
                          fontSize: 31,
                          height: 1.38,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'نفحص اليوم..\nلبيئة عمل أفضل غدًا',
                        style: TextStyle(
                          fontSize: 13,
                          color: ink,
                          shadows: [
                            Shadow(color: Colors.white, blurRadius: 12),
                          ],
                          height: 1.7,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 4,
                child: Material(
                  color: green,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onNavigate(2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 20,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.document_scanner_outlined,
                            color: Colors.white,
                            size: 37,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'بدء الفحص',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'بث مباشر · معالجة على الآيفون',
                                  style: TextStyle(
                                    color: Color(0xFFC2DED5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const CircleAvatar(
                            backgroundColor: Color(0xFF24765F),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _tile(
                      'المناطق',
                      'عرض مناطق العمل',
                      Icons.map_outlined,
                      () => onNavigate(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tile(
                      'التقارير',
                      'اطّلع على النتائج',
                      Icons.bar_chart_rounded,
                      () => onNavigate(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => onNavigate(4),
                borderRadius: BorderRadius.circular(22),
                child: const Surface(
                  padding: EdgeInsets.all(17),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFFE0F2EB),
                        child: Icon(Icons.view_in_ar_rounded, color: green),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اكتشف محيطك',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'رؤية السلامة · اتجاه المناطق والمسافات',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left, color: muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _tile(
                      'الأوامر الصوتية',
                      'قل أمرك لسلامة',
                      Icons.mic_none_rounded,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VoicePage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tile(
                      'لوحة القيادة',
                      'المخاطر والمهام',
                      Icons.dashboard_outlined,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeadershipPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'سلامتك تهمنا · التزم بإجراءات الموقع دائمًا',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _tile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback tap,
  ) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(24),
    child: Surface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 35, color: ink),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 9),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: muted),
        ],
      ),
    ),
  );
}
