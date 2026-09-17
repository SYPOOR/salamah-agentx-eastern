import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/safety.dart';
import '../../services/safety_engines.dart';
import '../../widgets/site_map.dart';

class ZoneDrawingPage extends StatefulWidget {
  final SafetyZone? zone;
  final ZoneVertex center;
  final List<SafetyZone> neighbors;
  const ZoneDrawingPage({
    super.key,
    this.zone,
    required this.center,
    this.neighbors = const [],
  });
  @override
  State<ZoneDrawingPage> createState() => _ZoneDrawingPageState();
}

class _ZoneDrawingPageState extends State<ZoneDrawingPage> {
  final map = SiteMapController();
  late final TextEditingController name;
  late ZoneType type;
  late bool polygon, active;
  bool satellite = false;
  final List<ZoneVertex> points = [];
  double radius = 30;
  String? error;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.zone?.name ?? '');
    type = widget.zone?.type ?? ZoneType.work;
    polygon = widget.zone?.isPolygon ?? false;
    active = widget.zone?.isActive ?? true;
    radius = widget.zone?.radius ?? 30;
    if (widget.zone != null) {
      points.addAll(
        polygon
            ? widget.zone!.vertices
            : [ZoneVertex(widget.zone!.latitude, widget.zone!.longitude)],
      );
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  ZoneVertex get center => points.isEmpty
      ? widget.center
      : polygon
      ? ZoneVertex(
          points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
          points.map((p) => p.longitude).reduce((a, b) => a + b) /
              points.length,
        )
      : points.first;
  ZoneVertex get edge => ZoneVertex(
    center.latitude,
    center.longitude +
        radius / (111195 * math.cos(center.latitude * math.pi / 180)),
  );
  SafetyZone get draft => SafetyZone(
    id: widget.zone?.id ?? 'draft',
    name: name.text.trim(),
    type: type,
    latitude: center.latitude,
    longitude: center.longitude,
    radius: polygon
        ? points.fold(
            1.0,
            (r, p) => math.max(
              r,
              ZoneService.distance(
                center.latitude,
                center.longitude,
                p.latitude,
                p.longitude,
              ),
            ),
          )
        : radius,
    createdAt: widget.zone?.createdAt ?? DateTime.now(),
    isActive: active,
    vertices: polygon ? List.of(points) : const [],
  );
  void tap(ZoneVertex p) => setState(() {
    error = null;
    if (polygon) {
      if (points.length < 32) points.add(p);
    } else if (points.isEmpty) {
      points.add(p);
    } else {
      radius = ZoneService.distance(
        center.latitude,
        center.longitude,
        p.latitude,
        p.longitude,
      ).clamp(2, 1000);
    }
  });
  void drag(int i, ZoneVertex p) => setState(() {
    error = null;
    if (polygon) {
      points[i] = p;
    } else if (i == 0) {
      points[0] = p;
    } else {
      radius = ZoneService.distance(
        center.latitude,
        center.longitude,
        p.latitude,
        p.longitude,
      ).clamp(2, 1000);
    }
  });
  Future<void> save() async {
    final invalid = points.isEmpty
        ? 'حدّد المنطقة على الخريطة أولًا'
        : polygon
        ? ZoneService.validatePolygon(points)
        : null;
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    final form = GlobalKey<FormState>();
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            24,
            22,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تفاصيل المنطقة',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'اسم المنطقة'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'أدخل اسم المنطقة'
                        : null,
                  ),
                  DropdownButtonFormField<ZoneType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'نوع المنطقة'),
                    items: ZoneType.values
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(zoneTypeName(t)),
                          ),
                        )
                        .toList(),
                    onChanged: (t) => refresh(() => type = t!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تفعيل مراقبة المنطقة'),
                    value: active,
                    onChanged: (v) => refresh(() => active = v),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('حفظ المنطقة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (done == true && mounted) {
      final z = draft;
      Navigator.pop(
        context,
        SafetyZone(
          id:
              widget.zone?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          name: z.name,
          type: z.type,
          latitude: z.latitude,
          longitude: z.longitude,
          radius: z.radius,
          createdAt: z.createdAt,
          isActive: z.isActive,
          vertices: z.vertices,
        ),
      );
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.zone == null ? 'ارسم منطقة جديدة' : 'تعديل حدود المنطقة',
      ),
      actions: [
        IconButton(
          tooltip: 'صور الأقمار الصناعية',
          onPressed: () => setState(() => satellite = !satellite),
          icon: Icon(satellite ? Icons.map_outlined : Icons.satellite_alt),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('دائرة'),
                    icon: Icon(Icons.circle_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('مضلع باللمس'),
                    icon: Icon(Icons.polyline_outlined),
                  ),
                ],
                selected: {polygon},
                onSelectionChanged: (s) => setState(() {
                  polygon = s.single;
                  points.clear();
                  error = null;
                }),
              ),
              const SizedBox(height: 10),
              Text(
                polygon
                    ? 'اضغط زوايا المنطقة بالترتيب. اضغط مطولًا على نقطة لسحبها.'
                    : points.isEmpty
                    ? 'اضغط لتحديد المركز، ثم اضغط عند حافة المنطقة.'
                    : 'اضغط لتغيير الحجم، أو اسحب المركز والحافة بالضغط المطوّل.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SiteMap(
                  center: widget.center,
                  controller: map,
                  editing: true,
                  satellite: satellite,
                  onTap: tap,
                  onDrag: drag,
                  zones: [
                    ...widget.neighbors.where((z) => z.id != widget.zone?.id),
                    if (points.isNotEmpty && (!polygon || points.length >= 3))
                      draft,
                  ],
                  handles: polygon
                      ? points
                      : points.isEmpty
                      ? []
                      : [center, edge],
                  draft: polygon ? points : const [],
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoomIn',
                      onPressed: () => map.zoom(true),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoomOut',
                      onPressed: () => map.zoom(false),
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(error!, style: const TextStyle(color: red)),
                  ),
                if (!polygon && points.isNotEmpty)
                  Row(
                    children: [
                      Text('نصف القطر ${radius.round()} م'),
                      Expanded(
                        child: Slider(
                          min: 2,
                          max: 1000,
                          value: radius.clamp(2, 1000),
                          onChanged: (v) => setState(() => radius = v),
                        ),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Text(polygon ? '${points.length} زوايا' : 'تحديد باللمس'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: points.isEmpty
                          ? null
                          : () => setState(() {
                              points.removeLast();
                              error = null;
                            }),
                      icon: const Icon(Icons.undo),
                      label: const Text('تراجع'),
                    ),
                    TextButton(
                      onPressed: points.isEmpty
                          ? null
                          : () => setState(() {
                              points.clear();
                              error = null;
                            }),
                      child: const Text('إعادة الرسم'),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.check),
                    label: const Text('اعتماد الحدود'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

String zoneTypeName(ZoneType t) => switch (t) {
  ZoneType.work => 'منطقة عمل',
  ZoneType.restricted => 'منطقة محظورة',
  ZoneType.highRisk => 'منطقة حذر',
};
