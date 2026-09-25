part of 'tour.dart';

const Duration _pulsePeriod = Duration(milliseconds: 1600);
const double _ringStroke = 2;
const double _pulseSpread = 12;

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({
    required this.controller,
    required this.options,
    required this.registry,
    this.onFinish,
    this.onSkip,
    this.onStepChanged,
    this.onTargetSkipped,
  });

  final CoachTourController controller;
  final CoachTourOptions options;
  final CoachTourRegistry registry;
  final VoidCallback? onFinish;
  final ValueChanged<int>? onSkip;
  final void Function(int index, CoachTarget target)? onStepChanged;
  final ValueChanged<CoachSkippedTarget>? onTargetSkipped;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: widget.options.morphDuration,
    value: 1,
  );
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: _pulsePeriod);
  final FocusNode _cardFocus = FocusNode(debugLabel: 'CoachTour card');

  CoachTourController get _controller => widget.controller;
  CoachTourOptions get _options => widget.options;

  /// Where the hole morphs from and to. Null means "no hole" (centred step).
  RRect? _from;
  RRect? _to;
  bool _ready = false;
  bool _reduced = false;
  int _navigation = 0;

  bool get _pulsing => _options.breathingRing && !_reduced;

  RRect? get _displayed {
    final from = _from;
    final to = _to;
    if (from == null && to == null) return null;
    final t = _options.morphCurve.transform(_morph.value);
    final r = RRect.lerp(from ?? _collapse(to!), to ?? _collapse(from!), t)!;
    return r.width < 0.5 || r.height < 0.5 ? null : r;
  }

  static RRect _collapse(RRect r) => RRect.fromRectAndRadius(
        Rect.fromCenter(center: r.center, width: 0, height: 0),
        Radius.zero,
      );

  @override
  void initState() {
    super.initState();
    _controller._host = this;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goTo(0, 1);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = _options.reduceMotion ??
        MediaQuery.maybeDisableAnimationsOf(context) ??
        false;
    if (_pulsing) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
    if (_reduced && _morph.isAnimating) _morph.value = 1;
  }

  @override
  void didChangeMetrics() {
    SchedulerBinding.instance.addPostFrameCallback((_) => _remeasure());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_controller._host == this) _controller._host = null;
    // Removed from outside (e.g. popUntil): the user left the tour.
    if (!_controller._ended) {
      _controller._complete(CoachTourResult.skipped);
      widget.onSkip?.call(math.max(_controller._index, 0));
    }
    _morph.dispose();
    _pulse.dispose();
    _cardFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- targets

  BuildContext? _contextFor(CoachTarget t) {
    final key = t.key ?? (t.id == null ? null : widget.registry.lookup(t.id!));
    final ctx = key?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    return ctx;
  }

  Rect? _measure(BuildContext target) {
    final box = target.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final global = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final self = context.findRenderObject();
    if (self is! RenderBox || !self.hasSize) return global;
    return global.shift(-self.localToGlobal(Offset.zero));
  }

  /// The target's rect in overlay coordinates, or null when unmounted.
  Rect? _locate(CoachTarget t) {
    final target = _contextFor(t);
    return target == null ? null : _measure(target);
  }

  Size get _size {
    final self = context.findRenderObject();
    if (self is RenderBox && self.hasSize) return self.size;
    return MediaQuery.sizeOf(context);
  }

  Rect get _safeBounds =>
      MediaQuery.paddingOf(context).deflateRect(Offset.zero & _size);

  bool _fullyVisible(Rect r) {
    final b = _safeBounds;
    return r.left >= b.left &&
        r.top >= b.top &&
        r.right <= b.right &&
        r.bottom <= b.bottom;
  }

  bool _visibleEnough(Rect r) {
    if (r.isEmpty) return false;
    final i = r.intersect(Offset.zero & _size);
    if (i.width <= 0 || i.height <= 0) return false;
    return i.width * i.height >= 0.5 * r.width * r.height;
  }

  RRect _holeFor(CoachTarget t, Rect r) =>
      t.holeFor(r, textDirection: Directionality.of(context));

  // ------------------------------------------------------------- navigation

  Future<void> _goTo(int start, int direction) async {
    final token = ++_navigation;
    final steps = _controller.steps;
    var i = start;
    while (i >= 0 && i < steps.length) {
      final t = steps[i];
      if (!t.isAnchored) {
        _show(i, null);
        return;
      }
      var rect = _locate(t);
      if (rect != null && _options.scrollIntoView && !_fullyVisible(rect)) {
        await _ensureVisible(t);
        if (!mounted || token != _navigation || _controller._ended) return;
        rect = _locate(t);
      }
      if (rect == null) {
        _report(i, CoachSkipReason.unmounted);
      } else if (!_visibleEnough(rect)) {
        _report(i, CoachSkipReason.notVisible);
      } else {
        _show(i, _holeFor(t, rect));
        return;
      }
      i += direction;
    }
    if (direction > 0) {
      _end(_controller._index < 0
          ? CoachTourResult.nothingToShow
          : CoachTourResult.finished);
    }
  }

  Future<void> _ensureVisible(CoachTarget t) async {
    final target = _contextFor(t);
    if (target == null) return;
    try {
      await Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: _reduced ? Duration.zero : _options.scrollDuration,
        curve: Curves.easeInOutCubic,
      );
    } on Object {
      // A target that cannot scroll is judged on where it is.
    }
    if (!mounted) return;
    await SchedulerBinding.instance.endOfFrame;
  }

  void _report(int index, CoachSkipReason reason) {
    final report = CoachSkippedTarget(
      index: index,
      target: _controller.steps[index],
      reason: reason,
    );
    _controller._skipped.add(report);
    widget.onTargetSkipped?.call(report);
  }

  void _show(int index, RRect? hole) {
    final shown = _displayed;
    setState(() {
      if (!_ready || _reduced) {
        _from = hole;
        _to = hole;
        _morph.value = 1;
      } else {
        _from = shown;
        _to = hole;
        _morph.forward(from: 0);
      }
      _ready = true;
    });
    final target = _controller.steps[index];
    _controller
      .._index = index
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      ..notifyListeners();
    widget.onStepChanged?.call(index, target);

    if (_options.announce) {
      final labels = _labels(context);
      final parts = [
        labels.stepOf(index + 1, _controller.length),
        if (target.title.isNotEmpty) target.title,
        if (target.body != null && target.body!.isNotEmpty) target.body!,
      ];
      SemanticsService.announce(
        parts.join('. '),
        Directionality.of(context),
      );
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_controller._ended) _cardFocus.requestFocus();
    });
  }

  void _remeasure() {
    if (!mounted || !_ready || _controller._ended) return;
    final t = _controller.current;
    if (t == null || !t.isAnchored) {
      setState(() {});
      return;
    }
    final rect = _locate(t);
    if (rect == null || !_visibleEnough(rect)) {
      _goTo(_controller._index, 1);
      return;
    }
    final hole = _holeFor(t, rect);
    setState(() {
      _from = hole;
      _to = hole;
      _morph.value = 1;
    });
  }

  void _end(CoachTourResult result) {
    if (_controller._ended) return;
    final index = math.max(_controller._index, 0);
    _controller._complete(result);
    switch (result) {
      case CoachTourResult.finished:
        widget.onFinish?.call();
      case CoachTourResult.skipped:
        widget.onSkip?.call(index);
      case CoachTourResult.nothingToShow:
        break;
    }
    final route = _controller._route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop(result);
    } else {
      navigator.removeRoute(route, result);
    }
  }

  // ------------------------------------------------------------------ input

  void _onBarrierTap(Offset position) {
    final hole = _displayed;
    if (hole != null && hole.contains(position)) return;
    switch (_options.barrierAction) {
      case CoachBarrierAction.next:
        _controller.next();
      case CoachBarrierAction.dismiss:
        _controller.skip();
      case CoachBarrierAction.none:
        break;
    }
  }

  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    switch (_options.backAction) {
      case CoachBackAction.skip:
        _controller.skip();
      case CoachBackAction.previous:
        if (_controller._index <= 0) {
          _controller.skip();
        } else {
          _controller.previous();
        }
      case CoachBackAction.ignore:
        break;
    }
  }

  CoachTourLabels _labels(BuildContext context) =>
      _options.labels ??
      CoachTourLabels.forLocale(Localizations.maybeLocaleOf(context));

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ring = _options.ringColor ?? theme.colorScheme.primary;
    final safe = MediaQuery.paddingOf(context) +
        EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom);
    final passThrough = _options.holeTap == CoachHoleTap.passThrough;

    final spotlight = AnimatedBuilder(
      animation: Listenable.merge([_morph, _pulse]),
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _SpotlightPainter(
          hole: _ready ? _displayed : null,
          visible: _ready,
          pulse: _pulsing ? _pulse.value : 0,
          scrim: _options.scrimColor,
          ring: ring,
        ),
      ),
    );

    Widget? card;
    final index = _controller._index;
    if (_ready && index >= 0) {
      final target = _controller.steps[index];
      final details = CoachStepDetails(
        index: index,
        total: _controller.length,
        target: target,
        controller: _controller,
        labels: _labels(context),
        showBackButton: _options.showBackButton,
        showSkipButton: _options.showSkipButton,
        showProgress: _options.showProgress,
      );
      final content = target.contentBuilder?.call(context, details) ??
          CoachTourCard(details: details);
      final ringExtent =
          _ringStroke / 2 + (_pulsing ? _pulseSpread + _ringStroke : 0);
      card = _CardLayout(
        hole: _to?.outerRect.inflate(ringExtent),
        padding: safe + EdgeInsets.all(_options.margin),
        placement: target.placement,
        textDirection: Directionality.of(context),
        gap: _options.cardGap,
        maxWidth: _options.cardMaxWidth,
        child: KeyedSubtree(
          key: CoachTour.cardKey,
          child: Semantics(
            container: true,
            label: details.labels.stepOf(index + 1, _controller.length),
            child: Focus(
              focusNode: _cardFocus,
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(index),
                tween: Tween(begin: 0, end: 1),
                duration: _reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 12),
                    child: child,
                  ),
                ),
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _controller.skip,
        },
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          child: BlockSemantics(
            child: _HoleHitTest(
              hole: passThrough ? () => _displayed : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapUp: (d) => _onBarrierTap(d.localPosition),
                    child: spotlight,
                  ),
                  if (card != null) card,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ painting

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.hole,
    required this.visible,
    required this.pulse,
    required this.scrim,
    required this.ring,
  });

  final RRect? hole;
  final bool visible;
  final double pulse;
  final Color scrim;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final screen = Offset.zero & size;
    final scrimPaint = Paint()..color = scrim;
    final h = hole;
    if (h == null) {
      canvas.drawRect(screen, scrimPaint);
      return;
    }
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(screen),
        Path()..addRRect(h),
      ),
      scrimPaint,
    );
    // A solid edge so the cut never looks like a rendering artefact...
    canvas.drawRRect(
      h,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringStroke
        ..color = ring.withValues(alpha: .9),
    );
    // ...and a ring that swells and fades so a still spotlight reads as live.
    if (pulse > 0) {
      final spread = 2 + pulse * (_pulseSpread - 2);
      canvas.drawRRect(
        h.inflate(spread),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringStroke
          ..color = ring.withValues(alpha: (1 - pulse) * .55),
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole ||
      old.visible != visible ||
      old.pulse != pulse ||
      old.scrim != scrim ||
      old.ring != ring;
}

// ----------------------------------------------------------------- hit test

class _HoleHitTest extends SingleChildRenderObjectWidget {
  const _HoleHitTest({required this.hole, super.child});

  final RRect? Function()? hole;

  @override
  _RenderHoleHitTest createRenderObject(BuildContext context) =>
      _RenderHoleHitTest(hole);

  @override
  void updateRenderObject(BuildContext context, _RenderHoleHitTest r) =>
      r.hole = hole;
}

class _RenderHoleHitTest extends RenderProxyBox {
  _RenderHoleHitTest(this.hole);

  RRect? Function()? hole;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final h = hole?.call();
    if (h != null && h.contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}

// ------------------------------------------------------------------- layout

class _CardLayout extends SingleChildRenderObjectWidget {
  const _CardLayout({
    required this.hole,
    required this.padding,
    required this.placement,
    required this.textDirection,
    required this.gap,
    required this.maxWidth,
    super.child,
  });

  final Rect? hole;
  final EdgeInsets padding;
  final CoachPlacement placement;
  final TextDirection textDirection;
  final double gap;
  final double maxWidth;

  @override
  _RenderCardLayout createRenderObject(BuildContext context) =>
      _RenderCardLayout()..update(this);

  @override
  void updateRenderObject(BuildContext context, _RenderCardLayout r) =>
      r.update(this);
}

class _RenderCardLayout extends RenderShiftedBox {
  _RenderCardLayout() : super(null);

  Rect? _hole;
  EdgeInsets _padding = EdgeInsets.zero;
  CoachPlacement _placement = CoachPlacement.auto;
  TextDirection _textDirection = TextDirection.ltr;
  double _gap = 12;
  double _maxWidth = 360;

  void update(_CardLayout w) {
    if (w.hole == _hole &&
        w.padding == _padding &&
        w.placement == _placement &&
        w.textDirection == _textDirection &&
        w.gap == _gap &&
        w.maxWidth == _maxWidth) {
      return;
    }
    _hole = w.hole;
    _padding = w.padding;
    _placement = w.placement;
    _textDirection = w.textDirection;
    _gap = w.gap;
    _maxWidth = w.maxWidth;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    size = constraints.biggest;
    final child = this.child;
    if (child == null) return;
    final bounds = _padding.deflateRect(Offset.zero & size);
    if (bounds.width <= 0 || bounds.height <= 0) {
      child.layout(BoxConstraints.tight(Size.zero));
      return;
    }
    final slot = placeCoachCard(
      hole: _hole,
      bounds: bounds,
      placement: _placement,
      textDirection: _textDirection,
      gap: _gap,
      maxWidth: _maxWidth,
      measureHeight: (width) {
        child.layout(
          BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: bounds.height,
          ),
          parentUsesSize: true,
        );
        return child.size.height;
      },
    );
    child.layout(
      BoxConstraints(
        minWidth: slot.rect.width,
        maxWidth: slot.rect.width,
        maxHeight: slot.rect.height,
      ),
      parentUsesSize: true,
    );
    (child.parentData! as BoxParentData).offset = slot.rect.topLeft;
  }
}
