import 'package:flutter/widgets.dart';

import 'labels.dart';

/// What a tap on the dimmed area outside the hole does.
enum CoachBarrierAction {
  /// Go to the next step.
  next,

  /// Skip the tour.
  dismiss,

  /// Nothing.
  none,
}

/// What a tap inside the hole does.
enum CoachHoleTap {
  /// The tap is swallowed; the target does not receive it.
  block,

  /// The tap reaches the highlighted widget.
  passThrough,
}

/// What the system back button or predictive back gesture does.
enum CoachBackAction {
  /// Skip the tour.
  skip,

  /// Go to the previous step; skip on the first one.
  previous,

  /// Nothing; the tour stays open.
  ignore,
}

/// Behaviour and look of a tour.
@immutable
class CoachTourOptions {
  /// Creates options. Every field has a sensible default.
  const CoachTourOptions({
    this.barrierAction = CoachBarrierAction.next,
    this.holeTap = CoachHoleTap.block,
    this.backAction = CoachBackAction.skip,
    this.breathingRing = true,
    this.reduceMotion,
    this.scrollIntoView = true,
    this.morphDuration = const Duration(milliseconds: 450),
    this.scrollDuration = const Duration(milliseconds: 300),
    this.morphCurve = Curves.easeInOutCubic,
    this.scrimColor = const Color(0xCC0B0F14),
    this.ringColor,
    this.labels,
    this.showBackButton = true,
    this.showSkipButton = true,
    this.showProgress = true,
    this.announce = true,
    this.cardMaxWidth = 360,
    this.cardGap = 12,
    this.margin = 16,
  });

  /// Tap outside the hole.
  final CoachBarrierAction barrierAction;

  /// Tap inside the hole.
  final CoachHoleTap holeTap;

  /// System back / predictive back.
  final CoachBackAction backAction;

  /// Draws a slowly pulsing ring around the hole.
  final bool breathingRing;

  /// Forces reduced motion on or off. When null, follows
  /// [MediaQueryData.disableAnimations]. Reduced motion disables the pulse,
  /// the morph and animated scrolling.
  final bool? reduceMotion;

  /// Scrolls targets into view with [Scrollable.ensureVisible].
  final bool scrollIntoView;

  /// Duration of the hole morph between targets.
  final Duration morphDuration;

  /// Duration of the scroll that brings a target into view.
  final Duration scrollDuration;

  /// Curve of the hole morph.
  final Curve morphCurve;

  /// Color of the dimmed area.
  final Color scrimColor;

  /// Color of the ring; defaults to the theme's primary color.
  final Color? ringColor;

  /// Button texts; defaults to [CoachTourLabels.forLocale] of the app locale.
  final CoachTourLabels? labels;

  /// Shows "Back" from the second step on.
  final bool showBackButton;

  /// Shows "Skip" before the last step.
  final bool showSkipButton;

  /// Shows progress dots.
  final bool showProgress;

  /// Announces each step to screen readers.
  final bool announce;

  /// Maximum card width.
  final double cardMaxWidth;

  /// Space between the hole (ring included) and the card.
  final double cardGap;

  /// Minimum space between the card and the safe area edges.
  final double margin;
}
