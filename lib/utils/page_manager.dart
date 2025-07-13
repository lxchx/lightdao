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
  final int initialPage;

  /// 每页最大数据条数，可选
  final int? pageMaxSize;

  /// 当前已加载的最小页码
  int _minLoadedPage;

  /// 当前已加载的最大页码
  int _maxLoadedPage;

  final ValueNotifier<PageState> previousPageStateNotifier;
  final ValueNotifier<PageState> nextPageStateNotifier;

  // 已知最大页数
  int? _knownMaxPage;

  @protected
  final Map<int, List<T>> _pageItems = {};

  PageLoadCallback<T>? _previousPageCallback;
  PageLoadCallback<T>? _nextPageCallback;

  bool get isEmpty => _pageItems.isEmpty || totalItemsCount == 0;

  PageManager({
    required this.initialPage,
    this.pageMaxSize,
  })  : _minLoadedPage = initialPage,
        _maxLoadedPage = initialPage,
        previousPageStateNotifier = ValueNotifier(initialPage > 1 ? const PageHasMore() : const PageFullLoaded()),
        nextPageStateNotifier = ValueNotifier(const PageHasMore());

  PageManager.withInitialItems({
    required this.initialPage,
    required this.pageMaxSize,
    required List<T> initialItems,
  })  : _minLoadedPage = initialPage,
        _maxLoadedPage = initialPage,
        previousPageStateNotifier = ValueNotifier(initialPage > 1 ? const PageHasMore() : const PageFullLoaded()),
        nextPageStateNotifier = ValueNotifier(pageMaxSize != null && initialItems.length < pageMaxSize ? const PageFullLoaded() : const PageHasMore()) {
    
    final items = _processNewItems(initialItems);
    _pageItems[initialPage] = items;
    _onAfterPageLoad(initialPage, items);

    if (pageMaxSize != null && initialItems.length < pageMaxSize!) {
      _knownMaxPage = initialPage;
    }
  }

  Future<void> initialize() async {
    if (_pageItems.containsKey(initialPage)) return;
    nextPageStateNotifier.value = const PageLoading();
    try {
      final rawItems = await fetchPage(initialPage);
      final items = _processNewItems(rawItems);
      _pageItems[initialPage] = items;
      _onAfterPageLoad(initialPage, items);
      nextPageStateNotifier.value = _isLastPage(rawItems) ? const PageFullLoaded() : const PageHasMore();
    } catch (e) {
      nextPageStateNotifier.value = PageError(e, initialize);
    }
  }

  /// 子类需要实现的获取页面数据的方法
  Future<List<T>> fetchPage(int page);
  bool isSameItem(T item1, T item2) => item1 == item2;
  
  @protected
  List<T> _processNewItems(List<T> rawItems) => rawItems;
  @protected
  void _onAfterPageLoad(int page, List<T> processedItems) {}
  
  bool _isLastPage(List<T> fetchedItems) {
    if (pageMaxSize != null) {
      return fetchedItems.length < pageMaxSize!;
    }
    return fetchedItems.isEmpty;
  }

  RangeValues get loadedPageRange => RangeValues(_minLoadedPage.toDouble(), _maxLoadedPage.toDouble());
  int get totalItemsCount => _pageItems.values.fold(0, (sum, items) => sum + items.length);

  List<T> get allLoadedItems {
    final List<T> allItems = [];
    for (int page = _minLoadedPage; page <= _maxLoadedPage; page++) {
      if (_pageItems.containsKey(page)) {
        allItems.addAll(_pageItems[page]!);
      }
    }
    return allItems;
  }

  (T, int, int)? getItemByIndex(int index) {
    if (index < 0 || index >= totalItemsCount) return null;
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

  int getLastItemIndexByPage(int page) {
    if (page < _minLoadedPage || page > _maxLoadedPage) return -1;
    final firstIndex = getFirstItemIndexByPage(page);
    if (firstIndex == -1 || !_pageItems.containsKey(page)) return -1;
    return firstIndex + _pageItems[page]!.length - 1;
  }

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

  Future<void> tryLoadPreviousPage({bool ignoreError = false}) async {
    if (previousPageStateNotifier.value is PageLoading || previousPageStateNotifier.value is PageFullLoaded) return;
    if (!ignoreError && previousPageStateNotifier.value is PageError) return;

    final previousPage = _minLoadedPage - 1;
    if (previousPage < 1) {
      previousPageStateNotifier.value = const PageFullLoaded();
      return;
    }
    previousPageStateNotifier.value = const PageLoading();

    try {
      final rawItems = await fetchPage(previousPage);
      final items = _processNewItems(rawItems);
      bool insertExecuted = false;
      
      void doInsert() {
        if (items.isNotEmpty) {
          _pageItems[previousPage] = items;
          _onAfterPageLoad(previousPage, items);
          _minLoadedPage = previousPage;
        }
        previousPageStateNotifier.value = (previousPage == 1) ? const PageFullLoaded() : const PageHasMore();
        insertExecuted = true;
      }

      if (_previousPageCallback != null) {
        _previousPageCallback!(previousPage, items.length, false, doInsert);
      } else {
        doInsert();
      }
    } catch (e) {
      previousPageStateNotifier.value = PageError(e, () => tryLoadPreviousPage(ignoreError: true));
    }
  }

  Future<void> tryLoadNextPage({bool ignoreError = false}) async {
    if (nextPageStateNotifier.value is PageLoading || nextPageStateNotifier.value is PageFullLoaded) return;
    if (!ignoreError && nextPageStateNotifier.value is PageError) return;

    final nextPage = _maxLoadedPage + 1;
    if (_knownMaxPage != null && nextPage > _knownMaxPage!) {
      nextPageStateNotifier.value = const PageFullLoaded();
      return;
    }
    nextPageStateNotifier.value = const PageLoading();

    try {
      final rawItems = await fetchPage(nextPage);
      final items = _processNewItems(rawItems);
      bool insertExecuted = false;

      void doInsert() {
        if (items.isNotEmpty) {
          _pageItems[nextPage] = items;
          _onAfterPageLoad(nextPage, items);
          _maxLoadedPage = nextPage;
        }
        if (_isLastPage(rawItems)) {
          nextPageStateNotifier.value = const PageFullLoaded();
          _knownMaxPage = items.isEmpty ? nextPage - 1 : nextPage;
        } else {
          nextPageStateNotifier.value = const PageHasMore();
        }
        insertExecuted = true;
      }

      if (_nextPageCallback != null) {
        _nextPageCallback!(nextPage, items.length, false, doInsert);
      } else {
        doInsert();
      }
    } catch (e) {
      nextPageStateNotifier.value = PageError(e, () => tryLoadNextPage(ignoreError: true));
    }
  }

  Future<int> forceLoadNextPage() async {
    if (nextPageStateNotifier.value is PageLoading) return 0;
    
    // 该功能仅适用于有固定页面大小的场景。
    if (pageMaxSize == null) {
      await tryLoadNextPage();
      return 0; // 无法计算新增数量，返回0。
    }

    nextPageStateNotifier.value = const PageLoading();
    int newItemCount = 0;

    try {
      final lastPageItems = _pageItems[_maxLoadedPage];
      final isLastPageFull = (lastPageItems?.length ?? 0) >= pageMaxSize!;

      if (isLastPageFull) {
        final nextPage = _maxLoadedPage + 1;
        final rawItems = await fetchPage(nextPage);
        final items = _processNewItems(rawItems);
        newItemCount = items.length;

        doInsert() {
          if (items.isNotEmpty) {
            _pageItems[nextPage] = items;
            _onAfterPageLoad(nextPage, items);
            _maxLoadedPage = nextPage;
          }
          if (_isLastPage(rawItems)) {
            nextPageStateNotifier.value = const PageFullLoaded();
            _knownMaxPage = items.isEmpty ? nextPage - 1 : nextPage;
          } else {
            nextPageStateNotifier.value = const PageHasMore();
          }
        }
        if (_nextPageCallback != null) {
          _nextPageCallback!(nextPage, items.length, false, doInsert);
        } else {
          doInsert();
        }

      } else {
        final oldItems = lastPageItems ?? [];
        final oldItemsCount = oldItems.length;
        final rawNewItems = await fetchPage(_maxLoadedPage);

        // 注意：此处不应再次调用 _processNewItems，因为我们需要原始列表进行比较
        // 去重逻辑会在合并后，通过覆盖旧页的方式隐式完成。
        
        List<T> mergedItems;
        if (oldItemsCount > 0) {
          final lastOldItem = oldItems.last;
          int lastOldItemIndex = -1;
          for (int i = 0; i < rawNewItems.length; i++) {
            if (isSameItem(rawNewItems[i], lastOldItem)) {
              lastOldItemIndex = i;
              break;
            }
          }
          if (lastOldItemIndex != -1 && lastOldItemIndex < rawNewItems.length - 1) {
            mergedItems = List<T>.from(oldItems)..addAll(rawNewItems.sublist(lastOldItemIndex + 1));
          } else {
            mergedItems = rawNewItems;
          }
        } else {
          mergedItems = rawNewItems;
        }
        newItemCount = mergedItems.length - oldItemsCount;
        
        doInsert() {
          _pageItems[_maxLoadedPage] = mergedItems;
          _onAfterPageLoad(_maxLoadedPage, mergedItems);
          if (_isLastPage(rawNewItems)) {
            nextPageStateNotifier.value = const PageFullLoaded();
            _knownMaxPage = _maxLoadedPage;
          } else {
            nextPageStateNotifier.value = const PageHasMore();
          }
        }

        if (_nextPageCallback != null && newItemCount > 0) {
          _nextPageCallback!(_maxLoadedPage, newItemCount, true, doInsert);
        } else {
          doInsert();
        }
      }
    } catch (e) {
      nextPageStateNotifier.value = PageError(e, forceLoadNextPage);
    }
    return newItemCount;
  }
  
  void registerPreviousPageCallback(PageLoadCallback<T> callback) { _previousPageCallback = callback; }
  void registerNextPageCallback(PageLoadCallback<T> callback) { _nextPageCallback = callback; }
  void unregisterPreviousPageCallback() { _previousPageCallback = null; }
  void unregisterNextPageCallback() { _nextPageCallback = null; }
}

mixin DeduplicatingPageManagerMixin<T, Id> on PageManager<T> {
  final Set<Id> _loadedItemIds = {};
  final Map<Id, (int, int)> _itemLocationCache = {};

  /// 子类必须实现此方法，以提供每个数据项的唯一ID。
  Id getItemId(T item);

  /// 重写基类的处理方法，注入去重和更新逻辑。
  @override
  List<T> _processNewItems(List<T> rawItems) {
    final uniqueNewItems = <T>[];
    for (final newItem in rawItems) {
      final id = getItemId(newItem);
      if (_loadedItemIds.contains(id)) {
        // ID已存在（数据漂移），执行更新。
        if (_itemLocationCache.containsKey(id)) {
          final (oldPage, oldIndexInPage) = _itemLocationCache[id]!;
          if (_pageItems.containsKey(oldPage) && _pageItems[oldPage]!.length > oldIndexInPage) {
            _pageItems[oldPage]![oldIndexInPage] = newItem;
          }
        }
      } else {
        // 全新的数据项。
        _loadedItemIds.add(id);
        uniqueNewItems.add(newItem);
      }
    }
    return uniqueNewItems;
  }

  /// 在数据插入后，更新新项目的位置缓存。
  @override
  void _onAfterPageLoad(int page, List<T> processedItems) {
    if (_pageItems.containsKey(page)) {
      final items = processedItems;
      for (int i = 0; i < items.length; i++) {
        final id = getItemId(items[i]);
        _itemLocationCache[id] = (page, i);
      }
    }
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
    if (result.items.length < pageMaxSize!) {
      nextPageStateNotifier.value = const PageFullLoaded();
    } else {
      nextPageStateNotifier.value = const PageHasMore();
    }
    return result.items;
  }
}

/// 版块页面管理器
/// 用于处理没有固定最大页数的普通板块。
class ForumPageManager extends PageManager<ThreadJson> with DeduplicatingPageManagerMixin<ThreadJson, int> {
  final int forumId;
  final String? cookie;
  final Duration timeout;

  ForumPageManager({
    required this.forumId,
    this.cookie,
    this.timeout = const Duration(seconds: 10),
    super.initialPage = 1,
  }) : super(pageMaxSize: null);

  @override
  int getItemId(ThreadJson item) => item.id;

  @override
  Future<List<ThreadJson>> fetchPage(int page) async {
    final items = await fetchForumThreads(forumId, page, cookie).timeout(timeout);
    return items;
  }
}

/// 时间线页面管理器
/// 它会处理时间线的 maxPage 限制。
class TimelinePageManager extends PageManager<ThreadJson> with DeduplicatingPageManagerMixin<ThreadJson, int> {
  final int timelineId;
  final String? cookie;
  final int maxPage;
  final Duration timeout;

  TimelinePageManager({
    required this.timelineId,
    required this.maxPage,
    this.cookie,
    this.timeout = const Duration(seconds: 10),
    super.initialPage = 1,
  }) : super(pageMaxSize: null) {
    _knownMaxPage = maxPage;
  }

  @override
  int getItemId(ThreadJson item) => item.id;

  @override
  Future<List<ThreadJson>> fetchPage(int page) async {
    if (page > maxPage) return [];
    final items = await fetchTimelineThreads(timelineId, page, cookie).timeout(timeout);
    return items;
  }
}
