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
  Size get preferredSize => visible ? child.preferredSize : Size.zero;

  @override
  State<SlidingAppBar> createState() => _SlidingAppBarState();
}

class _SlidingAppBarState extends State<SlidingAppBar> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: widget.duration, 
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.visible ? controller.reverse() : controller.forward();
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: Offset(0, -1)).animate(
        CurvedAnimation(parent: controller, curve: widget.curve),
      ),
      child: widget.child,
    );
  }
}