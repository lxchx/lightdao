import 'dart:async';
import 'package:flutter/material.dart';
import 'package:breakpoint/breakpoint.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/ui/page/search.dart';
import 'package:lightdao/ui/widget/fading_scroll_view.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/ui/widget/util_funtions.dart';
import 'package:lightdao/utils/page_manager.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lightdao/data/xdao/timeline.dart';
import 'package:lightdao/utils/status.dart';

import '../../data/setting.dart';
import '../../data/xdao/thread.dart';
import '../widget/reply_item.dart';
import 'package:lightdao/ui/widget/scaffold_accessory_builder.dart';

/// 一个数据类，用于封装AppPage和ForumPage之间传递的板块选择信息。
class ForumSelection {
  final int id;
  final String name;
  final bool isTimeline;

  const ForumSelection({
    required this.id,
    required this.name,
    required this.isTimeline,
  });
}

class ForumPage extends StatefulWidget {
  final ValueNotifier<ForumSelection> forumSelectionNotifier;
  final VoidCallback? scaffoldSetState;

  const ForumPage({
    super.key,
    required this.forumSelectionNotifier,
    this.scaffoldSetState,
  });

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends ScaffoldAccessoryBuilder<ForumPage> {
  late PageManager<ThreadJson> _pageManager;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  int _lastBuildingReplyIndex = -1;
  late ForumSelection _currentSelection;

  XFile? _postImageFile;
  final _postTextControler = TextEditingController();
  final _postTitleControler = TextEditingController();
  final _postAuthorControler = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.forumSelectionNotifier.addListener(_onForumSelectionChanged);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _currentSelection = widget.forumSelectionNotifier.value;
      _initializePageManager();
      _isInitialized = true;
    }
  }

  void _scrollListener() {
    if (_isInitialized &&
        _scrollController.position.pixels +
                MediaQuery.of(context).size.height * 1.5 >=
            _scrollController.position.maxScrollExtent) {
      _pageManager.tryLoadNextPage();
    }
  }

  void _onForumSelectionChanged() {
    final newSelection = widget.forumSelectionNotifier.value;
    if (newSelection.id == _currentSelection.id &&
        newSelection.isTimeline == _currentSelection.isTimeline) {
      return;
    }
    _currentSelection = newSelection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollController.jumpTo(0);
      if (mounted) _initializePageManager();
    });
  }

  void _initializePageManager() {
    final selection = widget.forumSelectionNotifier.value;
    final appState = Provider.of<MyAppState>(context, listen: false);

    if (_isInitialized) {
      _pageManager.nextPageStateNotifier.removeListener(_onPageStateChanged);
    }

    _lastBuildingReplyIndex = -1;

    if (selection.isTimeline) {
      final timeline = appState.setting.cacheTimelines.firstWhere(
        (t) => t.id == selection.id,
        orElse: () => Timeline(
          id: selection.id,
          name: selection.name,
          displayName: '',
          notice: '',
          maxPage: 20,
        ),
      );
      _pageManager = TimelinePageManager(
        timelineId: selection.id,
        maxPage: timeline.maxPage,
        cookie: appState.getCurrentCookie(),
      );
    } else {
      _pageManager = ForumPageManager(
        forumId: selection.id,
        cookie: appState.getCurrentCookie(),
      );
    }

    _pageManager.nextPageStateNotifier.addListener(_onPageStateChanged);
    _pageManager.initialize();

    if (mounted) setState(() {});
  }

  void _onPageStateChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      if (widget.scaffoldSetState != null) {
        widget.scaffoldSetState!();
      }
    });
  }

  @override
  void dispose() {
    widget.forumSelectionNotifier.removeListener(_onForumSelectionChanged);
    if (_isInitialized) {
      _pageManager.nextPageStateNotifier.removeListener(_onPageStateChanged);
    }
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _postTextControler.dispose();
    _postTitleControler.dispose();
    _postAuthorControler.dispose();
    super.dispose();
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
              } else {
                setDialogState(() {});
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
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);

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
                      displayName: '',
                      notice: '公告获取失败！',
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

              return RefreshIndicator(
                onRefresh: () async {
                  _initializePageManager();
                },
                edgeOffset: 100,
                child: ValueListenableBuilder(
                  valueListenable: _pageManager.nextPageStateNotifier,
                  builder: (context, value, child) {
                    return CustomScrollView(
                      physics: value is PageLoading && _pageManager.isEmpty
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      key: PageStorageKey(
                        'CustomScrollViewInForumPage_${currentSelection.id}',
                      ),
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
                                              orElse: () => appState
                                                  .forumMap
                                                  .values
                                                  .first,
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
                                  () => _initializePageManager(),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
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
                        Builder(
                          builder: (context) {
                            if (_pageManager.isEmpty && value is PageError) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('加载失败: ${value.error}'),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: value.retry,
                                        child: const Text('重试'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            if (_pageManager.isEmpty &&
                                value is PageFullLoaded) {
                              return const SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(48.0),
                                    child: Text(
                                      "这里什么都没有... ( ´_ゝ`)",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return SliverPadding(
                              padding: EdgeInsets.all(breakpoint.gutters),
                              sliver: SliverMasonryGrid.count(
                                crossAxisCount: forumRowCount,
                                mainAxisSpacing: breakpoint.gutters,
                                crossAxisSpacing: breakpoint.gutters,
                                childCount:
                                    _pageManager.totalItemsCount +
                                    (_pageManager.nextPageStateNotifier.value
                                            is! PageLoading
                                        ? 0
                                        : _pageManager.isEmpty
                                        ? 7 * forumRowCount
                                        : 1), // 追加表示Loadding的骨架reply
                                itemBuilder: (context, index) {
                                  if (index < _pageManager.totalItemsCount) {
                                    var mustCollapsed = false;
                                    if (_lastBuildingReplyIndex > 0 &&
                                        _lastBuildingReplyIndex >= index) {
                                      mustCollapsed = true;
                                    }
                                    _lastBuildingReplyIndex = index;

                                    final item = _pageManager.getItemByIndex(
                                      index,
                                    );
                                    if (item == null) return const SizedBox();
                                    final post = item.$1;
                                    final replyItem = Theme(
                                      data: Theme.of(context).copyWith(
                                        textTheme: Theme.of(context).textTheme
                                            .apply(
                                              fontSizeFactor: appState
                                                  .setting
                                                  .forumFontSizeFactor,
                                            ),
                                      ),
                                      child: ReplyItem(
                                        inCardView: appState.setting.isCardView,
                                        collapsedRef: mustCollapsed,
                                        isThreadFirstOrForumPreview: true,
                                        contentNeedCollapsed: true,
                                        threadJson: post,
                                        contentHeroTag: 'ThreadCard ${post.id}',
                                        imageHeroTag:
                                            'Image ${post.img}${post.ext}',
                                        cacheImageSize: true,
                                      ),
                                    );
                                    onTapThread() =>
                                        appState.navigateThreadPage2(
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
                                          if (post.userHash != 'Tips')
                                            SimpleDialogOption(
                                              child: Text('屏蔽串No.${post.id}'),
                                              onPressed: () {
                                                if (!appState
                                                    .setting
                                                    .threadFilters
                                                    .any(
                                                      (f) =>
                                                          f is IdThreadFilter &&
                                                          f.id == post.id,
                                                    )) {
                                                  appState.setState(
                                                    (_) => appState
                                                        .setting
                                                        .threadFilters
                                                        .add(
                                                          IdThreadFilter(
                                                            id: post.id,
                                                          ),
                                                        ),
                                                  );
                                                }
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          if (post.userHash != 'Tips')
                                            SimpleDialogOption(
                                              child: Text(
                                                '屏蔽饼干${post.userHash}',
                                              ),
                                              onPressed: () {
                                                if (!appState
                                                    .setting
                                                    .threadFilters
                                                    .any(
                                                      (f) =>
                                                          f is UserHashFilter &&
                                                          f.userHash ==
                                                              post.userHash,
                                                    )) {
                                                  appState.setState(
                                                    (_) => appState
                                                        .setting
                                                        .threadFilters
                                                        .add(
                                                          UserHashFilter(
                                                            userHash:
                                                                post.userHash,
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
                                                if (!appState
                                                    .setting
                                                    .threadFilters
                                                    .any(
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

                                    final replyActionBar =
                                        appState.setting.isCardView
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  children: [
                                                    IconButton.filledTonal(
                                                      onPressed:
                                                          onLongPressThread,
                                                      icon: Icon(
                                                        Icons.more_vert,
                                                      ),
                                                    ),
                                                    IconButton.filledTonal(
                                                      onPressed: () async =>
                                                          await Share.share(
                                                            'https://www.nmbxd1.com/t/${post.id}',
                                                          ),
                                                      icon: Icon(Icons.share),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton.filledTonal(
                                                onPressed: () {
                                                  if (appState.isStared(
                                                    post.id,
                                                  )) {
                                                    appState.setState((_) {
                                                      appState
                                                          .setting
                                                          .starHistory
                                                          .removeWhere(
                                                            (rply) =>
                                                                rply
                                                                    .thread
                                                                    .id ==
                                                                post.id,
                                                          );
                                                    });
                                                  } else {
                                                    appState.setState((_) {
                                                      final history = appState
                                                          .setting
                                                          .viewHistory
                                                          .get(post.id);
                                                      if (history != null) {
                                                        appState
                                                            .setting
                                                            .starHistory
                                                            .add(history);
                                                      } else {
                                                        appState
                                                            .setting
                                                            .starHistory
                                                            .add(
                                                              ReplyJsonWithPage(
                                                                1,
                                                                0,
                                                                post.id,
                                                                post,
                                                                post,
                                                              ),
                                                            );
                                                      }
                                                    });
                                                  }
                                                },
                                                icon: Icon(
                                                  appState.isStared(post.id)
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                ),
                                              ),
                                              IconButton.filledTonal(
                                                onPressed: () => appState
                                                    .navigateThreadPage2(
                                                      context,
                                                      post.id,
                                                      false,
                                                      thread: post,
                                                    ),
                                                icon: post.replyCount == 0
                                                    ? Icon(Icons.message)
                                                    : Badge(
                                                        backgroundColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .surfaceContainer,
                                                        textColor: Theme.of(context)
                                                            .colorScheme
                                                            .onPrimaryContainer,
                                                        label: Text(
                                                          post.replyCount
                                                              .toString(),
                                                        ),
                                                        child: Icon(
                                                          Icons.message,
                                                        ),
                                                      ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () async =>
                                                      await Share.share(
                                                        'https://www.nmbxd1.com/t/${post.id}',
                                                      ),
                                                  child: SizedBox(
                                                    height: 35,
                                                    child: Row(
                                                      children: [
                                                        Spacer(),
                                                        Icon(
                                                          Icons.share,
                                                          size:
                                                              Theme.of(context)
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
                                                      post.id,
                                                    )) {
                                                      appState.setState((_) {
                                                        appState
                                                            .setting
                                                            .starHistory
                                                            .removeWhere(
                                                              (rply) =>
                                                                  rply
                                                                      .thread
                                                                      .id ==
                                                                  post.id,
                                                            );
                                                      });
                                                    } else {
                                                      appState.setState((_) {
                                                        final history = appState
                                                            .setting
                                                            .viewHistory
                                                            .get(post.id);
                                                        if (history != null) {
                                                          appState
                                                              .setting
                                                              .starHistory
                                                              .add(history);
                                                        } else {
                                                          appState
                                                              .setting
                                                              .starHistory
                                                              .add(
                                                                ReplyJsonWithPage(
                                                                  1,
                                                                  0,
                                                                  post.id,
                                                                  post,
                                                                  post,
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
                                                                post.id,
                                                              )
                                                              ? Icons.favorite
                                                              : Icons
                                                                    .favorite_border,
                                                          size:
                                                              Theme.of(context)
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
                                                        post.replyCount == 0
                                                            ? '评论'
                                                            : post.replyCount
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
                                                      currentSelection
                                                          .isTimeline,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      replyItem,
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
                                                                id: targetForum
                                                                    .id,
                                                                name: targetForum
                                                                    .getShowName(),
                                                                isTimeline:
                                                                    false,
                                                              );
                                                            }
                                                          },
                                                          backgroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surfaceContainer,
                                                          padding:
                                                              EdgeInsets.zero,
                                                          labelStyle:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelSmall,
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
                                          )
                                        else
                                          Material(
                                            type: MaterialType.transparency,
                                            child: Card(
                                              shadowColor: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                                onTap: onTapThread,
                                                onLongPress: onLongPressThread,
                                                child: Padding(
                                                  padding: EdgeInsets.all(
                                                    breakpoint.gutters,
                                                  ),
                                                  child: Material(
                                                    type: MaterialType
                                                        .transparency,
                                                    child: FilterableThreadWidget(
                                                      reply: post,
                                                      isTimeLineFilter:
                                                          currentSelection
                                                              .isTimeline,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
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
                                                                    id: targetForum
                                                                        .id,
                                                                    name: targetForum
                                                                        .getShowName(),
                                                                    isTimeline:
                                                                        false,
                                                                  );
                                                                }
                                                              },
                                                              backgroundColor:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .surfaceContainer,
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              labelStyle:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .labelSmall,
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
                                        if (index !=
                                                _pageManager.totalItemsCount -
                                                    1 &&
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
                                        baseColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withAlpha(70),
                                        highlightColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withAlpha(50),
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
                                              child: Theme(
                                                data: Theme.of(context).copyWith(
                                                  textTheme: Theme.of(context)
                                                      .textTheme
                                                      .apply(
                                                        fontSizeFactor: appState
                                                            .setting
                                                            .forumFontSizeFactor,
                                                      ),
                                                ),
                                                child: ReplyItem(
                                                  contentNeedCollapsed: false,
                                                  threadJson: fakeThread,
                                                ),
                                              ),
                                            )
                                          else
                                            Card(
                                              shadowColor: Colors.transparent,
                                              child: Padding(
                                                padding: EdgeInsets.all(
                                                  breakpoint.gutters,
                                                ),
                                                child: Theme(
                                                  data: Theme.of(context).copyWith(
                                                    textTheme: Theme.of(context)
                                                        .textTheme
                                                        .apply(
                                                          fontSizeFactor: appState
                                                              .setting
                                                              .forumFontSizeFactor,
                                                        ),
                                                  ),
                                                  child: ReplyItem(
                                                    inCardView: true,
                                                    contentNeedCollapsed: false,
                                                    threadJson: fakeThread,
                                                  ),
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
                              ),
                            );
                          },
                        ),
                        SliverToBoxAdapter(
                          child: ValueListenableBuilder<PageState>(
                            valueListenable: _pageManager.nextPageStateNotifier,
                            builder: (context, state, child) {
                              if (_pageManager.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              Widget content;
                              switch (state) {
                                case PageLoading():
                                  return const SizedBox.shrink();
                                case PageFullLoaded():
                                  content = Center(
                                    child: Text(
                                      "--- 已到达世界的尽头 ---",
                                      style: TextStyle(
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  );
                                case PageError(
                                  error: final err,
                                  retry: final retry,
                                ):
                                  content = Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          "加载更多失败: $err",
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: retry,
                                          child: const Text('重试'),
                                        ),
                                      ],
                                    ),
                                  );
                                case PageHasMore():
                                  return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: breakpoint.gutters,
                                ),
                                child: content,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  List<Widget> buildDrawerContent(BuildContext context) {
    final appState = Provider.of<MyAppState>(context, listen: false);

    void handleSelection(ForumSelection selection) {
      final currentSelection = widget.forumSelectionNotifier.value;
      if (selection.id == currentSelection.id &&
          selection.isTimeline == currentSelection.isTimeline) {
        return;
      }
      widget.forumSelectionNotifier.value = selection;
      if (Breakpoint.fromMediaQuery(context).window < WindowSize.medium) {
        Navigator.of(context).pop();
      }
    }

    return [
      ValueListenableBuilder<ForumSelection>(
        valueListenable: widget.forumSelectionNotifier,
        builder: (context, currentSelection, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HookBuilder(
                builder: (context) {
                  final isReordering = useState(false);

                  return ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text('常用板块'),
                    subtitle: Text(
                      isReordering.value ? '可拖动滑柄排序' : '长按板块来添加或删除',
                    ),
                    children: <Widget>[
                      if (isReordering.value)
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          onReorder: (oldIndex, newIndex) {
                            appState.setState((_) {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = appState.setting.favoredItems
                                  .removeAt(oldIndex);
                              appState.setting.favoredItems.insert(
                                newIndex,
                                item,
                              );
                            });
                          },
                          children: appState.setting.favoredItems.map((item) {
                            final String name;
                            if (item.type == FavoredItemType.forum) {
                              name =
                                  appState.forumMap[item.id]?.getShowName() ??
                                  '未知板块';
                            } else {
                              name = appState.setting.cacheTimelines
                                  .firstWhere(
                                    (t) => t.id == item.id,
                                    orElse: () => Timeline(
                                      id: -1,
                                      name: '未知时间线',
                                      displayName: '',
                                      notice: '',
                                      maxPage: 0,
                                    ),
                                  )
                                  .getShowName();
                            }
                            return ListTile(
                              key: ValueKey('${item.type}-${item.id}'),
                              title: HtmlWidget(name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => appState.setState(
                                      (_) => appState.setting.favoredItems
                                          .removeWhere(
                                            (i) =>
                                                i.id == item.id &&
                                                i.type == item.type,
                                          ),
                                    ),
                                  ),
                                  ReorderableDragStartListener(
                                    index: appState.setting.favoredItems
                                        .indexOf(item),
                                    child: const Icon(Icons.drag_indicator),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      else
                        ...appState.setting.favoredItems.map((item) {
                          final String name;
                          final bool isTimeline;
                          if (item.type == FavoredItemType.forum) {
                            name =
                                appState.forumMap[item.id]?.getShowName() ??
                                '未知板块';
                            isTimeline = false;
                          } else {
                            name = appState.setting.cacheTimelines
                                .firstWhere(
                                  (t) => t.id == item.id,
                                  orElse: () => Timeline(
                                    id: -1,
                                    name: '未知时间线',
                                    displayName: '',
                                    notice: '',
                                    maxPage: 0,
                                  ),
                                )
                                .getShowName();
                            isTimeline = true;
                          }
                          return ListTile(
                            onTap: () => handleSelection(
                              ForumSelection(
                                id: item.id,
                                name: name,
                                isTimeline: isTimeline,
                              ),
                            ),
                            onLongPress: () => isReordering.value = true,
                            title: HtmlWidget(name),
                            selected:
                                currentSelection.isTimeline == isTimeline &&
                                currentSelection.id == item.id,
                          );
                        }),
                      if (isReordering.value)
                        ListTile(
                          textColor: Theme.of(context).colorScheme.secondary,
                          title: Center(
                            child: Text(
                              '完成',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          onTap: () {
                            isReordering.value = !isReordering.value;
                          },
                        ),
                    ],
                  );
                },
              ),
              if (appState.fetchTimelinesStatus == SimpleStatus.completed)
                ExpansionTile(
                  initiallyExpanded: currentSelection.isTimeline,
                  title: const Text('时间线'),
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
                          onLongPress: () {
                            if (!appState.setting.favoredItems.any(
                              (item) =>
                                  item.id == timeline.id &&
                                  item.type == FavoredItemType.timeline,
                            )) {
                              appState.setState(
                                (_) => appState.setting.favoredItems.add(
                                  FavoredItem(
                                    id: timeline.id,
                                    type: FavoredItemType.timeline,
                                  ),
                                ),
                              );
                            }
                          },
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
                              if (!appState.setting.favoredItems.any(
                                (item) =>
                                    item.id == forum.id &&
                                    item.type == FavoredItemType.forum,
                              )) {
                                appState.setState(
                                  (_) => appState.setting.favoredItems.add(
                                    FavoredItem(
                                      id: forum.id,
                                      type: FavoredItemType.forum,
                                    ),
                                  ),
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

  @override
  Widget? buildFloatingActionButton(BuildContext context) {
    if (_pageManager.nextPageStateNotifier.value is PageLoading &&
        _pageManager.isEmpty) {
      return null;
    }
    return ValueListenableBuilder<ForumSelection>(
      valueListenable: widget.forumSelectionNotifier,
      builder: (context, currentSelection, child) {
        final appState = Provider.of<MyAppState>(context, listen: false);
        return FloatingActionButton.extended(
          onPressed: () => showReplyBottomSheet(
            context,
            true,
            currentSelection.isTimeline
                ? appState.forumMap.values
                      .firstWhere(
                        (forum) => forum.name == "综合版1",
                        orElse: () => appState.forumMap.values.first,
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
            () => _initializePageManager(),
          ),
          tooltip: '发串',
          label: const Text('发串'),
          icon: const Icon(Icons.edit),
        );
      },
    );
  }

  @override
  bool onReLocated(BuildContext anchorContext) {
    if (_scrollController.position.pixels != 0) {
      _scrollController.animateTo(
        0,
        duration: Durations.long4,
        curve: Curves.easeOutExpo,
      );
      return true;
    } else {
      return false;
    }
  }
}
