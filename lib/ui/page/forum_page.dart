import 'dart:async';

import 'package:flutter/material.dart';
import 'package:breakpoint/breakpoint.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/ui/page/search.dart';
import 'package:lightdao/ui/widget/fading_scroll_view.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/ui/widget/util_funtions.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lightdao/data/xdao/timeline.dart';
import 'package:lightdao/utils/status.dart';

import '../../data/setting.dart';
import '../../data/xdao/thread.dart';
import '../../utils/throttle.dart';
import '../../utils/xdao_api.dart';
import '../widget/reply_item.dart';
import 'package:lightdao/ui/widget/navigable_page.dart';

/// 论坛帖子列表页面，实现了NavigablePage接口，可以向其父Scaffold提供自己的抽屉内容。
class ForumPage extends StatefulWidget implements NavigablePage {
  /// 用于与AppPage进行通信的Notifier，在构造时由父组件注入。
  final ValueNotifier<ForumSelection> forumSelectionNotifier;

  const ForumPage({super.key, required this.forumSelectionNotifier});

  @override
  State<ForumPage> createState() => _ForumPageState();

  /// 实现NavigablePage接口的方法，构建并返回此页面的抽屉“内容”列表。
  @override
  List<Widget> buildDrawerContent(BuildContext context) {
    final appState = Provider.of<MyAppState>(context, listen: false);

    void handleSelection(ForumSelection selection) {
      // 更新Notifier的值，这将通过监听器触发ForumPage的状态刷新。
      forumSelectionNotifier.value = selection;
      // 仅在小屏幕（即有模态抽屉）时才关闭抽屉。
      if (Breakpoint.fromMediaQuery(context).window < WindowSize.medium) {
        Navigator.of(context).pop();
      }
    }

    // 使用ValueListenableBuilder确保抽屉内的选中状态可以实时响应变化。
    return [
      ValueListenableBuilder<ForumSelection>(
        valueListenable: forumSelectionNotifier,
        builder: (context, currentSelection, child) {
          // 将所有ExpansionTile直接放在一个Column里，作为内容返回。
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpansionTile(
                initiallyExpanded: true,
                title: Text('常用板块'),
                subtitle: Text('长按进行添加或移除'),
                children: appState.setting.favoredForums
                    .map(
                      (forum) => ListTile(
                        onTap: () => handleSelection(
                          ForumSelection(
                            id: forum.id,
                            name: forum.getShowName(),
                            isTimeline: false,
                          ),
                        ),
                        onLongPress: () => appState.setState(
                          (_) => appState.setting.favoredForums.removeWhere(
                            (f) => f.id == forum.id,
                          ),
                        ),
                        title: HtmlWidget(forum.getShowName()),
                        selected:
                            !currentSelection.isTimeline &&
                            currentSelection.id == forum.id,
                      ),
                    )
                    .toList(),
              ),
              if (appState.fetchTimelinesStatus == SimpleStatus.completed)
                ExpansionTile(
                  initiallyExpanded: currentSelection.isTimeline,
                  title: Text('时间线'),
                  children: appState.setting.cacheTimelines
                      .map(
                        (timeline) => ListTile(
                          onTap: () => handleSelection(
                            ForumSelection(
                              id: timeline.id,
                              name: timeline.getShowName(),
                              isTimeline: true,
                            ),
                          ),
                          title: HtmlWidget(timeline.getShowName()),
                          selected:
                              currentSelection.isTimeline &&
                              currentSelection.id == timeline.id,
                        ),
                      )
                      .toList(),
                ),
              if (appState.fetchForumsStatus == SimpleStatus.completed)
                ...appState.setting.cacheForumLists.map(
                  (forumList) => ExpansionTile(
                    initiallyExpanded:
                        !currentSelection.isTimeline &&
                        forumList.forums.any(
                          (f) => f.id == currentSelection.id,
                        ),
                    title: HtmlWidget(forumList.name),
                    children: forumList.forums
                        .map(
                          (forum) => ListTile(
                            onTap: () => handleSelection(
                              ForumSelection(
                                id: forum.id,
                                name: forum.getShowName(),
                                isTimeline: false,
                              ),
                            ),
                            onLongPress: () {
                              if (!appState.setting.favoredForums.any(
                                (f) => f.id == forum.id,
                              )) {
                                appState.setState(
                                  (_) =>
                                      appState.setting.favoredForums.add(forum),
                                );
                              }
                            },
                            title: HtmlWidget(forum.getShowName()),
                            selected:
                                !currentSelection.isTimeline &&
                                currentSelection.id == forum.id,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }
}

class _ForumPageState extends State<ForumPage> {
  int _currentPage = 1;
  int _lastBuildingReplyIndex = -1;
  final Set<int> _threadIds = {};
  List<ThreadJson> _posts = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final _preFetchThrottle = Throttle(
    interval: const Duration(microseconds: 300),
  );

  XFile? _postImageFile;
  final _postTextControler = TextEditingController();
  final _postTitleControler = TextEditingController();
  final _postAuthorControler = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 关键：监听来自AppPage的Notifier，当其值改变时，刷新页面数据。
    widget.forumSelectionNotifier.addListener(_onForumSelectionChanged);
    // 初始加载
    _fetchPosts();
    // 监听滚动，用于实现无限加载
    _scrollController.addListener(() {
      _preFetchThrottle.run(() async {
        if (_scrollController.position.pixels +
                    MediaQuery.of(context).size.height * 2 >=
                _scrollController.position.maxScrollExtent &&
            !_isLoading) {
          _loadMorePosts();
        }
      });
    });
  }

  /// 当板块选择变化时调用的回调函数。
  void _onForumSelectionChanged() {
    // 确保刷新操作在build方法之外执行，避免UI构建冲突。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _flushPosts();
        _fetchPosts();
      }
    });
  }

  /// 清空帖子列表和相关状态。
  void _flushPosts() {
    if (!mounted) return;
    setState(() {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _lastBuildingReplyIndex = -1;
      _threadIds.clear();
      _posts.clear();
      _isLoading = false;
      _currentPage = 1;
    });
  }

  /// 从API获取帖子数据。
  Future<void> _fetchPosts() async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);

    // 从Notifier获取当前需要加载的板块信息。
    final selection = widget.forumSelectionNotifier.value;
    final appState = Provider.of<MyAppState>(context, listen: false);

    try {
      late List<ThreadJson> newPosts;
      if (selection.isTimeline) {
        newPosts = await fetchTimelineThreads(
          selection.id,
          _currentPage,
          appState.getCurrentCookie(),
        );
      } else {
        newPosts = await fetchForumThreads(
          selection.id,
          _currentPage,
          appState.getCurrentCookie(),
        );
      }

      if (appState.setting.dontShowFilttedForumInTimeLine) {
        newPosts = newPosts.where((thread) {
          final result = appState.filterTimeLineThread(thread);
          return !(result.$1 == true && result.$2 is ForumThreadFilter);
        }).toList();
      }

      if (mounted) {
        setState(() {
          _posts.addAll(
            newPosts.where((thread) => !_threadIds.contains(thread.id)),
          );
          _threadIds.addAll(newPosts.map((thread) => thread.id));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("错误: ${e.toString()}")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMorePosts() async {
    _currentPage++;
    await _fetchPosts();
  }

  Future<void> _showSearchDialog() async {
    final appState = Provider.of<MyAppState>(context, listen: false);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextEditingController searchThreadIdController =
            TextEditingController();
        bool isValidThreadId = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void onTextChanged(String value) {
              final valid = RegExp(r'^[1-9]\d*$').hasMatch(value.trim());
              if (valid != isValidThreadId) {
                setDialogState(() => isValidThreadId = valid);
              }
            }

            return AlertDialog(
              title: const Text('搜索/跳转'),
              content: TextField(
                controller: searchThreadIdController,
                decoration: const InputDecoration(hintText: "串号或搜索词"),
                autofocus: true,
                onChanged: onTextChanged,
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: <Widget>[
                TextButton(
                  onPressed: isValidThreadId
                      ? () {
                          final String inputText = searchThreadIdController.text
                              .trim();
                          final int? threadId = int.tryParse(inputText);
                          if (threadId != null) {
                            appState.navigateThreadPage2(
                              context,
                              threadId,
                              true,
                            );
                          }
                        }
                      : null,
                  child: Text(
                    isValidThreadId
                        ? '跳转到No.${searchThreadIdController.text.trim()}'
                        : '跳转',
                  ),
                ),
                TextButton(
                  onPressed: searchThreadIdController.text.trim().isEmpty
                      ? null
                      : () {
                          final String inputText = searchThreadIdController.text
                              .trim();
                          Navigator.of(dialogContext).pop();
                          Navigator.push(
                            context,
                            appState.createPageRoute(
                              builder: (context) =>
                                  SearchPage(query: inputText),
                            ),
                          );
                        },
                  child: const Text('搜索(需科学上网)'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    // 组件销毁时，务必移除监听器，防止内存泄漏。
    widget.forumSelectionNotifier.removeListener(_onForumSelectionChanged);
    _scrollController.dispose();
    _postTextControler.dispose();
    _postTitleControler.dispose();
    _postAuthorControler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);

    // 使用ValueListenableBuilder来确保整个页面在板块选择变化时能够正确重构。
    return ValueListenableBuilder<ForumSelection>(
      valueListenable: widget.forumSelectionNotifier,
      builder: (context, currentSelection, child) {
        final forumInfo = currentSelection.isTimeline
            ? appState.setting.cacheTimelines
                  .firstWhere(
                    (t) => t.id == currentSelection.id,
                    orElse: () => Timeline(
                      id: -1,
                      name: '',
                      notice: '未获取到公告！',
                      displayName: '',
                      maxPage: 20,
                    ),
                  )
                  .notice
            : appState.forumMap[currentSelection.id]?.msg ?? '';

        return SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final forumRowCount = appState.setting.isMultiColumn
                  ? (constraints.maxWidth / appState.setting.columnWidth)
                            .toInt() +
                        1
                  : 1;
              final initSkeletonizerCount = forumRowCount * 7;

              return RefreshIndicator(
                onRefresh: () async {
                  _flushPosts();
                  await _fetchPosts();
                },
                edgeOffset: 100, // 适配SliverAppBar的高度
                child: CustomScrollView(
                  // 使用包含板块ID的Key，确保在切换板块时能重置滚动状态。
                  key: PageStorageKey(
                    'CustomScrollViewInForumPage_${currentSelection.id}',
                  ),
                  physics: _posts.isNotEmpty
                      ? const AlwaysScrollableScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      surfaceTintColor: Colors.transparent,
                      toolbarHeight: breakpoint.window >= WindowSize.small
                          ? kToolbarHeight + 20
                          : kToolbarHeight,
                      leading: breakpoint.window < WindowSize.small
                          ? IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            )
                          : null,
                      automaticallyImplyLeading: false,
                      pinned:
                          appState.setting.fixedBottomBar ||
                          breakpoint.window >= WindowSize.small,
                      snap: false,
                      floating: breakpoint.window < WindowSize.small,
                      actions: [
                        if (_isLoading)
                          IconButton(
                            onPressed: _onForumSelectionChanged,
                            icon: const Icon(Icons.refresh),
                          ),
                        if (forumInfo.trim() != '')
                          IconButton(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('版规'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 150,
                                  child: FadingScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SelectionArea(
                                          child: HtmlWidget(forumInfo),
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text('了解'),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            ),
                            icon: const Icon(Icons.info),
                          ),
                        IconButton(
                          onPressed: _showSearchDialog,
                          icon: const Icon(Icons.search),
                        ),
                        if (breakpoint.window >= WindowSize.small)
                          FloatingActionButton.extended(
                            elevation: 0,
                            onPressed: () => showReplyBottomSheet(
                              context,
                              true,
                              currentSelection.isTimeline
                                  ? appState.forumMap.values
                                        .firstWhere(
                                          (forum) => forum.name == "综合版1",
                                          orElse: () =>
                                              appState.forumMap.values.first,
                                        )
                                        .id
                                  : currentSelection.id,
                              -1,
                              fakeThread,
                              _postImageFile,
                              (image) => _postImageFile = image,
                              _postTitleControler,
                              _postAuthorControler,
                              _postTextControler,
                              _onForumSelectionChanged,
                            ),
                            tooltip: '发串',
                            label: const Text('发串'),
                            icon: const Icon(Icons.edit),
                          ),
                        SizedBox(width: breakpoint.gutters),
                      ],
                      title: GestureDetector(
                        onTap: () async {
                          if (_scrollController.hasClients) {
                            await _scrollController.animateTo(
                              0,
                              duration: Durations.medium1,
                              curve: Curves.linearToEaseOut,
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HtmlWidget(currentSelection.name),
                                Text(
                                  'X岛・nmbxd.com',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                              ],
                            ),
                            Expanded(child: Container()),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        right: breakpoint.gutters - 2,
                        left: breakpoint.window > WindowSize.xsmall
                            ? 0
                            : breakpoint.gutters - 2,
                      ),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: forumRowCount,
                        itemBuilder: (context, index) {
                          if (index < _posts.length) {
                            var mustCollapsed = false;
                            if (_lastBuildingReplyIndex > 0 &&
                                _lastBuildingReplyIndex > index)
                              mustCollapsed = true;
                            _lastBuildingReplyIndex = index;

                            final post = _posts[index];
                            final replyItem = ReplyItem(
                              inCardView: appState.setting.isCardView,
                              collapsedRef: mustCollapsed,
                              isThreadFirstOrForumPreview: true,
                              contentNeedCollapsed: true,
                              threadJson: post,
                              contentHeroTag: 'ThreadCard ${post.id}',
                              imageHeroTag: 'Image ${post.img}${post.ext}',
                              cacheImageSize: true,
                            );
                            onTapThread() => appState.navigateThreadPage2(
                              context,
                              post.id,
                              false,
                              thread: post,
                            );

                            onLongPressThread() => showDialog(
                              context: context,
                              builder: (BuildContext context) => SimpleDialog(
                                title: const Text('屏蔽操作'),
                                children: [
                                  SimpleDialogOption(
                                    child: Text('屏蔽串No.${post.id}'),
                                    onPressed: () {
                                      if (!appState.setting.threadFilters.any(
                                        (f) =>
                                            f is IdThreadFilter &&
                                            f.id == post.id,
                                      )) {
                                        appState.setState(
                                          (_) => appState.setting.threadFilters
                                              .add(IdThreadFilter(id: post.id)),
                                        );
                                      }
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  SimpleDialogOption(
                                    child: Text('屏蔽饼干${post.userHash}'),
                                    onPressed: () {
                                      if (!appState.setting.threadFilters.any(
                                        (f) =>
                                            f is UserHashFilter &&
                                            f.userHash == post.userHash,
                                      )) {
                                        appState.setState(
                                          (_) => appState.setting.threadFilters
                                              .add(
                                                UserHashFilter(
                                                  userHash: post.userHash,
                                                ),
                                              ),
                                        );
                                      }
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  if (currentSelection.isTimeline)
                                    SimpleDialogOption(
                                      child: Text(
                                        '在时间线屏蔽${appState.forumMap[post.fid]?.getShowName() ?? '(版面id: ${post.fid})'}',
                                      ),
                                      onPressed: () {
                                        if (!appState.setting.threadFilters.any(
                                          (f) =>
                                              f is ForumThreadFilter &&
                                              f.fid == post.fid,
                                        )) {
                                          appState.setState(
                                            (_) => appState
                                                .setting
                                                .threadFilters
                                                .add(
                                                  ForumThreadFilter(
                                                    fid: post.fid,
                                                  ),
                                                ),
                                          );
                                        }
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                ],
                              ),
                            );

                            final replyActionBar = appState.setting.isCardView
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            IconButton.filledTonal(
                                              onPressed: onLongPressThread,
                                              icon: Icon(Icons.more_vert),
                                            ),
                                            IconButton.filledTonal(
                                              onPressed: () async =>
                                                  await Share.share(
                                                    'https://www.nmbxd1.com/t/${_posts[index].id}',
                                                  ),
                                              icon: Icon(Icons.share),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton.filledTonal(
                                        onPressed: () {
                                          if (appState.isStared(
                                            _posts[index].id,
                                          )) {
                                            appState.setState((_) {
                                              appState.setting.starHistory
                                                  .removeWhere(
                                                    (rply) =>
                                                        rply.thread.id ==
                                                        _posts[index].id,
                                                  );
                                            });
                                          } else {
                                            appState.setState((_) {
                                              final history = appState
                                                  .setting
                                                  .viewHistory
                                                  .get(_posts[index].id);
                                              if (history != null) {
                                                appState.setting.starHistory
                                                    .add(history);
                                              } else {
                                                appState.setting.starHistory
                                                    .add(
                                                      ReplyJsonWithPage(
                                                        1,
                                                        0,
                                                        _posts[index].id,
                                                        _posts[index],
                                                        _posts[index],
                                                      ),
                                                    );
                                              }
                                            });
                                          }
                                        },
                                        icon: Icon(
                                          appState.isStared(_posts[index].id)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                        ),
                                      ),
                                      IconButton.filledTonal(
                                        onPressed: () =>
                                            appState.navigateThreadPage2(
                                              context,
                                              _posts[index].id,
                                              false,
                                              thread: _posts[index],
                                            ),
                                        icon: _posts[index].replyCount == 0
                                            ? Icon(Icons.message)
                                            : Badge(
                                                backgroundColor: Theme.of(
                                                  context,
                                                ).colorScheme.surfaceContainer,
                                                textColor: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                                label: Text(
                                                  _posts[index].replyCount
                                                      .toString(),
                                                ),
                                                child: Icon(Icons.message),
                                              ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async => await Share.share(
                                            'https://www.nmbxd1.com/t/${_posts[index].id}',
                                          ),
                                          child: SizedBox(
                                            height: 35,
                                            child: Row(
                                              children: [
                                                Spacer(),
                                                Icon(
                                                  Icons.share,
                                                  size: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.fontSize,
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                ),
                                                Text('分享'),
                                                Spacer(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () {
                                            if (appState.isStared(
                                              _posts[index].id,
                                            )) {
                                              appState.setState((_) {
                                                appState.setting.starHistory
                                                    .removeWhere(
                                                      (rply) =>
                                                          rply.thread.id ==
                                                          _posts[index].id,
                                                    );
                                              });
                                            } else {
                                              appState.setState((_) {
                                                final history = appState
                                                    .setting
                                                    .viewHistory
                                                    .get(_posts[index].id);
                                                if (history != null) {
                                                  appState.setting.starHistory
                                                      .add(history);
                                                } else {
                                                  appState.setting.starHistory
                                                      .add(
                                                        ReplyJsonWithPage(
                                                          1,
                                                          0,
                                                          _posts[index].id,
                                                          _posts[index],
                                                          _posts[index],
                                                        ),
                                                      );
                                                }
                                              });
                                            }
                                          },
                                          child: SizedBox(
                                            height: 35,
                                            child: Row(
                                              children: [
                                                Spacer(),
                                                Icon(
                                                  appState.isStared(
                                                        _posts[index].id,
                                                      )
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.fontSize,
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                ),
                                                Text('收藏'),
                                                Spacer(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: SizedBox(
                                          height: 35,
                                          child: Row(
                                            children: [
                                              Spacer(),
                                              Icon(
                                                Icons.message,
                                                size: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.fontSize,
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 2,
                                                    ),
                                              ),
                                              Text(
                                                _posts[index].replyCount == 0
                                                    ? '评论'
                                                    : _posts[index].replyCount
                                                          .toString(),
                                              ),
                                              Spacer(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );

                            return Column(
                              children: [
                                if (!appState.setting.isCardView)
                                  InkWell(
                                    onTap: onTapThread,
                                    onLongPress: onLongPressThread,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        left: 10,
                                        right: 10,
                                      ),
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: FilterableThreadWidget(
                                          reply: post,
                                          isTimeLineFilter:
                                              currentSelection.isTimeline,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              replyItem,
                                              if (currentSelection.isTimeline)
                                                ActionChip(
                                                  onPressed: () {
                                                    final targetForum = appState
                                                        .forumMap[post.fid];
                                                    if (targetForum != null) {
                                                      widget
                                                          .forumSelectionNotifier
                                                          .value = ForumSelection(
                                                        id: targetForum.id,
                                                        name: targetForum
                                                            .getShowName(),
                                                        isTimeline: false,
                                                      );
                                                    }
                                                  },
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainer,
                                                  padding: EdgeInsets.zero,
                                                  labelStyle: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall,
                                                  label: HtmlWidget(
                                                    appState.forumMap[post.fid]
                                                            ?.getShowName() ??
                                                        '',
                                                  ),
                                                ),
                                              replyActionBar,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Material(
                                    type: MaterialType.transparency,
                                    child: Card(
                                      shadowColor: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          12.0,
                                        ),
                                        onTap: onTapThread,
                                        onLongPress: onLongPressThread,
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                            breakpoint.gutters,
                                          ),
                                          child: Material(
                                            type: MaterialType.transparency,
                                            child: FilterableThreadWidget(
                                              reply: post,
                                              isTimeLineFilter:
                                                  currentSelection.isTimeline,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  replyItem,
                                                  SizedBox(
                                                    height:
                                                        currentSelection
                                                            .isTimeline
                                                        ? 5
                                                        : 10,
                                                  ),
                                                  if (currentSelection
                                                      .isTimeline)
                                                    ActionChip(
                                                      onPressed: () {
                                                        final targetForum =
                                                            appState
                                                                .forumMap[post
                                                                .fid];
                                                        if (targetForum !=
                                                            null) {
                                                          widget
                                                              .forumSelectionNotifier
                                                              .value = ForumSelection(
                                                            id: targetForum.id,
                                                            name: targetForum
                                                                .getShowName(),
                                                            isTimeline: false,
                                                          );
                                                        }
                                                      },
                                                      backgroundColor:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .surfaceContainer,
                                                      padding: EdgeInsets.zero,
                                                      labelStyle: Theme.of(
                                                        context,
                                                      ).textTheme.labelSmall,
                                                      label: HtmlWidget(
                                                        appState
                                                                .forumMap[post
                                                                    .fid]
                                                                ?.getShowName() ??
                                                            '',
                                                      ),
                                                    ),
                                                  replyActionBar,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (index != _posts.length - 1 &&
                                    !appState.setting.isCardView)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: const Divider(height: 2),
                                  ),
                              ],
                            );
                          } else {
                            return Skeletonizer(
                              effect: ShimmerEffect(
                                baseColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer.withAlpha(70),
                                highlightColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer.withAlpha(50),
                              ),
                              enabled: true,
                              child: Column(
                                children: [
                                  if (!appState.setting.isCardView)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 10,
                                        bottom: 15,
                                        left: 10,
                                        right: 10,
                                      ),
                                      child: ReplyItem(
                                        contentNeedCollapsed: false,
                                        threadJson: fakeThread,
                                      ),
                                    )
                                  else
                                    Card(
                                      shadowColor: Colors.transparent,
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          breakpoint.gutters,
                                        ),
                                        child: ReplyItem(
                                          inCardView: true,
                                          contentNeedCollapsed: false,
                                          threadJson: fakeThread,
                                        ),
                                      ),
                                    ),
                                  if (!appState.setting.isCardView)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Divider(height: 2),
                                    ),
                                ],
                              ),
                            );
                          }
                        },
                        childCount:
                            1 +
                            _posts.length +
                            (_posts.isNotEmpty ? 1 : initSkeletonizerCount),
                        mainAxisSpacing: breakpoint.gutters * 1.5 / 2,
                        crossAxisSpacing: breakpoint.gutters * 1.5 / 2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
