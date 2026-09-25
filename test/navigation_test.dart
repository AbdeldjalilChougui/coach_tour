import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late List<GlobalKey> keys;
  late List<String> events;

  Future<CoachTourController> startTour(
    WidgetTester tester, {
    int count = 3,
    CoachTourOptions options = const CoachTourOptions(),
  }) async {
    keys = List.generate(count, (_) => GlobalKey());
    events = [];
    await pumpApp(
      tester,
      Stack(children: [
        for (var i = 0; i < count; i++)
          Placed(boxKey: keys[i], offset: Offset(20, 80.0 + i * 120)),
      ]),
    );
    final controller = CoachTour.start(
      appContext(tester),
      [
        for (var i = 0; i < count; i++)
          CoachTarget(key: keys[i], title: 'Title $i', body: 'Body $i'),
      ],
      options: options,
      onStepChanged: (i, t) => events.add('step:$i:${t.title}'),
      onFinish: () => events.add('finish'),
      onSkip: (i) => events.add('skip:$i'),
    );
    await settle(tester);
    return controller;
  }

  testWidgets('starts at the first step and shows its card', (tester) async {
    final c = await startTour(tester);
    expect(c.isActive, isTrue);
    expect(c.index, 0);
    expect(c.length, 3);
    expect(find.text('Title 0'), findsOneWidget);
    expect(find.text('Body 0'), findsOneWidget);
    expect(events, ['step:0:Title 0']);
    c.finish();
    await settle(tester);
  });

  testWidgets('Next buttons walk the tour and Done finishes it',
      (tester) async {
    final c = await startTour(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Title 1'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Title 2'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(events, [
      'step:0:Title 0',
      'step:1:Title 1',
      'step:2:Title 2',
      'finish',
    ]);
    expect(c.isActive, isFalse);
    expect(await c.result, CoachTourResult.finished);
    expect(find.byKey(CoachTour.cardKey), findsNothing);
  });

  testWidgets('Back returns to the previous step', (tester) async {
    final c = await startTour(tester);
    expect(find.text('Back'), findsNothing, reason: 'no back on step 0');
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Back'));
    await settle(tester);
    expect(c.index, 0);
    expect(events, ['step:0:Title 0', 'step:1:Title 1', 'step:0:Title 0']);
    c.finish();
    await settle(tester);
  });

  testWidgets('Skip button ends the tour with onSkip', (tester) async {
    final c = await startTour(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(events.last, 'skip:1');
    expect(events, isNot(contains('finish')));
    expect(await c.result, CoachTourResult.skipped);
  });

  testWidgets('controller next, previous, goTo, skip, finish', (tester) async {
    final c = await startTour(tester, count: 4);
    await c.goTo(3);
    await settle(tester);
    expect(c.index, 3);
    await c.previous();
    await settle(tester);
    expect(c.index, 2);
    await c.next();
    await settle(tester);
    expect(c.index, 3);
    expect(() => c.goTo(9), throwsRangeError);
    c.finish();
    await settle(tester);
    expect(events, [
      'step:0:Title 0',
      'step:3:Title 3',
      'step:2:Title 2',
      'step:3:Title 3',
      'finish',
    ]);
    // Calls after the end are ignored.
    c.skip();
    await c.next();
    expect(events.last, 'finish');
  });

  testWidgets('previous on the first step does nothing', (tester) async {
    final c = await startTour(tester);
    await c.previous();
    await settle(tester);
    expect(c.index, 0);
    expect(events, ['step:0:Title 0']);
    c.skip();
    await settle(tester);
  });

  testWidgets('centred steps show a card without a hole', (tester) async {
    await pumpApp(tester, const SizedBox.expand());
    final c = CoachTour.start(appContext(tester), const [
      CoachTarget.centered(title: 'Welcome', body: 'Hello'),
    ]);
    await settle(tester);
    expect(c.hole, isNull);
    expect(find.text('Welcome'), findsOneWidget);
    final card = cardRect(tester);
    expect((card.center.dx - 400).abs(), lessThan(1));
    c.finish();
    await settle(tester);
  });

  testWidgets('contentBuilder replaces the default card', (tester) async {
    final key = GlobalKey();
    await pumpApp(tester, Placed(boxKey: key, offset: const Offset(10, 10)));
    CoachStepDetails? seen;
    final c = CoachTour.start(appContext(tester), [
      CoachTarget(
        key: key,
        title: 'ignored',
        contentBuilder: (context, details) {
          seen = details;
          return TextButton(
            onPressed: details.controller.next,
            child: const Text('Custom'),
          );
        },
      ),
    ]);
    await settle(tester);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('ignored'), findsNothing);
    expect(seen!.index, 0);
    expect(seen!.total, 1);
    expect(seen!.isLast, isTrue);
    await tester.tap(find.text('Custom'));
    await settle(tester);
    expect(await c.result, CoachTourResult.finished);
  });

  testWidgets('targets found through the registry', (tester) async {
    final registry = CoachTourRegistry();
    await pumpApp(
      tester,
      CoachTourRegistryScope(
        registry: registry,
        child: Column(children: [
          const SizedBox(height: 50),
          CoachAnchor(
              id: 'search', child: const SizedBox(width: 200, height: 40)),
        ]),
      ),
    );
    final c = CoachTour.start(
      tester.element(find.byType(CoachAnchor)),
      const [CoachTarget(id: 'search', title: 'Search')],
    );
    await settle(tester);
    expect(c.hole!.outerRect.top, closeTo(50 - 8, 0.01));
    expect(registry.lookup('search'), isNotNull);
    c.finish();
    await settle(tester);
  });

  test('registry keys are stable and can be registered manually', () {
    final registry = CoachTourRegistry();
    expect(registry.keyFor('a'), same(registry.keyFor('a')));
    final key = GlobalKey();
    registry.register('b', key);
    expect(registry.lookup('b'), same(key));
    registry.unregister('b');
    expect(registry.lookup('b'), isNull);
  });
}
