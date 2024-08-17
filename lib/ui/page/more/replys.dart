import 'package:flutter/material.dart';

class ReplysPage extends StatelessWidget {
  final String title;
  final SliverChildBuilderDelegate listDelegate;
  final bool reverse;
  final List<Widget>? actions;

  ReplysPage({
    required this.title,
    required this.listDelegate,
    this.reverse = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        child: CustomScrollView(
          reverse: reverse,
          slivers: [
            SliverList(
              delegate: listDelegate,
            ),
          ],
        ),
      ),
    );
  }
}