import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late GlobalKey a;
  late GlobalKey b;

  Future<CoachTourController> startTour(
    WidgetTester tester, {
    bool disableAnimations = false,
    CoachTourOptions options = const CoachTourOptions(),
  }) async {
    a = GlobalKey();
    b = GlobalKey();
    await pumpApp(
      tester,
      Stack(children: [
        Placed(boxKey: a, offset: const Offset(20, 60)),
        Placed(boxKey: b, offset: const Offset(300, 420)),
      ]),
      disableAnimations: disableAnimations,
    );
    final c = CoachTour.start(
      appContext(tester),
      [
        CoachTarget(key: a, title: 'A', shape: CoachShape.rect),
        CoachTarget(key: b, title: 'B', shape: CoachShape.circle),
      ],
      options: options,
    );
    await settle(tester);
    return c;
  }

  testWidgets('breathing ring keeps animating by default', (tester) async {
    final c = await startTour(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    c.finish();
    await settle(tester);
  });

  testWidgets('breathingRing: false leaves the overlay idle', (tester) async {
    final c = await startTour(
      tester,
      options: const CoachTourOptions(breathingRing: false),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    c.finish();
    await settle(tester);
  });

  Future<void> expectReduced(
    WidgetTester tester,
    CoachTourController c,
  ) async {
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse, reason: 'no pulse');

    await c.next();
    await tester.pump();
    final end = c.current!.holeFor(tester.getRect(find.byKey(b)));
    expect(c.displayedHole, rrectMoreOrLessEquals(end), reason: 'no morph');
    c.finish();
    await settle(tester);
  }

  testWidgets('MediaQuery.disableAnimations turns off pulse and morph',
      (tester) async {
    final c = await startTour(tester, disableAnimations: true);
    await expectReduced(tester, c);
  });

  testWidgets('options.reduceMotion forces reduced motion', (tester) async {
    final c = await startTour(
      tester,
      options: const CoachTourOptions(reduceMotion: true),
    );
    await expectReduced(tester, c);
  });

  testWidgets('without reduced motion the hole morphs over several frames',
      (tester) async {
    final c = await startTour(tester);
    await c.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final end = c.current!.holeFor(tester.getRect(find.byKey(b)));
    expect(c.displayedHole!.center, isNot(end.center));
    c.finish();
    await settle(tester);
  });
}
