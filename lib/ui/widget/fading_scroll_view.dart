import 'package:flutter/material.dart';

class FadingScrollView extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;
  final bool? primary;
  final bool? reverse;
  final double fadeStart;
  final double fadeEnd;
  final bool showScrollbar;

  const FadingScrollView({
    super.key,
    required this.child,
    this.controller,
    this.physics,
    this.padding,
    this.primary,
    this.reverse,
    this.fadeStart = 0.85,
    this.fadeEnd = 1.0,
    this.showScrollbar = true,
  });

  @override
  State<FadingScrollView> createState() => _FadingScrollViewState();
}

class _FadingScrollViewState extends State<FadingScrollView> {
  late ScrollController _controller;
  bool _isScrollable = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content = SingleChildScrollView(
          controller: _controller,
          physics: widget.physics,
          padding: widget.padding,
          primary: widget.primary,
          reverse: widget.reverse ?? false,
          child: widget.child,
        );

        // 在布局完成后检查是否可滚动
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.hasClients) {
            final newIsScrollable = _controller.position.maxScrollExtent > 0;
            if (newIsScrollable != _isScrollable) {
              setState(() {
                _isScrollable = newIsScrollable;
              });
            }
          }
        });

        // 只有在内容可滚动时才添加滚动条和遮罩
        if (_isScrollable) {
          if (widget.showScrollbar) {
            content = Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              thickness: 6,
              radius: Radius.circular(3),
              child: content,
            );
          }

          content = ShaderMask(
            shaderCallback: (Rect rect) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white.withAlpha((255 * 0.1).round()),
                ],
                stops: [0.0, widget.fadeStart, widget.fadeEnd],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: content,
          );
        }

        return content;
      },
    );
  }
}
