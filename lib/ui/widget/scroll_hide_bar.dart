import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 让底栏"跟手"地随滚动收起/展开。
///
/// [hidden] 是收起的比例：0 = 完全显示，1 = 完全收起。手指拖动时按滚动距离
/// 一比一地改它（往下滚多少，栏就收多少）；松手、惯性结束后再补到最近的一端。
///
/// 只响应用户发起的滚动（拖动及其惯性）。栏的高度变化会改变列表视口，
/// 进而可能引出一次程序性的回弹滚动；若连这种滚动也响应，就会自己触发自己、
/// 来回抖动。
class ScrollHideController {
  ScrollHideController({required TickerProvider vsync})
    : hidden = AnimationController(vsync: vsync, value: 0);

  /// 0 = 完全显示，1 = 完全收起。
  final AnimationController hidden;

  /// 栏的高度，用来把滚动距离换算成比例。
  double extent = kToolbarHeight;

  ScrollDirection _direction = ScrollDirection.idle;

  /// 接到 NotificationListener<ScrollNotification> 的 onNotification 上。
  bool handleNotification(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      _direction = n.direction;
      if (_direction == ScrollDirection.idle) _settle();
    } else if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (_direction == ScrollDirection.idle || delta == 0) return false;
      // 越界回弹（iOS 橡皮筋）期间不动
      if (n.metrics.outOfRange) return false;
      if (n.metrics.pixels <= n.metrics.minScrollExtent) {
        hidden.value = 0;
        return false;
      }
      hidden.value = (hidden.value + delta / extent).clamp(0.0, 1.0);
    } else if (n is ScrollEndNotification) {
      if (_direction == ScrollDirection.idle) _settle();
    }
    return false;
  }

  void _settle() {
    final v = hidden.value;
    if (v <= 0 || v >= 1 || hidden.isAnimating) return;
    hidden.animateTo(
      v < 0.5 ? 0 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  /// 立刻完全显示（例如切换页面、跳转之后）。
  void show() {
    if (hidden.value != 0) hidden.animateTo(0, duration: Durations.short3);
  }

  void dispose() => hidden.dispose();
}

/// 高度随 [controller] 收起的底栏容器：内容整体往下滑出，而不是被压扁。
class ScrollHideBottomBar extends StatelessWidget {
  const ScrollHideBottomBar({
    super.key,
    required this.controller,
    required this.height,
    required this.fixed,
    required this.child,
  });

  final ScrollHideController controller;
  final double height;

  /// 为 true 时始终完全显示（对应设置里的"固定底栏"）。
  final bool fixed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    controller.extent = height;
    return AnimatedBuilder(
      animation: controller.hidden,
      child: child,
      builder: (context, child) {
        final t = fixed ? 0.0 : controller.hidden.value;
        return ClipRect(
          child: SizedBox(
            height: height * (1 - t),
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: height,
              maxHeight: height,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// 跟着底栏一起缩小消失的悬浮按钮容器。
class ScrollHideFab extends StatelessWidget {
  const ScrollHideFab({
    super.key,
    required this.controller,
    required this.fixed,
    required this.child,
  });

  final ScrollHideController controller;
  final bool fixed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.hidden,
      child: child,
      builder: (context, child) {
        final t = fixed ? 0.0 : controller.hidden.value;
        if (t >= 1) return const SizedBox.shrink();
        return IgnorePointer(
          ignoring: t > 0.5,
          child: Transform.scale(scale: 1 - t, child: child),
        );
      },
    );
  }
}
