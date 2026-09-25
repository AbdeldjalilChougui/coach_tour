part of 'tour.dart';

/// How a tour ended.
enum CoachTourResult {
  /// The user went past the last step, or [CoachTourController.finish] was
  /// called.
  finished,

  /// The user skipped, or [CoachTourController.skip] was called.
  skipped,

  /// No step could be shown.
  nothingToShow,
}

/// Why a step was skipped.
enum CoachSkipReason {
  /// The target widget is not mounted.
  unmounted,

  /// The target is mounted but could not be brought on screen.
  notVisible,
}

/// A step that was skipped because its target could not be highlighted.
@immutable
class CoachSkippedTarget {
  /// Creates a report.
  const CoachSkippedTarget({
    required this.index,
    required this.target,
    required this.reason,
  });

  /// Index of the step in the tour.
  final int index;

  /// The step.
  final CoachTarget target;

  /// Why it was skipped.
  final CoachSkipReason reason;

  @override
  String toString() => 'CoachSkippedTarget($index, $reason)';
}

/// Drives a running tour. Returned by [CoachTour.start].
///
/// Navigation methods return a future that completes once the step is shown
/// (after any scrolling). Calls after the tour ended are ignored.
class CoachTourController extends ChangeNotifier {
  CoachTourController._(this.steps);

  /// The steps, as passed to [CoachTour.start].
  final List<CoachTarget> steps;

  _CoachOverlayState? _host;
  Route<CoachTourResult>? _route;
  int _index = -1;
  bool _ended = false;
  final Completer<CoachTourResult> _result = Completer<CoachTourResult>();
  final List<CoachSkippedTarget> _skipped = [];

  /// Index of the step on screen, or -1 before the first one is shown.
  int get index => _index;

  /// Number of steps.
  int get length => steps.length;

  /// The step on screen.
  CoachTarget? get current => _index < 0 ? null : steps[_index];

  /// Whether the tour is still running.
  bool get isActive => !_ended;

  /// Steps skipped so far because their target could not be shown.
  List<CoachSkippedTarget> get skipped => List.unmodifiable(_skipped);

  /// Completes when the tour ends.
  Future<CoachTourResult> get result => _result.future;

  /// The hole of the current step once settled, in overlay coordinates;
  /// null for a centred step.
  RRect? get hole => _host?._to;

  /// The hole as painted right now, including mid-morph.
  RRect? get displayedHole => _host?._displayed;

  /// Shows the next step, or finishes after the last one.
  Future<void> next() async {
    if (_ended || _host == null) return;
    await _host!._goTo(_index + 1, 1);
  }

  /// Shows the previous step. Does nothing on the first reachable step.
  Future<void> previous() async {
    if (_ended || _host == null || _index <= 0) return;
    await _host!._goTo(_index - 1, -1);
  }

  /// Shows step [index]. Throws [RangeError] when out of bounds.
  Future<void> goTo(int index) {
    RangeError.checkValidIndex(index, steps, 'index');
    if (_ended || _host == null) return Future<void>.value();
    return _host!._goTo(index, index >= _index ? 1 : -1);
  }

  /// Ends the tour as skipped.
  void skip() {
    if (_ended) return;
    _host?._end(CoachTourResult.skipped);
  }

  /// Ends the tour as finished.
  void finish() {
    if (_ended) return;
    _host?._end(CoachTourResult.finished);
  }

  /// Re-measures the current target, for example after its layout changed
  /// without a window metrics change.
  void refresh() => _host?._remeasure();

  void _complete(CoachTourResult result) {
    if (_ended) return;
    _ended = true;
    _result.complete(result);
    notifyListeners();
  }
}
