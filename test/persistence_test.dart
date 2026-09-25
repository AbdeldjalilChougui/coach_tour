import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('MemoryCoachTourStore', () {
    test('hasSeen, markSeen, reset', () async {
      final store = MemoryCoachTourStore();
      expect(await store.hasSeen('home'), isFalse);
      await store.markSeen('home');
      expect(await store.hasSeen('home'), isTrue);
      expect(await store.hasSeen('other'), isFalse);
      await store.reset('home');
      expect(await store.hasSeen('home'), isFalse);
    });
  });

  late GlobalKey key;
  Future<void> pump(WidgetTester tester) async {
    key = GlobalKey();
    await pumpApp(tester, Placed(boxKey: key, offset: const Offset(20, 20)));
  }

  testWidgets('startOnce runs once and marks the tour seen when finished',
      (tester) async {
    await pump(tester);
    final store = MemoryCoachTourStore();
    final c = await CoachTour.startOnce(
      appContext(tester),
      tourId: 'home',
      store: store,
      steps: [CoachTarget(key: key, title: 'T')],
    );
    expect(c, isNotNull);
    await settle(tester);
    expect(await store.hasSeen('home'), isFalse, reason: 'not yet done');
    c!.finish();
    await settle(tester);
    expect(await store.hasSeen('home'), isTrue);

    final again = await CoachTour.startOnce(
      appContext(tester),
      tourId: 'home',
      store: store,
      steps: [CoachTarget(key: key, title: 'T')],
    );
    await settle(tester);
    expect(again, isNull);
    expect(find.byKey(CoachTour.cardKey), findsNothing);
  });

  testWidgets('skipping marks seen unless markSeenOnSkip is false',
      (tester) async {
    await pump(tester);
    final store = MemoryCoachTourStore();
    final c = await CoachTour.startOnce(
      appContext(tester),
      tourId: 'a',
      store: store,
      steps: [CoachTarget(key: key, title: 'T')],
      markSeenOnSkip: false,
    );
    await settle(tester);
    c!.skip();
    await settle(tester);
    expect(await store.hasSeen('a'), isFalse);

    final d = await CoachTour.startOnce(
      appContext(tester),
      tourId: 'a',
      store: store,
      steps: [CoachTarget(key: key, title: 'T')],
    );
    await settle(tester);
    d!.skip();
    await settle(tester);
    expect(await store.hasSeen('a'), isTrue);
  });

  testWidgets('a tour with nothing to show is not marked seen', (tester) async {
    await pump(tester);
    final store = MemoryCoachTourStore();
    final c = await CoachTour.startOnce(
      appContext(tester),
      tourId: 'x',
      store: store,
      steps: [CoachTarget(key: GlobalKey(), title: 'unmounted')],
    );
    await settle(tester);
    expect(await c!.result, CoachTourResult.nothingToShow);
    expect(await store.hasSeen('x'), isFalse);
  });

  testWidgets('works with a custom store implementation', (tester) async {
    await pump(tester);
    final store = _MapStore();
    final c = await CoachTour.startOnce(
      appContext(tester),
      tourId: 'custom',
      store: store,
      steps: [CoachTarget(key: key, title: 'T')],
    );
    await settle(tester);
    c!.finish();
    await settle(tester);
    expect(store.values['coach_tour.custom'], isTrue);
  });
}

class _MapStore implements CoachTourStore {
  final Map<String, bool> values = {};

  @override
  Future<bool> hasSeen(String tourId) async =>
      values['coach_tour.$tourId'] ?? false;

  @override
  Future<void> markSeen(String tourId) async =>
      values['coach_tour.$tourId'] = true;

  @override
  Future<void> reset(String tourId) async =>
      values.remove('coach_tour.$tourId');
}
