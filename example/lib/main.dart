import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() => runApp(const DemoApp());

/// Demo app for coach_tour.
class DemoApp extends StatefulWidget {
  /// Creates the demo app.
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'coach_tour demo',
        locale: _locale,
        supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: HomePage(
          locale: _locale,
          onLocale: (l) => setState(() => _locale = l),
        ),
      );
}

/// Screen with a few targets spread around, including one far down a list.
class HomePage extends StatefulWidget {
  /// Creates the page.
  const HomePage({required this.locale, required this.onLocale, super.key});

  /// Current locale.
  final Locale locale;

  /// Changes the locale.
  final ValueChanged<Locale> onLocale;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Kept for the whole app session; swap for a shared_preferences-backed
  // store to remember across launches (see the README).
  static final CoachTourStore _store = MemoryCoachTourStore();

  final _search = GlobalKey();
  final _fab = GlobalKey();
  final _deep = GlobalKey();
  final _language = GlobalKey();
  bool _passThrough = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachTour.startOnce(
        context,
        tourId: 'home',
        store: _store,
        steps: _steps(),
      );
    });
  }

  List<CoachTarget> _steps() => [
        const CoachTarget.centered(
          title: 'Welcome',
          body: 'A 30-second tour of this screen. Tap anywhere to continue.',
        ),
        CoachTarget(
          key: _search,
          title: 'Search',
          body: 'Find anything by name. The hole morphs from one target to '
              'the next.',
          shape: CoachShape.stadium,
        ),
        CoachTarget(
          key: _language,
          title: 'Language',
          body: 'Buttons are translated in English, French and Arabic, and '
              'the layout flips in right-to-left.',
          shape: CoachShape.circle,
          padding: const EdgeInsets.all(4),
        ),
        CoachTarget(
          key: _deep,
          title: 'Scrolled into view',
          body: 'This row was off screen. The tour scrolled to it first.',
          radius: 16,
        ),
        CoachTarget(
          key: _fab,
          title: 'Add',
          body: 'The card flips above targets near the bottom.',
          shape: CoachShape.circle,
          contentBuilder: (context, details) => CoachTourCard(
            details: details,
            child: const Text('Custom content can sit inside the card.'),
          ),
        ),
      ];

  void _replay() {
    CoachTour.start(
      context,
      _steps(),
      options: CoachTourOptions(
        holeTap: _passThrough ? CoachHoleTap.passThrough : CoachHoleTap.block,
        backAction: CoachBackAction.previous,
      ),
      onTargetSkipped: (s) => debugPrint('Skipped $s'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final next = switch (widget.locale.languageCode) {
      'en' => const Locale('fr'),
      'fr' => const Locale('ar'),
      _ => const Locale('en'),
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('coach_tour'),
        actions: [
          IconButton(
            key: _language,
            tooltip: 'Switch language',
            icon: const Icon(Icons.translate),
            onPressed: () => widget.onLocale(next),
          ),
          IconButton(
            tooltip: 'Replay tour',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _replay,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchBar(
              key: _search,
              hintText: 'Search',
              leading: const Icon(Icons.search),
            ),
            SwitchListTile(
              title: const Text('Taps in the hole reach the target'),
              value: _passThrough,
              onChanged: (v) => setState(() => _passThrough = v),
            ),
            for (var i = 0; i < 30; i++)
              Card(
                key: i == 24 ? _deep : null,
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('Item ${i + 1}'),
                  subtitle: const Text('A row in a long list'),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: _fab,
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
