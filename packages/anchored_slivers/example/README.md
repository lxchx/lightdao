# anchored_slivers example

Two demos for [`anchored_slivers`](../README.md), one screen each:

* **List** — a `SliverAnchoredList` with 300 cards. Every card's fake "image"
  grows from 40 dp to a random 80–320 dp a while after it is first built, the
  way a network image would. Use the app bar to
  * switch the anchored layout off and compare it with a plain `SliverList`,
  * resize the five items above the anchor,
  * prepend 20 items,
  * jump to item 150.

  The translucent line is the anchor line (`anchorAlignment: 0.5`); the bar at
  the bottom shows the live `anchorIndex` and scroll offset.
* **Masonry** — a `SliverAnchoredMasonry.extent`. Drag the slider to change the
  maximum column width (120–400 dp), or turn on **Side panel** to give 50% of
  the width to a panel and watch the lane count drop while the anchored row
  stays put. The status bar shows `laneCount` and `anchorIndex`.

The wide layout (`>= 840 dp`) uses a `NavigationRail`; narrower screens use a
`NavigationBar`.

## Run it

```sh
flutter pub get
flutter run -d chrome          # or any other device
flutter analyze
flutter test
```

## Screenshots

`test/screenshots_test.dart` renders the app at six screen shapes and writes
golden PNGs — no device or desktop window required:

```sh
flutter test --update-goldens test/screenshots_test.dart
cp test/goldens/*.png ../../docs/shots/widget/
```

The tests need real fonts (otherwise every glyph is a box); they load Roboto and
MaterialIcons from `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts`, or from
`test/fonts/` if you put a copy there.

Image loading is switched off in the tests (`DemoImageStore(autoLoad: false)`),
because a pending `Timer` fails a widget test; the test loads a deterministic
subset instead, so the frames are stable and show both card states.
