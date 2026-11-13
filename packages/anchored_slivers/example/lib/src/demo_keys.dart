import 'package:flutter/widgets.dart';

/// Keys shared by the demo app and `test/screenshots_test.dart`.
///
/// The same keys address the same control in a wide (rail) and a narrow
/// (bottom bar) layout, so the golden tests do not need to care which one is
/// on screen.
abstract final class DemoKeys {
  static const Key listPage = Key('list-page');
  static const Key masonryPage = Key('masonry-page');

  static const Key navList = Key('nav-list');
  static const Key navMasonry = Key('nav-masonry');

  static const Key listAnchoredToggle = Key('list-anchored-toggle');
  static const Key listResizeAbove = Key('list-resize-above');
  static const Key listPrepend = Key('list-prepend');
  static const Key listJump = Key('list-jump');

  static const Key masonrySidePanel = Key('masonry-side-panel');
  static const Key masonryMaxExtent = Key('masonry-max-extent');
  static const Key masonryResizeAbove = Key('masonry-resize-above');
}
