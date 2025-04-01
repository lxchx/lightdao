import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Quad, Vector3;

part 'package:tsukuyomi_list/src/flutter/widgets/interactive_viewer.dart';

class TsukuyomiInteractiveViewer extends InteractiveViewer {
  TsukuyomiInteractiveViewer({
    super.key,
    super.panAxis,
    super.maxScale,
    super.transformationController,
    required super.child,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
  });

  TsukuyomiInteractiveViewer.builder({
    super.key,
    super.panAxis,
    super.maxScale,
    super.transformationController,
    required super.builder,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
  }) : super.builder();

  final GestureScaleStartCallback? onScaleStart;

  final GestureScaleUpdateCallback? onScaleUpdate;

  final GestureScaleEndCallback? onScaleEnd;

  @override
  State<InteractiveViewer> createState() => _TsukuyomiInteractiveViewerState();
}

class _TsukuyomiInteractiveViewerState extends _InteractiveViewerState {
  @override
  TsukuyomiInteractiveViewer get widget {
    return super.widget as TsukuyomiInteractiveViewer;
  }

  @override
  void _onScaleStart(ScaleStartDetails details) {
    super._onScaleStart(details);
    widget.onScaleStart?.call(details);
  }

  @override
  void _onScaleUpdate(ScaleUpdateDetails details) {
    super._onScaleUpdate(details);
    widget.onScaleUpdate?.call(details);
  }

  @override
  void _onScaleEnd(ScaleEndDetails details) {
    super._onScaleEnd(details);
    widget.onScaleEnd?.call(details);
  }
}
