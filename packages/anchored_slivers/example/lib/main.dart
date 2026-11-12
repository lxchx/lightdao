import 'package:flutter/material.dart';

import 'src/demo_images.dart';
import 'src/home_shell.dart';

void main() => runApp(const ExampleApp());

/// Root of the example app.
///
/// [images] is injectable so widget tests can turn the simulated image loading
/// off: a [Timer] left pending at the end of a test fails it.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key, this.images});

  /// Shared fake-image store. When null the app owns one with loading on.
  final DemoImageStore? images;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final DemoImageStore _images = widget.images ?? DemoImageStore();
  late final bool _ownsImages = widget.images == null;

  @override
  void dispose() {
    if (_ownsImages) _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'anchored_slivers example',
      debugShowCheckedModeBanner: false,
      theme: demoTheme(),
      home: HomeShell(images: _images),
    );
  }
}

/// The Material 3 theme, shared by the app and the golden tests.
ThemeData demoTheme() {
  final ColorScheme colors = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3D5AFE),
  );
  return ThemeData(colorScheme: colors, useMaterial3: true);
}
