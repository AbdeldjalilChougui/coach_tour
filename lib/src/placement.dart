import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'coach_target.dart';

/// Where the card ended up.
@immutable
class CoachCardSlot {
  /// Creates a slot.
  const CoachCardSlot({
    required this.rect,
    required this.side,
    required this.overflow,
  });

  /// The card's rect. Its height may be smaller than the measured height when
  /// [overflow] is true; the default card scrolls in that case.
  final Rect rect;

  /// The side actually used: [CoachPlacement.auto] for centred cards,
  /// otherwise one of the four sides.
  final CoachPlacement side;

  /// Whether no side had room for the full card height.
  final bool overflow;
}

/// Places a card next to [hole] inside [bounds] without covering it.
///
/// [measureHeight] returns the card height for a given width. Sides are tried
/// in order: the preferred one, its opposite (the "flip"), then the others.
/// The first side with room for the whole card wins. When none has room, the
/// largest free region is used and the card is shortened ([CoachCardSlot.overflow]).
///
/// The card never overlaps [hole] unless the hole leaves no free region in
/// [bounds] at all; then the card is placed at the bottom of [bounds].
CoachCardSlot placeCoachCard({
  required Rect? hole,
  required Rect bounds,
  required double Function(double width) measureHeight,
  CoachPlacement placement = CoachPlacement.auto,
  TextDirection textDirection = TextDirection.ltr,
  double gap = 12,
  double maxWidth = 360,
  double minSideWidth = 180,
  double minHeight = 48,
}) {
  final fullWidth = math.min(maxWidth, bounds.width);
  if (hole == null) {
    final h = math.min(measureHeight(fullWidth), bounds.height);
    return CoachCardSlot(
      rect: Rect.fromCenter(center: bounds.center, width: fullWidth, height: h),
      side: CoachPlacement.auto,
      overflow: measureHeight(fullWidth) > bounds.height,
    );
  }

  final ltr = textDirection == TextDirection.ltr;
  Rect region(CoachPlacement side) {
    final right = (side == CoachPlacement.end) == ltr;
    switch (side) {
      case CoachPlacement.above:
        return Rect.fromLTRB(
            bounds.left, bounds.top, bounds.right, hole.top - gap);
      case CoachPlacement.below:
        return Rect.fromLTRB(
            bounds.left, hole.bottom + gap, bounds.right, bounds.bottom);
      case CoachPlacement.start:
      case CoachPlacement.end:
        return right
            ? Rect.fromLTRB(
                hole.right + gap, bounds.top, bounds.right, bounds.bottom)
            : Rect.fromLTRB(
                bounds.left, bounds.top, hole.left - gap, bounds.bottom);
      case CoachPlacement.auto:
        throw ArgumentError.value(side);
    }
  }

  bool vertical(CoachPlacement s) =>
      s == CoachPlacement.above || s == CoachPlacement.below;

  Rect position(CoachPlacement side, Rect r, double w, double h) {
    if (vertical(side)) {
      final x = (hole.center.dx - w / 2).clamp(r.left, r.right - w).toDouble();
      final y = side == CoachPlacement.below ? r.top : r.bottom - h;
      return Rect.fromLTWH(x, y, w, h);
    }
    final y = (hole.center.dy - h / 2).clamp(r.top, r.bottom - h).toDouble();
    final right = (side == CoachPlacement.end) == ltr;
    final x = right ? r.left : r.right - w;
    return Rect.fromLTWH(x, y, w, h);
  }

  final order = _order(placement, hole, bounds);
  CoachPlacement? bestSide;
  Rect? bestRegion;
  double bestWidth = 0;
  var bestArea = 0.0;

  for (final side in order) {
    final r = region(side);
    if (r.width <= 0 || r.height <= 0) continue;
    if (!vertical(side) && r.width < minSideWidth) continue;
    final w = math.min(fullWidth, r.width);
    final h = measureHeight(w);
    if (h <= r.height) {
      return CoachCardSlot(
          rect: position(side, r, w, h), side: side, overflow: false);
    }
    // Prefer regions tall enough to be usable, then the largest.
    final area = w * r.height + (r.height >= minHeight ? 1e9 : 0);
    if (area > bestArea) {
      bestArea = area;
      bestSide = side;
      bestRegion = r;
      bestWidth = w;
    }
  }

  if (bestSide != null) {
    final r = bestRegion!;
    return CoachCardSlot(
      rect: position(bestSide, r, bestWidth, r.height),
      side: bestSide,
      overflow: true,
    );
  }

  // The hole leaves no room anywhere: overlap is unavoidable.
  final h = math.min(measureHeight(fullWidth), bounds.height);
  return CoachCardSlot(
    rect: Rect.fromLTWH(
      bounds.center.dx - fullWidth / 2,
      bounds.bottom - h,
      fullWidth,
      h,
    ),
    side: CoachPlacement.below,
    overflow: true,
  );
}

List<CoachPlacement> _order(CoachPlacement p, Rect hole, Rect bounds) {
  const above = CoachPlacement.above;
  const below = CoachPlacement.below;
  const start = CoachPlacement.start;
  const end = CoachPlacement.end;
  switch (p) {
    case CoachPlacement.auto:
      return hole.center.dy < bounds.center.dy
          ? const [below, above, end, start]
          : const [above, below, end, start];
    case CoachPlacement.above:
      return const [above, below, end, start];
    case CoachPlacement.below:
      return const [below, above, end, start];
    case CoachPlacement.start:
      return const [start, end, below, above];
    case CoachPlacement.end:
      return const [end, start, below, above];
  }
}
