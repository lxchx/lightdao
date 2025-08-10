import 'package:flutter/material.dart';

class ExitSignal {
  bool _isExiting = false;

  void trigger() {
    _isExiting = true;
  }

  bool get isTriggered => _isExiting;

  void reset() {
    _isExiting = false;
  }
}

/// A widget used to dismiss its [child].
///
/// Similar to [Dismissible] with some adjustments.
class DragDismissible extends StatefulWidget {
  const DragDismissible({
    required this.child,
    this.onDismissed,
    this.dismissThreshold = 0.2,
    this.enabled = true,
    this.backgroundColor,
    this.exitSignal,
  });

  final Widget child;
  final double dismissThreshold;
  final VoidCallback? onDismissed;
  final bool enabled;
  final Color? backgroundColor;
  final ExitSignal? exitSignal;

  @override
  State<DragDismissible> createState() => _DragDismissibleState();
}

class _DragDismissibleState extends State<DragDismissible>
    with SingleTickerProviderStateMixin {
  late AnimationController _animateController;
  late Animation<Offset> _moveAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Decoration> _opacityAnimation;

  double _dragExtent = 0;
  bool _dragUnderway = false;

  bool _isExiting = false;

  int _pointerCount = 0;

  bool get _isActive => _dragUnderway || _animateController.isAnimating;

  @override
  void initState() {
    super.initState();

    _animateController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _updateMoveAnimation();
  }

  @override
  void didUpdateWidget(DragDismissible oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检查信号是否被触发
    if (widget.exitSignal != null && widget.exitSignal!.isTriggered) {
      // 触发退出动画
      setState(() {
        _isExiting = true;
        _scaleAnimation = AlwaysStoppedAnimation(1.0); // 让缩放动画失效
      });

      _animateController.forward();

      // 重置信号，避免重复触发
      widget.exitSignal!.reset();
    }
  }

  @override
  void dispose() {
    _animateController.dispose();

    super.dispose();
  }

  void _updateMoveAnimation() {
    final double end = _dragExtent.sign;

    _moveAnimation = _animateController.drive(
      Tween<Offset>(begin: Offset.zero, end: Offset(0, end)),
    );

    _scaleAnimation = _animateController.drive(
      Tween<double>(begin: 1, end: 0.5),
    );

    _opacityAnimation = DecorationTween(
      begin: BoxDecoration(
        color: _isExiting
            ? Colors.transparent
            : widget.backgroundColor ?? const Color(0xFF000000),
      ),
      end: BoxDecoration(color: const Color(0x00000000)),
    ).animate(_animateController);
  }

  void _handleDragStart(DragStartDetails details) {
    if (_pointerCount > 1) return;

    _dragUnderway = true;

    if (_animateController.isAnimating) {
      _dragExtent =
          _animateController.value * context.size!.height * _dragExtent.sign;
      _animateController.stop();
    } else {
      _dragExtent = 0.0;
      _animateController.value = 0.0;
    }
    setState(_updateMoveAnimation);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_pointerCount > 1) return;

    if (!_isActive || _animateController.isAnimating) {
      return;
    }

    final double delta = details.primaryDelta!;
    final double oldDragExtent = _dragExtent;

    if (_dragExtent + delta < 0) {
      _dragExtent += delta;
    } else if (_dragExtent + delta > 0) {
      _dragExtent += delta;
    }

    if (oldDragExtent.sign != _dragExtent.sign) {
      setState(_updateMoveAnimation);
    }

    if (!_animateController.isAnimating) {
      _animateController.value = _dragExtent.abs() / context.size!.height;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isActive || _animateController.isAnimating) {
      return;
    }

    _dragUnderway = false;

    if (_animateController.isCompleted) {
      return;
    }

    if (!_animateController.isDismissed) {
      // if the dragged value exceeded the dismissThreshold, call onDismissed
      // else animate back to initial position.
      if (_animateController.value > widget.dismissThreshold) {
        widget.onDismissed?.call();
      } else {
        _animateController.reverse();
      }
    }
  }

  void _pointerAdded(PointerEvent event) {
    setState(() {
      _pointerCount++;
    });
  }

  void _pointerRemoved(PointerEvent event) {
    setState(() {
      _pointerCount = _pointerCount > 0 ? _pointerCount - 1 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = PopScope(
      canPop: false,
      // 拦截退出做一些修改，否则之前的page会被背景挡住，把渐变动画播完。
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        setState(() {
          _isExiting = true;
          _scaleAnimation = AlwaysStoppedAnimation(1.0); // 让缩放动画失效
        });

        _animateController.forward();
      },
      child: DecoratedBoxTransition(
        decoration: _opacityAnimation,
        child: SlideTransition(
          position: _moveAnimation,
          child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
        ),
      ),
    );

    return Listener(
      onPointerDown: _pointerAdded,
      onPointerUp: _pointerRemoved,
      onPointerCancel: _pointerRemoved,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: (widget.enabled && _pointerCount <= 1)
            ? _handleDragStart
            : null,
        onVerticalDragUpdate: (widget.enabled && _pointerCount <= 1)
            ? _handleDragUpdate
            : null,
        onVerticalDragEnd: (widget.enabled && _pointerCount <= 1)
            ? _handleDragEnd
            : null,
        child: content,
      ),
    );
  }
}
