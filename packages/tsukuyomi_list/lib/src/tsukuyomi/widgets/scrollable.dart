import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

part 'package:tsukuyomi_list/src/flutter/widgets/scrollable.dart';

part 'package:tsukuyomi_list/src/flutter/widgets/scrollable_helpers.dart';

class TsukuyomiScrollable extends Scrollable {
  const TsukuyomiScrollable({
    super.key,
    super.axisDirection,
    super.controller,
    super.physics,
    required super.viewportBuilder,
    super.incrementCalculator,
    super.excludeFromSemantics,
    super.semanticChildCount,
    super.dragStartBehavior,
    super.restorationId,
    super.scrollBehavior,
    super.clipBehavior,
    this.ignorePointer = false,
  });

  factory TsukuyomiScrollable.from({
    required Scrollable scrollable,
    bool ignorePointer = false,
  }) {
    return TsukuyomiScrollable(
      key: scrollable.key,
      axisDirection: scrollable.axisDirection,
      controller: scrollable.controller,
      physics: scrollable.physics,
      viewportBuilder: scrollable.viewportBuilder,
      incrementCalculator: scrollable.incrementCalculator,
      excludeFromSemantics: scrollable.excludeFromSemantics,
      semanticChildCount: scrollable.semanticChildCount,
      dragStartBehavior: scrollable.dragStartBehavior,
      restorationId: scrollable.restorationId,
      scrollBehavior: scrollable.scrollBehavior,
      clipBehavior: scrollable.clipBehavior,
      ignorePointer: ignorePointer,
    );
  }

  final bool ignorePointer;

  @override
  TsukuyomiScrollableState createState() => TsukuyomiScrollableState();
}

class TsukuyomiScrollableState extends ScrollableState {
  @override
  TsukuyomiScrollable get widget {
    return super.widget as TsukuyomiScrollable;
  }

  @override
  Map<Type, GestureRecognizerFactory> get _gestureRecognizers {
    if (widget.ignorePointer) {
      return const <Type, GestureRecognizerFactory>{};
    }
    return super._gestureRecognizers;
  }

  @override
  void _receivedPointerSignal(PointerSignalEvent event) {
    if (widget.ignorePointer) {
      return;
    }
    super._receivedPointerSignal(event);
  }
}