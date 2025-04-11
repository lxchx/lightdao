import 'dart:async';
import 'dart:math';

import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:hive/hive.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/ui/page/more/cookies_management.dart';
import 'package:lightdao/ui/widget/util_funtions.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

import '../../data/setting.dart';
import '../../data/xdao/ref.dart';
import '../../data/xdao/reply.dart';
import '../../utils/throttle.dart';
import '../../utils/xdao_api.dart';
import '../widget/reply_item.dart';

class ThreadPage extends StatefulWidget {
  final ThreadJson thread;
  final String threadForumName;
  final int startPage;
  final int startReplyId;
  final bool withWholePage;
  final String? poContentHeroTag;
  final String? poImgContentHeroTag;

  ThreadPage({
    required this.thread,
    required this.threadForumName,
    required this.startPage,
    this.startReplyId = -1,
    this.withWholePage = false,
    this.poContentHeroTag,
    this.poImgContentHeroTag,
  });

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class ReplyJsonWithPage {
  final int page;
  final int pos;
  final ReplyJson thread;
  final ReplyJson reply;
  final int threadId;

  ReplyJsonWithPage(
      this.page, this.pos, this.threadId, this.thread, this.reply);
}

class ReplyJsonWithPageAdapter extends TypeAdapter<ReplyJsonWithPage> {
  @override
  final int typeId = 8;

  @override
  ReplyJsonWithPage read(BinaryReader reader) {
    return ReplyJsonWithPage(
      reader.readInt(),
      reader.readInt(),
      reader.readInt(),
      reader.read() as ReplyJson,
      reader.read() as ReplyJson,
    );
  }

  @override
  void write(BinaryWriter writer, ReplyJsonWithPage obj) {
    writer.writeInt(obj.page);
    writer.writeInt(obj.pos);
    writer.writeInt(obj.threadId);
    writer.write(obj.thread);
    writer.write(obj.reply);
  }
}

SliverMultiBoxAdaptorElement? findSliverMultiBoxAdaptorElement(
    Element element) {
  if (element is SliverMultiBoxAdaptorElement) {
    return element;
  }
  SliverMultiBoxAdaptorElement? target;
  element.visitChildElements((child) {
    target = findSliverMultiBoxAdaptorElement(child) ?? target;
  });
  return target;
}

class _ThreadPageState extends State<ThreadPage> {
  int _currentMaxPage = 0;
  int _currentMinPage = 0;
  ReplyJsonWithPage? _curVisableReplyWithPage;
  int _lastBuildingReplyIndex = -1;
  late int _currentRepliesCount;
  List<ReplyJsonWithPage> _replies = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingAfter = false;
  bool _isLoadingBefore = false;
  bool _poReplyExpandFlag = false;
  bool _hasMoreAfter = true;
  bool _hasMoreBefore = true;
  bool _isBottomVisible = true;
  bool _isRawPicMode = false;
  SliverMultiBoxAdaptorElement? _sliverMultiBoxAdaptorElement;
  final _getCurPageThrottle = Throttle(interval: Duration(microseconds: 200));
  final _preFetchThrottle = Throttle(interval: Duration(microseconds: 300));
  XFile? _imageFile;
  final _replyTextControler = TextEditingController();
  final _replyTitleControler = TextEditingController();
  final _replyAuthorControler = TextEditingController();
  final refCache = LRUCache<int, Future<RefHtml>>(100);
  Timer? _timer;

  void updateCurrentVisablePage(int firstIndex, int lastIndex) {
    if (firstIndex >= 0) {
      setState(() {
        _curVisableReplyWithPage = _replies[firstIndex];
      });
    }
  }

  saveHistory() {
    final appState = Provider.of<MyAppState>(context, listen: false);
    final history = _curVisableReplyWithPage;
    if (history == null) {
      return;
    }

    appState.setState((_) {
      if (appState.setting.starHistory
          .any(((rply) => rply.threadId == widget.thread.id))) {
        appState.setting.starHistory
            .removeWhere((rply) => rply.threadId == widget.thread.id);
        appState.setting.starHistory.insert(0, history);
      }
      appState.setting.viewHistory.put(widget.thread.id, history);
    });
  }

  @override
  Widget build(BuildContext context) {
    Future.delayed(Durations.short2, () {
      if (!mounted) return;
      setState(() {
        _poReplyExpandFlag = true;
      });
    });
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    late List<String> allImageNames;
    if (widget.thread.img != '') {
      allImageNames = [
        '${widget.thread.img}${widget.thread.ext}',
        ..._replies
            .where((r) => r.reply.img != '')
            .map((r) => '${r.reply.img}${r.reply.ext}')
      ];
    } else {
      allImageNames = _replies
          .where((r) => r.reply.img != '')
          .map((r) => '${r.reply.img}${r.reply.ext}')
          .toList();
    }
    return Scaffold(
      body: Theme(
        data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
                  fontSizeFactor: appState.setting.fontSizeFactor,
                )),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notice) {
            _getCurPageThrottle.run(() async {
              _sliverMultiBoxAdaptorElement = _sliverMultiBoxAdaptorElement ??
                  findSliverMultiBoxAdaptorElement(notice.context! as Element)!;
              final viewportDimension = notice.metrics.viewportDimension;
              int firstIndex = -1;
              int lastIndex = -1;

              void onVisitChildren(Element element) {
                final SliverMultiBoxAdaptorParentData oldParentData = element
                    .renderObject
                    ?.parentData as SliverMultiBoxAdaptorParentData;
                double layoutOffset = oldParentData.layoutOffset!;
                double pixels = notice.metrics.pixels;
                double all = pixels + viewportDimension;

                if (layoutOffset >= pixels) {
                  firstIndex = firstIndex < oldParentData.index! - 1
                      ? firstIndex
                      : oldParentData.index! - 1;
                  if (layoutOffset <= all) {
                    lastIndex = lastIndex > oldParentData.index!
                        ? lastIndex
                        : oldParentData.index!;
                  }
                  firstIndex = firstIndex > 0 ? firstIndex : 0;
                } else {
                  lastIndex = firstIndex = oldParentData.index!;
                }
              }

              _sliverMultiBoxAdaptorElement!.visitChildren(onVisitChildren);
              updateCurrentVisablePage(firstIndex, lastIndex);
            });
            return false;
          },
          child: CustomScrollView(
            cacheExtent: MediaQuery.of(context).size.height * 3,
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                pinned: false,
                snap: false,
                floating: true,
                title: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HtmlWidget(
                        '${widget.threadForumName}・${widget.thread.id}',
                      ),
                      Text(
                        'X岛・nmbxd.com',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).hintColor),
                      )
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                      tooltip: '分享',
                      onPressed: () async => await Share.share(
                          'https://www.nmbxd1.com/t/${widget.thread.id}'),
                      icon: Icon(Icons.share)),
                  IconButton(
                      tooltip: '切换原图模式',
                      onPressed: () => setState(() {
                            _isRawPicMode = !_isRawPicMode;
                          }),
                      icon: Icon(_isRawPicMode
                          ? Icons.raw_on
                          : Icons.photo_size_select_actual)),
                ],
              ),
              SliverToBoxAdapter(
                child: InkWell(
                  onLongPress: () =>
                      showThreadActionMenu(context, widget.thread, true),
                  child: Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: breakpoint.gutters / 2,
                            horizontal: breakpoint.gutters),
                        child: FilterableThreadWidget(
                          reply: widget.thread,
                          isTimeLineFilter: false,
                          child: ReplyItem(
                            isRawPicMode: _isRawPicMode,
                            isThreadFirstOrForumPreview: true,
                            contentNeedCollapsed:
                                _poReplyExpandFlag ? false : true,
                            threadJson: widget.thread,
                            refCache: refCache,
                            contentHeroTag: widget.poContentHeroTag ??
                                'ThreadCard ${widget.thread.id}',
                            imageHeroTag: widget.poImgContentHeroTag ??
                                'Image ${widget.thread.img}${widget.thread.ext}',
                            imageInitIndex: widget.thread.img != '' ? 0 : null,
                            imageNames:
                                widget.thread.img != '' ? allImageNames : null,
                          ),
                        ),
                      )),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: breakpoint.gutters / 2,
                  ),
                  child: Divider(
                    height: 2,
                  ),
                ),
              ),
              if (_currentMinPage > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: breakpoint.gutters / 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              _loadMoreBeforeReplies();
                            },
                            child: Text('加载之前的回复')),
                      ],
                    ),
                  ),
                ),
              if (_currentMinPage > 1 && appState.setting.dividerBetweenReply)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: breakpoint.gutters / 2,
                    ),
                    child: Divider(
                      height: 2,
                    ),
                  ),
                ),
              if (_isLoadingBefore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: breakpoint.gutters,
                        vertical: breakpoint.gutters / 2),
                    child: Skeletonizer(
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
                      child: ReplyItem(
                        contentNeedCollapsed: false,
                        threadJson: fakeThread,
                      ),
                    ),
                  ),
                ),
              if (_isLoadingBefore && appState.setting.dividerBetweenReply)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: breakpoint.gutters / 2,
                    ),
                    child: Divider(
                      height: 2,
                    ),
                  ),
                ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  addAutomaticKeepAlives: false,
                  (BuildContext context, int index) {
                    bool mustCollapsed = false;
                    if (_lastBuildingReplyIndex > 0 &&
                        _lastBuildingReplyIndex > index) {
                      mustCollapsed = true; // 往上加载，折叠ref防止视距外的ref展开造成的滚动跳变
                    }
                    _lastBuildingReplyIndex = index;
                    final imageName =
                        '${_replies[index].reply.img}${_replies[index].reply.ext}';
                    final imageIndex = allImageNames.indexOf(imageName);
                    return Column(
                      children: [
                        InkWell(
                          onLongPress: () => showThreadActionMenu(
                              context, _replies[index].reply, false),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: breakpoint.gutters,
                                vertical: breakpoint.gutters / 2),
                            child: FilterableThreadWidget(
                              reply: _replies[index].reply,
                              isTimeLineFilter: false,
                              child: ReplyItem(
                                key: Key(
                                    'ReplyCard ${_replies[index].reply.id}'),
                                isRawPicMode: _isRawPicMode,
                                collapsedRef: mustCollapsed,
                                refCache: refCache,
                                contentNeedCollapsed: false,
                                poUserHash: widget.thread.userHash,
                                threadJson: _replies[index].reply,
                                imageHeroTag:
                                    'Image ${_replies[index].reply.img}${_replies[index].reply.ext}',
                                imageInitIndex:
                                    imageIndex >= 0 ? imageIndex : null,
                                imageNames:
                                    imageIndex >= 0 ? allImageNames : null,
                              ),
                            ),
                          ),
                        ),
                        if (appState.setting.dividerBetweenReply)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: breakpoint.gutters / 2,
                            ),
                            child: Divider(
                              height: 2,
                            ),
                          ),
                      ],
                    );
                  },
                  childCount: _replies.length,
                ),
              ),
              if (_isLoadingAfter)
                SliverToBoxAdapter(
                  child: Skeletonizer(
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: breakpoint.gutters / 2,
                          horizontal: breakpoint.gutters),
                      child: ReplyItem(
                        contentNeedCollapsed: false,
                        threadJson: fakeThread,
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: breakpoint.gutters / 2),
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            if (_currentMaxPage > 2) {
                              _currentMaxPage -= 2;
                            } else {
                              _currentMaxPage = 0;
                            }
                            _hasMoreAfter = true;
                            _loadMoreAfterReplies();
                          });
                        },
                        child: Text.rich(
                          textAlign: TextAlign.center,
                          TextSpan(text: '到底了(　ﾟ 3ﾟ)\n', children: [
                            TextSpan(
                              text: '\n刷新试试？',
                              style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontSize: 12),
                            )
                          ]),
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton:
          (!_isBottomVisible && !appState.setting.fixedBottomBar)
              ? null
              : FloatingActionButton(
                  shape: CircleBorder(),
                  onPressed: () => showReplyBottomSheet(
                      context,
                      false,
                      widget.thread.id,
                      _currentRepliesCount ~/ 19 + 1,
                      widget.thread,
                      _imageFile,
                      (image) => _imageFile = image,
                      _replyTitleControler,
                      _replyAuthorControler,
                      _replyTextControler, () {
                    // 如果已经加载到最后一页，重新加载以刷出自己的回复
                    if (_currentMaxPage >= _currentRepliesCount ~/ 19 + 1 ||
                        _currentMaxPage == 0) {
                      setState(() {
                        if (_currentMaxPage > 2) {
                          _currentMaxPage -= 2;
                        } else {
                          _currentMaxPage = 0;
                        }
                        _hasMoreAfter = true;
                      });
                      _loadMoreAfterReplies();
                    }
                  }),
                  tooltip: '回复',
                  child: Icon(Icons.create),
                ),
      bottomNavigationBar: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutExpo,
          height: _isBottomVisible || appState.setting.fixedBottomBar ? 67 : 0,
          child: BottomAppBar(
            shape: CircularNotchedRectangle(),
            /*
            shape: AutomaticNotchedShape(
              RoundedRectangleBorder(),
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            */
            child: _isBottomVisible || appState.setting.fixedBottomBar
                ? Row(
                    children: [
                      IconButton(
                          tooltip: '收藏',
                          onPressed: () {
                            if (appState.isStared(widget.thread.id)) {
                              appState.setState((_) {
                                appState.setting.starHistory.removeWhere(
                                    (rply) =>
                                        rply.thread.id == widget.thread.id);
                              });
                            } else {
                              appState.setState((_) {
                                final history = _curVisableReplyWithPage ??
                                    (_replies.isEmpty
                                        ? ReplyJsonWithPage(
                                            1,
                                            0,
                                            widget.thread.id,
                                            widget.thread,
                                            widget.thread)
                                        : _replies.first);
                                appState.setting.starHistory.add(history);
                              });
                            }
                          },
                          icon: Icon(appState.isStared(widget.thread.id)
                              ? Icons.favorite
                              : Icons.favorite_border)),
                      IconButton(
                          tooltip: '跳页',
                          onPressed: () {
                            final totalPages = _currentRepliesCount ~/ 19 + 1;
                            final curPage = _curVisableReplyWithPage?.page ??
                                (widget.startPage >= 1 ? widget.startPage : 1);
                            TextEditingController pageController =
                                TextEditingController(text: curPage.toString());
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('跳页'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          height: 75,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              IconButton(
                                                onPressed: curPage > 1
                                                    ? () {
                                                        Navigator.of(context)
                                                            .pop(1);
                                                      }
                                                    : null,
                                                icon: Icon(Icons.first_page),
                                                tooltip: '首页',
                                              ),
                                              IconButton(
                                                onPressed: curPage > 1
                                                    ? () {
                                                        Navigator.of(context)
                                                            .pop(curPage - 1);
                                                      }
                                                    : null,
                                                icon: Icon(Icons.chevron_left),
                                                tooltip: '上一页',
                                              ),
                                              SizedBox(
                                                width: 70,
                                                child: TextField(
                                                  controller: pageController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: '页数',
                                                    border:
                                                        OutlineInputBorder(),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              Text('/ $totalPages'),
                                              IconButton(
                                                onPressed: curPage < totalPages
                                                    ? () {
                                                        Navigator.of(context)
                                                            .pop(curPage + 1);
                                                      }
                                                    : null,
                                                icon: Icon(Icons.chevron_right),
                                                tooltip: '下一页',
                                              ),
                                              IconButton(
                                                onPressed: curPage < totalPages
                                                    ? () {
                                                        Navigator.of(context)
                                                            .pop(totalPages);
                                                      }
                                                    : null,
                                                icon: Icon(Icons.last_page),
                                                tooltip: '尾页',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        int? page =
                                            int.tryParse(pageController.text);
                                        if (page != null &&
                                            page > 0 &&
                                            page <= totalPages) {
                                          Navigator.of(context).pop(page);
                                        }
                                      },
                                      child: Text('确定'),
                                    ),
                                  ],
                                );
                              },
                            ).then((selectedPage) async {
                              if (selectedPage != null &&
                                  selectedPage != curPage) {
                                print('跳到第 $selectedPage 页');
                                _currentMaxPage = selectedPage - 1;
                                _currentMinPage = selectedPage;
                                _replies.clear();
                                _curVisableReplyWithPage = null;
                                _hasMoreAfter = true;
                                _hasMoreBefore =
                                    selectedPage > 1 ? true : false;
                                _isLoadingAfter = false;
                                _isLoadingBefore = false;
                                _lastBuildingReplyIndex = -1; // 让ref能正确展开
                                await _loadMoreAfterReplies();
                                _curVisableReplyWithPage = _replies.first;
                              }
                            });
                          },
                          icon: Icon(Icons.move_down)),
                      IconButton(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                    title: Text(
                                        '字体大小缩放(${appState.setting.fontSizeFactor.toStringAsFixed(1)})'),
                                    content: SizedBox(
                                      width: 250,
                                      height: 48,
                                      child: Column(
                                        children: [
                                          Slider(
                                            min: 0.7,
                                            max: 1.3,
                                            value:
                                                appState.setting.fontSizeFactor,
                                            divisions: 6,
                                            onChanged: (double value) {
                                              appState.setState((state) {
                                                state.setting.fontSizeFactor =
                                                    value;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: Text('确定'))
                                    ],
                                  ));
                        },
                        icon: Icon(Icons.format_size),
                      ),
                    ],
                  )
                : SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Future<dynamic> showThreadActionMenu(
      BuildContext context, ReplyJson reply, bool isThread) {
    return showDialog(
      context: context,
      builder: (context) {
        final appState = Provider.of<MyAppState>(context, listen: false);
        return SimpleDialog(
          title: Text(reply.userHash != 'Tips' ? 'No.${reply.id}' : 'Tips'),
          children: [
            if (reply.userHash != 'Tips')
              SimpleDialogOption(
                child: Text(isThread ? '引用该串' : '引用回复'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _replyTextControler.text += '>>No.${reply.id}\n';
                  showReplyBottomSheet(
                      context,
                      false,
                      widget.thread.id,
                      _currentRepliesCount ~/ 19 + 1,
                      widget.thread,
                      _imageFile,
                      (image) => _imageFile = image,
                      _replyTitleControler,
                      _replyAuthorControler,
                      _replyTextControler, () {
                    // 如果已经加载到最后一页，重新加载以刷出自己的回复
                    if (_currentMaxPage >= _currentRepliesCount ~/ 19 + 1 ||
                        _currentMaxPage == 0) {
                      setState(() {
                        if (_currentMaxPage > 2) {
                          _currentMaxPage -= 2;
                        } else {
                          _currentMaxPage = 0;
                        }
                        _hasMoreAfter = true;
                      });
                      _loadMoreAfterReplies();
                    }
                  });
                },
              ),
            SimpleDialogOption(
              child: Text('复制内容'),
              onPressed: () {
                final appState =
                    Provider.of<MyAppState>(context, listen: false);
                pageRoute({
                  required Widget Function(BuildContext) builder,
                }) {
                  final setting =
                      Provider.of<MyAppState>(context, listen: false).setting;
                  if (setting.enableSwipeBack) {
                    return SwipeablePageRoute(builder: builder);
                  } else {
                    return MaterialPageRoute(builder: builder);
                  }
                }

                Navigator.of(context).pop();
                Navigator.of(context).push(
                  pageRoute(
                    builder: (BuildContext context) => Scaffold(
                      appBar: AppBar(
                        title: Text('自由复制'),
                      ),
                      body: Theme(
                        data: Theme.of(context).copyWith(
                            textTheme: Theme.of(context).textTheme.apply(
                                  fontSizeFactor:
                                      appState.setting.fontSizeFactor,
                                )),
                        child: SelectionArea(
                          child: ListView(
                            children: [
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: ReplyItem(
                                    poUserHash: widget.thread.userHash,
                                    threadJson: reply,
                                    contentNeedCollapsed: false,
                                    noMoreParse: true,
                                    contentHeroTag: "reply${reply.id}",
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SimpleDialogOption(
              child: Text('屏蔽No.${reply.id}'),
              onPressed: () {
                if (!appState.setting.threadFilters.any((filter) =>
                    filter is IdThreadFilter && filter.id == reply.id)) {
                  appState.setState((_) {
                    appState.setting.threadFilters
                        .add(IdThreadFilter(id: reply.id));
                  });
                }
                Navigator.of(context).pop();
              },
            ),
            SimpleDialogOption(
              child: Text('屏蔽饼干${reply.userHash}'),
              onPressed: () {
                if (!appState.setting.threadFilters.any((filter) =>
                    filter is UserHashFilter &&
                    filter.userHash == reply.userHash)) {
                  appState.setState((_) {
                    appState.setting.threadFilters
                        .add(UserHashFilter(userHash: reply.userHash));
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _poReplyExpandFlag = false;
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentRepliesCount = widget.thread.replyCount;
    var startPage = widget.startPage;
    if (startPage == 0) startPage = 1;
    var historyIndex = -1;
    if (widget.withWholePage) {
      if (widget.startReplyId > 0) {
        historyIndex = widget.thread.replies
            .indexWhere((data) => data.id == widget.startReplyId);
        if (historyIndex == -1) {
          _replies.addAll(widget.thread.replies.mapIndex((i, reply) =>
              ReplyJsonWithPage(
                  startPage, i, widget.thread.id, widget.thread, reply)));
        } else {
          _replies.addAll(widget.thread.replies.sublist(historyIndex).mapIndex(
              (i, reply) => ReplyJsonWithPage(
                  startPage, i, widget.thread.id, widget.thread, reply)));
        }
      } else {
        _replies.addAll(widget.thread.replies.mapIndex((index, reply) =>
            ReplyJsonWithPage(_currentMinPage, index, widget.thread.id,
                widget.thread, reply)));
      }
    }

    if (widget.withWholePage) {
      _currentMaxPage = startPage;
      _currentMinPage = historyIndex > 0 ? startPage + 1 : startPage;
    } else {
      _currentMaxPage = startPage + 1; // startPage由_loadStartReplies加载
      _currentMinPage = startPage;
    }

    if (_currentMinPage == 1) {
      _hasMoreBefore = false;
    }
    if (!widget.withWholePage) _loadStartReplies(widget.startPage);
    _scrollController.addListener(() {
      _preFetchThrottle.run(() async {
        if (_scrollController.position.pixels +
                    MediaQuery.of(context).size.height * 2 >
                _scrollController.position.maxScrollExtent &&
            !_isLoadingAfter &&
            _hasMoreAfter) {
          _loadMoreAfterReplies();
        }
      });
    });
    _scrollController.addListener(() {
      switch (_scrollController.position.userScrollDirection) {
        case ScrollDirection.idle:
          break;
        case ScrollDirection.forward:
          _isBottomVisible = true;
        case ScrollDirection.reverse:
          _isBottomVisible = false;
      }
    });
    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      saveHistory();
    });
  }

  Future<void> _loadMoreBeforeReplies() async {
    if (!mounted || _isLoadingBefore) return;
    setState(() {
      _isLoadingBefore = true;
    });
    if (!_hasMoreBefore) {
      return;
    }
    setState(() {
      _currentMinPage--;
    });
    final appState = Provider.of<MyAppState>(context, listen: false);
    try {
      final newThreadData = await getThread(
          widget.thread.id, _currentMinPage, appState.getCurrentCookie());
      _currentRepliesCount =
          max(_currentRepliesCount, newThreadData.replyCount);
      setState(() {
        if (newThreadData.replies.isEmpty ||
            (newThreadData.replies.length == 1 &&
                newThreadData.replies[0].userHash == 'Tips')) {
          _hasMoreBefore = false;
          return;
        }
        if (_currentMinPage == 0) {
          _hasMoreBefore = false;
        }
        for (var rply in newThreadData.replies) {
          refCache.put(rply.id, Future.value(RefHtml.fromReplyJson(rply)));
        }
        _replies.removeWhere((item) => item.page == _currentMinPage);
        _replies.insertAll(
            0,
            newThreadData.replies.mapIndex((index, reply) => ReplyJsonWithPage(
                _currentMinPage,
                index,
                widget.thread.id,
                widget.thread,
                reply)));
      });
    } on XDaoApiMsgException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.msg),
        ));
      }
    } on XDaoApiNotSuccussException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.msg),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasMoreBefore = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBefore = false;
        });
      }
    }
  }

  Future<void> _loadStartReplies(int startPage) async {
    if (!mounted) return;
    setState(() {
      _isLoadingAfter = true;
    });
    final appState = Provider.of<MyAppState>(context, listen: false);
    try {
      final newThreadData = await getThread(
          widget.thread.id, startPage, appState.getCurrentCookie());
      _currentRepliesCount =
          max(_currentRepliesCount, newThreadData.replyCount);
      setState(() {
        if (newThreadData.replies.isEmpty ||
            (newThreadData.replies.length == 1 &&
                newThreadData.replies[0].userHash == 'Tips')) {
          return;
        }
        for (var rply in newThreadData.replies) {
          refCache.put(rply.id, Future.value(RefHtml.fromReplyJson(rply)));
        }
        if (widget.startReplyId > 0) {
          final historyIndex = newThreadData.replies
              .indexWhere((data) => data.id == widget.startReplyId);
          if (historyIndex == -1) {
            _replies.addAll(newThreadData.replies.mapIndex((i, reply) =>
                ReplyJsonWithPage(
                    startPage, i, widget.thread.id, widget.thread, reply)));
          } else {
            _replies.addAll(newThreadData.replies
                .sublist(historyIndex)
                .mapIndex((i, reply) => ReplyJsonWithPage(
                    startPage, i, widget.thread.id, widget.thread, reply)));
            if (historyIndex >= 1) {
              _currentMinPage = startPage + 1; // before可加载
              _hasMoreBefore = true;
            }
          }
        } else {
          _replies.addAll(newThreadData.replies.mapIndex((i, reply) =>
              ReplyJsonWithPage(
                  startPage, i, widget.thread.id, widget.thread, reply)));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAfter = false;
        });
      }
    }
  }

  Future<void> _loadMoreAfterReplies() async {
    if (!mounted || _isLoadingAfter) return;
    setState(() {
      _isLoadingAfter = true;
    });
    if (!_hasMoreAfter) {
      setState(() {
        _isLoadingAfter = false;
      });
      return;
    }
    if (_currentMaxPage < 0) _currentMaxPage = 0;
    setState(() {
      _currentMaxPage++;
      if (_currentMaxPage > _currentRepliesCount ~/ 19 + 1) {
        _hasMoreAfter = false;
      }
    });
    final appState = Provider.of<MyAppState>(context, listen: false);
    try {
      final newThreadData = await getThread(
          widget.thread.id, _currentMaxPage, appState.getCurrentCookie());
      setState(() {
        if (newThreadData.replies.isEmpty ||
            (newThreadData.replies.length == 1 &&
                newThreadData.replies[0].userHash == 'Tips')) {
          _hasMoreAfter = false;
          return;
        }
        _currentRepliesCount =
            max(_currentRepliesCount, newThreadData.replyCount);
        _replies.removeWhere((item) => item.page == _currentMaxPage);
        for (var rply in newThreadData.replies) {
          refCache.put(rply.id, Future.value(RefHtml.fromReplyJson(rply)));
        }
        _replies.addAll(newThreadData.replies.mapIndex((i, reply) =>
            ReplyJsonWithPage(
                _currentMaxPage, i, widget.thread.id, widget.thread, reply)));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
        ));
        setState(() {
          _hasMoreAfter = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAfter = false;
        });
      }
    }
  }
}
