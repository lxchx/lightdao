import 'package:flutter/material.dart';

class SlidingAppBar extends StatefulWidget implements PreferredSizeWidget {
  SlidingAppBar({
    required this.child,
    required this.visible,
    required this.duration,
    this.curve = Curves.easeInOut,
  });

  final PreferredSizeWidget child;
  final Duration duration;
  final Curve curve;
  final bool visible;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  State<SlidingAppBar> createState() => _SlidingAppBarState();
}

class _SlidingAppBarState extends State<SlidingAppBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.visible) {
      _controller.value = 1.0; // 完全可见
    } else {
      _controller.value = 0.0; // 完全隐藏
    }
  }

  @override
  void didUpdateWidget(SlidingAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward(); // 可见状态
      } else {
        _controller.reverse(); // 隐藏状态
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return PreferredSize(
          // 使用动画的值来计算当前的 preferredSize
          preferredSize: Size(
            widget.child.preferredSize.width,
            widget.child.preferredSize.height * _animation.value,
          ),
          child: ClipRect( // 使用 ClipRect 来裁剪内容，使其平滑消失/出现
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _animation.value, // 高度因子也使用动画值
              child: SlideTransition(
                position: Tween<Offset>(begin: Offset(0, -1), end: Offset.zero).animate(
                  CurvedAnimation(parent: _controller, curve: widget.curve),
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
