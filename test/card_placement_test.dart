import 'dart:math';

import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _screens = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(390, 844),
  Size(430, 932),
  Size(844, 390),
  Size(768, 1024),
  Size(1024, 768),
  Size(1280, 800),
];

bool _overlaps(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 0.01 && i.height > 0.01;
}

bool _inside(Rect inner, Rect outer) =>
    inner.left >= outer.left - 0.01 &&
    inner.top >= outer.top - 0.01 &&
    inner.right <= outer.right + 0.01 &&
    inner.bottom <= outer.bottom + 0.01;

void main() {
  group('placeCoachCard (property)', () {
    test('never overlaps the hole and stays inside bounds', () {
      final random = Random(7);
      var cases = 0;
      for (final screen in _screens) {
        final bounds = (Offset.zero & screen).deflate(16);
        for (var i = 0; i < 400; i++) {
          final w = 16 + random.nextDouble() * screen.width * 0.5;
          final h = 16 + random.nextDouble() * screen.height * 0.4;
          final hole = Rect.fromLTWH(
            bounds.left + random.nextDouble() * (bounds.width - w),
            bounds.top + random.nextDouble() * (bounds.height - h),
            w,
            h,
          );
          final base = 60 + random.nextDouble() * 260;
          final placement = CoachPlacement
              .values[random.nextInt(CoachPlacement.values.length)];
          final dir = random.nextBool() ? TextDirection.ltr : TextDirection.rtl;
          final slot = placeCoachCard(
            hole: hole,
            bounds: bounds,
            measureHeight: (width) => base + 20000 / width,
            placement: placement,
            textDirection: dir,
          );
          cases++;
          final ctx = 'screen=$screen hole=$hole placement=$placement '
              'dir=$dir slot=${slot.rect}';
          expect(_overlaps(slot.rect, hole), isFalse, reason: ctx);
          expect(_inside(slot.rect, bounds), isTrue, reason: ctx);
          expect(slot.rect.height, greaterThan(0), reason: ctx);
        }
      }
      expect(cases, 3200);
    });

    test('flips below when there is no room above', () {
      const bounds = Rect.fromLTWH(0, 0, 400, 800);
      final slot = placeCoachCard(
        hole: const Rect.fromLTWH(100, 20, 100, 40),
        bounds: bounds,
        measureHeight: (_) => 200,
        placement: CoachPlacement.above,
      );
      expect(slot.side, CoachPlacement.below);
      expect(slot.rect.top, greaterThanOrEqualTo(60));
    });

    test('flips above when there is no room below', () {
      const bounds = Rect.fromLTWH(0, 0, 400, 800);
      final slot = placeCoachCard(
        hole: const Rect.fromLTWH(100, 700, 100, 40),
        bounds: bounds,
        measureHeight: (_) => 200,
        placement: CoachPlacement.below,
      );
      expect(slot.side, CoachPlacement.above);
      expect(slot.rect.bottom, lessThanOrEqualTo(700));
    });

    test('auto picks the roomier half', () {
      const bounds = Rect.fromLTWH(0, 0, 400, 800);
      expect(
        placeCoachCard(
          hole: const Rect.fromLTWH(10, 100, 50, 50),
          bounds: bounds,
          measureHeight: (_) => 150,
        ).side,
        CoachPlacement.below,
      );
      expect(
        placeCoachCard(
          hole: const Rect.fromLTWH(10, 600, 50, 50),
          bounds: bounds,
          measureHeight: (_) => 150,
        ).side,
        CoachPlacement.above,
      );
    });

    test('shrinks (and flags overflow) when nothing fits fully', () {
      const bounds = Rect.fromLTWH(0, 0, 300, 500);
      final slot = placeCoachCard(
        hole: const Rect.fromLTWH(0, 150, 300, 200),
        bounds: bounds,
        measureHeight: (_) => 400,
      );
      expect(slot.overflow, isTrue);
      expect(
          _overlaps(slot.rect, const Rect.fromLTWH(0, 150, 300, 200)), isFalse);
    });

    test('centres the card when there is no hole', () {
      const bounds = Rect.fromLTWH(0, 0, 400, 800);
      final slot = placeCoachCard(
        hole: null,
        bounds: bounds,
        measureHeight: (_) => 100,
      );
      expect(slot.rect.center, bounds.center);
    });
  });

  group('overlay card (property)', () {
    testWidgets('never covers the hole across positions and screen sizes',
        (tester) async {
      addTearDown(tester.view.reset);
      final random = Random(3);
      for (final screen in _screens) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = screen;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
        for (var i = 0; i < 6; i++) {
          final key = GlobalKey();
          final size = Size(
            24 + random.nextDouble() * screen.width * 0.4,
            24 + random.nextDouble() * 60,
          );
          final offset = Offset(
            random.nextDouble() * (screen.width - size.width),
            40 + random.nextDouble() * (screen.height - size.height - 70),
          );
          await pumpApp(
              tester, Placed(boxKey: key, offset: offset, size: size));
          final controller = CoachTour.start(
            appContext(tester),
            [
              CoachTarget(
                key: key,
                title: 'A reasonably long title',
                body: 'Body text that wraps over a couple of lines so the '
                    'card has a realistic height on a small phone.',
                placement: CoachPlacement
                    .values[random.nextInt(CoachPlacement.values.length)],
              ),
            ],
          );
          await settle(tester, frames: 12);
          final hole = controller.hole!.outerRect;
          final card = cardRect(tester);
          final safe = const EdgeInsets.only(top: 24, bottom: 16)
              .deflateRect(Offset.zero & screen);
          final ctx = 'screen=$screen target=${offset & size} card=$card';
          expect(_overlaps(card, hole), isFalse, reason: ctx);
          expect(_inside(card, safe), isTrue, reason: ctx);
          expect(tester.takeException(), isNull, reason: ctx);
          controller.finish();
          await settle(tester, frames: 8);
        }
      }
    });
  });
}
