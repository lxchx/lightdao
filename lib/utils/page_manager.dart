import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/utils/google_cse_api.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/xdao_api.dart';

@immutable
sealed class PageState {
  const PageState();
}

/// There are more pages to load.
class PageHasMore extends PageState {
  const PageHasMore();
}

/// All pages have been loaded.
class PageFullLoaded extends PageState {
  const PageFullLoaded();
}

/// Currently loading a page.
class PageLoading extends PageState {
  const PageLoading();
}

/// An error occurred while loading.
class PageError extends PageState {
  final Object error;
  final Future<void> Function() retry;

  const PageError(this.error, this.retry);
}

/// 页面加载状态回调
typedef PageLoadCallback<T> = void Function(int pageIndex, int itemCount,
    bool isExistingPageUpdate, void Function() doInsert);

/// 页面管理器抽象类
/// 负责管理多页数据的加载、缓存和状态跟踪
abstract class PageManager<T> {
  /// 初始页码
  final int initialPage;

  /// 每页最大数据条数
  final int pageMaxSize;

  /// 当前已加载的最小页码
  int _minLoadedPage;

  /// 当前已加载的最大页码
  int _maxLoadedPage;

  /// 前页状态通知
  final ValueNotifier<PageState> previousPageStateNotifier;

  /// 后页状态通知
  final ValueNotifier<PageState> nextPageStateNotifier;

  /// 已知的最大页数，初始为null表示未知
  int? _knownMaxPage;

  /// 存储每页的数据
  final Map<int, List<T>> _pageItems = {};

  /// 前页加载回调
  PageLoadCallback<T>? _previousPageCallback;

  /// 后页加载回调
  PageLoadCallback<T>? _nextPageCallback;

  /// 检查是否为空
bool get isEmpty => _pageItems.isEmpty || totalItemsCount == 0;

  /// 构造函数
  PageManager({
    required this.initialPage,
    required this.pageMaxSize,
  })  : _minLoadedPage = initialPage,
        _maxLoadedPage = initialPage,
        previousPageStateNotifier = ValueNotifier(initialPage > 1 ? PageHasMore() : PageFullLoaded()),
        nextPageStateNotifier = ValueNotifier(PageHasMore());

  /// 带初始数据的构造函数
  ///
  /// [initialPage] 初始页码
  /// [pageMaxSize] 每页最大数据条数
  /// [initialItems] 初始页的数据列表
  PageManager.withInitialItems({
    required this.initialPage,
    required this.pageMaxSize,
    required List<T> initialItems,
  })  : _minLoadedPage = initialPage,
        _maxLoadedPage = initialPage,
        previousPageStateNotifier = ValueNotifier(initialPage > 1 ? PageHasMore() : PageFullLoaded()),
        nextPageStateNotifier = ValueNotifier(initialItems.length < pageMaxSize ? PageFullLoaded() : PageHasMore()) {
    _pageItems[initialPage] = initialItems;
    if (initialItems.length < pageMaxSize) {
      _knownMaxPage = initialPage;
    }
  }

  /// 初始化加载
  Future<void> initialize() async {
    if (_pageItems.containsKey(initialPage)) return;
    nextPageStateNotifier.value = PageLoading();
    try {
      final items = await _fetchPage(initialPage);
      nextPageStateNotifier.value = items.length < pageMaxSize ? PageFullLoaded() : PageHasMore();
    } catch (e) {
      nextPageStateNotifier.value = PageError(e, initialize);
    }
  }

  /// 跳转到指定页面
  ///
  /// [page] 目标页码
  /// 会清除所有已加载的页面数据，并将指定页面设为初始页
  Future<void> jumpToPage(int page) async {
    assert(page > 0, 'Page number must be greater than 0');

    // 清除所有已加载的页面数据
    _pageItems.clear();

    // 重置页面状态
    _minLoadedPage = page;
    _maxLoadedPage = page;
    previousPageStateNotifier.value = page > 1 ? PageHasMore() : PageFullLoaded();
    nextPageStateNotifier.value = PageHasMore();
    _knownMaxPage = null; // 重置已知最大页数

    // 加载新页面的数据
    nextPageStateNotifier.value = PageLoading();
    try {
      final items = await _fetchPage(page);
      nextPageStateNotifier.value = items.length < pageMaxSize ? PageFullLoaded() : PageHasMore();
    } catch (e) {
      nextPageStateNotifier.value = PageError(e, () => jumpToPage(page));
    }
  }

  /// 子类需要实现的获取页面数据的方法
  Future<List<T>> fetchPage(int page);

  /// 子类可以重写此方法以提供自定义的比较逻辑
  bool isSameItem(T item1, T item2) {
    return item1 == item2;
  }



  /// 当前已加载的页面范围
  RangeValues get loadedPageRange =>
      RangeValues(_minLoadedPage.toDouble(), _maxLoadedPage.toDouble());

  /// 当前总数据条数
  int get totalItemsCount {
    return _pageItems.values.fold(0, (sum, items) => sum + items.length);
  }

  /// 获取所有已加载的数据，按顺序排列
  List<T> get allLoadedItems {
    final List<T> allItems = [];

    // 按页码顺序添加数据
    for (int page = _minLoadedPage; page <= _maxLoadedPage; page++) {
      if (_pageItems.containsKey(page)) {
        allItems.addAll(_pageItems[page]!);
      }
    }

    return allItems;
  }

  /// 根据索引获取数据及其页码
  ///
  /// [index] 数据在所有已加载数据中的索引
  /// 返回 (数据, 页码, 页内索引) 元组，如果索引无效则返回null
  (T, int, int)? getItemByIndex(int index) {
    if (index < 0 || index >= totalItemsCount) {
      return null;
    }

    int currentIndex = 0;
    for (int page = _minLoadedPage; page <= _maxLoadedPage; page++) {
      if (!_pageItems.containsKey(page)) continue;

      final pageItems = _pageItems[page]!;
      if (currentIndex + pageItems.length > index) {
        final pageIndex = index - currentIndex;
        return (pageItems[pageIndex], page, pageIndex);
      }

      currentIndex += pageItems.length;
    }

    return null;
  }

  /// 根据页码获取该页第一个数据的索引
  ///
  /// [page] 页码
  /// 返回该页第一个数据的索引，如果页码无效则返回-1
  int getFirstItemIndexByPage(int page) {
    if (page < _minLoadedPage || page > _maxLoadedPage) return -1;

    int index = 0;
    for (int p = _minLoadedPage; p < page; p++) {
      if (_pageItems.containsKey(p)) {
        index += _pageItems[p]!.length;
      }
    }

    return index;
  }

  /// 根据页码获取该页最后一个数据的索引
  ///
  /// [page] 页码
  /// 返回该页最后一个数据的索引，如果页码无效则返回-1
  int getLastItemIndexByPage(int page) {
    if (page < _minLoadedPage || page > _maxLoadedPage) return -1;

    final firstIndex = getFirstItemIndexByPage(page);
    if (firstIndex == -1 || !_pageItems.containsKey(page)) return -1;

    return firstIndex + _pageItems[page]!.length - 1;
  }

  /// 获取页面范围信息
  ///
  /// 返回一个Map，键为页码，值为(首数据索引, 尾数据索引)元组
  Map<int, (int, int)> get pageRangeInfo {
    final Map<int, (int, int)> result = {};

    for (int page = _minLoadedPage; page <= _maxLoadedPage; page++) {
      if (_pageItems.containsKey(page)) {
        final firstIndex = getFirstItemIndexByPage(page);
        final lastIndex = getLastItemIndexByPage(page);
        if (firstIndex != -1 && lastIndex != -1) {
          result[page] = (firstIndex, lastIndex);
        }
      }
    }

    return result;
  }

  /// 尝试加载前一页
  ///
  /// 如果正在加载前一页或没有更多前页，则不执行任何操作
  Future<void> tryLoadPreviousPage({bool ignoreError = false}) async {

    if (previousPageStateNotifier.value is PageLoading || previousPageStateNotifier.value is PageFullLoaded) return;
    if (!ignoreError && previousPageStateNotifier.value is PageError) return;

    final previousPage = _minLoadedPage - 1;
    if (previousPage < 1) {
      previousPageStateNotifier.value = PageFullLoaded();
      return;
    }

    previousPageStateNotifier.value = PageLoading();

    try {
      final items = await fetchPage(previousPage);

      bool insertExecuted = false;

      // 创建插入数据的回调函数
      doInsert() {
        if (items.isNotEmpty) {
          _pageItems[previousPage] = items;
          _minLoadedPage = previousPage;
        }

        // 如果是第一页，标记没有更多前页
        if (previousPage == 1) {
          previousPageStateNotifier.value = PageFullLoaded();
        } else {
          previousPageStateNotifier.value = PageHasMore();
        }

        insertExecuted = true;
      }

      // 如果有回调，则调用回调并让回调决定何时执行doInsert
      if (_previousPageCallback != null) {
        _previousPageCallback!(previousPage, items.length, false, doInsert);

        // 检查回调是否执行了doInsert
        if (!insertExecuted) {
          doInsert();
        }
      } else {
        // 没有回调，直接执行插入
        doInsert();
      }
    } catch (e) {
      previousPageStateNotifier.value = PageError(
        e,
        () => tryLoadPreviousPage(ignoreError: true),
      );
    }
  }

  /// 尝试加载后一页
  ///
  /// 如果正在加载后一页或没有更多后页，则不执行任何操作
  Future<void> tryLoadNextPage({bool ignoreError = false}) async {
    if (nextPageStateNotifier.value is PageLoading || nextPageStateNotifier.value is PageFullLoaded) return;
    if (!ignoreError && nextPageStateNotifier.value is PageError) return;

    final nextPage = _maxLoadedPage + 1;

    // 如果已知最大页数，且已经加载到最大页，则不再加载
    if (_knownMaxPage != null && nextPage > _knownMaxPage!) {
      nextPageStateNotifier.value = PageFullLoaded();
      return;
    }

    nextPageStateNotifier.value = PageLoading();

    try {
      final items = await fetchPage(nextPage);

      bool insertExecuted = false;

      // 创建插入数据的回调函数
      doInsert() {
        if (items.isNotEmpty) {
          _pageItems[nextPage] = items;
          _maxLoadedPage = nextPage;
        }

        // 如果返回的数据为空或不足一页，说明没有更多页面了
        if (items.isEmpty || items.length < pageMaxSize) {
          nextPageStateNotifier.value = PageFullLoaded();
          _knownMaxPage = items.isEmpty ? nextPage - 1 : nextPage;
        } else {
          nextPageStateNotifier.value = PageHasMore();
        }

        insertExecuted = true;
      }

      // 如果有回调，则调用回调并让回调决定何时执行doInsert
      if (_nextPageCallback != null) {
        _nextPageCallback!(nextPage, items.length, false, doInsert);

        // 检查回调是否执行了doInsert
        if (!insertExecuted) {
          doInsert();
        }
      } else {
        // 没有回调，直接执行插入
        doInsert();
      }
    } catch (e) {
      nextPageStateNotifier.value = PageError(e, () => tryLoadNextPage(ignoreError: true));
    }
  }

  /// 强制拉取新的后页
  ///
  /// 当最后一页未满页时，重新拉取最后一页
  /// 当最后一页满页时，拉取下一页
  /// 返回新增的数据数量
  Future<int> forceLoadNextPage() async {
    if (nextPageStateNotifier.value is PageLoading) return 0;

    nextPageStateNotifier.value = PageLoading();
    int newItemCount = 0;

    try {
      final lastPageItems = _pageItems[_maxLoadedPage];
      final isLastPageFull =
          lastPageItems != null && lastPageItems.length >= pageMaxSize;

      if (isLastPageFull) {
        // 最后一页已满，拉取下一页
        final nextPage = _maxLoadedPage + 1;
        final items = await fetchPage(nextPage);
        newItemCount = items.length;

        bool insertExecuted = false;

        // 创建插入数据的回调函数
        doInsert() {
          if (items.isNotEmpty) {
            _pageItems[nextPage] = items;
            _maxLoadedPage = nextPage;
          }

          // 如果返回的数据为空或不足一页，说明没有更多页面了
          if (items.isEmpty || items.length < pageMaxSize) {
            nextPageStateNotifier.value = PageFullLoaded();
            _knownMaxPage = items.isEmpty ? nextPage - 1 : nextPage;
          } else {
            nextPageStateNotifier.value = PageHasMore();
          }

          insertExecuted = true;
        }

        // 如果有回调，则调用回调并让回调决定何时执行doInsert
        if (_nextPageCallback != null) {
          _nextPageCallback!(nextPage, items.length, false, doInsert);

          // 检查回调是否执行了doInsert
          if (!insertExecuted) {
            doInsert();
          }
        } else {
          // 没有回调，直接执行插入
          doInsert();
        }
      } else {
        // 最后一页未满，重新拉取最后一页
        final oldItems = lastPageItems ?? [];
        final oldItemsCount = oldItems.length;
        final newItems = await fetchPage(_maxLoadedPage);

        // 智能合并新旧数据
        List<T> mergedItems;
        int actualNewItemCount;

        if (oldItemsCount > 0) {
          // 尝试找到旧数据中最后一项在新数据中的位置
          final lastOldItem = oldItems.last;
          int lastOldItemIndex = -1;

          for (int i = 0; i < newItems.length; i++) {
            if (isSameItem(newItems[i], lastOldItem)) {
              lastOldItemIndex = i;
              break;
            }
          }

          if (lastOldItemIndex != -1 &&
              lastOldItemIndex < newItems.length - 1) {
            // 找到了匹配项，只添加新数据中匹配项之后的数据
            mergedItems = List<T>.from(oldItems);
            mergedItems.addAll(newItems.sublist(lastOldItemIndex + 1));
            actualNewItemCount = newItems.length - (lastOldItemIndex + 1);
          } else {
            // 没找到匹配项或匹配项是新数据的最后一项，直接使用新数据
            mergedItems = newItems;
            actualNewItemCount = max(0, newItems.length - oldItemsCount);
          }
        } else {
          // 旧数据为空，直接使用新数据
          mergedItems = newItems;
          actualNewItemCount = newItems.length;
        }
        newItemCount = actualNewItemCount;

        bool insertExecuted = false;

        // 创建插入数据的回调函数
        doInsert() {
          _pageItems[_maxLoadedPage] = mergedItems;

          // 如果返回的数据仍不足一页，说明没有更多页面了
          if (mergedItems.length < pageMaxSize) {
            nextPageStateNotifier.value = PageFullLoaded();
            _knownMaxPage = _maxLoadedPage;
          } else {
            nextPageStateNotifier.value = PageHasMore();
          }

          insertExecuted = true;
        }

        // 如果有回调，则调用回调并让回调决定何时执行doInsert
        if (_nextPageCallback != null && newItemCount > 0) {
          _nextPageCallback!(_maxLoadedPage, newItemCount, true, doInsert);

          // 检查回调是否执行了doInsert
          if (!insertExecuted) {
            doInsert();
          }
        } else {
          // 没有回调或数据没有增加，直接执行插入
          doInsert();
        }
      }
    } catch (e) {
      nextPageStateNotifier.value = PageError(e, forceLoadNextPage);
    }

    return newItemCount;
  }

  /// 注册前页加载回调
  ///
  /// [callback] 回调函数，参数为:
  /// - pageIndex: 页码
  /// - itemCount: 新增数据数量
  /// - isExistingPageUpdate: 是否是更新已有页面的数据(目前永为false)
  /// - doInsert: 执行数据插入的回调函数
  void registerPreviousPageCallback(PageLoadCallback<T> callback) {
    _previousPageCallback = callback;
  }

  /// 注册后页加载回调
  ///
  /// [callback] 回调函数，参数为:
  /// - pageIndex: 页码
  /// - itemCount: 新增数据数量
  /// - isExistingPageUpdate: 是否是更新已有页面的数据
  /// - doInsert: 执行数据插入的回调函数
  void registerNextPageCallback(PageLoadCallback<T> callback) {
    _nextPageCallback = callback;
  }

  /// 取消注册前页加载回调
  void unregisterPreviousPageCallback() {
    _previousPageCallback = null;
  }

  /// 取消注册后页加载回调
  void unregisterNextPageCallback() {
    _nextPageCallback = null;
  }

  /// 获取指定页的数据
  ///
  /// [page] 页码
  /// [forceRefresh] 是否强制刷新，即使已经加载过该页
  /// 返回该页的数据列表
  Future<List<T>> _fetchPage(int page, {bool forceRefresh = false}) async {
    if (!forceRefresh && _pageItems.containsKey(page)) {
      return _pageItems[page]!;
    }

    // 调用子类实现的方法获取页面数据
    final items = await fetchPage(page);

    _pageItems[page] = items;
    return items;
  }
}

/// 串页面管理器
class ThreadPageManager extends PageManager<ReplyJson> {
  final int threadId;
  final String? cookie;
  final LRUCache<int, Future<RefHtml>>? refCache;
  final bool isPoOnly;
  final Duration timeout;

  /// fetchPage 时顺带获取最大页数，逻辑比较特殊，放到子类这里实现
  late int _threadMaxPage;
  int? get maxPage => _threadMaxPage;

  int? _fid;
  int? get fid => _fid;

  ThreadJson? headerReply;
  ThreadJson? get header => headerReply;

  ThreadPageManager({
    required this.threadId,
    required this.cookie,
    required super.initialPage,
    this.refCache,
    this.isPoOnly = false,
    this.timeout = const Duration(seconds: 10),
  }) : super(pageMaxSize: 19) {
    _threadMaxPage = initialPage;
  }

  ThreadPageManager.withInitialItems({
    required this.threadId,
    required this.cookie,
    required super.initialPage,
    required super.initialItems,
    this.refCache,
    this.isPoOnly = false,
    this.timeout = const Duration(seconds: 10),
  }) : super.withInitialItems(
          pageMaxSize: 19,
        ) {
    _threadMaxPage = initialPage;
  }

  @override
  Future<List<ReplyJson>> fetchPage(int page) async {
    final getItems = isPoOnly ? getThreadPoOnly : getThread;
    final pageThread = await getItems(threadId, page, cookie).timeout(timeout);
    _threadMaxPage = max(_threadMaxPage, pageThread.replyCount ~/ 19 + 1);
    _fid ??= pageThread.fid;
    headerReply = pageThread;

    // 目前XDao的逻辑，可能会用一个单包含tips酱回复的页表示空页
    if (pageThread.replies.length == 1 && pageThread.replies[0].id == 9999999) {
      return [];
    }
    if (refCache != null) {
      for (final reply in pageThread.replies) {
        refCache!.put(reply.id, Future.value(RefHtml.fromReplyJson(reply)));
      }
    }

    return pageThread.replies;
  }

  @override
  bool isSameItem(ReplyJson item1, ReplyJson item2) {
    return item1.id == item2.id;
  }
}

class CSEPageManager extends PageManager<GcseItem> {
  final String query;
  final String cx;
  final String key;
  final Duration timeout;

  CSEPageManager({
    required this.query,
    this.cx = 'a72793f0a2020430b',
    this.key = 'AIzaSyD2OeVt3FHS98PqRzynqcKnCRzc47igpbM',
    this.timeout = const Duration(seconds: 10),
    super.initialPage = 1,
    super.pageMaxSize = 10,
  });

  @override
  Future<List<GcseItem>> fetchPage(int page) async {
    // 计算 start 参数
    int start = 1;
    if (page == initialPage) {
      start = 1;
    } else {
      start = totalItemsCount + 1;
    }
    final result = await googleCseSearch(
      q: query,
      cx: cx,
      key: key,
      start: start,
    ).timeout(timeout);
    // 如果返回数量不足一页，标记没有更多后页
    if (result.items.length < pageMaxSize) {
      nextPageStateNotifier.value = const PageFullLoaded();
    } else {
      nextPageStateNotifier.value = const PageHasMore();
    }
    return result.items;
  }
}
