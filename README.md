# coach_tour

Spotlight onboarding tours for Flutter. The hole morphs smoothly from one target to the next, a ring breathes around it, and the card places itself so it never covers what it is explaining.

[![pub package](https://img.shields.io/pub/v/coach_tour.svg)](https://pub.dev/packages/coach_tour)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- **Targets** by `GlobalKey`, or by id through a `CoachTourRegistry` so steps can be declared in one place while the widgets live anywhere in the tree.
- **Shapes**: `rect`, `rrect`, `circle` and `stadium`, with per-step padding and radius. The hole morphs between targets, shape included (a rectangle can become a circle).
- **Breathing ring** around the hole (optional).
- **Card auto-placement** above, below, start or end. It never covers the hole, stays inside the SafeArea and flips to the other side when there is no room. When no side has room for the whole card, it is shortened and scrolls.
- **Scroll into view**: off-screen targets are brought on screen with `Scrollable.ensureVisible` first. Targets that are unmounted or cannot be made visible are skipped and reported (`onTargetSkipped`).
- **Rotation and resize**: the target is re-measured whenever window metrics change.
- **Controller**: `next`, `previous`, `goTo`, `skip`, `finish`, plus `onStepChanged`, `onFinish` and `onSkip` callbacks and a `result` future.
- **Configurable input**: taps in the hole are blocked or pass through to the target. Taps on the dimmed barrier go to the next step, dismiss the tour or do nothing. The back button and predictive back skip the tour, go back one step or are ignored (via `PopScope`).
- **Show once**: `CoachTour.startOnce` with a pluggable `CoachTourStore` (`hasSeen` / `markSeen`). There is no storage dependency.
- **Localized buttons** (Next, Back, Skip, Done) in English, French and Arabic, all overridable. RTL layouts are supported: `start` and `end` placements, directional padding and the button order follow the text direction.
- **Accessibility**: the overlay is a modal route scope that hides the page from screen readers. Focus moves to the card, each step is announced ("Step 2 of 5. Title. Body."), and Escape skips the tour.
- **Reduced motion** (`MediaQueryData.disableAnimations`, or `reduceMotion: true`) turns off the pulse, the morph and animated scrolling.

## Install

```yaml
dependencies:
  coach_tour: ^0.1.0
```

## Usage

```dart
import 'package:coach_tour/coach_tour.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = GlobalKey();
  final _add = GlobalKey();

  void _startTour() {
    final controller = CoachTour.start(
      context,
      [
        const CoachTarget.centered(title: 'Welcome', body: 'A quick tour.'),
        CoachTarget(
          key: _search,
          title: 'Search',
          body: 'Find anything by name.',
          shape: CoachShape.stadium,
        ),
        CoachTarget(
          key: _add,
          title: 'Add',
          body: 'Create a new item.',
          shape: CoachShape.circle,
          placement: CoachPlacement.above,
        ),
      ],
      options: const CoachTourOptions(
        barrierAction: CoachBarrierAction.next,
        holeTap: CoachHoleTap.block,
        backAction: CoachBackAction.previous,
      ),
      onStepChanged: (index, target) => debugPrint('step $index'),
      onFinish: () => debugPrint('finished'),
      onSkip: (index) => debugPrint('skipped at $index'),
      onTargetSkipped: (s) => debugPrint('could not show ${s.index}: ${s.reason}'),
    );
    controller.result.then((r) => debugPrint('result: $r'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: SearchBar(key: _search, hintText: 'Search'),
          actions: [
            IconButton(onPressed: _startTour, icon: const Icon(Icons.help)),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          key: _add,
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      );
}
```

### Targets registered by id

```dart
final registry = CoachTourRegistry();

// High in the tree:
CoachTourRegistryScope(registry: registry, child: const MyApp());

// Anywhere below it:
CoachAnchor(id: 'profile.avatar', child: const CircleAvatar());

// Where the tour is declared:
CoachTour.start(context, const [
  CoachTarget(id: 'profile.avatar', title: 'Your profile'),
]);
```

Without a scope, `CoachAnchor` and `CoachTour.start` share `CoachTourRegistry.global`. Each id can be mounted only once at a time.

### Custom card content

```dart
CoachTarget(
  key: key,
  title: 'Filters',
  contentBuilder: (context, details) => CoachTourCard(
    details: details,
    child: Image.asset('assets/filters.gif'),
  ),
);
```

Return any widget from `contentBuilder` to replace the card entirely, and drive the tour through `details.controller`.

### Showing a tour once (persistence)

`CoachTour.startOnce` asks a `CoachTourStore` whether the tour was seen. It marks the tour seen when it finishes, and when it is skipped unless `markSeenOnSkip: false`. A tour that had nothing to show is not marked, so it tries again next time. The package ships `MemoryCoachTourStore`. For real persistence, implement the interface over your storage. Here it is with `shared_preferences`, which you add to your own app:

```dart
import 'package:coach_tour/coach_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsCoachTourStore implements CoachTourStore {
  PrefsCoachTourStore(this.prefs);

  final SharedPreferencesAsync prefs;

  String _key(String id) => 'coach_tour.seen.$id';

  @override
  Future<bool> hasSeen(String tourId) async =>
      await prefs.getBool(_key(tourId)) ?? false;

  @override
  Future<void> markSeen(String tourId) => prefs.setBool(_key(tourId), true);

  @override
  Future<void> reset(String tourId) => prefs.remove(_key(tourId));
}

// After the first frame of the screen:
await CoachTour.startOnce(
  context,
  tourId: 'home.v1',
  store: PrefsCoachTourStore(SharedPreferencesAsync()),
  steps: steps,
);
```

Bump the id (`home.v2`) when the tour changes enough to show it again.

### Labels

Button texts follow the app locale (`en`, `fr`, `ar`, with English as the fallback). Override them with `CoachTourOptions(labels: CoachTourLabels.fr.copyWith(done: "C'est parti"))` or with a full `CoachTourLabels(...)`.

### Options

| Option | Default | Meaning |
| --- | --- | --- |
| `barrierAction` | `next` | Tap outside the hole: `next`, `dismiss`, `none` |
| `holeTap` | `block` | Tap inside the hole: `block`, `passThrough` |
| `backAction` | `skip` | Back / predictive back: `skip`, `previous`, `ignore` |
| `breathingRing` | `true` | Pulsing ring around the hole |
| `reduceMotion` | `null` | Force reduced motion on or off; `null` follows the platform |
| `scrollIntoView` | `true` | Scroll targets on screen before highlighting |
| `morphDuration`, `morphCurve`, `scrollDuration` | 450 ms, easeInOutCubic, 300 ms | Motion |
| `scrimColor`, `ringColor` | dark scrim, theme primary | Colors |
| `showBackButton`, `showSkipButton`, `showProgress` | `true` | Default card parts |
| `announce` | `true` | Announce each step to screen readers |
| `cardMaxWidth`, `cardGap`, `margin` | 360, 12, 16 | Card geometry |

## Coming from tutorial_coach_mark / showcaseview

| tutorial_coach_mark | showcaseview | coach_tour |
| --- | --- | --- |
| `TargetFocus(keyTarget: key, contents: [...])` | `Showcase(key: key, title:, description:, child:)` | `CoachTarget(key: key, title:, body:)` |
| `ShapeLightFocus.Circle` / `RRect` | `targetShapeBorder:` | `shape: CoachShape.circle / rrect / rect / stadium` |
| `paddingFocus` | `targetPadding` | `padding` |
| `ContentAlign.top` / `bottom` / `left` / `right` | `tooltipPosition` | `placement: above / below / start / end / auto` |
| `TutorialCoachMark(...).show(context: context)` | `ShowCaseWidget.of(context).startShowCase([...])` | `CoachTour.start(context, steps)` |
| `next()` / `previous()` / `skip()` | `next()` / `previous()` / `dismiss()` | `controller.next()` / `previous()` / `skip()` / `goTo()` / `finish()` |
| `onFinish`, `onSkip`, `onClickTarget` | `onFinish`, `onComplete` | `onFinish`, `onSkip`, `onStepChanged` |
| `enableTargetTab` / `enableOverlayTab` | `disableBarrierInteraction`, `disposeOnTap` | `holeTap`, `barrierAction` |
| (no wrapper needed) | `ShowCaseWidget` around the app | no wrapper; optional `CoachTourRegistryScope` for ids |

Names in the first two columns are those of the other packages' public docs; check your installed version, since both have renamed parameters across major releases.

What changes:

- There is no builder around your app and no widget wrapping each target. Pass the `GlobalKey` you already have, or wrap with `CoachAnchor` if you prefer ids.
- The hole morphs between steps instead of cutting, and the card placement never covers the hole.
- Off-screen targets are scrolled into view. Missing ones are skipped and reported instead of throwing.
- "Show once" is built in through `startOnce` and a store you control.
- Back button, Escape, focus, screen-reader announcements, RTL and reduced motion are handled.

## Limitations

- A target inside a lazy list (`ListView.builder`) that was never built has no context, so it cannot be scrolled to; it is skipped as unmounted. Scroll it into existence first, or keep the target outside the lazy part.
- Visibility is judged against the screen (at least half the target must be on it). A target hidden by clipping inside its own parent, or covered by another widget, is not detected.
- A `circle` hole uses the longer side of the padded target as its diameter, so the corners of a wide target fall outside it. Use `stadium` or `rrect` for wide targets.
- When a target is so large that no side has room for a card (for example a full-screen list), the card is placed at the bottom and overlaps the hole.
- The card is placed relative to where the hole ends up. While the hole is still morphing, it can pass under the card for a moment.
- With `CoachHoleTap.passThrough`, a tap that navigates away leaves the tour open on the previous route. Call `controller.finish()` from the target's handler first.
- Navigation calls made before the overlay's first frame are ignored.

## License

MIT. See [LICENSE](LICENSE).

## Author

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
