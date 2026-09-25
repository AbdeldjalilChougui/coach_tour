import 'package:flutter/material.dart';

import 'coach_target.dart';
import 'labels.dart';
import 'tour.dart';

/// Everything a card needs to render one step.
@immutable
class CoachStepDetails {
  /// Creates details.
  const CoachStepDetails({
    required this.index,
    required this.total,
    required this.target,
    required this.controller,
    required this.labels,
    this.showBackButton = true,
    this.showSkipButton = true,
    this.showProgress = true,
  });

  /// Index of the step.
  final int index;

  /// Number of steps.
  final int total;

  /// The step.
  final CoachTarget target;

  /// Controller of the running tour.
  final CoachTourController controller;

  /// Resolved button texts.
  final CoachTourLabels labels;

  /// Whether the default card shows "Back".
  final bool showBackButton;

  /// Whether the default card shows "Skip".
  final bool showSkipButton;

  /// Whether the default card shows progress dots.
  final bool showProgress;

  /// Whether this is the first step.
  bool get isFirst => index == 0;

  /// Whether this is the last step.
  bool get isLast => index == total - 1;
}

/// The default card: progress dots, title, body and Skip / Back / Next.
///
/// Use it from a [CoachTarget.contentBuilder] to keep the default look
/// around custom content.
class CoachTourCard extends StatelessWidget {
  /// Creates the card for [details], with [child] under the body if given.
  const CoachTourCard({required this.details, this.child, super.key});

  /// The step being shown.
  final CoachStepDetails details;

  /// Extra content between the body and the buttons.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = details;
    final labels = d.labels;
    final body = d.target.body;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.showProgress && d.total > 1) ...[
              _Dots(index: d.index, total: d.total, color: scheme.primary),
              const SizedBox(height: 12),
            ],
            if (d.target.title.isNotEmpty)
              Text(
                d.target.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            if (body != null && body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            if (child != null) ...[const SizedBox(height: 12), child!],
            const SizedBox(height: 12),
            // Lays the buttons out in a row, and stacks them when a narrow
            // screen or a large text scale leaves no room.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 4,
              children: [
                if (d.showSkipButton && !d.isLast)
                  TextButton(
                    onPressed: d.controller.skip,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    child: Text(labels.skip),
                  ),
                if (d.showBackButton && !d.isFirst)
                  TextButton(
                    onPressed: d.controller.previous,
                    child: Text(labels.back),
                  ),
                FilledButton(
                  onPressed: d.isLast ? d.controller.finish : d.controller.next,
                  child: Text(d.isLast ? labels.done : labels.next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.total, required this.color});

  final int index;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: i == index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == index ? color : color.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      );
}
