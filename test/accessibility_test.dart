import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('each step is announced', (tester) async {
    final a = GlobalKey();
    final b = GlobalKey();
    await pumpApp(
      tester,
      Stack(children: [
        Placed(boxKey: a, offset: const Offset(20, 20)),
        Placed(boxKey: b, offset: const Offset(20, 300)),
      ]),
    );
    final c = CoachTour.start(appContext(tester), [
      CoachTarget(key: a, title: 'Search', body: 'Find anything.'),
      CoachTarget(key: b, title: 'Filters', body: 'Narrow it down.'),
    ]);
    await settle(tester);
    var said = tester.takeAnnouncements();
    expect(said.single.message, 'Step 1 of 2. Search. Find anything.');
    await c.next();
    await settle(tester);
    said = tester.takeAnnouncements();
    expect(said.single.message, 'Step 2 of 2. Filters. Narrow it down.');
    c.finish();
    await settle(tester);
  });

  testWidgets('announce: false stays quiet', (tester) async {
    final a = GlobalKey();
    await pumpApp(tester, Placed(boxKey: a, offset: const Offset(20, 20)));
    final c = CoachTour.start(
      appContext(tester),
      [CoachTarget(key: a, title: 'Search')],
      options: const CoachTourOptions(announce: false),
    );
    await settle(tester);
    expect(tester.takeAnnouncements(), isEmpty);
    c.finish();
    await settle(tester);
  });

  testWidgets('overlay is a modal route scope that hides the page',
      (tester) async {
    final handle = tester.ensureSemantics();
    final a = GlobalKey();
    await pumpApp(
      tester,
      Stack(children: [
        const Positioned(left: 300, top: 400, child: Text('Page text')),
        Placed(boxKey: a, offset: const Offset(20, 20)),
      ]),
    );
    expect(_liveLabels(tester), contains('Page text'));
    final c = CoachTour.start(
      appContext(tester),
      [CoachTarget(key: a, title: 'Search', body: 'Body')],
    );
    await settle(tester);

    expect(_liveLabels(tester), isNot(contains('Page text')));
    expect(_liveLabels(tester), contains('Search'));
    final card = tester.getSemantics(
      find
          .descendant(
            of: find.byKey(CoachTour.cardKey),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(card.label, contains('Step 1 of 1'));
    expect(
      find.ancestor(
        of: find.byKey(CoachTour.cardKey),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.scopesRoute ?? false),
        ),
      ),
      findsWidgets,
    );
    c.finish();
    await settle(tester);
    handle.dispose();
  });
}

/// Labels of the semantics tree a screen reader actually sees.
List<String> _liveLabels(WidgetTester tester) {
  final labels = <String>[];
  bool visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren(visit);
    return true;
  }

  final root = tester
      .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
  visit(root);
  return labels.expand((l) => l.split('\n')).toList();
}
