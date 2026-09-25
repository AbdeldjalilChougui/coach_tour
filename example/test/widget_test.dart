import 'package:coach_tour/coach_tour.dart';
import 'package:coach_tour_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the tour starts on launch and can be walked to the end',
      (tester) async {
    await tester.pumpWidget(const DemoApp());
    Future<void> settle() async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await settle();
    expect(find.text('Welcome'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await settle();
    }
    expect(find.text('Scrolled into view'), findsNothing);
    await tester.tap(find.text('Done'));
    await settle();
    expect(find.byKey(CoachTour.cardKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
