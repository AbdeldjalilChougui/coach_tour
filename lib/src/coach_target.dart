import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'card.dart';

/// The outline of the spotlight hole.
enum CoachShape {
  /// Square corners.
  rect,

  /// Rounded corners of [CoachTarget.radius].
  rrect,

  /// A circle centred on the target whose diameter is the longer side of the
  /// padded target rect.
  circle,

  /// A pill: the shorter side is fully rounded.
  stadium,
}

/// Where the card goes relative to the hole.
///
/// `start` and `end` follow the ambient [TextDirection].
enum CoachPlacement {
  /// Below the hole when it sits in the top half of the screen, above it
  /// otherwise; falls back to the sides.
  auto,

  /// Above the hole.
  above,

  /// Below the hole.
  below,

  /// On the leading side (left in LTR, right in RTL).
  start,

  /// On the trailing side (right in LTR, left in RTL).
  end,
}

/// Builds custom card content for one step.
typedef CoachContentBuilder = Widget Function(
  BuildContext context,
  CoachStepDetails details,
);

/// One stop of a tour.
///
/// Point it at a widget either with a [key] you attach to that widget, or
/// with an [id] registered in a [CoachTourRegistry] (see [CoachAnchor]).
/// A target with neither is a centred step: no hole, the card sits in the
/// middle of the screen.
@immutable
class CoachTarget {
  /// Creates a step that highlights the widget identified by [key] or [id].
  const CoachTarget({
    this.key,
    this.id,
    this.title = '',
    this.body,
    this.shape = CoachShape.rrect,
    this.padding = const EdgeInsets.all(8),
    this.radius = 12,
    this.contentBuilder,
    this.placement = CoachPlacement.auto,
  });

  /// Creates a step with no hole and a centred card, useful to open or close
  /// a tour.
  const CoachTarget.centered({
    required this.title,
    this.body,
    this.contentBuilder,
  })  : key = null,
        id = null,
        shape = CoachShape.rect,
        padding = EdgeInsets.zero,
        radius = 0,
        placement = CoachPlacement.auto;

  /// Key attached to the widget to highlight. Takes precedence over [id].
  final GlobalKey? key;

  /// Id of an anchor registered in a [CoachTourRegistry].
  final String? id;

  /// Card title.
  final String title;

  /// Card body text.
  final String? body;

  /// Outline of the hole.
  final CoachShape shape;

  /// Space between the target and the edge of the hole.
  final EdgeInsetsGeometry padding;

  /// Corner radius for [CoachShape.rrect].
  final double radius;

  /// Replaces the default card when set.
  final CoachContentBuilder? contentBuilder;

  /// Preferred card position.
  final CoachPlacement placement;

  /// Whether this step points at a widget (as opposed to a centred step).
  bool get isAnchored => key != null || id != null;

  /// The hole cut for a target occupying [target].
  RRect holeFor(
    Rect target, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final r = padding.resolve(textDirection).inflateRect(target);
    switch (shape) {
      case CoachShape.rect:
        return RRect.fromRectAndRadius(r, Radius.zero);
      case CoachShape.rrect:
        final max = math.min(r.width, r.height) / 2;
        return RRect.fromRectAndRadius(
          r,
          Radius.circular(radius.clamp(0, max).toDouble()),
        );
      case CoachShape.stadium:
        return RRect.fromRectAndRadius(
          r,
          Radius.circular(math.min(r.width, r.height) / 2),
        );
      case CoachShape.circle:
        final d = math.max(r.width, r.height);
        return RRect.fromRectAndRadius(
          Rect.fromCenter(center: r.center, width: d, height: d),
          Radius.circular(d / 2),
        );
    }
  }
}
