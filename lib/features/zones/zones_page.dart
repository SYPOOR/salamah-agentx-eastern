import '../../core/arabic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../models/safety.dart';
import '../../widgets/common.dart';

class ZonesPage extends ConsumerStatefulWidget {
  const ZonesPage({super.key});
  @override
  ConsumerState<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends ConsumerState<ZonesPage> {
  final map = MapController();
  LatLng selected = const LatLng(24.7136, 46.6753);
  bool picked = false;
  bool showMap = true;
  @override
  void dispose() {
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    return Scaffold(
      appBar: AppBar(
        title: const ArabicText('Safety zones'),
        actions: [
          IconButton(
            tooltip: 'إضافة منطقة',
            onPressed: () => _edit(),
            icon: const Icon(Icons.add_circle_outline, color: green),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        children: [
          const ArabicText(
            'Define the boundaries. Know the risk.',
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
                icon: Icon(Icons.format_list_bulleted),
              ),
            ],
            selected: {showMap},
            onSelectionChanged: (v) => setState(() => showMap = v.single),
          ),
          const SizedBox(height: 16),
          if (showMap)
            SizedBox(
              height: 360,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: map,
                      options: MapOptions(
                        initialCenter: app.position == null
                            ? selected
                            : LatLng(
                                app.position!.latitude,
                                app.position!.longitude,
                              ),
                        initialZoom: 17,
                        onTap: (_, p) => setState(() {
                          selected = p;
                          picked = true;
                        }),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.safetylens.safety_lens_ai',
                        ),
                        CircleLayer(
                          circles: app.zones
                              .where((z) => z.isActive)
                              .map(
                                (z) => CircleMarker(
                                  point: LatLng(z.latitude, z.longitude),
                                  radius: z.radius,
                                  useRadiusInMeter: true,
                                  color: zoneColor(
                                    z.type,
                                  ).withValues(alpha: .18),
                                  borderColor: zoneColor(z.type),
                                  borderStrokeWidth: 2,
                                ),
                              )
                              .toList(),
                        ),
                        MarkerLayer(
                          markers: [
                            if (picked)
                              Marker(
                                point: selected,
                                width: 38,
                                height: 38,
                                child: const Icon(
                                  Icons.add_location_alt,
                                  color: ink,
                                  size: 35,
                                ),
                              ),
                            if (app.locationFresh)
                              Marker(
                                point: LatLng(
                                  app.position!.latitude,
                                  app.position!.longitude,
                                ),
                                width: 20,
                                height: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SimpleAttributionWidget(
                          source: Text(
                            '© OpenStreetMap contributors',
                            style: TextStyle(color: Colors.black, fontSize: 9),
                          ),
                          backgroundColor: Colors.white70,
                        ),
                      ],
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Column(
                        children: [
                          _mapButton(
                            Icons.add,
                            () => map.move(
                              map.camera.center,
                              map.camera.zoom + 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _mapButton(
                            Icons.remove,
                            () => map.move(
                              map.camera.center,
                              map.camera.zoom - 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _mapButton(Icons.my_location, () async {
                            await app.startMonitoring();
                            if (app.position != null) {
                              map.move(
                                LatLng(
                                  app.position!.latitude,
                                  app.position!.longitude,
                                ),
                                18,
                              );
                            }
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          ArabicText(
            picked
                ? 'Selected: ${selected.latitude.toStringAsFixed(6)}, ${selected.longitude.toStringAsFixed(6)}'
                : 'Tap the map to choose a zone center. Map tiles need internet.',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const ArabicText('Add safety zone'),
          ),
          const SizedBox(height: 12),
          Surface(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      app.locationFresh ? Icons.gps_fixed : Icons.gps_not_fixed,
                      color: app.locationFresh ? green : orange,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ArabicText(
                        app.locationError ??
                            (app.locationFresh
                                ? 'دقة الموقع ±${app.position!.accuracy.round()} م'
                                : 'Location monitoring is off'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (app.monitoring) {
                          await app.stopMonitoring();
                        } else {
                          await app.startMonitoring();
                        }
                      },
                      child: ArabicText(app.monitoring ? 'Stop' : 'Start'),
                    ),
                  ],
                ),
                if (app.locationError != null)
                  TextButton(
                    onPressed: Geolocator.openAppSettings,
                    child: const ArabicText('Open device settings'),
                  ),
                const ArabicText(
                  'GPS boundaries are approximate. Small 2–5 m warnings may be unreliable indoors.',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          SectionTitle('Saved zones', trailing: '${app.zones.length} TOTAL'),
          if (app.zones.isEmpty)
            const Surface(
              child: EmptyState(
                icon: Icons.add_location_alt_outlined,
                title: 'Your site starts here',
                description:
                    'Add a work area and a restricted area to enable zone monitoring.',
              ),
            ),
          ...app.zones.map((z) {
            final r = app.currentReadings
                .where((r) => r.zone.id == z.id)
                .firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Surface(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 46,
                      decoration: BoxDecoration(
                        color: zoneColor(z.type),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ArabicText(
                            z.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          ArabicText(
                            '${switch (z.type) {
                              ZoneType.work => 'منطقة عمل',
                              ZoneType.restricted => 'منطقة محظورة',
                              ZoneType.highRisk => 'منطقة حذر',
                            }} · نصف القطر ${z.radius.round()} م',
                            style: TextStyle(
                              color: zoneColor(z.type),
                              fontSize: 10,
                            ),
                          ),
                          if (r != null)
                            ArabicText(
                              '${r.inside ? 'داخل المنطقة' : 'على بعد ${r.boundaryDistance.round()} م'}${r.uncertain ? ' · الموقع غير مؤكد' : ''}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          _edit(z);
                        } else {
                          final remove = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: ArabicText('Delete ${z.name}?'),
                              content: const ArabicText(
                                'Monitoring for this zone will stop. Recorded events remain.',
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
                          if (remove == true) {
                            try {
                              await app.deleteZone(z.id);
                            } catch (e) {
                              if (context.mounted) {
                                showError(context, e);
                              }
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ArabicText('Edit zone'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ArabicText('Delete zone'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback action) => SizedBox(
    width: 36,
    height: 36,
    child: IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: Colors.white,
      ),
      padding: EdgeInsets.zero,
      onPressed: action,
      icon: Icon(icon, size: 18),
    ),
  );
  Future<void> _edit([SafetyZone? zone]) async {
    final app = ref.read(appProvider);
    final center = zone == null
        ? (picked
              ? selected
              : app.position == null
              ? selected
              : LatLng(app.position!.latitude, app.position!.longitude))
        : LatLng(zone.latitude, zone.longitude);
    final result = await showModalBottomSheet<SafetyZone>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ZoneEditor(zone: zone, center: center),
    );
    if (result != null) {
      try {
        await app.saveZone(result);
        if (mounted) {
          setState(() => picked = false);
          selected = LatLng(result.latitude, result.longitude);
          if (showMap) map.move(selected, 17);
        }
      } catch (e) {
        if (mounted) {
          showError(context, e);
        }
      }
    }
  }
}

class _ZoneEditor extends StatefulWidget {
  final SafetyZone? zone;
  final LatLng center;
  const _ZoneEditor({this.zone, required this.center});
  @override
  State<_ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<_ZoneEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, lat, lon, radius;
  late ZoneType type;
  late bool active;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.zone?.name);
    lat = TextEditingController(
      text: widget.center.latitude.toStringAsFixed(6),
    );
    lon = TextEditingController(
      text: widget.center.longitude.toStringAsFixed(6),
    );
    radius = TextEditingController(
      text: '${widget.zone?.radius.round() ?? 30}',
    );
    type = widget.zone?.type ?? ZoneType.work;
    active = widget.zone?.isActive ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    lat.dispose();
    lon.dispose();
    radius.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArabicText(
              widget.zone == null ? 'Create safety zone' : 'Edit safety zone',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم المنطقة'),
              maxLength: 60,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'أدخل اسم المنطقة' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ZoneType>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'نوع المنطقة'),
              items: ZoneType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: ArabicText(switch (t) {
                        ZoneType.work => 'Green · Work zone',
                        ZoneType.restricted => 'Red · Restricted zone',
                        ZoneType.highRisk => 'Orange · High risk zone',
                      }),
                    ),
                  )
                  .toList(),
              onChanged: (t) => setState(() => type = t!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _number(lat, 'Latitude', -90, 90)),
                const SizedBox(width: 10),
                Expanded(child: _number(lon, 'Longitude', -180, 180)),
              ],
            ),
            const SizedBox(height: 16),
            _number(radius, 'Radius (meters)', 1, 10000),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const ArabicText('Active monitoring'),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(
                      context,
                      SafetyZone(
                        id:
                            widget.zone?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        name: name.text.trim(),
                        type: type,
                        latitude: double.parse(lat.text),
                        longitude: double.parse(lon.text),
                        radius: double.parse(radius.text),
                        isActive: active,
                        createdAt: widget.zone?.createdAt ?? DateTime.now(),
                      ),
                    );
                  }
                },
                child: const ArabicText('Save zone'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _number(
    TextEditingController c,
    String label,
    double min,
    double max,
  ) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      final n = double.tryParse(v ?? '');
      return n == null || !n.isFinite || n < min || n > max
          ? 'أدخل قيمة بين $min و$max'
          : null;
    },
  );
}
