import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [body] inside a MaterialApp scaffold.
Future<void> pumpApp(
  WidgetTester tester,
  Widget body, {
  Locale? locale,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(body: body),
    ),
  );
}

/// The context tours are started from.
BuildContext appContext(WidgetTester tester) =>
    tester.element(find.byType(Scaffold));

/// Pumps fixed frames: long enough for scrolls, morphs and route
/// transitions, and safe to use while the breathing ring repeats forever.
Future<void> settle(WidgetTester tester, {int frames = 25}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The on-screen rect of the card.
Rect cardRect(WidgetTester tester) =>
    tester.getRect(find.byKey(CoachTour.cardKey));

/// A box placed at an absolute position.
class Placed extends StatelessWidget {
  /// Creates a box of [size] at [offset], keyed with [boxKey].
  const Placed({
    required this.boxKey,
    required this.offset,
    this.size = const Size(100, 40),
    super.key,
  });

  /// Key of the placed box.
  final GlobalKey boxKey;

  /// Top-left corner.
  final Offset offset;

  /// Box size.
  final Size size;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned(
            left: offset.dx,
            top: offset.dy,
            child: SizedBox.fromSize(key: boxKey, size: size),
          ),
        ],
      );
}

/// Tolerant equality for rounded rects.
Matcher rrectMoreOrLessEquals(RRect expected) => predicate<RRect?>(
      (actual) =>
          actual != null &&
          (actual.left - expected.left).abs() < 0.01 &&
          (actual.top - expected.top).abs() < 0.01 &&
          (actual.right - expected.right).abs() < 0.01 &&
          (actual.bottom - expected.bottom).abs() < 0.01 &&
          (actual.tlRadiusX - expected.tlRadiusX).abs() < 0.01 &&
          (actual.brRadiusY - expected.brRadiusY).abs() < 0.01,
      'RRect close to $expected',
    );
