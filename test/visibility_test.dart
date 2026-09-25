import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('scrolls an off-screen target into view before highlighting',
      (tester) async {
    final key = GlobalKey();
    final scroll = ScrollController();
    await pumpApp(
      tester,
      // Not a lazy ListView: an item that was never built has no context
      // to scroll to (see Limitations in the README).
      SingleChildScrollView(
        controller: scroll,
        child: Column(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(
                key: i == 30 ? key : null,
                height: 60,
                child: Text('Row $i'),
              ),
          ],
        ),
      ),
    );
    expect(tester.getRect(find.byKey(key)).top, greaterThan(600));

    final c = CoachTour.start(appContext(tester), [
      CoachTarget(key: key, title: 'Row thirty'),
    ]);
    await settle(tester);

    expect(scroll.offset, greaterThan(0));
    final rect = tester.getRect(find.byKey(key));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(600));
    expect(c.index, 0);
    expect(c.hole!.outerRect.center.dy, closeTo(rect.center.dy, 0.01));
    expect(find.text('Row thirty'), findsOneWidget);
    c.finish();
    await settle(tester);
  });

  testWidgets('does not scroll when the target is already visible',
      (tester) async {
    final key = GlobalKey();
    final scroll = ScrollController();
    await pumpApp(
      tester,
      ListView(
        controller: scroll,
        children: [
          for (var i = 0; i < 40; i++)
            SizedBox(key: i == 2 ? key : null, height: 60),
        ],
      ),
    );
    final c = CoachTour.start(appContext(tester), [
      CoachTarget(key: key, title: 'Visible'),
    ]);
    await settle(tester);
    expect(scroll.offset, 0);
    c.finish();
    await settle(tester);
  });

  testWidgets('skips an unmounted target and reports it', (tester) async {
    final mounted = GlobalKey();
    final missing = GlobalKey();
    final skipped = <CoachSkippedTarget>[];
    final steps = <int>[];
    await pumpApp(
        tester, Placed(boxKey: mounted, offset: const Offset(10, 10)));
    final c = CoachTour.start(
      appContext(tester),
      [
        CoachTarget(key: missing, title: 'Missing'),
        CoachTarget(key: mounted, title: 'Here'),
        const CoachTarget(id: 'nobody-registered-this', title: 'Nope'),
      ],
      onStepChanged: (i, _) => steps.add(i),
      onTargetSkipped: skipped.add,
    );
    await settle(tester);
    expect(c.index, 1);
    expect(find.text('Here'), findsOneWidget);
    expect(steps, [1]);
    expect(skipped.single.index, 0);
    expect(skipped.single.reason, CoachSkipReason.unmounted);

    await c.next();
    await settle(tester);
    expect(skipped.map((s) => s.index), [0, 2]);
    expect(await c.result, CoachTourResult.finished);
    expect(c.skipped.length, 2);
  });

  testWidgets('skips a target that cannot be made visible', (tester) async {
    final off = GlobalKey();
    final on = GlobalKey();
    final skipped = <CoachSkippedTarget>[];
    await pumpApp(
      tester,
      Stack(children: [
        Placed(boxKey: off, offset: const Offset(-900, 100)),
        Placed(boxKey: on, offset: const Offset(100, 100)),
      ]),
    );
    final c = CoachTour.start(
      appContext(tester),
      [
        CoachTarget(key: off, title: 'Off'),
        CoachTarget(key: on, title: 'On'),
      ],
      onTargetSkipped: skipped.add,
    );
    await settle(tester);
    expect(c.index, 1);
    expect(skipped.single.reason, CoachSkipReason.notVisible);
    c.finish();
    await settle(tester);
  });

  testWidgets('a tour with nothing to show ends without onFinish',
      (tester) async {
    await pumpApp(tester, const SizedBox());
    var finished = false;
    final c = CoachTour.start(
      appContext(tester),
      [CoachTarget(key: GlobalKey(), title: 'Gone')],
      onFinish: () => finished = true,
    );
    await settle(tester);
    expect(await c.result, CoachTourResult.nothingToShow);
    expect(finished, isFalse);
    expect(find.byKey(CoachTour.cardKey), findsNothing);
  });

  testWidgets('re-measures after rotation / resize', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    final key = GlobalKey();
    await pumpApp(
      tester,
      Align(
        alignment: Alignment.centerRight,
        child: SizedBox(key: key, width: 80, height: 40),
      ),
    );
    final c = CoachTour.start(appContext(tester), [
      CoachTarget(key: key, title: 'Right edge', shape: CoachShape.rect),
    ]);
    await settle(tester);
    expect(c.hole!.outerRect.right, closeTo(400 + 8, 0.01));

    tester.view.physicalSize = const Size(800, 400);
    await settle(tester);
    final rect = tester.getRect(find.byKey(key));
    expect(rect.right, 800);
    expect(
      c.hole,
      rrectMoreOrLessEquals(c.current!.holeFor(rect)),
    );
    expect(c.displayedHole, rrectMoreOrLessEquals(c.hole!));
    final card = cardRect(tester);
    expect(card.intersect(c.hole!.outerRect).isEmpty, isTrue);
    c.finish();
    await settle(tester);
  });
}
