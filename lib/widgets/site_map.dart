import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/safety.dart';
import '../core/theme.dart';

class SiteMapController {
  MethodChannel? _channel;
  MapController? _fallback;
  Future<void> move(ZoneVertex p, {double meters = 350}) async {
    if (_channel != null) {
      await _channel!.invokeMethod('move', {...p.toJson(), 'meters': meters});
    }
    _fallback?.move(LatLng(p.latitude, p.longitude), 17);
  }

  Future<void> zoom(bool closer) async {
    if (_channel != null) {
      await _channel!.invokeMethod('zoom', {'factor': closer ? .5 : 2.0});
    }
    final f = _fallback;
    if (f != null) {
      f.move(f.camera.center, (f.camera.zoom + (closer ? 1 : -1)).clamp(2, 20));
    }
  }
}

class SiteMap extends StatefulWidget {
  final ZoneVertex center;
  final List<SafetyZone> zones;
  final List<ZoneVertex> handles, draft;
  final ZoneVertex? user;
  final bool editing, satellite;
  final ValueChanged<ZoneVertex>? onTap;
  final void Function(int, ZoneVertex)? onDrag;
  final SiteMapController? controller;
  const SiteMap({
    super.key,
    required this.center,
    this.zones = const [],
    this.handles = const [],
    this.draft = const [],
    this.user,
    this.editing = false,
    this.satellite = false,
    this.onTap,
    this.onDrag,
    this.controller,
  });
  @override
  State<SiteMap> createState() => _SiteMapState();
}

class _SiteMapState extends State<SiteMap> {
  MethodChannel? channel;
  final fallback = MapController();
  String? error;
  Map<String, Object?> get payload => {
    ...widget.center.toJson(),
    'zones': widget.zones.map((z) => z.toJson()).toList(),
    'handles': widget.handles.map((p) => p.toJson()).toList(),
    'draft': widget.draft.map((p) => p.toJson()).toList(),
    'user': widget.user?.toJson(),
    'editing': widget.editing,
    'satellite': widget.satellite,
  };
  @override
  void didUpdateWidget(covariant SiteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (channel != null) {
      final data = payload;
      final signature = jsonEncode(data);
      if (signature != lastPayload) {
        lastPayload = signature;
        channel!.invokeMethod('update', data);
      }
    }
  }

  String? lastPayload;
  void created(int id) {
    channel = MethodChannel('ai.safetylens/map/$id');
    widget.controller?._channel = channel;
    channel!.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'error') {
        setState(() => error = call.arguments as String);
        return;
      }
      final a = Map<String, dynamic>.from(call.arguments as Map);
      final p = ZoneVertex(
        (a['latitude'] as num).toDouble(),
        (a['longitude'] as num).toDouble(),
      );
      if (call.method == 'tap') widget.onTap?.call(p);
      if (call.method == 'drag') widget.onDrag?.call(a['index'] as int, p);
    });
    channel!.invokeMethod('update', payload);
  }

  @override
  void dispose() {
    channel?.invokeMethod('dispose');
    channel?.setMethodCallHandler(null);
    widget.controller?._channel = null;
    widget.controller?._fallback = null;
    fallback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) widget.controller?._fallback = fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (Platform.isIOS)
          UiKitView(
            viewType: 'ai.safetylens/map',
            creationParams: payload,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: created,
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          )
        else
          FlutterMap(
            mapController: fallback,
            options: MapOptions(
              initialCenter: LatLng(
                widget.center.latitude,
                widget.center.longitude,
              ),
              initialZoom: 17,
              onTap: (_, p) =>
                  widget.onTap?.call(ZoneVertex(p.latitude, p.longitude)),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.safetylens.safetyLensAi',
              ),
              CircleLayer(
                circles: widget.zones
                    .where((z) => !z.isPolygon)
                    .map(
                      (z) => CircleMarker(
                        point: LatLng(z.latitude, z.longitude),
                        radius: z.radius,
                        useRadiusInMeter: true,
                        color: zoneColor(z.type).withValues(alpha: .18),
                        borderColor: zoneColor(z.type),
                        borderStrokeWidth: 2,
                      ),
                    )
                    .toList(),
              ),
              PolygonLayer(
                polygons: widget.zones
                    .where((z) => z.isPolygon)
                    .map(
                      (z) => Polygon(
                        points: z.vertices
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        color: zoneColor(z.type).withValues(alpha: .18),
                        borderColor: zoneColor(z.type),
                        borderStrokeWidth: 2,
                      ),
                    )
                    .toList(),
              ),
              MarkerLayer(
                markers: widget.handles.indexed
                    .map(
                      (e) => Marker(
                        point: LatLng(e.$2.latitude, e.$2.longitude),
                        child: CircleAvatar(
                          radius: 12,
                          child: Text('${e.$1 + 1}'),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SimpleAttributionWidget(
                source: Text('© OpenStreetMap contributors'),
              ),
            ],
          ),
        if (error != null)
          Positioned(
            left: 10,
            right: 10,
            top: 10,
            child: Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  error!,
                  style: const TextStyle(color: red, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
