import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('default labels for en, fr and ar, English fallback', () {
    expect(CoachTourLabels.forLocale(const Locale('en')).next, 'Next');
    final fr = CoachTourLabels.forLocale(const Locale('fr', 'CA'));
    expect([fr.next, fr.back, fr.skip, fr.done],
        ['Suivant', 'Précédent', 'Passer', 'Terminé']);
    expect(fr.stepOf(2, 5), 'Étape 2 sur 5');
    final ar = CoachTourLabels.forLocale(const Locale('ar'));
    expect([ar.next, ar.back, ar.skip, ar.done],
        ['التالي', 'السابق', 'تخطي', 'تم']);
    expect(CoachTourLabels.forLocale(const Locale('de')).done, 'Done');
    expect(CoachTourLabels.forLocale(null).skip, 'Skip');
  });

  test('copyWith overrides single labels', () {
    final l = CoachTourLabels.en.copyWith(done: 'Got it');
    expect(l.done, 'Got it');
    expect(l.next, 'Next');
  });

  Future<CoachTourController> startTour(
    WidgetTester tester, {
    Locale? locale,
    CoachTourOptions options = const CoachTourOptions(),
    CoachPlacement placement = CoachPlacement.auto,
  }) async {
    final a = GlobalKey();
    final b = GlobalKey();
    await pumpApp(
      tester,
      Stack(children: [
        Placed(
            boxKey: a,
            offset: const Offset(400, 260),
            size: const Size(80, 40)),
        Placed(
            boxKey: b,
            offset: const Offset(400, 400),
            size: const Size(80, 40)),
      ]),
      locale: locale,
    );
    final c = CoachTour.start(
      appContext(tester),
      [
        CoachTarget(key: a, title: 'A', placement: placement),
        CoachTarget(key: b, title: 'B', placement: placement),
      ],
      options: options,
    );
    await settle(tester);
    return c;
  }

  testWidgets('buttons follow the app locale (fr)', (tester) async {
    final c = await startTour(tester, locale: const Locale('fr'));
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    await c.next();
    await settle(tester);
    expect(find.text('Précédent'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
    c.finish();
    await settle(tester);
  });

  testWidgets('labels option overrides the defaults', (tester) async {
    final c = await startTour(
      tester,
      locale: const Locale('ar'),
      options: const CoachTourOptions(
        labels: CoachTourLabels(
          next: 'Go',
          back: 'Prev',
          skip: 'Later',
          done: 'Finish',
        ),
      ),
    );
    expect(find.text('Go'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    c.finish();
    await settle(tester);
  });

  testWidgets('placement start is on the left in LTR', (tester) async {
    final c = await startTour(tester, placement: CoachPlacement.start);
    final card = cardRect(tester);
    expect(card.right, lessThanOrEqualTo(c.hole!.outerRect.left));
    c.finish();
    await settle(tester);
  });

  testWidgets('RTL: start is on the right and end on the left', (tester) async {
    var c = await startTour(
      tester,
      locale: const Locale('ar'),
      placement: CoachPlacement.start,
    );
    expect(find.text('التالي'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('التالي'))),
        TextDirection.rtl);
    expect(
        cardRect(tester).left, greaterThanOrEqualTo(c.hole!.outerRect.right));
    c.finish();
    await settle(tester);

    c = await startTour(
      tester,
      locale: const Locale('ar'),
      placement: CoachPlacement.end,
    );
    expect(cardRect(tester).right, lessThanOrEqualTo(c.hole!.outerRect.left));
    c.finish();
    await settle(tester);
  });

  testWidgets('RTL: the primary button sits on the left of the card',
      (tester) async {
    final c = await startTour(tester, locale: const Locale('ar'));
    final card = cardRect(tester);
    final next = tester.getRect(find.text('التالي'));
    expect(next.center.dx, lessThan(card.center.dx));
    c.finish();
    await settle(tester);
  });
}
