import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'card.dart';
import 'coach_target.dart';
import 'labels.dart';
import 'options.dart';
import 'placement.dart';
import 'registry.dart';
import 'store.dart';

part 'controller.dart';
part 'overlay.dart';

/// Entry points for showing a tour.
abstract final class CoachTour {
  /// Key of the widget wrapping the card; handy in tests.
  static const Key cardKey = ValueKey<String>('coach_tour.card');

  /// Shows a tour over the current screen and returns its controller.
  ///
  /// The overlay is pushed as a transparent modal route on the root
  /// navigator (or the nearest one when [useRootNavigator] is false). Steps
  /// whose target is unmounted or cannot be scrolled into view are skipped
  /// and reported through [onTargetSkipped].
  ///
  /// Callbacks: [onStepChanged] each time a step is shown, then exactly one
  /// of [onFinish] (the last step was passed) or [onSkip] (the user skipped;
  /// receives the step index). A tour where no step could be shown calls
  /// neither and completes with [CoachTourResult.nothingToShow].
  static CoachTourController start(
    BuildContext context,
    List<CoachTarget> steps, {
    VoidCallback? onFinish,
    ValueChanged<int>? onSkip,
    void Function(int index, CoachTarget target)? onStepChanged,
    ValueChanged<CoachSkippedTarget>? onTargetSkipped,
    CoachTourOptions options = const CoachTourOptions(),
    CoachTourRegistry? registry,
    bool useRootNavigator = true,
  }) {
    final controller = CoachTourController._(List.unmodifiable(steps));
    if (steps.isEmpty) {
      controller._complete(CoachTourResult.nothingToShow);
      return controller;
    }
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final reduced = options.reduceMotion ??
        MediaQuery.maybeDisableAnimationsOf(context) ??
        false;
    final route = _CoachTourRoute(
      reduced: reduced,
      builder: (_) => _CoachOverlay(
        controller: controller,
        options: options,
        registry: registry ?? CoachTourRegistry.of(context),
        onFinish: onFinish,
        onSkip: onSkip,
        onStepChanged: onStepChanged,
        onTargetSkipped: onTargetSkipped,
      ),
    );
    controller._route = route;
    unawaited(navigator.push(route));
    return controller;
  }

  /// Shows the tour [tourId] unless [store] says it was already seen.
  ///
  /// Returns null when the tour was seen (or [context] unmounted while the
  /// store was read). The tour is marked seen when it finishes, and when it
  /// is skipped unless [markSeenOnSkip] is false. A tour with nothing to
  /// show is not marked, so it can try again next time.
  static Future<CoachTourController?> startOnce(
    BuildContext context, {
    required String tourId,
    required CoachTourStore store,
    required List<CoachTarget> steps,
    bool markSeenOnSkip = true,
    VoidCallback? onFinish,
    ValueChanged<int>? onSkip,
    void Function(int index, CoachTarget target)? onStepChanged,
    ValueChanged<CoachSkippedTarget>? onTargetSkipped,
    CoachTourOptions options = const CoachTourOptions(),
    CoachTourRegistry? registry,
    bool useRootNavigator = true,
  }) async {
    if (await store.hasSeen(tourId)) return null;
    if (!context.mounted) return null;
    final controller = start(
      context,
      steps,
      onFinish: onFinish,
      onSkip: onSkip,
      onStepChanged: onStepChanged,
      onTargetSkipped: onTargetSkipped,
      options: options,
      registry: registry,
      useRootNavigator: useRootNavigator,
    );
    unawaited(controller.result.then((result) {
      final mark = switch (result) {
        CoachTourResult.finished => true,
        CoachTourResult.skipped => markSeenOnSkip,
        CoachTourResult.nothingToShow => false,
      };
      if (mark) return store.markSeen(tourId);
    }));
    return controller;
  }
}

class _CoachTourRoute extends PopupRoute<CoachTourResult> {
  _CoachTourRoute({required this.builder, required this.reduced});

  final WidgetBuilder builder;
  final bool reduced;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration =>
      reduced ? Duration.zero : const Duration(milliseconds: 250);

  // The overlay handles barrier taps itself; the default barrier would
  // swallow taps meant to pass through the hole. The overlay also blocks
  // the page's semantics itself.
  @override
  Widget buildModalBarrier() => const SizedBox.shrink();

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) =>
      builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
}
