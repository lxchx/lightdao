import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/setting.dart';
import 'package:provider/provider.dart';

/// 一个“标题栏 + 一条列表”的页面（收藏、发言、浏览…）。
///
/// 设置里关闭“固定底栏&顶栏”时，标题栏和首页、串页一样跟着手指收起/展开；
/// 打开时保持原来固定的 AppBar，外观、标题、actions 都不变。
class ReplysPage extends StatefulWidget {
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
  State<ReplysPage> createState() => _ReplysPageState();
}

class _ReplysPageState extends State<ReplysPage> {
  /// 跟手顶栏和下面的列表共用的控制器：列表修正滚动位置时，顶栏不会把修正
  /// 误当成“用户往下滑了一大段”而收起（和串页同一套）。
  final SliverAnchorController _anchorController = SliverAnchorController();

  @override
  void dispose() {
    _anchorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final appBar = AppBar(title: Text(widget.title), actions: widget.actions);

    // 固定顶栏：和改动前完全一样。reverse 的列表第一条 sliver 会排在最下面，
    // 跟手顶栏在那里没有意义，所以也走这一支。
    if (appState.setting.fixedBottomBar || widget.reverse) {
      return Scaffold(
        appBar: appBar,
        body: SafeArea(
          child: CustomScrollView(
            reverse: widget.reverse,
            slivers: [SliverList(delegate: widget.listDelegate)],
          ),
        ),
      );
    }

    // 跟手顶栏：和首页、串页是同一套（SliverAnchoredFloatingHeader）。
    // 顶栏自己把状态栏那一条算进高度里，所以这里只留底部的 SafeArea。
    return Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverAnchoredFloatingHeader(
              controller: _anchorController,
              extent: kToolbarHeight + MediaQuery.of(context).padding.top,
              child: appBar,
            ),
            SliverAnchoredList(
              delegate: widget.listDelegate,
              controller: _anchorController,
            ),
          ],
        ),
      ),
    );
  }
}
