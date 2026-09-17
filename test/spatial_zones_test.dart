import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:safety_lens_ai/models/safety.dart';
import 'package:safety_lens_ai/services/safety_engines.dart';
import 'package:safety_lens_ai/features/safety_vision/ar_label_layout.dart';

void main() {
  const square = [
    ZoneVertex(0, 0),
    ZoneVertex(0, .001),
    ZoneVertex(.001, .001),
    ZoneVertex(.001, 0),
  ];
  test('polygon containment and edge distance ignore enclosing circle', () {
    final z = SafetyZone(
      id: 'p',
      name: 'Restricted',
      type: ZoneType.restricted,
      latitude: .0005,
      longitude: .0005,
      radius: 500,
      createdAt: DateTime(2026),
      vertices: square,
    );
    final engine = ZoneService();
    final inside = engine.evaluate(GeoPoint(.0005, .0005, accuracy: 3), [
      z,
    ]).single;
    expect(inside.inside, isTrue);
    expect(inside.boundaryDistance, 0);
    expect(inside.uncertain, isFalse);
    final outside = engine.evaluate(GeoPoint(.0005, .0011, accuracy: 3), [
      z,
    ]).single;
    expect(outside.inside, isFalse);
    expect(outside.boundaryDistance, closeTo(11.12, .1));
    final boundary = engine.evaluate(GeoPoint(.0005, .001, accuracy: 3), [
      z,
    ]).single;
    expect(boundary.inside, isTrue);
    expect(boundary.uncertain, isTrue);
  });
  test('concave cutout is outside, vertex ordering may be reversed', () {
    const l = [
      ZoneVertex(0, 0),
      ZoneVertex(0, .002),
      ZoneVertex(.001, .002),
      ZoneVertex(.001, .001),
      ZoneVertex(.002, .001),
      ZoneVertex(.002, 0),
    ];
    expect(ZoneService.validatePolygon(l), isNull);
    expect(ZoneService.polygonDistance(.0015, .0015, l), greaterThan(0));
    expect(ZoneService.polygonDistance(.0015, .0005, l), lessThan(0));
    expect(
      ZoneService.polygonDistance(.0015, .0005, l.reversed.toList()),
      lessThan(0),
    );
  });
  test('crossing, collinear and overlapping boundaries cannot be saved', () {
    expect(
      ZoneService.validatePolygon([square[0], square[2], square[1], square[3]]),
      isNotNull,
    );
    expect(
      ZoneService.validatePolygon(const [
        ZoneVertex(0, 0),
        ZoneVertex(0, .001),
        ZoneVertex(0, .002),
      ]),
      isNotNull,
    );
    expect(ZoneService.validatePolygon([...square, square.first]), isNotNull);
    expect(ZoneService.validatePolygon(square), isNull);
  });
  test('persisted circles remain compatible; polygons round trip', () {
    final old = {
      'id': 'a',
      'name': 'old',
      'type': 'work',
      'latitude': 24.0,
      'longitude': 46.0,
      'radius': 30,
      'isActive': true,
      'createdAt': '2026-01-01T00:00:00.000',
    };
    expect(SafetyZone.fromJson(old).isPolygon, isFalse);
    final p = SafetyZone.fromJson({
      ...old,
      'vertices': square.map((v) => v.toJson()).toList(),
    });
    expect(SafetyZone.fromJson(p.toJson()).vertices.length, 4);
  });
  test('nearby AR cards never overlap and priority target stays visible', () {
    final targets = List.generate(
      12,
      (i) => ARLabelTarget('$i', const Offset(.5, .5)),
    );
    final placed = placeARLabels(targets, const Size(390, 844));
    expect(placed.first.target.id, '0');
    expect(placed.length, greaterThan(1));
    for (var i = 0; i < placed.length; i++) {
      expect(placed[i].rect.top, greaterThanOrEqualTo(180));
      expect(placed[i].rect.bottom, lessThanOrEqualTo(659));
      for (var j = i + 1; j < placed.length; j++) {
        expect(placed[i].rect.overlaps(placed[j].rect), isFalse);
      }
    }
    expect(placeARLabels(targets, const Size(200, 300)), isEmpty);
  });
}
