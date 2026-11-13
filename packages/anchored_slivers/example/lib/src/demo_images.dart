import 'dart:async';

import 'package:flutter/material.dart';

/// Deterministic 31-bit hash.
///
/// The demo needs "random" numbers that are identical on every device, in
/// every run and inside golden tests, so it does not use [Random]: this keeps
/// the values independent of the engine's RNG implementation.
int demoHash(int value) {
  int x = value & 0x7fffffff;
  x = (x ^ 61) ^ (x >> 16);
  x = (x + (x << 3)) & 0x7fffffff;
  x ^= x >> 4;
  x = (x * 0x27d4eb2d) & 0x7fffffff;
  x ^= x >> 15;
  return x;
}

/// Height of a card's fake "image" while it is still loading.
const double kPlaceholderHeight = 40;

/// Height of a card's fake "image" once it has loaded: 80..320 dp, derived
/// from the item id.
double loadedImageHeight(int id) => 80 + demoHash(id) % 241;

/// How long the fake image of [id] takes to load: 300..1500 ms.
Duration simulatedLoadDelay(int id) =>
    Duration(milliseconds: 300 + demoHash(id * 31 + 7) % 1201);

/// A pleasant, stable colour per item id, used for the avatar and the image
/// block, so a card is recognisable across screenshots.
Color demoColor(int id) {
  final int hue = demoHash(id * 17 + 3) % 360;
  final double saturation = 0.38 + (demoHash(id + 11) % 20) / 100;
  return HSLColor.fromAHSL(1, hue.toDouble(), saturation, 0.72).toColor();
}

/// Remembers which fake images have finished loading, and hands out their
/// current height.
///
/// Images "load" on a timer the first time their card is built, so only items
/// the user actually scrolled past become tall. The loaded height is kept for
/// the lifetime of the store (the page), so scrolling back does not reload and
/// does not jump again.
///
/// Set [autoLoad] to false to disable the timers entirely (widget tests do
/// that: a pending [Timer] fails a test) and load items explicitly with
/// [loadAll] / [randomize].
class DemoImageStore extends ChangeNotifier {
  DemoImageStore({this.autoLoad = true});

  /// Whether building a card schedules its simulated load.
  final bool autoLoad;

  final Map<int, double> _heights = <int, double>{};
  final Map<int, Timer> _timers = <int, Timer>{};
  int _generation = 0;
  bool _disposed = false;

  /// Current height of the fake image of [id]: the loaded height, or
  /// [kPlaceholderHeight] while it is still loading.
  double heightOf(int id) => _heights[id] ?? kPlaceholderHeight;

  /// Whether the fake image of [id] already finished loading.
  bool isLoaded(int id) => _heights.containsKey(id);

  /// Schedules the fake load of [id] the first time its card is built.
  ///
  /// Safe to call from a builder: it is a no-op for ids that are already
  /// loaded, already loading, or when [autoLoad] is off.
  void ensureScheduled(int id) {
    if (!autoLoad || _disposed) return;
    if (_heights.containsKey(id) || _timers.containsKey(id)) return;
    _timers[id] = Timer(simulatedLoadDelay(id), () {
      _timers.remove(id);
      if (_disposed) return;
      _heights[id] = loadedImageHeight(id);
      notifyListeners();
    });
  }

  /// Marks the fake images of [ids] as loaded, in one notification.
  void loadAll(Iterable<int> ids) {
    bool changed = false;
    for (final int id in ids) {
      if (_heights.containsKey(id)) continue;
      _timers.remove(id)?.cancel();
      _heights[id] = loadedImageHeight(id);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Marks a single fake image as loaded.
  void load(int id) => loadAll(<int>[id]);

  /// Gives [ids] fresh pseudo-random heights, as if their images had been
  /// re-fetched at a different size.
  ///
  /// Successive [generation]s alternate between a short and a tall image, so a
  /// resize of items above the anchor is obvious in a screenshot while the
  /// exact height still looks random and stays deterministic.
  void randomize(Iterable<int> ids, {required int generation}) {
    final int base = generation.isOdd ? 250 : 60;
    final Map<int, double> updated = <int, double>{
      for (final int id in ids)
        id: (base + demoHash(id * 7919 + generation * 104) % 71).toDouble(),
    };
    if (updated.isEmpty) return;
    _generation++;
    _heights.addAll(updated);
    notifyListeners();
  }

  /// Number of times [randomize] was called. Handy in debug output.
  int get generation => _generation;

  @override
  void dispose() {
    _disposed = true;
    for (final Timer timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
