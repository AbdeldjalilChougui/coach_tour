import 'package:flutter/widgets.dart';

/// Texts of the default card buttons and step counter.
@immutable
class CoachTourLabels {
  /// Creates labels. [stepOf] defaults to the English "Step x of y".
  const CoachTourLabels({
    required this.next,
    required this.back,
    required this.skip,
    required this.done,
    this.stepOf = _enStepOf,
  });

  /// English.
  static const CoachTourLabels en = CoachTourLabels(
    next: 'Next',
    back: 'Back',
    skip: 'Skip',
    done: 'Done',
  );

  /// French.
  static const CoachTourLabels fr = CoachTourLabels(
    next: 'Suivant',
    back: 'Précédent',
    skip: 'Passer',
    done: 'Terminé',
    stepOf: _frStepOf,
  );

  /// Arabic.
  static const CoachTourLabels ar = CoachTourLabels(
    next: 'التالي',
    back: 'السابق',
    skip: 'تخطي',
    done: 'تم',
    stepOf: _arStepOf,
  );

  /// Labels for [locale]'s language, English when unsupported or null.
  static CoachTourLabels forLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'fr' => fr,
        'ar' => ar,
        _ => en,
      };

  /// "Next" button.
  final String next;

  /// "Back" button.
  final String back;

  /// "Skip" button.
  final String skip;

  /// Button on the last step.
  final String done;

  /// Step counter used for announcements and semantics, 1-based.
  final String Function(int step, int total) stepOf;

  /// Returns a copy with the given labels replaced.
  CoachTourLabels copyWith({
    String? next,
    String? back,
    String? skip,
    String? done,
    String Function(int step, int total)? stepOf,
  }) =>
      CoachTourLabels(
        next: next ?? this.next,
        back: back ?? this.back,
        skip: skip ?? this.skip,
        done: done ?? this.done,
        stepOf: stepOf ?? this.stepOf,
      );
}

String _enStepOf(int step, int total) => 'Step $step of $total';
String _frStepOf(int step, int total) => 'Étape $step sur $total';
String _arStepOf(int step, int total) => 'الخطوة $step من $total';
