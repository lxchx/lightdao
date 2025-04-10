import 'dart:async';

import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/utils/page_manager.dart';
import 'package:lightdao/ui/widget/reply_item.dart';
import 'package:lightdao/ui/widget/slivding_app_bar.dart';
import 'package:lightdao/ui/widget/util_funtions.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/throttle.dart';
import 'package:lightdao/utils/xdao_api.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:tsukuyomi_list/tsukuyomi_list.dart';

/// 分隔线包装器
///
/// 根据条件在子组件下方添加分隔线
class DividerWrapper extends StatelessWidget {
  final Widget child;

  final bool showDivider;

  final EdgeInsetsGeometry? dividerPadding;

  final Widget divider;

  const DividerWrapper({
    super.key,
    required this.child,
    required this.showDivider,
    this.dividerPadding,
    this.divider = const Divider(),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        if (showDivider)
          dividerPadding != null
              ? Padding(
                  padding: dividerPadding!,
                  child: divider,
                )
              : divider,
      ],
    );
  }
}

class ThreadPage2 extends StatefulWidget {
  final ThreadJson headerThread;
  final int startPage;
  final bool isCompletePage;
  final int? startReplyId;

  ThreadPage2({
    super.key,
    required this.headerThread,
    required this.startPage,
    this.isCompletePage = false,
    this.startReplyId,
  });

  @override
  State<ThreadPage2> createState() => _ThreadPage2State();
}

class _ThreadPage2State extends State<ThreadPage2> {
  final _scrollController = TsukuyomiListScrollController();
  late ThreadPageManager _pageManager;
  ThreadPageManager? _poPageManager;

  bool _isPoOnlyMode = false;
  bool _showBar = true;
  final _saveHistoryThrottle = Throttle(interval: Duration(seconds: 1));
  bool _isRawPicMode = false;

  final _refCache = LRUCache<int, Future<RefHtml>>(100);

  // 回复相关状态
  XFile? _replyImageFile;
  final _replyTextControler = TextEditingController();
  final _replyTitleControler = TextEditingController();
  final _replyAuthorControler = TextEditingController();

  ThreadPageManager get _curPageManager {
    return _isPoOnlyMode ? _poPageManager! : _pageManager;
  }

  int? get _anchorReplyIndex {
    if (_curPageManager.totalItemsCount == 0) return null;

    final anchorIndex = _scrollController.anchorIndex;
    // 处理特殊情况：顶部和底部
    if (anchorIndex == 0) return 0;
    if (anchorIndex == _curPageManager.totalItemsCount + 1) {
      return _curPageManager.totalItemsCount - 1;
    }

    // 普通情况：减1得到实际回复索引
    return anchorIndex - 1;
  }

  int get _anchorPage => _anchorReplyIndex == null
      ? 1
      : _curPageManager.getItemByIndex(_anchorReplyIndex!)?.$2 ?? 1;

  void _showFontSizeDialog(BuildContext context) {
    final appState = Provider.of<MyAppState>(context, listen: false);

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
                      value: appState.setting.fontSizeFactor,
                      divisions: 6,
                      onChanged: (double value) {
                        appState.setState((state) {
                          state.setting.fontSizeFactor = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('确定'))
              ],
            ));
  }

  void _toggleFavorite(BuildContext context) {
    final appState = Provider.of<MyAppState>(context, listen: false);
    final threadId = widget.headerThread.id;

    if (appState.isStared(threadId)) {
      appState.setState((_) {
        appState.setting.starHistory
            .removeWhere((reply) => reply.thread.id == threadId);
      });
    } else {
      appState.setState((_) {
        final history = ReplyJsonWithPage(
          _anchorPage,
          _curPageManager.getItemByIndex(_anchorReplyIndex!)!.$3,
          widget.headerThread.id,
          widget.headerThread,
          _curPageManager.getItemByIndex(_anchorReplyIndex!)!.$1,
        );

        appState.setting.starHistory.add(history);
      });
    }
  }

  void _showPageJumpDialog(BuildContext context) {
    final currentPage = _anchorPage;
    final maxPage = _curPageManager.maxPage ?? 1;

    int selectedPage = currentPage;
    bool jumpToEnd = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isFirstPage = selectedPage <= 1;
            final isPrevDisabled = selectedPage <= 1;
            final isNextDisabled = selectedPage >= maxPage;
            final isLastPage = selectedPage >= maxPage;

            return AlertDialog(
              title: Text('跳页'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    clipBehavior: Clip.none,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(Icons.first_page),
                          onPressed: isFirstPage
                              ? null
                              : () {
                                  setState(() {
                                    selectedPage = 1;
                                  });
                                },
                          tooltip: '第一页',
                        ),
                        IconButton(
                          icon: Icon(Icons.navigate_before),
                          onPressed: isPrevDisabled
                              ? null
                              : () {
                                  setState(() {
                                    selectedPage = selectedPage - 1;
                                  });
                                },
                          tooltip: '上一页',
                        ),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: TextEditingController(
                                text: selectedPage.toString()),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '页数',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                final newPage = int.tryParse(value);
                                if (newPage != null &&
                                    newPage > 0 &&
                                    newPage <= maxPage) {
                                  setState(() {
                                    selectedPage = newPage;
                                  });
                                }
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text('/ $maxPage'),
                        IconButton(
                          icon: Icon(Icons.navigate_next),
                          onPressed: isNextDisabled
                              ? null
                              : () {
                                  setState(() {
                                    selectedPage = selectedPage + 1;
                                  });
                                },
                          tooltip: '下一页',
                        ),
                        IconButton(
                          icon: Icon(Icons.last_page),
                          onPressed: isLastPage
                              ? null
                              : () {
                                  setState(() {
                                    selectedPage = maxPage;
                                  });
                                },
                          tooltip: '最后一页',
                        ),
                      ],
                    ),
                  ),
                  if (isLastPage)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: jumpToEnd,
                            onChanged: (value) {
                              setState(() {
                                jumpToEnd = value ?? false;
                              });
                            },
                          ),
                          Text('跳到页尾'),
                        ],
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
                    Navigator.of(context).pop();
                    _jumpToPage(selectedPage, jumpToEnd);
                  },
                  child: Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<T?> _handlePageManagerError<T>(Future<T> future) {
    return future.then((value) {
      setState(() {});
      return value;
    }).onError((error, stackTrace) {
      if (error is XDaoApiNotSuccussException || error is XDaoApiMsgException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return Future.value(null);
      }

      // 对于其他类型的错误，显示吐司但仍然抛出
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发生错误: ${error.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        throw error; // 重新抛出错误
      }
      return Future.value(null);
    });
  }

  void _jumpToPage(int page, bool jumpToEnd) {
    final loadedRange = _curPageManager.loadedPageRange;

    // 检查页面是否已加载
    if (page >= loadedRange.start && page <= loadedRange.end) {
      // 页面已加载，直接跳转
      int targetIndex;
      if (jumpToEnd && page == _curPageManager.maxPage) {
        // 跳到页尾
        targetIndex = _curPageManager.getLastItemIndexByPage(page);
      } else {
        // 跳到页首
        targetIndex = _curPageManager.getFirstItemIndexByPage(page);
      }

      if (targetIndex != -1) {
        // TsukuyomiList的索引需要+1（因为第一项是头部）
        _scrollController.jumpToIndex(targetIndex + 1);
        if (jumpToEnd) {
          _handlePageManagerError(_curPageManager.tryLoadNextPage());
        }
      }
    } else {
      // 页面未加载，使用jumpToPage方法
      _handlePageManagerError(_curPageManager.jumpToPage(page)).then((_) {
        if (jumpToEnd) {
          _scrollController.jumpToIndex(_curPageManager.totalItemsCount - 1);
          _handlePageManagerError(_curPageManager.tryLoadNextPage());
        }
      });
    }
  }

  _saveHistory() {
    if (_pageManager.isEmpty ||
        _anchorReplyIndex == null ||
        (_anchorReplyIndex != null &&
            _anchorReplyIndex! > _curPageManager.totalItemsCount)) {
      return;
    }
    final appState = Provider.of<MyAppState>(context, listen: false);
    final history = _anchorReplyIndex != null
        ? ReplyJsonWithPage(
            _anchorPage,
            _curPageManager.getItemByIndex(_anchorReplyIndex!)!.$3,
            widget.headerThread.id,
            widget.headerThread,
            _curPageManager.getItemByIndex(_anchorReplyIndex!)!.$1,
          )
        : null;
    if (history == null) {
      return;
    }

    appState.setState((_) {
      if (_isPoOnlyMode) {
        appState.setting.viewPoOnlyHistory.put(widget.headerThread.id, history);
      } else {
        if (appState.setting.starHistory
            .any(((rply) => rply.threadId == widget.headerThread.id))) {
          appState.setting.starHistory
              .removeWhere((rply) => rply.threadId == widget.headerThread.id);
          appState.setting.starHistory.insert(0, history);
        }
        appState.setting.viewHistory.put(widget.headerThread.id, history);
      }
    });
  }

  Future<dynamic> _showThreadActionMenu(
      BuildContext context, ReplyJson reply, bool isThread) {
    return showDialog(
      context: context,
      builder: (context) {
        final appState = Provider.of<MyAppState>(context, listen: false);

        // 创建引用选项
        Widget buildQuoteOption() {
          return SimpleDialogOption(
            child: Text(isThread ? '引用该串' : '引用回复'),
            onPressed: () {
              Navigator.of(context).pop();
              _replyTextControler.text += '>>No.${reply.id}\n';

              // 显示回复底部表单
              showReplyBottomSheet(
                  context,
                  false,
                  widget.headerThread.id,
                  _curPageManager.maxPage ?? 1,
                  widget.headerThread,
                  _replyImageFile,
                  (image) => _replyImageFile = image,
                  _replyTitleControler,
                  _replyAuthorControler,
                  _replyTextControler, () {
                // 在回调中首先检查组件是否仍然挂载
                if (!mounted) return;

                // 如果已经加载到最后一页，重新加载以刷出自己的回复
                if (_anchorPage >= (_curPageManager.maxPage ?? 1)) {
                  _handlePageManagerError(_curPageManager.forceLoadNextPage());
                }

                // 显示发送成功提示
                if (mounted) {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text('发送成功'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: '查看回复',
                        onPressed: () {
                          // 跳转到最后一页前检查组件是否仍然挂载
                          if (!mounted) return;
                          _jumpToPage(_curPageManager.maxPage ?? 1, true);
                        },
                      ),
                    ),
                  );
                }
              });
            },
          );
        }

        // 创建复制内容选项
        Widget buildCopyContentOption() {
          return SimpleDialogOption(
            child: Text('复制内容'),
            onPressed: () {
              // 获取页面路由
              PageRoute pageRoute(
                  {required Widget Function(BuildContext) builder}) {
                final setting =
                    Provider.of<MyAppState>(context, listen: false).setting;
                return setting.enableSwipeBack
                    ? SwipeablePageRoute(builder: builder)
                    : MaterialPageRoute(builder: builder);
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
                                fontSizeFactor: appState.setting.fontSizeFactor,
                              )),
                      child: SelectionArea(
                        child: ListView(
                          children: [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                      textTheme: Theme.of(context)
                                          .textTheme
                                          .apply(
                                            fontSizeFactor:
                                                appState.setting.fontSizeFactor,
                                          )),
                                  child: ReplyItem(
                                    poUserHash: widget.headerThread.userHash,
                                    threadJson: reply,
                                    contentNeedCollapsed: false,
                                    noMoreParse: true,
                                    contentHeroTag: "reply${reply.id}",
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        // 创建屏蔽ID选项
        Widget buildBlockIdOption() {
          return SimpleDialogOption(
            child: Text('屏蔽No.${reply.id}'),
            onPressed: () {
              // 检查并添加ID过滤器
              bool isIdFiltered = appState.setting.threadFilters.any((filter) =>
                  filter is IdThreadFilter && filter.id == reply.id);

              if (!isIdFiltered) {
                appState.setState((_) {
                  appState.setting.threadFilters
                      .add(IdThreadFilter(id: reply.id));
                });
              }
              Navigator.of(context).pop();
            },
          );
        }

        // 创建屏蔽饼干选项
        Widget buildBlockUserHashOption() {
          return SimpleDialogOption(
            child: Text('屏蔽饼干${reply.userHash}'),
            onPressed: () {
              // 检查并添加饼干过滤器
              bool isUserHashFiltered = appState.setting.threadFilters.any(
                  (filter) =>
                      filter is UserHashFilter &&
                      filter.userHash == reply.userHash);

              if (!isUserHashFiltered) {
                appState.setState((_) {
                  appState.setting.threadFilters
                      .add(UserHashFilter(userHash: reply.userHash));
                });
              }
              Navigator.of(context).pop();
            },
          );
        }

        // 构建对话框
        return SimpleDialog(
          title: Text(reply.userHash != 'Tips' ? 'No.${reply.id}' : 'Tips'),
          children: [
            if (reply.userHash != 'Tips') buildQuoteOption(),
            buildCopyContentOption(),
            buildBlockIdOption(),
            buildBlockUserHashOption(),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    final appState = Provider.of<MyAppState>(context, listen: false);
    if (widget.isCompletePage) {
      _pageManager = ThreadPageManager.withInitialItems(
        threadId: widget.headerThread.id,
        initialPage: widget.startPage,
        cookie: appState.getCurrentCookie(),
        initialItems: widget.headerThread.replies,
        refCache: _refCache,
      );
    } else {
      _pageManager = ThreadPageManager(
        threadId: widget.headerThread.id,
        initialPage: widget.startPage,
        cookie: appState.getCurrentCookie(),
        refCache: _refCache,
      );
    }
    _pageManager
        .registerPreviousPageCallback((page, newItemCount, _, doInsert) {
      _scrollController.onBatchInsertItems(0, newItemCount, () => doInsert());
    });
    _scrollController.addListener(() {
      final shouldShowBar = _scrollController.position.userScrollDirection !=
          ScrollDirection.reverse;
      if (_showBar != shouldShowBar) {
        setState(() => _showBar = shouldShowBar);
      }
    });
    _scrollController.addListener(() {
      // 当距离底部不到一个屏幕高度时加载下一页
      final position = _scrollController.position;
      final maxScrollExtent = position.maxScrollExtent;
      final currentPixels = position.pixels;
      final viewportDimension = position.viewportDimension;

      if (maxScrollExtent - currentPixels <= viewportDimension) {
        _handlePageManagerError(_curPageManager.tryLoadNextPage());
      }
    });
    _scrollController.addListener(() {
      _saveHistoryThrottle.run(() async => _saveHistory());
    });

    Future.microtask(() async {
      await _handlePageManagerError(_pageManager.initialize());
      setState(() {});
      // 预加载下一页
      _handlePageManagerError(
          _pageManager.tryLoadNextPage().then((_) => setState(() {})));
      Future.delayed(Duration(milliseconds: 100), () {
        if (!mounted) return;

        _saveHistory();
        if (widget.startReplyId == null) {
          return;
        }
        final replyIndex = _pageManager.allLoadedItems
            .indexWhere((rply) => rply.id == widget.startReplyId);
        if (replyIndex <= 1) {
          // 前两个reply就不跳转了，免得总跳转体感不流畅
          return;
        }
        if (replyIndex != -1) {
          // 确保列表已经构建完成后跳转到历史记录的reply
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _scrollController.jumpToIndex(replyIndex + 1);
              } catch (e) {
                print('跳转失败: $e');
              }
            }
          });
        }
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);

    final replyCount = _curPageManager.totalItemsCount;

    final initReplyIndex = !widget.isCompletePage
        ? null
        : widget.headerThread.replies
            .indexWhere((rply) => rply.id == widget.startReplyId);

    // 确保索引有效（大于0且小于总项数）
    final validInitReplyIndex = initReplyIndex != null &&
            initReplyIndex > 0 &&
            initReplyIndex < replyCount + 2
        ? initReplyIndex
        : null;

    late List<String> allImageNames;
    allImageNames = [
      if (widget.headerThread.img != '')
        '${widget.headerThread.img}${widget.headerThread.ext}',
      ..._curPageManager.allLoadedItems
          .where((rply) => rply.img != '')
          .map((rply) => '${rply.img}${rply.ext}')
    ];

    Widget myDividerWrapper({required Widget child, double padding = 0}) {
      return DividerWrapper(
        showDivider: appState.setting.dividerBetweenReply,
        dividerPadding: EdgeInsets.symmetric(vertical: breakpoint.gutters / 2),
        child: child,
      );
    }

    final loadingReply = Padding(
      padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
      child: Skeletonizer(
        effect: ShimmerEffect(
          baseColor:
              Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(70),
          highlightColor:
              Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(50),
        ),
        enabled: true,
        child: ReplyItem(
          contentNeedCollapsed: false,
          threadJson: fakeThread,
        ),
      ),
    );

    return Scaffold(
      appBar: SlidingAppBar(
        duration: Durations.medium1,
        visible: _showBar || appState.setting.fixedBottomBar,
        child: AppBar(
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HtmlWidget(
                  '${appState.forumMap[widget.headerThread.fid]?.getShowName() ?? '未知'}・${widget.headerThread.id}',
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
                    'https://www.nmbxd1.com/t/${widget.headerThread.id}'),
                icon: Icon(Icons.share)),
            PopupMenuButton<String>(
              tooltip: '更多选项',
              onSelected: (value) async {
                switch (value) {
                  case 'raw_mode':
                    setState(() {
                      _isRawPicMode = !_isRawPicMode;
                    });
                    break;
                  case 'po_mode':
                    if (_poPageManager == null) {
                      final threadHistory = appState.setting.viewPoOnlyHistory
                          .get(widget.headerThread.id);

                      _poPageManager = ThreadPageManager(
                        threadId: widget.headerThread.id,
                        initialPage: threadHistory?.page ?? 1,
                        cookie: appState.getCurrentCookie(),
                        refCache: _refCache,
                        isPoOnly: true,
                      );

                      _handlePageManagerError(_poPageManager!.initialize());

                      _poPageManager!.registerPreviousPageCallback(
                          (page, newItemCount, _, doInsert) {
                        _scrollController.onBatchInsertItems(
                            0, newItemCount, () => doInsert());
                      });
                    }
                    await _scrollController.animateTo(0,
                        duration: Durations.long1, curve: Curves.easeOut);
                    setState(() => _isPoOnlyMode = !_isPoOnlyMode);
                    //setState(() {});
                    break;
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'raw_mode',
                  checked: _isRawPicMode,
                  child: Text('原图模式'),
                ),
                CheckedPopupMenuItem(
                  value: 'po_mode',
                  checked: _isPoOnlyMode,
                  child: Text('仅看Po'),
                ),
              ],
            ),
          ],
        ),
      ),
      body: TsukuyomiList.builder(
        cacheExtent: MediaQuery.of(context).size.height * 3,
        controller: _scrollController,
        initialScrollIndex: validInitReplyIndex,
        itemCount: replyCount + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                InkWell(
                  onLongPress: () =>
                      _showThreadActionMenu(context, widget.headerThread, true),
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: breakpoint.gutters,
                        right: breakpoint.gutters,
                        bottom: breakpoint.gutters / 2),
                    child: FilterableThreadWidget(
                      reply: widget.headerThread,
                      isTimeLineFilter: false,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            textTheme: Theme.of(context).textTheme.apply(
                                  fontSizeFactor:
                                      appState.setting.fontSizeFactor,
                                )),
                        child: ReplyItem(
                          poUserHash: widget.headerThread.userHash,
                          isRawPicMode: _isRawPicMode,
                          isThreadFirstOrForumPreview: true,
                          threadJson: widget.headerThread,
                          contentNeedCollapsed: false,
                          contentHeroTag:
                              'ThreadCard ${widget.headerThread.id}',
                          imageHeroTag:
                              'Image ${widget.headerThread.img}${widget.headerThread.ext}',
                          imageInitIndex:
                              widget.headerThread.img == '' ? null : 0,
                          imageNames: allImageNames,
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(),
                if (_curPageManager.isLoadingPreviousPage)
                  myDividerWrapper(child: loadingReply)
                else if (_curPageManager.hasMorePreviousPages)
                  myDividerWrapper(
                      child: InkWell(
                    onTap: () {
                      _scrollController.jumpToIndex(1);
                      _handlePageManagerError(
                          _curPageManager.tryLoadPreviousPage());
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              _scrollController.jumpToIndex(1);
                              _handlePageManagerError(
                                  _curPageManager.tryLoadPreviousPage());
                            },
                            child: Text('加载前页的回复')),
                      ],
                    ),
                  ))
              ],
            );
          } else if (index == replyCount + 1) {
            return Column(
              children: [
                if (_curPageManager.isLoadingNextPage)
                  loadingReply
                else
                  Column(
                    children: [
                      if (!appState.setting.dividerBetweenReply)
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: breakpoint.gutters / 2),
                          child: Divider(),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: InkWell(
                          onTap: () {
                            _handlePageManagerError(
                                    _curPageManager.forceLoadNextPage())
                                .then((replyCount) {
                              if (replyCount == 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('没有更多回复了！'),
                                    duration: Durations.long1,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            });
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: breakpoint.gutters / 2),
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
                              style:
                                  TextStyle(color: Theme.of(context).hintColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                //const Text('这里是尾部'),
              ],
            );
          }
          final replyIndex = index - 1;
          // 有的时候因为数据不同步会导致index越界，简单处理一下
          if (replyIndex >= _curPageManager.totalItemsCount) {
            return SizedBox.shrink();
          }
          final (reply, page, _) = _curPageManager.getItemByIndex(replyIndex)!;
          final imageName = '${reply.img}${reply.ext}';
          final imageIndex = allImageNames.indexOf(imageName);
          return myDividerWrapper(
            child: InkWell(
              onLongPress: () => _showThreadActionMenu(context, reply, false),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: breakpoint.gutters,
                    vertical: breakpoint.gutters / 2),
                child: FilterableThreadWidget(
                  reply: reply,
                  isTimeLineFilter: false,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                        textTheme: Theme.of(context).textTheme.apply(
                              fontSizeFactor: appState.setting.fontSizeFactor,
                            )),
                    child: ReplyItem(
                      key: ValueKey('threadCard ${reply.id} in Page $page'),
                      poUserHash: widget.headerThread.userHash,
                      isRawPicMode: _isRawPicMode,
                      threadJson: reply,
                      contentNeedCollapsed: false,
                      imageHeroTag: 'Image ${reply.img}${reply.ext}',
                      imageInitIndex: imageIndex,
                      imageNames: allImageNames,
                      refCache: _refCache,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutExpo,
          height: _showBar || appState.setting.fixedBottomBar ? 67 : 0,
          child: BottomAppBar(
            shape: CircularNotchedRectangle(),
            child: _showBar || appState.setting.fixedBottomBar
                ? Row(
                    children: [
                      IconButton(
                        tooltip: '收藏',
                        onPressed: () => _toggleFavorite(context),
                        icon: Icon(appState.isStared(widget.headerThread.id)
                            ? Icons.favorite
                            : Icons.favorite_border),
                      ),
                      IconButton(
                          tooltip: '页跳转',
                          onPressed: () {
                            _showPageJumpDialog(context);
                          },
                          icon: Icon(Icons.move_down)),
                      IconButton(
                        tooltip: '字体大小调整',
                        onPressed: () => _showFontSizeDialog(context),
                        icon: Icon(Icons.format_size),
                      ),
                    ],
                  )
                : SizedBox.shrink(),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: (!_showBar && !appState.setting.fixedBottomBar)
          ? null
          : FloatingActionButton(
              shape: CircleBorder(),
              tooltip: '回复',
              child: Icon(Icons.create),
              onPressed: () => showReplyBottomSheet(
                  context,
                  false,
                  widget.headerThread.id,
                  _curPageManager.maxPage ?? 1,
                  widget.headerThread,
                  _replyImageFile,
                  (image) => _replyImageFile = image,
                  _replyTitleControler,
                  _replyAuthorControler,
                  _replyTextControler, () {
                // 在回调中首先检查组件是否仍然挂载
                if (!mounted) return;

                // 如果已经加载到最后一页，重新加载以刷出自己的回复
                if (_anchorPage >= (_curPageManager.maxPage ?? 1)) {
                  _handlePageManagerError(_curPageManager.forceLoadNextPage());
                }

                // 显示发送成功提示
                if (mounted) {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text('发送成功'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: '查看回复',
                        onPressed: () {
                          // 跳转到最后一页前检查组件是否仍然挂载
                          if (!mounted) return;
                          _jumpToPage(_curPageManager.maxPage ?? 1, true);
                        },
                      ),
                    ),
                  );
                }
              }),
            ),
    );
  }
}
