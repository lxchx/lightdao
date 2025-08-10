// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'package:tsukuyomi_list/src/tsukuyomi/widgets/scroll_activity.dart';

/// An activity that animates a scroll view based on animation parameters.
///
/// For example, a [DrivenScrollActivity] is used to implement
/// [ScrollController.animateTo].
///
/// See also:
///
///  * [BallisticScrollActivity], which animates a scroll view based on a
///    physics [Simulation].
class DrivenScrollActivity extends ScrollActivity {
  /// Creates an activity that animates a scroll view based on animation
  /// parameters.
  ///
  /// All of the parameters must be non-null.
  DrivenScrollActivity(
    super.delegate, {
    required double from,
    required double to,
    required Duration duration,
    required Curve curve,
    required TickerProvider vsync,
  }) : assert(duration > Duration.zero) {
    _completer = Completer<void>();
    _controller = AnimationController.unbounded(
      value: from,
      debugLabel: objectRuntimeType(this, 'DrivenScrollActivity'),
      vsync: vsync,
    )
      ..addListener(_tick)
      ..animateTo(to, duration: duration, curve: curve)
          .whenComplete(_end); // won't trigger if we dispose _controller first
  }

  late final Completer<void> _completer;
  late final AnimationController _controller;

  /// A [Future] that completes when the activity stops.
  ///
  /// For example, this [Future] will complete if the animation reaches the end
  /// or if the user interacts with the scroll view in way that causes the
  /// animation to stop before it reaches the end.
  Future<void> get done => _completer.future;

  void _tick() {
    if (delegate.setPixels(_controller.value) != 0.0) {
      delegate.goIdle();
    }
  }

  void _end() {
    delegate.goBallistic(velocity);
  }

  @override
  void dispatchOverscrollNotification(
      ScrollMetrics metrics, BuildContext context, double overscroll) {
    OverscrollNotification(
            metrics: metrics,
            context: context,
            overscroll: overscroll,
            velocity: velocity)
        .dispatch(context);
  }

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _controller.velocity;

  @override
  void dispose() {
    _completer.complete();
    _controller.dispose();
    super.dispose();
  }

  @override
  String toString() {
    return '${describeIdentity(this)}($_controller)';
  }
}
