import 'dart:ui';

class ARLabelTarget {
  final String id;
  final Offset anchor;
  const ARLabelTarget(this.id, this.anchor);
}

class ARLabelPlacement {
  final ARLabelTarget target;
  final Rect rect;
  const ARLabelPlacement(this.target, this.rect);
}

// Priority order comes from selection then distance; every card has a leader to its real projection.
List<ARLabelPlacement> placeARLabels(
  List<ARLabelTarget> targets,
  Size size, {
  double top = 180,
  double bottom = 185,
}) {
  final result = <ARLabelPlacement>[];
  const width = 146.0, height = 65.0, gap = 8.0;
  if (size.width < width + 16 || size.height < top + bottom + height) {
    return result;
  }
  for (final target in targets) {
    if (target.anchor.dx < -.05 || target.anchor.dx > 1.05) continue;
    final x = (target.anchor.dx * size.width - width / 2).clamp(
      8.0,
      size.width - width - 8,
    );
    final y = (target.anchor.dy * size.height - height / 2).clamp(
      top,
      size.height - bottom - height,
    );
    for (final delta in [0.0, -73.0, 73.0, -146.0, 146.0, -219.0, 219.0]) {
      final candidate = Rect.fromLTWH(x, y + delta, width, height);
      if (candidate.top < top || candidate.bottom > size.height - bottom) {
        continue;
      }
      if (result.any(
        (p) => p.rect.inflate(gap / 2).overlaps(candidate.inflate(gap / 2)),
      )) {
        continue;
      }
      result.add(ARLabelPlacement(target, candidate));
      break;
    }
  }
  return result;
}
