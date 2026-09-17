import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../models/safety.dart';
import '../../widgets/common.dart';
import '../../widgets/site_map.dart';
import 'zone_drawing_page.dart';

class ZonesMapPage extends ConsumerStatefulWidget {
  const ZonesMapPage({super.key});
  @override
  ConsumerState<ZonesMapPage> createState() => _ZonesMapPageState();
}

class _ZonesMapPageState extends ConsumerState<ZonesMapPage> {
  final map = SiteMapController();
  bool showMap = true, satellite = false;
  ZoneVertex? selected;
  Future<void> edit([SafetyZone? z]) async {
    final app = ref.read(appProvider), pos = ref.read(appProvider).position;
    final center = z != null
        ? ZoneVertex(z.latitude, z.longitude)
        : selected ??
              (pos == null
                  ? const ZoneVertex(24.7136, 46.6753)
                  : ZoneVertex(pos.latitude, pos.longitude));
    final result = await Navigator.push<SafetyZone>(
      context,
      MaterialPageRoute(
        builder: (_) => ZoneDrawingPage(
          zone: z,
          center: center,
          neighbors: app.zones.where((z) => z.isActive).toList(),
        ),
      ),
    );
    if (result != null) {
      try {
        await app.saveZone(result);
        if (mounted) {
          setState(
            () => selected = ZoneVertex(result.latitude, result.longitude),
          );
          if (showMap) await map.move(selected!);
        }
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider), pos = ref.watch(appProvider).position;
    final center =
        selected ??
        (pos == null
            ? const ZoneVertex(24.7136, 46.6753)
            : ZoneVertex(pos.latitude, pos.longitude));
    return Scaffold(
      appBar: AppBar(
        title: const Text('مناطق العمل'),
        actions: [
          IconButton(
            tooltip: 'إضافة منطقة',
            onPressed: () => edit(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          const Text(
            'ارسم حدود موقعك باللمس وراقب المناطق المحيطة',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('الخريطة'),
                icon: Icon(Icons.map_outlined),
              ),
              ButtonSegment(
                value: false,
                label: Text('القائمة'),
                icon: Icon(Icons.list),
              ),
            ],
            selected: {showMap},
            onSelectionChanged: (s) => setState(() => showMap = s.single),
          ),
          const SizedBox(height: 14),
          if (showMap)
            SizedBox(
              height: 360,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SiteMap(
                        controller: map,
                        center: center,
                        satellite: satellite,
                        zones: app.zones.where((z) => z.isActive).toList(),
                        user: app.locationFresh
                            ? ZoneVertex(pos!.latitude, pos.longitude)
                            : null,
                        handles: selected == null ? [] : [selected!],
                        onTap: (p) => setState(() => selected = p),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Column(
                        children: [
                          _button(
                            satellite
                                ? Icons.map_outlined
                                : Icons.satellite_alt,
                            'صور الأقمار الصناعية',
                            () => setState(() => satellite = !satellite),
                          ),
                          _button(Icons.my_location, 'موقعي', () async {
                            await app.startMonitoring();
                            if (mounted && app.position != null) {
                              final p = app.position!;
                              await map.move(
                                ZoneVertex(p.latitude, p.longitude),
                              );
                            }
                          }),
                          _button(Icons.add, 'تكبير', () => map.zoom(true)),
                          _button(Icons.remove, 'تصغير', () => map.zoom(false)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => edit(),
            icon: const Icon(Icons.gesture),
            label: Text(
              selected == null
                  ? 'إضافة منطقة بالرسم'
                  : 'ارسم منطقة عند النقطة المحددة',
            ),
          ),
          const SizedBox(height: 14),
          Surface(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  app.locationFresh ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: app.locationFresh ? green : orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    app.locationError ??
                        (app.locationFresh
                            ? 'دقة موقعك ±${pos!.accuracy.round()} م'
                            : 'مراقبة الموقع متوقفة'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => app.monitoring
                      ? app.stopMonitoring()
                      : app.startMonitoring(),
                  child: Text(app.monitoring ? 'إيقاف' : 'تشغيل'),
                ),
              ],
            ),
          ),
          SectionTitle('المناطق المحفوظة', trailing: '${app.zones.length}'),
          if (app.zones.isEmpty)
            const Surface(
              child: EmptyState(
                icon: Icons.draw_outlined,
                title: 'ابدأ برسم منطقة',
                description:
                    'حدّد دائرة أو اضغط زوايا مضلع. لا تحتاج إلى كتابة إحداثيات.',
              ),
            ),
          ...app.zones.map((z) {
            final r = app.currentReadings
                .where((r) => r.zone.id == z.id)
                .firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: zoneColor(z.type).withValues(alpha: .12),
                    child: Icon(
                      z.isPolygon
                          ? Icons.polyline_outlined
                          : Icons.circle_outlined,
                      color: zoneColor(z.type),
                    ),
                  ),
                  title: Text(z.name),
                  subtitle: Text(
                    '${zoneTypeName(z.type)} · ${z.isPolygon ? '${z.vertices.length} زوايا' : '${z.radius.round()} م'}${!z.isActive ? ' · معطلة' : ''}${r == null
                        ? ''
                        : r.inside
                        ? '\nداخل المنطقة'
                        : '\nعلى بعد ${r.boundaryDistance.round()} م'}',
                  ),
                  onTap: () => edit(z),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        edit(z);
                        return;
                      }
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('حذف ${z.name}؟'),
                          content: const Text(
                            'تتوقف مراقبة هذه المنطقة. يبقى سجل الأحداث محفوظًا.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true) {
                        try {
                          await app.deleteZone(z.id);
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل الحدود')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _button(IconData icon, String label, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: IconButton.filledTonal(
          tooltip: label,
          onPressed: onPressed,
          icon: Icon(icon, size: 21),
        ),
      );
}
