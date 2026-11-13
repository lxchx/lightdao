import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/ui/widget/top_bar.dart';
import 'package:provider/provider.dart';

/// 一个“标题栏 + 一条列表”的页面（收藏、发言、浏览…）。
///
/// 顶栏用哪一支由 top_bar.dart 统一判定：手机竖屏保持原来的两种形态（设置里
/// 打开“固定底栏&顶栏”时是固定的 AppBar，否则跟手收起）；侧栏导航模式下顶栏
/// 固定时半透明 + 背景模糊、矮屏时纯色跟手隐藏，内容都从顶栏下面滑过。
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
    final TopBarMode topBarMode = topBarModeOf(
      context,
      fixedBottomBar: appState.setting.fixedBottomBar,
    );
    final Widget topBarTitle = Text(widget.title);

    // 手机竖屏（底部导航）：与改动前完全一致。固定顶栏（或 reverse 的列表）用
    // Scaffold 的固定 AppBar，其余跟手收起。
    if (topBarMode == TopBarMode.phone) {
      final AppBar appBar = AppBar(title: topBarTitle, actions: widget.actions);
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

    // 侧栏导航模式：顶栏固定时半透明 + 背景模糊，矮屏时纯色跟手隐藏。两种都
    // 在同一个 CustomScrollView 里，内容要能从顶栏下面滑过去。
    final bool pinnedTopBar = topBarMode == TopBarMode.pinnedGlass;
    // 顶栏图标的同色柔光由 GlassTopBar 自己在 build 里按当前 Theme 取（见
    // top_bar.dart），调用方给进来的 actions 原样传下去即可。
    return Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          reverse: widget.reverse,
          slivers: [
            SliverAnchoredFloatingHeader(
              controller: _anchorController,
              extent: kToolbarHeight + MediaQuery.of(context).padding.top,
              pinned: pinnedTopBar,
              child: pinnedTopBar
                  ? GlassTopBar(title: topBarTitle, actions: widget.actions)
                  : solidTopBar(
                      context: context,
                      title: topBarTitle,
                      actions: widget.actions,
                    ),
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
