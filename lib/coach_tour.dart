/// Spotlight onboarding tours for Flutter.
///
/// Start a tour with [CoachTour.start] (or [CoachTour.startOnce] with a
/// [CoachTourStore]), describe each stop with a [CoachTarget], and drive it
/// from the returned [CoachTourController].
library;

export 'src/card.dart' show CoachStepDetails, CoachTourCard;
export 'src/coach_target.dart'
    show CoachContentBuilder, CoachShape, CoachPlacement, CoachTarget;
export 'src/labels.dart' show CoachTourLabels;
export 'src/options.dart'
    show CoachBackAction, CoachBarrierAction, CoachHoleTap, CoachTourOptions;
export 'src/placement.dart' show CoachCardSlot, placeCoachCard;
export 'src/registry.dart'
    show CoachAnchor, CoachTourRegistry, CoachTourRegistryScope;
export 'src/store.dart' show CoachTourStore, MemoryCoachTourStore;
export 'src/tour.dart'
    show
        CoachSkipReason,
        CoachSkippedTarget,
        CoachTour,
        CoachTourController,
        CoachTourResult;
