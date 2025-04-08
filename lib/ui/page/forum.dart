import 'dart:async';

import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/ui/page/trend_page.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/status.dart';
import 'package:lightdao/ui/page/more_page.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/ui/widget/util_funtions.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../data/setting.dart';
import '../../data/xdao/thread.dart';
import '../../utils/throttle.dart';
import '../../utils/xdao_api.dart';
import '../widget/reply_item.dart';

class ForumPage extends StatefulWidget {
  @override
  State<ForumPage> createState() => _ForumPageState();
}

class ExampleDestination {
  const ExampleDestination(
      {required this.label, required this.icon, required this.selectedIcon});

  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

const List<ExampleDestination> destinations = <ExampleDestination>[
  ExampleDestination(
    selectedIcon: Icon(Icons.home),
    icon: Icon(Icons.home_outlined),
    label: '板块',
  ),
  ExampleDestination(
    selectedIcon: Icon(Icons.favorite),
    icon: Icon(Icons.favorite_border),
    label: '收藏',
  ),
  ExampleDestination(
    selectedIcon: Icon(Icons.whatshot),
    icon: Icon(Icons.whatshot_outlined),
    label: '趋势',
  ),
  ExampleDestination(
    icon: Icon(Icons.more_horiz),
    selectedIcon: Icon(Icons.more_horiz),
    label: '更多',
  ),
];

class _ForumPageState extends State<ForumPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isTimeline = true;
  int _currentPage = 1;
  int _lastBuildingReplyIndex = -1;
  Set<int> _threadIds = {};
  List<ThreadJson> _posts = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  int _currentForumOrTimelineId = 1;
  String _barName = '综合线';
  int _currentNavigatorIndex = 0;
  bool _isBottomVisible = true;
  final _preFetchThrottle = Throttle(interval: Duration(microseconds: 300));
  final _bottomThrottle = Throttle(interval: Duration(microseconds: 500));
  bool _isOutSideDrawerExpanded = true;
  final trendRefCache = LRUCache<int, Future<RefHtml>>(100);

  XFile? _postImageFile;
  final _postTextControler = TextEditingController();
  final _postTitleControler = TextEditingController();
  final _postAuthorControler = TextEditingController();

  void onDestinationSelected(int index) async {
    if (_currentNavigatorIndex == 0 && _currentNavigatorIndex == index) {
      if (_scrollController.offset > 0) {
        await _scrollController.animateTo(0,
            duration: Durations.medium1, curve: Curves.linearToEaseOut);
      } else {
        _scaffoldKey.currentState?.openDrawer();
      }
    }
    setState(() {
      _currentNavigatorIndex = index;
      if (index != 0) {
        _isBottomVisible = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<MyAppState>(context, listen: false);
    _currentForumOrTimelineId = appState.setting.initForumOrTimelineId;
    _isTimeline = appState.setting.initIsTimeline;
    _barName = appState.setting.initForumOrTimelineName;
    _fetchPosts();
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
    _scrollController.addListener(() {
      _bottomThrottle.run(() async {
        switch (_scrollController.position.userScrollDirection) {
          case ScrollDirection.idle:
            break;
          case ScrollDirection.forward:
            if (!_isBottomVisible) {
              setState(() {
                _isBottomVisible = true;
              });
            }
          case ScrollDirection.reverse:
            if (_isBottomVisible) {
              setState(() {
                _isBottomVisible = false;
              });
            }
        }
      });
    });
  }

  void _flushPosts() {
    setState(() {
      // 当导航在其他页时，给_scrollController做操作会崩溃，忽略即可
      try {
        _scrollController.jumpTo(0);
      } catch (e) {
        print(e);
      }

      _threadIds.clear();
      _posts.clear();
      _isLoading = false;
      _currentPage = 1;
    });
  }

  Future<void> _fetchPosts() async {
    if (!mounted || _isLoading) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final appState = Provider.of<MyAppState>(context, listen: false);
      late List<ThreadJson> newPosts;
      if (_isTimeline) {
        newPosts = await fetchTimelineThreads(_currentForumOrTimelineId,
            _currentPage, appState.getCurrentCookie());
      } else {
        newPosts = await fetchForumThreads(_currentForumOrTimelineId,
            _currentPage, appState.getCurrentCookie());
      }

      if (appState.setting.dontShowFilttedForumInTimeLine) {
        newPosts = newPosts.where((thread) {
          final result = appState.filterTimeLineThread(thread);
          if (result.$1 == true && result.$2 is ForumThreadFilter) {
            return false;
          } else {
            return true;
          }
        }).toList();
      }

      setState(() {
        _posts.addAll(
            newPosts.skipWhile((thread) => _threadIds.contains(thread.id)));
        _threadIds.addAll(newPosts.map((thread) => thread.id));
        _isLoading = false;
      });
    } on TimeoutException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Timeout: ${e.toString()}"),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: ${e.toString()}"),
        ));
      }
    }
  }

  Future<void> _loadMorePosts() async {
    _currentPage++;
    await _fetchPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    List<Widget> otherPages = [
      starPage(context),
      TrendPage(
        refCache: trendRefCache,
      ),
      MorePage()
    ];
    threadsBuilder(BuildContext context, int index) {
      if (index < _posts.length) {
        var mustCollapsed = false;
        if (_lastBuildingReplyIndex > 0 && _lastBuildingReplyIndex > index) {
          mustCollapsed = true; // 往上加载，折叠ref防止视距外的ref展开造成的滚动跳变
        }
        _lastBuildingReplyIndex = _lastBuildingReplyIndex = index;
        final replyItem = ReplyItem(
          // 如果是往回加载，折叠ref防止视距外的ref展开造成的滚动跳变
          inCardView: appState.setting.isCardView,
          collapsedRef: mustCollapsed,
          isThreadFirstOrForumPreview: true,
          contentNeedCollapsed: true,
          threadJson: _posts[index],
          contentHeroTag: 'ThreadCard ${_posts[index].id}',
          imageHeroTag: 'Image ${_posts[index].img}${_posts[index].ext}',
        );
        final navigator = Navigator.of(context);
        onTapThread() =>
            appState.navigateThreadPage2(context, _posts[index].id, false,
                thread: _posts[index]);

        onLongPressThread() {
          final thread = _posts[index];
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SimpleDialog(
                title: const Text('屏蔽操作'),
                children: [
                  SimpleDialogOption(
                    child: Text('屏蔽串No.${thread.id}'),
                    onPressed: () {
                      if (!appState.setting.threadFilters.any((filter) =>
                          filter is IdThreadFilter && filter.id == thread.id)) {
                        appState.setState((_) {
                          appState.setting.threadFilters
                              .add(IdThreadFilter(id: thread.id));
                        });
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  SimpleDialogOption(
                    child: Text('屏蔽饼干${thread.userHash}'),
                    onPressed: () {
                      if (!appState.setting.threadFilters.any((filter) =>
                          filter is UserHashFilter &&
                          filter.userHash == thread.userHash)) {
                        appState.setState((_) {
                          appState.setting.threadFilters
                              .add(UserHashFilter(userHash: thread.userHash));
                        });
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  if (_isTimeline)
                    SimpleDialogOption(
                      child: Text(
                          '在时间线屏蔽${appState.forumMap[thread.fid]?.getShowName() ?? '(版面id: ${thread.fid})'}'),
                      onPressed: () {
                        if (!appState.setting.threadFilters.any((filter) =>
                            filter is ForumThreadFilter &&
                            filter.fid == thread.fid)) {
                          appState.setState((_) {
                            appState.setting.threadFilters
                                .add(ForumThreadFilter(fid: thread.fid));
                          });
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
              );
            },
          );
        }

        final replyActionBar = appState.setting.isCardView
            ? Row(children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton.filledTonal(
                          onPressed: onLongPressThread,
                          icon: Icon(Icons.more_vert)),
                      IconButton.filledTonal(
                          onPressed: () async => await Share.share(
                              'https://www.nmbxd1.com/t/${_posts[index].id}'),
                          icon: Icon(Icons.share))
                    ],
                  ),
                ),
                IconButton.filledTonal(
                    onPressed: () {
                      if (appState.isStared(_posts[index].id)) {
                        appState.setState((_) {
                          appState.setting.starHistory.removeWhere(
                              (rply) => rply.thread.id == _posts[index].id);
                        });
                      } else {
                        appState.setState((_) {
                          final history = appState.setting.viewHistory
                              .get(_posts[index].id);
                          if (history != null) {
                            appState.setting.starHistory.add(history);
                          } else {
                            appState.setting.starHistory.add(ReplyJsonWithPage(
                                1,
                                0,
                                _posts[index].id,
                                _posts[index],
                                _posts[index]));
                          }
                        });
                      }
                    },
                    icon: Icon(
                      appState.isStared(_posts[index].id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    )),
                IconButton.filledTonal(
                    onPressed: () => appState.navigateThreadPage2(
                        context, _posts[index].id, false,
                        thread: _posts[index]),
                    icon: _posts[index].replyCount == 0
                        ? Icon(Icons.message)
                        : Badge(
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainer,
                            textColor: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            label: Text(_posts[index].replyCount.toString()),
                            child: Icon(Icons.message),
                          )),
              ])
            : Row(
                children: [
                  Expanded(
                      child: InkWell(
                    onTap: () async => await Share.share(
                        'https://www.nmbxd1.com/t/${_posts[index].id}'),
                    child: SizedBox(
                      height: 35,
                      child: Row(children: [
                        Spacer(),
                        Icon(
                          Icons.share,
                          size:
                              Theme.of(context).textTheme.bodyMedium?.fontSize,
                        ),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2)),
                        Text('分享'),
                        Spacer(),
                      ]),
                    ),
                  )),
                  Expanded(
                      child: InkWell(
                    onTap: () {
                      if (appState.isStared(_posts[index].id)) {
                        appState.setState((_) {
                          appState.setting.starHistory.removeWhere(
                              (rply) => rply.thread.id == _posts[index].id);
                        });
                      } else {
                        appState.setState((_) {
                          final history = appState.setting.viewHistory
                              .get(_posts[index].id);
                          if (history != null) {
                            appState.setting.starHistory.add(history);
                          } else {
                            appState.setting.starHistory.add(ReplyJsonWithPage(
                                1,
                                0,
                                _posts[index].id,
                                _posts[index],
                                _posts[index]));
                          }
                        });
                      }
                    },
                    child: SizedBox(
                      height: 35,
                      child: Row(children: [
                        Spacer(),
                        Icon(
                            appState.isStared(_posts[index].id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.fontSize),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2)),
                        Text('收藏'),
                        Spacer(),
                      ]),
                    ),
                  )),
                  Expanded(
                      child: SizedBox(
                    height: 35,
                    child: Row(children: [
                      Spacer(),
                      Icon(
                        Icons.message,
                        size: Theme.of(context).textTheme.bodyMedium?.fontSize,
                      ),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2)),
                      Text(_posts[index].replyCount == 0
                          ? '评论'
                          : _posts[index].replyCount.toString()),
                      Spacer(),
                    ]),
                  )),
                ],
              );

        return Column(
          children: [
            if (!appState.setting.isCardView)
              InkWell(
                onTap: onTapThread,
                onLongPress: onLongPressThread,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                  child: Material(
                    type: MaterialType.transparency,
                    child: FilterableThreadWidget(
                      reply: _posts[index],
                      isTimeLineFilter: _isTimeline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          replyItem,
                          if (_isTimeline)
                            ActionChip(
                                onPressed: () {
                                  if (_isTimeline ||
                                      _currentForumOrTimelineId !=
                                          _posts[index].fid) {
                                    _isTimeline = false;
                                    _currentForumOrTimelineId =
                                        _posts[index].fid;
                                    _barName = appState
                                            .forumMap[_posts[index].fid]
                                            ?.getShowName() ??
                                        '';
                                    _flushPosts();
                                    _fetchPosts();
                                  }
                                },
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                                padding: EdgeInsets.all(0),
                                labelStyle:
                                    Theme.of(context).textTheme.labelSmall,
                                label: HtmlWidget(
                                  appState.forumMap[_posts[index].fid]
                                          ?.getShowName() ??
                                      '',
                                )),
                          replyActionBar
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
                      borderRadius: BorderRadius.circular(12.0),
                      onTap: onTapThread,
                      onLongPress: onLongPressThread,
                      child: Padding(
                        padding: EdgeInsets.all(breakpoint.gutters),
                        child: Material(
                            type: MaterialType.transparency,
                            child: FilterableThreadWidget(
                              reply: _posts[index],
                              isTimeLineFilter: _isTimeline,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  replyItem,
                                  SizedBox(
                                    height: _isTimeline ? 5 : 10,
                                  ),
                                  if (_isTimeline)
                                    ActionChip(
                                        onPressed: () {
                                          if (_isTimeline ||
                                              _currentForumOrTimelineId !=
                                                  _posts[index].fid) {
                                            _isTimeline = false;
                                            _currentForumOrTimelineId =
                                                _posts[index].fid;
                                            _barName = appState
                                                    .forumMap[_posts[index].fid]
                                                    ?.getShowName() ??
                                                '';
                                            _flushPosts();
                                            _fetchPosts();
                                          }
                                        },
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainer,
                                        padding: EdgeInsets.all(0),
                                        labelStyle: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                        label: HtmlWidget(
                                          appState.forumMap[_posts[index].fid]
                                                  ?.getShowName() ??
                                              '',
                                        )),
                                  replyActionBar
                                ],
                              ),
                            )),
                      ),
                    ),
                  )),
            if (index != _posts.length - 1 && !appState.setting.isCardView)
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(
                    height: 2,
                  )),
          ],
        );
      } else {
        return Skeletonizer(
          effect: ShimmerEffect(
            baseColor:
                Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(70),
            highlightColor:
                Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(50),
          ),
          enabled: true,
          child: Column(
            children: [
              if (!appState.setting.isCardView)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 10, bottom: 15, left: 10, right: 10),
                  child: ReplyItem(
                    contentNeedCollapsed: false,
                    threadJson: fakeThread,
                  ),
                )
              else
                Card(
                  shadowColor: Colors.transparent,
                  child: Padding(
                    padding: EdgeInsets.all(breakpoint.gutters),
                    child: ReplyItem(
                      inCardView: true,
                      contentNeedCollapsed: false,
                      threadJson: fakeThread,
                    ),
                  ),
                ),
              if (!appState.setting.isCardView)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Divider(
                      height: 2,
                    )),
            ],
          ),
        );
      }
    }

    final forumSelectList = [
      ExpansionTile(
        initiallyExpanded: true,
        title: Text('常用板块'),
        subtitle: Text('长按进行添加或移除'),
        children: [
          ...appState.setting.favoredForums.map(
            (forum) => ListTile(
              onTap: () {
                setState(() {
                  _currentNavigatorIndex = 0;
                  if (_isTimeline || _currentForumOrTimelineId != forum.id) {
                    _isTimeline = false;
                    _currentForumOrTimelineId = forum.id;
                    _scaffoldKey.currentState?.closeDrawer();
                    _flushPosts();
                    _fetchPosts();
                    _barName = forum.getShowName();
                  }
                });
              },
              onLongPress: () => appState.setState((_) {
                appState.setting.favoredForums
                    .removeWhere((f) => f.id == forum.id);
              }),
              title: HtmlWidget(forum.getShowName()),
              selected: !_isTimeline && _currentForumOrTimelineId == forum.id,
            ),
          ),
        ],
      ),
      if (appState.fetchTimelinesStatus == SimpleStatus.completed)
        ExpansionTile(
          initiallyExpanded: _isTimeline,
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50.0),
          ),
          title: HtmlWidget('时间线'),
          children: [
            ...appState.setting.cacheTimelines.map((timeline) {
              return ListTile(
                onTap: () {
                  setState(() {
                    _currentNavigatorIndex = 0;
                  });
                  if (!_isTimeline ||
                      _currentForumOrTimelineId != timeline.id) {
                    _isTimeline = true;
                    _currentForumOrTimelineId = timeline.id;
                    _scaffoldKey.currentState?.closeDrawer();
                    _flushPosts();
                    _fetchPosts();
                    _barName = timeline.getShowName();
                  }
                },
                title: HtmlWidget(timeline.getShowName()),
                selected:
                    _isTimeline && _currentForumOrTimelineId == timeline.id,
              );
            })
          ],
        )
      else if (appState.fetchTimelinesStatus == SimpleStatus.loading)
        ListTile(
          title: Text(
            '时间线',
          ),
          trailing: CircularProgressIndicator(),
        )
      else
        ListTile(
          title: Text(
            '时间线',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: Text('加载出错'),
          trailing: IconButton(
              onPressed: () => setState(() {
                    appState.tryFetchTimelines(scaffoldMessengerKey);
                    _scaffoldKey.currentState?.closeDrawer();
                    Future.delayed(Duration(seconds: 1),
                        () => _scaffoldKey.currentState?.openDrawer());
                  }),
              icon: Icon(Icons.refresh)),
        ),
      if (appState.fetchForumsStatus == SimpleStatus.completed)
        ...appState.setting.cacheForumLists.map((forumList) {
          return ExpansionTile(
            initiallyExpanded: !_isTimeline &&
                forumList.forums.any((f) => f.id == _currentForumOrTimelineId),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50.0),
            ),
            title: HtmlWidget(forumList.name),
            children: forumList.forums.map((forum) {
              return ListTile(
                onTap: () {
                  setState(() {
                    _currentNavigatorIndex = 0;
                    if (_isTimeline || _currentForumOrTimelineId != forum.id) {
                      _isTimeline = false;
                      _currentForumOrTimelineId = forum.id;
                      _scaffoldKey.currentState?.closeDrawer();
                      _flushPosts();
                      _fetchPosts();
                      _barName = forum.getShowName();
                    }
                  });
                },
                onLongPress: () {
                  if (!appState.setting.favoredForums
                      .any((f) => f.id == forum.id)) {
                    appState.setState((_) {
                      appState.setting.favoredForums.add(forum);
                    });
                  }
                },
                title: HtmlWidget(forum.getShowName()),
                selected: !_isTimeline && _currentForumOrTimelineId == forum.id,
              );
            }).toList(),
          );
        })
      else if (appState.fetchForumsStatus == SimpleStatus.loading)
        ListTile(
          title: Text(
            '所有板块',
          ),
          trailing: CircularProgressIndicator(),
        )
      else
        ListTile(
          title: Text(
            '所有板块',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: Text('加载出错'),
          trailing: IconButton(
              onPressed: () => setState(() {
                    appState.tryFetchForumLists(scaffoldMessengerKey);
                    _scaffoldKey.currentState?.closeDrawer();
                    Future.delayed(Duration(seconds: 1),
                        () => _scaffoldKey.currentState?.openDrawer());
                  }),
              icon: Icon(Icons.refresh)),
        ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawerEdgeDragWidth: MediaQuery.of(context).size.width / 3,
      drawer: breakpoint.window >= WindowSize.medium ||
              (breakpoint.window == WindowSize.xsmall &&
                  _currentNavigatorIndex != 0)
          ? null
          : Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: SafeArea(
                child: NavigationDrawer(
                  onDestinationSelected: onDestinationSelected,
                  selectedIndex: _currentNavigatorIndex,
                  children: <Widget>[
                    if (breakpoint.window <= WindowSize.xsmall)
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                        ),
                        child: Text('氢岛',
                            style: Theme.of(context).textTheme.headlineLarge),
                      ),
                    if (breakpoint.window > WindowSize.xsmall)
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: breakpoint.gutters,
                            vertical: breakpoint.gutters),
                        child: Text(
                          '氢岛',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    if (breakpoint.window > WindowSize.xsmall)
                      ...destinations.map(
                        (e) => NavigationDrawerDestination(
                          icon: e.icon,
                          selectedIcon: e.selectedIcon,
                          label: Text(e.label),
                        ),
                      ),
                    if (breakpoint.window > WindowSize.xsmall)
                      Padding(
                        padding: EdgeInsets.all(breakpoint.gutters / 2),
                        child: Divider(
                          height: 2,
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: breakpoint.gutters / 2),
                      child: Column(
                        children: forumSelectList,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: Row(children: [
        if (breakpoint.window >= WindowSize.medium)
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isOutSideDrawerExpanded ? 256 : 128,
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: NavigationDrawer(
                backgroundColor: Colors.transparent,
                onDestinationSelected: onDestinationSelected,
                selectedIndex: _currentNavigatorIndex,
                children: [
                  Padding(
                    padding: EdgeInsets.all(breakpoint.gutters / 2),
                    child: IconButton(
                        onPressed: () => setState(() {
                              _isOutSideDrawerExpanded =
                                  !_isOutSideDrawerExpanded;
                            }),
                        icon: Icon(_isOutSideDrawerExpanded
                            ? Icons.menu_open
                            : Icons.menu)),
                  ),
                  ...destinations.map(
                    (e) => NavigationDrawerDestination(
                      icon: e.icon,
                      selectedIcon: e.selectedIcon,
                      label: Text(e.label),
                    ),
                  ),
                  if (_isOutSideDrawerExpanded && _currentNavigatorIndex == 0)
                    Padding(
                      padding: EdgeInsets.all(breakpoint.gutters / 2),
                      child: Divider(
                        height: 2,
                      ),
                    ),
                  if (_isOutSideDrawerExpanded && _currentNavigatorIndex == 0)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: breakpoint.gutters / 2),
                      child: Column(
                        children: forumSelectList,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (breakpoint.window > WindowSize.xsmall &&
            breakpoint.window < WindowSize.medium)
          NavigationRail(
            labelType: NavigationRailLabelType.all,
            selectedIndex: _currentNavigatorIndex,
            onDestinationSelected: onDestinationSelected,
            leading: FloatingActionButton(
                heroTag: 'FloatingActionButton_AnyThing_Just_NOT_hit',
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                child: Icon(Icons.menu)),
            destinations: [
              ...destinations.map(
                (e) => NavigationRailDestination(
                  icon: e.icon,
                  selectedIcon: e.selectedIcon,
                  label: Text(e.label),
                ),
              ),
            ],
          ),
        Expanded(
          child: _currentNavigatorIndex != 0
              ? otherPages[_currentNavigatorIndex - 1]
              : SafeArea(
                  top: false,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final forumRowCount =
                        (constraints.maxWidth / 445).toInt() + 1;
                    final initSkeletonizerCount = forumRowCount * 7;
                    print(breakpoint.window);
                    return RefreshIndicator(
                      onRefresh: () {
                        _flushPosts();
                        return _fetchPosts();
                      },
                      edgeOffset: 100,
                      child: CustomScrollView(
                        cacheExtent: MediaQuery.of(context).size.height * 3,
                        key: PageStorageKey('CustomScrollViewInForumPage'),
                        physics: _posts.isNotEmpty
                            ? AlwaysScrollableScrollPhysics()
                            : NeverScrollableScrollPhysics(),
                        controller: _scrollController,
                        slivers: [
                          SliverAppBar(
                            surfaceTintColor: Colors.transparent,
                            toolbarHeight: breakpoint.window >= WindowSize.small
                                ? kToolbarHeight + 20
                                : kToolbarHeight,
                            automaticallyImplyLeading:
                                breakpoint.window < WindowSize.small,
                            pinned: breakpoint.window >= WindowSize.small,
                            snap: false,
                            floating: breakpoint.window < WindowSize.small,
                            actions: [
                              if (_isLoading)
                                IconButton(
                                    onPressed: () {
                                      _isLoading = false;
                                      _flushPosts();
                                      _fetchPosts();
                                    },
                                    icon: Icon(Icons.refresh)),
                              if (breakpoint.window >= WindowSize.small)
                                FloatingActionButton.extended(
                                  elevation: 0,
                                  onPressed: () => showReplyBottomSheet(
                                      context,
                                      true,
                                      _isTimeline
                                          ? appState.forumMap.values
                                              .firstWhere(
                                                  (forum) =>
                                                      forum.name == "综合版1",
                                                  orElse: () => appState
                                                      .forumMap.values.first)
                                              .id
                                          : _currentForumOrTimelineId,
                                      -1,
                                      fakeThread,
                                      _postImageFile,
                                      (image) => _postImageFile = image,
                                      _postTitleControler,
                                      _postAuthorControler,
                                      _postTextControler, () {
                                    setState(() {
                                      _flushPosts();
                                      _fetchPosts();
                                    });
                                  }),
                                  tooltip: '发串',
                                  label: Text('发串'),
                                  icon: const Icon(Icons.edit),
                                ),
                              SizedBox(width: breakpoint.gutters),
                            ],
                            title: GestureDetector(
                              onTap: () async {
                                await _scrollController.animateTo(0,
                                    duration: Durations.medium1,
                                    curve: Curves.linearToEaseOut);
                              },
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      HtmlWidget(
                                        _barName,
                                      ),
                                      Text(
                                        'X岛・nmbxd.com',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: Theme.of(context)
                                                    .hintColor),
                                      )
                                    ],
                                  ),
                                  Expanded(child: Container())
                                ],
                              ),
                            ),
                          ),
                          // 不知道为什么，这里的padding需要微调才显得对齐
                          SliverPadding(
                            padding: EdgeInsets.only(
                                right: breakpoint.gutters - 2,
                                left: breakpoint.window > WindowSize.xsmall
                                    ? 0
                                    : breakpoint.gutters - 2),
                            sliver: SliverMasonryGrid.count(
                              crossAxisCount: forumRowCount,
                              itemBuilder: threadsBuilder,
                              childCount: _posts.length +
                                  (_posts.isNotEmpty
                                      ? 1
                                      : initSkeletonizerCount),
                              mainAxisSpacing: breakpoint.gutters * 1.5 / 2,
                              crossAxisSpacing: breakpoint.gutters * 1.5 / 2,
                            ),
                          )
                        ],
                      ),
                    );
                  }),
                ),
        ),
      ]),
      floatingActionButton: breakpoint.window >= WindowSize.small ||
              _currentNavigatorIndex != 0 ||
              _posts.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showReplyBottomSheet(
                  context,
                  true,
                  _isTimeline
                      ? appState.forumMap.values
                          .firstWhere((forum) => forum.name == "综合版1",
                              orElse: () => appState.forumMap.values.first)
                          .id
                      : _currentForumOrTimelineId,
                  -1,
                  fakeThread,
                  _postImageFile,
                  (image) => _postImageFile = image,
                  _postTitleControler,
                  _postAuthorControler,
                  _postTextControler, () {
                setState(() {
                  _flushPosts();
                  _fetchPosts();
                });
              }),
              tooltip: '发串',
              label: const Text('发串'),
              icon: const Icon(Icons.edit),
            ),
      bottomNavigationBar: breakpoint.window >= WindowSize.small
          ? null
          : SafeArea(
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutExpo,
                  height: _isBottomVisible || appState.setting.fixedBottomBar
                      ? 67
                      : 0,
                  child: NavigationBar(
                    onDestinationSelected: onDestinationSelected,
                    selectedIndex: _currentNavigatorIndex,
                    destinations: <Widget>[
                      if (_isBottomVisible || appState.setting.fixedBottomBar)
                        ...destinations.map(
                          (e) => NavigationDestination(
                            icon: e.icon,
                            selectedIcon: e.selectedIcon,
                            label: e.label,
                          ),
                        )
                      else ...[
                        SizedBox.shrink(),
                        SizedBox.shrink(),
                      ]
                    ],
                  )),
            ),
    );
  }
}
