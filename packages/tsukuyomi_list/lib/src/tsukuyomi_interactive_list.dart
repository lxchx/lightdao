import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:tsukuyomi_list/src/tsukuyomi/widgets/interactive_viewer.dart';
import 'package:tsukuyomi_list/src/tsukuyomi_list.dart';
import 'package:vector_math/vector_math_64.dart' show Quad;

/// 缩放比例更新的回调
typedef OnScaleUpdate = void Function(double scale);

class TsukuyomiInteractiveList extends StatefulWidget {
  const TsukuyomiInteractiveList.builder({
    super.key,
    this.physics,
    this.controller,
    this.onItemsChanged,
    this.onScaleUpdate,
    this.middleScale = 2.5,
    this.maxScale = 5.0,
    this.initialScrollIndex = 0,
    this.scrollDirection = Axis.vertical,
    this.debugMask = false,
    this.scaleCurve = Curves.fastLinearToSlowEaseIn,
    this.scaleDuration = const Duration(milliseconds: 500),
    required this.itemCount,
    required this.itemBuilder,
  });

  /// 列表长度
  final int itemCount;

  /// 列表初始位置索引
  final int initialScrollIndex;

  /// 首次双击时的缩放比例
  final double middleScale;

  /// 最大缩放比例
  final double maxScale;

  /// 双击缩放动画效果
  final Curve scaleCurve;

  /// 双击缩放动画时长
  final Duration scaleDuration;

  /// 列表调试遮罩
  final bool debugMask;

  /// 列表滑动物理效果
  final ScrollPhysics? physics;

  /// 列表滚动方向
  final Axis scrollDirection;

  /// 列表项更新
  final ValueChanged<List<TsukuyomiListItem>>? onItemsChanged;

  /// 缩放比例更新
  final OnScaleUpdate? onScaleUpdate;

  /// 列表项构建器
  final IndexedWidgetBuilder itemBuilder;

  /// 列表滚动控制器
  final TsukuyomiListController? controller;

  @override
  State<TsukuyomiInteractiveList> createState() => _TsukuyomiInteractiveList();
}

class _TsukuyomiInteractiveList extends State<TsukuyomiInteractiveList> with SingleTickerProviderStateMixin {
  Drag? _drag;
  Offset? _doubleTapLocalPosition;
  late Animation<Matrix4> _zoomAnimation;
  late TsukuyomiListController _listController; // 列表滚动控制器
  late final AnimationController _scaleController; // 列表缩放动画控制器
  late final TransformationController _transformationController; // 列表变换控制器

  /// 当前缩放比例
  double _scale = 1.0;

  /// 判断当前缩放比例
  bool _isScale(double scale) {
    return nearEqual(_scale, scale, Tolerance.defaultTolerance.distance);
  }

  /// 获取当前缩放边界
  Rect _axisAlignedBoundingBox(Quad quad) {
    double xMin = quad.point0.x;
    double xMax = quad.point0.x;
    double yMin = quad.point0.y;
    double yMax = quad.point0.y;
    for (final point in [quad.point1, quad.point2, quad.point3]) {
      if (point.x < xMin) {
        xMin = point.x;
      } else if (point.x > xMax) {
        xMax = point.x;
      }

      if (point.y < yMin) {
        yMin = point.y;
      } else if (point.y > yMax) {
        yMax = point.y;
      }
    }

    return Rect.fromLTRB(xMin, yMin, xMax, yMax);
  }

  /// 根据点击位置和缩放比例获取变换矩阵
  Matrix4 _getMatrix4(Offset offset, double scale) {
    return Matrix4.identity()
      ..translate(-offset.dx * (scale - 1), -offset.dy * (scale - 1))
      ..scale(scale);
  }

  /// 是否需要忽略处理列表拖动事件
  bool _shouldIgnoreListDrag() {
    final position = _listController.position;
    return !position.physics.shouldAcceptUserOffset(position);
  }

  /// 处理触控开始事件
  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount > 1 || _shouldIgnoreListDrag()) {
      return;
    }
    _drag ??= _listController.position.drag(
      DragStartDetails(),
      () => _drag = null,
    );
  }

  /// 处理触控更新事件
  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount > 1 || _shouldIgnoreListDrag() || _drag == null) {
      return;
    }
    // 主轴方向的位移值
    final primaryDelta = switch (widget.scrollDirection) {
      Axis.vertical => details.focalPointDelta.dy,
      Axis.horizontal => details.focalPointDelta.dx,
    };
    // 如果没有发生位移
    if (primaryDelta == 0.0) {
      return;
    }
    // 缩放之后的位移值
    final scaledDelta = primaryDelta / _scale;
    // 将触控更新事件转化为列表滑动事件
    _drag!.update(DragUpdateDetails(
      primaryDelta: scaledDelta,
      globalPosition: details.focalPoint,
      delta: switch (widget.scrollDirection) {
        Axis.vertical => Offset(0, scaledDelta),
        Axis.horizontal => Offset(scaledDelta, 0),
      },
    ));
  }

  /// 处理触控结束事件
  void _onScaleEnd(ScaleEndDetails details) {
    if (details.pointerCount > 0 || _shouldIgnoreListDrag() || _drag == null) {
      return;
    }
    // 主轴方向的速度
    final primaryVelocity = switch (widget.scrollDirection) {
      Axis.vertical => details.velocity.pixelsPerSecond.dy,
      Axis.horizontal => details.velocity.pixelsPerSecond.dx,
    };
    // 缩放之后的速度
    final scaledVelocity = primaryVelocity / _scale;
    // 将触控结束事件转化为列表快速滑动事件
    _drag!.end(DragEndDetails(
      primaryVelocity: scaledVelocity,
      velocity: switch (widget.scrollDirection) {
        Axis.vertical => Velocity(pixelsPerSecond: Offset(0, scaledVelocity)),
        Axis.horizontal => Velocity(pixelsPerSecond: Offset(scaledVelocity, 0)),
      },
    ));
    _drag = null;
  }

  /// 处理双击按下事件
  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapLocalPosition = details.localPosition;
  }

  /// 处理双击取消事件
  void _onDoubleTapCancel() {
    _doubleTapLocalPosition = null;
  }

  /// 处理双击结束事件
  void _onDoubleTap() {
    if (_doubleTapLocalPosition == null) {
      return;
    }

    final Matrix4 matrix4;
    if (_isScale(1.0)) {
      // 如果是原始尺寸，则将图片缩放为中等尺寸
      matrix4 = _getMatrix4(_doubleTapLocalPosition!, widget.middleScale);
    } else {
      // 如果是其他尺寸，则都统一缩放为原始尺寸
      matrix4 = Matrix4.identity();
    }
    // 创建新的动画
    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: matrix4,
    ).animate(
      // 自定义动画效果
      CurveTween(curve: widget.scaleCurve).animate(_scaleController),
    );
    // 开始执行动画
    _scaleController.forward(from: 0);
    // 清除双击事件数据
    _doubleTapLocalPosition = null;
  }

  /// 处理页面变换事件
  void _onTranslate() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    // 如果缩放比例发生了变换
    if (_scale != scale) {
      _scale = scale;
      widget.onScaleUpdate?.call(_scale);
    }
  }

  /// 处理页面缩放事件
  void _onZoom() {
    _transformationController.value = _zoomAnimation.value;
  }

  @override
  void initState() {
    super.initState();
    _listController = widget.controller ?? TsukuyomiListController();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTranslate);
    _scaleController = AnimationController(
      vsync: this,
      duration: widget.scaleDuration,
    );
    _scaleController.addListener(_onZoom);
  }

  @override
  void didUpdateWidget(TsukuyomiInteractiveList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        assert(widget.controller != null);
        _listController = widget.controller!;
      } else {
        if (widget.controller == null) {
          _listController = TsukuyomiListController();
        } else {
          _listController = widget.controller!;
        }
      }
    }
    _scaleController.duration = widget.scaleDuration;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _onDoubleTap,
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTapCancel: _onDoubleTapCancel,
      child: LayoutBuilder(
        builder: (context, constraints) => TsukuyomiInteractiveViewer.builder(
          panAxis: switch (widget.scrollDirection) {
            Axis.vertical => PanAxis.horizontal,
            Axis.horizontal => PanAxis.vertical,
          },
          maxScale: widget.maxScale,
          transformationController: _transformationController,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          builder: (context, viewport) {
            final rect = _axisAlignedBoundingBox(viewport);
            final leading = switch (widget.scrollDirection) {
              Axis.vertical => rect.top,
              Axis.horizontal => rect.left,
            };
            final trailing = switch (widget.scrollDirection) {
              Axis.vertical => constraints.maxHeight - rect.bottom,
              Axis.horizontal => constraints.maxWidth - rect.right,
            };
            return ConstrainedBox(
              constraints: constraints,
              child: TsukuyomiList.builder(
                physics: widget.physics,
                itemCount: widget.itemCount,
                controller: _listController,
                itemBuilder: widget.itemBuilder,
                scrollDirection: widget.scrollDirection,
                initialScrollIndex: widget.initialScrollIndex,
                onItemsChanged: widget.onItemsChanged,
                debugMask: widget.debugMask,
                ignorePointer: true,
                leadingExtent: math.max(0.0, leading),
                trailingExtent: math.max(0.0, trailing),
              ),
            );
          },
        ),
      ),
    );
  }
}
