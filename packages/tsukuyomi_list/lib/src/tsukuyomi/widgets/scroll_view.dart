import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' hide ScrollAction, Scrollable;

import 'scrollable.dart';
import 'viewport.dart' hide Viewport;

part 'package:tsukuyomi_list/src/flutter/widgets/scroll_view.dart';

class TsukuyomiScrollView extends CustomScrollView {
  const TsukuyomiScrollView({
    super.key,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.scrollBehavior,
    super.shrinkWrap,
    super.center,
    super.anchor,
    super.cacheExtent,
    super.slivers,
    super.semanticChildCount,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.clipBehavior,
    this.ignorePointer = false,
  });

  final bool ignorePointer;

  @override
  @protected
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) {
    return TsukuyomiScrollViewViewport(
      axisDirection: axisDirection,
      offset: offset,
      slivers: slivers,
      cacheExtent: cacheExtent,
      center: center,
      anchor: anchor,
      clipBehavior: clipBehavior,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars:
            false, // 禁用滚动条以避免 [RawScrollbar] 在点击跳转时无法正确获取 [Scrollable] 而报错
      ),
      child: _convertScrollable(super.build(context)),
    );
  }

  /// 将 [Scrollable] 类型转化为 [TsukuyomiScrollable]
  Widget _convertScrollable(Widget widget) {
    if (widget is PrimaryScrollController) {
      return PrimaryScrollController.none(
        key: widget.key,
        child: _convertScrollable(widget.child),
      );
    }
    if (widget is NotificationListener) {
      return NotificationListener(
        key: widget.key,
        onNotification: widget.onNotification,
        child: _convertScrollable(widget.child),
      );
    }
    return TsukuyomiScrollable.from(
      scrollable: widget as Scrollable,
      ignorePointer: ignorePointer,
    );
  }
}
