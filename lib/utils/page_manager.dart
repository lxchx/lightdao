import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/xdao_api.dart';

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

  /// 是否正在加载前一页
  bool _isLoadingPreviousPage = false;

  /// 是否正在加载后一页
  bool _isLoadingNextPage = false;

  /// 是否还有前页可加载
  bool _hasMorePreviousPages = true;

  /// 是否还有后页可加载
  bool _hasMoreNextPages = true;

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
        _maxLoadedPage = initialPage;

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
        _maxLoadedPage = initialPage{
    _pageItems[initialPage] = initialItems;

    // 如果初始数据不足一页，标记没有更多后页
    if (initialItems.length < pageMaxSize) {
      _hasMoreNextPages = false;
      _knownMaxPage = initialPage;
    }
  }

  /// 初始化加载
  Future<void> initialize() async {
    if (_pageItems.containsKey(initialPage)) return;
    _isLoadingNextPage = true;
    try {
      await _fetchPage(initialPage);
    } finally {
      _isLoadingNextPage = false;
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
    _hasMorePreviousPages = page > 1; // 如果不是第一页，就还有前页可加载
    _hasMoreNextPages = true; // 重置后页状态
    _knownMaxPage = null; // 重置已知最大页数

    // 重置加载状态
    _isLoadingPreviousPage = false;
    _isLoadingNextPage = false;

    // 加载新页面的数据
    await _fetchPage(page);
  }

  /// 子类需要实现的获取页面数据的方法
  Future<List<T>> fetchPage(int page);

  /// 子类可以重写此方法以提供自定义的比较逻辑
  bool isSameItem(T item1, T item2) {
    return item1 == item2;
  }

  /// 是否还有前页未加载
  bool get hasMorePreviousPages => _hasMorePreviousPages && _minLoadedPage > 1;

  /// 是否还有后页未加载
  bool get hasMoreNextPages => _hasMoreNextPages;

  /// 是否正在加载前页
  bool get isLoadingPreviousPage => _isLoadingPreviousPage;

  /// 是否正在加载后页
  bool get isLoadingNextPage => _isLoadingNextPage;

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
  Future<void> tryLoadPreviousPage() async {
    if (_isLoadingPreviousPage || !hasMorePreviousPages) return;

    final previousPage = _minLoadedPage - 1;
    if (previousPage < 1) {
      _hasMorePreviousPages = false;
      return;
    }

    _isLoadingPreviousPage = true;

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
          _hasMorePreviousPages = false;
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
    } finally {
      _isLoadingPreviousPage = false;
    }
  }

  /// 尝试加载后一页
  ///
  /// 如果正在加载后一页或没有更多后页，则不执行任何操作
  Future<void> tryLoadNextPage() async {
    if (_isLoadingNextPage || !hasMoreNextPages) return;

    final nextPage = _maxLoadedPage + 1;

    // 如果已知最大页数，且已经加载到最大页，则不再加载
    if (_knownMaxPage != null && nextPage > _knownMaxPage!) {
      _hasMoreNextPages = false;
      return;
    }

    _isLoadingNextPage = true;

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
          _hasMoreNextPages = false;
          _knownMaxPage = items.isEmpty ? nextPage - 1 : nextPage;
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
    } finally {
      _isLoadingNextPage = false;
    }
  }

  /// 强制拉取新的后页
  ///
  /// 当最后一页未满页时，重新拉取最后一页
  /// 当最后一页满页时，拉取下一页
  /// 返回新增的数据数量
  Future<int> forceLoadNextPage() async {
    if (_isLoadingNextPage) return 0;

    _isLoadingNextPage = true;
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
            _hasMoreNextPages = false;
            _knownMaxPage = items.isEmpty ? nextPage - 1 : nextPage;
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
          if (newItems.length < pageMaxSize) {
            _hasMoreNextPages = false;
            _knownMaxPage = _maxLoadedPage;
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
    } finally {
      _isLoadingNextPage = false;
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

  /// fetchPage 时顺带获取最大页数，逻辑比较特殊，放到子类这里实现
  late int _threadMaxPage;

  int? _fid;
  int? get fid => _fid;

  ThreadPageManager({
    required this.threadId,
    required this.cookie,
    required super.initialPage,
    int? fid,
    this.refCache,
    this.isPoOnly = false,
  }) : super(pageMaxSize: 19) {
    _threadMaxPage = initialPage;
    _fid = fid;
  }

  ThreadPageManager.withInitialItems({
    required this.threadId,
    required this.cookie,
    required super.initialPage,
    required super.initialItems,
    this.refCache,
    this.isPoOnly = false,
  }) : super.withInitialItems(
          pageMaxSize: 19,
        ) {
    _threadMaxPage = initialPage;
  }

  int? get maxPage => _threadMaxPage;

  @override
  Future<List<ReplyJson>> fetchPage(int page) async {
    final getItems = isPoOnly ? getThreadPoOnly : getThread;
    final pageThread = await getItems(threadId, page, cookie);
    _threadMaxPage = max(_threadMaxPage, pageThread.replyCount ~/ 19 + 1);
    _fid ??= pageThread.fid;

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
