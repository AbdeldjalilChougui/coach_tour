import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late GlobalKey a;
  late GlobalKey b;
  late int targetTaps;
  late List<String> events;

  Future<CoachTourController> startTour(
    WidgetTester tester,
    CoachTourOptions options,
  ) async {
    a = GlobalKey();
    b = GlobalKey();
    targetTaps = 0;
    events = [];
    await pumpApp(
      tester,
      Stack(children: [
        Positioned(
          left: 40,
          top: 60,
          child: ElevatedButton(
            key: a,
            onPressed: () => targetTaps++,
            child: const Text('Target A'),
          ),
        ),
        Placed(boxKey: b, offset: const Offset(40, 300)),
      ]),
    );
    final c = CoachTour.start(
      appContext(tester),
      [
        CoachTarget(key: a, title: 'A'),
        CoachTarget(key: b, title: 'B'),
      ],
      options: options,
      onFinish: () => events.add('finish'),
      onSkip: (i) => events.add('skip:$i'),
    );
    await settle(tester);
    return c;
  }

  // Bottom-right corner: outside the hole and far from the card.
  const barrierPoint = Offset(790, 590);

  group('barrier', () {
    testWidgets('next (default) advances', (tester) async {
      final c = await startTour(tester, const CoachTourOptions());
      await tester.tapAt(barrierPoint);
      await settle(tester);
      expect(c.index, 1);
      c.finish();
      await settle(tester);
    });

    testWidgets('dismiss skips the tour', (tester) async {
      final c = await startTour(
        tester,
        const CoachTourOptions(barrierAction: CoachBarrierAction.dismiss),
      );
      await tester.tapAt(barrierPoint);
      await settle(tester);
      expect(events, ['skip:0']);
      expect(c.isActive, isFalse);
    });

    testWidgets('none ignores the tap and blocks the page', (tester) async {
      var pageTaps = 0;
      final key = GlobalKey();
      await pumpApp(
        tester,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => pageTaps++,
          child: Placed(boxKey: key, offset: const Offset(10, 10)),
        ),
      );
      final c = CoachTour.start(
        appContext(tester),
        [CoachTarget(key: key, title: 'T')],
        options: const CoachTourOptions(barrierAction: CoachBarrierAction.none),
      );
      await settle(tester);
      await tester.tapAt(barrierPoint);
      await settle(tester);
      expect(c.isActive, isTrue);
      expect(c.index, 0);
      expect(pageTaps, 0);
      c.finish();
      await settle(tester);
    });
  });

  group('hole', () {
    testWidgets('blocks taps by default', (tester) async {
      final c = await startTour(tester, const CoachTourOptions());
      await tester.tap(find.text('Target A'), warnIfMissed: false);
      await settle(tester);
      expect(targetTaps, 0);
      expect(c.index, 0, reason: 'a blocked hole tap is not a barrier tap');
      c.finish();
      await settle(tester);
    });

    testWidgets('passThrough forwards the tap to the target', (tester) async {
      final c = await startTour(
        tester,
        const CoachTourOptions(holeTap: CoachHoleTap.passThrough),
      );
      await tester.tap(find.text('Target A'));
      await settle(tester);
      expect(targetTaps, 1);
      expect(c.index, 0);
      c.finish();
      await settle(tester);
    });
  });

  group('back', () {
    testWidgets('skip (default) ends the tour', (tester) async {
      final c = await startTour(tester, const CoachTourOptions());
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(events, ['skip:0']);
      expect(c.isActive, isFalse);
      expect(find.byType(Scaffold), findsOneWidget, reason: 'page kept');
    });

    testWidgets('previous steps back, then skips on the first step',
        (tester) async {
      final c = await startTour(
        tester,
        const CoachTourOptions(backAction: CoachBackAction.previous),
      );
      await c.next();
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(c.index, 0);
      expect(c.isActive, isTrue);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(events, ['skip:0']);
    });

    testWidgets('ignore keeps the tour open', (tester) async {
      final c = await startTour(
        tester,
        const CoachTourOptions(backAction: CoachBackAction.ignore),
      );
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(c.isActive, isTrue);
      expect(events, isEmpty);
      c.finish();
      await settle(tester);
    });
  });

  testWidgets('Escape skips the tour', (tester) async {
    final c = await startTour(tester, const CoachTourOptions());
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(events, ['skip:0']);
    expect(c.isActive, isFalse);
  });

  testWidgets('focus moves to the card', (tester) async {
    final c = await startTour(tester, const CoachTourOptions());
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byKey(CoachTour.cardKey),
        matching: find.byWidget(focused.widget),
      ),
      findsOneWidget,
    );
    c.finish();
    await settle(tester);
  });
}
