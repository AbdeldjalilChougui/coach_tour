import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const target = Rect.fromLTWH(40, 200, 120, 40);
  const padding = EdgeInsets.fromLTRB(4, 6, 8, 10);
  final padded = Rect.fromLTRB(36, 194, 168, 250);

  group('CoachTarget.holeFor', () {
    test('rect has square corners around the padded rect', () {
      final hole = CoachTarget(
        key: GlobalKey(),
        title: 't',
        shape: CoachShape.rect,
        padding: padding,
      ).holeFor(target);
      expect(hole,
          rrectMoreOrLessEquals(RRect.fromRectAndRadius(padded, Radius.zero)));
    });

    test('rrect uses the given radius', () {
      final hole = CoachTarget(
        key: GlobalKey(),
        title: 't',
        padding: padding,
        radius: 10,
      ).holeFor(target);
      expect(
        hole,
        rrectMoreOrLessEquals(
          RRect.fromRectAndRadius(padded, const Radius.circular(10)),
        ),
      );
    });

    test('rrect radius is clamped to half the short side', () {
      final hole = CoachTarget(
        key: GlobalKey(),
        title: 't',
        padding: padding,
        radius: 500,
      ).holeFor(target);
      expect(hole.tlRadiusX, closeTo(padded.height / 2, 0.01));
    });

    test('stadium rounds the short side fully', () {
      final hole = CoachTarget(
        key: GlobalKey(),
        title: 't',
        shape: CoachShape.stadium,
        padding: padding,
      ).holeFor(target);
      expect(
        hole,
        rrectMoreOrLessEquals(
          RRect.fromRectAndRadius(padded, Radius.circular(padded.height / 2)),
        ),
      );
    });

    test('circle is centred on the padded rect, diameter = long side', () {
      final hole = CoachTarget(
        key: GlobalKey(),
        title: 't',
        shape: CoachShape.circle,
        padding: padding,
      ).holeFor(target);
      final d = padded.width;
      expect(
        hole,
        rrectMoreOrLessEquals(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: padded.center, width: d, height: d),
            Radius.circular(d / 2),
          ),
        ),
      );
    });

    test('directional padding follows the text direction', () {
      final t = CoachTarget(
        key: GlobalKey(),
        title: 't',
        shape: CoachShape.rect,
        padding: const EdgeInsetsDirectional.only(start: 20),
      );
      expect(t.holeFor(target).left, 20);
      expect(
        t.holeFor(target, textDirection: TextDirection.rtl).right,
        target.right + 20,
      );
    });
  });

  group('overlay hole', () {
    for (final shape in CoachShape.values) {
      testWidgets('matches target rect plus padding for $shape',
          (tester) async {
        final key = GlobalKey();
        await pumpApp(
          tester,
          Placed(
            boxKey: key,
            offset: const Offset(60, 120),
            size: const Size(140, 48),
          ),
        );
        final step = CoachTarget(
          key: key,
          title: 'Title',
          body: 'Body',
          shape: shape,
          padding: const EdgeInsets.all(6),
          radius: 14,
        );
        final controller = CoachTour.start(appContext(tester), [step]);
        await settle(tester);

        final rect = tester.getRect(find.byKey(key));
        expect(controller.hole, rrectMoreOrLessEquals(step.holeFor(rect)));
        expect(controller.displayedHole,
            rrectMoreOrLessEquals(step.holeFor(rect)));
        controller.finish();
        await settle(tester);
      });
    }

    testWidgets('morphs between targets, including a change of shape',
        (tester) async {
      final a = GlobalKey();
      final b = GlobalKey();
      await pumpApp(
        tester,
        Stack(children: [
          Placed(boxKey: a, offset: const Offset(20, 100)),
          Placed(
            boxKey: b,
            offset: const Offset(200, 400),
            size: const Size(56, 56),
          ),
        ]),
      );
      final steps = [
        CoachTarget(key: a, title: 'A', shape: CoachShape.rect),
        CoachTarget(key: b, title: 'B', shape: CoachShape.circle),
      ];
      final controller = CoachTour.start(appContext(tester), steps);
      await settle(tester);
      final start = controller.displayedHole!;

      controller.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final mid = controller.displayedHole!;
      final end = steps[1].holeFor(tester.getRect(find.byKey(b)));
      expect(mid.center, isNot(start.center));
      expect(mid.center, isNot(end.center));
      expect(mid.tlRadiusX, greaterThan(0));
      expect(mid.tlRadiusX, lessThan(end.tlRadiusX));

      await settle(tester);
      expect(controller.displayedHole, rrectMoreOrLessEquals(end));
      controller.finish();
      await settle(tester);
    });
  });
}
