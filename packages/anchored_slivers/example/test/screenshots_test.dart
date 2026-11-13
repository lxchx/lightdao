// Screenshot evidence for the anchored_slivers example app, produced by
// widget tests (no device or desktop window needed).
//
//   cd example
//   flutter test --update-goldens test/screenshots_test.dart
//
// The PNGs land in test/goldens/. Copy them to ../../docs/shots/widget/ (see
// README.md in this folder). A plain `flutter test` afterwards compares the
// app against those PNGs, so a layout regression fails the suite.
import 'dart:io';

import 'package:anchored_slivers_example/main.dart';
import 'package:anchored_slivers_example/src/demo_images.dart';
import 'package:anchored_slivers_example/src/demo_keys.dart';
import 'package:anchored_slivers_example/src/status_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One screen shape to photograph.
class _Profile {
  const _Profile(this.name, this.width, this.height, this.devicePixelRatio);

  /// Name used in the golden file names.
  final String name;

  /// Logical size of the screen, in dp.
  final double width;
  final double height;

  final double devicePixelRatio;

  /// The golden image is [width] * [devicePixelRatio] pixels wide.
  Size get physicalSize => Size(
    (width * devicePixelRatio).roundToDouble(),
    (height * devicePixelRatio).roundToDouble(),
  );

  @override
  String toString() =>
      '$name ${width.round()}x${height.round()}@$devicePixelRatio';
}

const List<_Profile> _profiles = <_Profile>[
  _Profile('phone', 360, 800, 3.0),
  _Profile('wide_phone', 412, 915, 2.625),
  _Profile('foldable_folded', 344, 882, 2.6),
  _Profile('foldable_unfolded', 884, 1104, 2.6),
  _Profile('tablet', 1280, 800, 2.0),
  _Profile('desktop', 1920, 1080, 1.0),
];

void main() {
  setUpAll(_loadFonts);

  for (final _Profile profile in _profiles) {
    testWidgets('screenshots: $profile', (WidgetTester tester) {
      return _withShadows(() => _takeScreenshots(tester, profile));
    });
  }
}

/// Shadows are off by default in widget tests but the screenshots want them.
/// The flag has to be restored inside the test body: the framework verifies
/// that painting debug variables are unset before teardown runs.
Future<void> _withShadows(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _takeScreenshots(WidgetTester tester, _Profile profile) async {
  tester.view.physicalSize = profile.physicalSize;
  tester.view.devicePixelRatio = profile.devicePixelRatio;
  addTearDown(tester.view.reset);

  // Simulated image loading stays off: a pending Timer fails a test. A
  // deterministic subset is loaded up front instead, so every frame shows
  // both loaded and still-loading cards and never changes on its own.
  final DemoImageStore images = DemoImageStore(autoLoad: false);
  addTearDown(images.dispose);
  images.loadAll(<int>[
    for (int id = 0; id < 300; id++)
      if (demoHash(id * 7 + 1) % 5 != 0) id,
  ]);

  await tester.pumpWidget(ExampleApp(images: images));
  await _settle(tester);

  // ---- List page, scrolled into the middle ---------------------------
  await _scrollToFraction(tester, DemoKeys.listPage, 0.42);
  await _golden(tester, 'list_${profile.name}_middle');

  final int anchorIndex = _statusInt(tester, 'list', 'anchorIndex');
  expect(
    anchorIndex,
    greaterThan(10),
    reason: 'the list should sit in the middle, not at the top',
  );

  final Finder anchorCard = _card(tester, DemoKeys.listPage, anchorIndex);
  expect(anchorCard, findsOneWidget);
  final double anchorTopBefore = tester.getTopLeft(anchorCard).dy;
  final Map<int, double> heightsAbove = _cardHeights(
    tester,
    DemoKeys.listPage,
    anchorIndex - 5,
    anchorIndex,
  );
  expect(
    heightsAbove,
    isNotEmpty,
    reason: 'at least one card above the anchor should be built',
  );

  await _golden(tester, 'list_${profile.name}_resize_before');

  await tester.tap(find.byKey(DemoKeys.listResizeAbove));
  await _settle(tester);

  expect(
    tester.getTopLeft(anchorCard).dy,
    moreOrLessEquals(anchorTopBefore, epsilon: 0.5),
    reason: 'the anchor item must not move when items above it resize',
  );
  expect(
    _changedCards(tester, DemoKeys.listPage, heightsAbove),
    greaterThan(0),
    reason: 'the resize must really change the cards above the anchor',
  );

  await _golden(tester, 'list_${profile.name}_resize_after');

  // ---- Masonry page, scrolled into the middle ------------------------
  await tester.tap(find.byKey(DemoKeys.navMasonry));
  await _settle(tester);
  await _scrollToFraction(tester, DemoKeys.masonryPage, 0.42);
  await _golden(tester, 'masonry_${profile.name}_middle');

  final int lanesClosed = _statusInt(tester, 'masonry', 'laneCount');
  expect(lanesClosed, greaterThanOrEqualTo(1));

  // The side panel takes half the width, so the masonry has fewer lanes.
  await tester.tap(find.byKey(DemoKeys.masonrySidePanel));
  await _settle(tester);

  expect(
    _statusInt(tester, 'masonry', 'laneCount'),
    lessThan(lanesClosed),
    reason: 'the side panel should squeeze the masonry into fewer lanes',
  );
  await _golden(tester, 'masonry_${profile.name}_panel_on');
}

// ---- helpers -------------------------------------------------------------

Future<void> _golden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// Pumps until implicit animations (switch thumbs, app bar elevation) and the
/// post-frame anchor readouts have settled.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Finder _scrollableOf(Key pageKey) => find.descendant(
  of: find.descendant(
    of: find.byKey(pageKey),
    matching: find.byType(CustomScrollView),
  ),
  matching: find.byType(Scrollable),
);

Future<void> _scrollToFraction(
  WidgetTester tester,
  Key pageKey,
  double fraction,
) async {
  final ScrollableState scrollable = tester.state<ScrollableState>(
    _scrollableOf(pageKey).first,
  );
  final ScrollPosition position = scrollable.position;
  position.jumpTo(position.maxScrollExtent * fraction);
  await _settle(tester);
}

/// Reads one number out of the page's status bar.
int _statusInt(WidgetTester tester, String prefix, String label) {
  final Text text = tester.widget<Text>(
    find.byKey(StatusBar.valueKey(prefix, label)),
  );
  return int.parse(text.data!);
}

Finder _card(WidgetTester tester, Key pageKey, int id) => find.descendant(
  of: find.byKey(pageKey),
  matching: find.byKey(ValueKey<int>(id)),
);

/// Heights of the cards with the given ids that are currently built.
Map<int, double> _cardHeights(
  WidgetTester tester,
  Key pageKey,
  int from,
  int to,
) {
  final Map<int, double> heights = <int, double>{};
  for (int id = from; id < to; id++) {
    if (id < 0) continue;
    final Finder card = _card(tester, pageKey, id);
    if (card.evaluate().isEmpty) continue;
    heights[id] = tester.getSize(card).height;
  }
  return heights;
}

/// How many of [before] have a different height now.
int _changedCards(WidgetTester tester, Key pageKey, Map<int, double> before) {
  int changed = 0;
  for (final MapEntry<int, double> entry in before.entries) {
    final Finder card = _card(tester, pageKey, entry.key);
    if (card.evaluate().isEmpty) continue;
    if ((tester.getSize(card).height - entry.value).abs() > 0.5) changed++;
  }
  return changed;
}

// ---- fonts ---------------------------------------------------------------

/// Loads real Roboto and MaterialIcons, otherwise every glyph in the golden is
/// a box.
///
/// `flutter test` exports FLUTTER_ROOT, which points at the SDK that is running
/// the test. A copy of the two files can also live in test/fonts/ for setups
/// where that variable is missing.
Future<void> _loadFonts() async {
  final Directory fonts = _materialFontsDirectory();

  final FontLoader roboto = FontLoader('Roboto');
  for (final String file in <String>[
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final File font = File('${fonts.path}/$file');
    if (font.existsSync()) roboto.addFont(_fontBytes(font));
  }
  await roboto.load();

  final File icons = File('${fonts.path}/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final FontLoader loader = FontLoader('MaterialIcons')
      ..addFont(_fontBytes(icons));
    await loader.load();
  }
}

Future<ByteData> _fontBytes(File file) async =>
    ByteData.sublistView(await file.readAsBytes());

Directory _materialFontsDirectory() {
  final List<String> candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final String root)
      '$root/bin/cache/artifacts/material_fonts',
    'test/fonts',
  ];
  for (final String path in candidates) {
    final Directory directory = Directory(path);
    if (File('${directory.path}/Roboto-Regular.ttf').existsSync()) {
      return directory;
    }
  }
  throw StateError(
    'No Roboto found. Looked in: ${candidates.join(', ')}. Copy '
    'Roboto-Regular.ttf (and MaterialIcons-Regular.otf) from '
    'bin/cache/artifacts/material_fonts into test/fonts/.',
  );
}
