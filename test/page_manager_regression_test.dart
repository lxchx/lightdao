// PageManager / ThreadPageManager 翻页状态机回归测试。
//
// test/audit/page_manager_audit_test.dart 是审计缺陷的定点用例；这里是按
// 「用户真实翻页流程」写的回归网：正常翻页、真实末页、页间部分重复，以及
// 原有行为（状态转换、页码、定位、去重结果）不许被后续改动破坏。

import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/utils/page_manager.dart';

/// 串页的每页回复数（服务端口径：1 条 tips + 19 条回复）。
const int _pageSize = 19;

ReplyJson reply(int id) => ReplyJson(
  id: id,
  fid: -1,
  replyCount: 0,
  img: '',
  ext: '',
  now: '2026-11-13(四)10:00:00',
  userHash: 'user$id',
  name: '无名氏',
  title: '无标题',
  content: 'reply $id',
  sage: false,
  admin: false,
  hide: false,
);

ThreadJson threadJson(int id) => ThreadJson(
  id: id,
  fid: 0,
  replyCount: 0,
  img: '',
  ext: '',
  now: '2026-11-13(四)10:00:00',
  userHash: 'user$id',
  name: '无名氏',
  title: '无标题',
  content: 'thread $id',
  sage: false,
  admin: false,
  hide: false,
  replies: const [],
);

/// 串页管理器：每页 19 条回复，fetchPage 返回内存里的数据。
class FakeThreadPM extends ThreadPageManager {
  FakeThreadPM({required super.initialPage}) : super(threadId: 1, cookie: null);

  final Map<int, List<ReplyJson>> pages = {};
  final List<int> fetchedPages = [];
  final List<String> stateLog = [];

  @override
  Future<List<ReplyJson>> fetchPage(int page) async {
    fetchedPages.add(page);
    return List<ReplyJson>.from(pages[page] ?? const <ReplyJson>[]);
  }
}

/// 板块/时间线页：没有固定页大小，带 DeduplicatingPageManagerMixin。
class FakeForumPM extends ForumPageManager {
  FakeForumPM() : super(forumId: 1);

  final Map<int, List<ThreadJson>> pages = {};
  final List<int> fetchedPages = [];

  @override
  Future<List<ThreadJson>> fetchPage(int page) async {
    fetchedPages.add(page);
    return List<ThreadJson>.from(pages[page] ?? const <ThreadJson>[]);
  }
}

List<ReplyJson> repliesFrom(int firstId, int count) =>
    List<ReplyJson>.generate(count, (i) => reply(firstId + i));

void main() {
  group('正常翻页：连续 3 页都有数据，第 4 页为空', () {
    late FakeThreadPM pm;

    setUp(() {
      pm = FakeThreadPM(initialPage: 1);
      pm.pages[1] = repliesFrom(1, _pageSize);
      pm.pages[2] = repliesFrom(20, _pageSize);
      pm.pages[3] = repliesFrom(39, _pageSize);
      pm.pages[4] = const <ReplyJson>[]; // 服务器用「只有 Tips 的页」表示空页
    });

    test('初始化后只有第 1 页，状态为 PageHasMore', () async {
      await pm.initialize();
      expect(pm.fetchedPages, [1]);
      expect(pm.totalItemsCount, _pageSize);
      expect(pm.loadedPageRange.start, 1);
      expect(pm.loadedPageRange.end, 1);
      expect(pm.nextPageStateNotifier.value, isA<PageHasMore>());
    });

    test('逐页翻到第 3 页：页码、条数、状态都对', () async {
      await pm.initialize();

      await pm.tryLoadNextPage();
      expect(pm.loadedPageRange.end, 2);
      expect(pm.totalItemsCount, _pageSize * 2);
      expect(pm.nextPageStateNotifier.value, isA<PageHasMore>());

      await pm.tryLoadNextPage();
      expect(pm.loadedPageRange.end, 3);
      expect(pm.totalItemsCount, _pageSize * 3);
      expect(pm.nextPageStateNotifier.value, isA<PageHasMore>());

      expect(pm.fetchedPages, [1, 2, 3]);
      expect(pm.allLoadedItems.map((r) => r.id).toList(), [
        for (var i = 1; i <= 57; i++) i,
      ]);
    });

    test('第 4 页返回空：落到 PageFullLoaded，页码不前进', () async {
      await pm.initialize();
      await pm.tryLoadNextPage();
      await pm.tryLoadNextPage();

      await pm.tryLoadNextPage(); // 第 4 页是空页
      expect(pm.nextPageStateNotifier.value, isA<PageFullLoaded>());
      expect(pm.loadedPageRange.end, 3, reason: '空页不该被算成已加载的一页');
      expect(pm.totalItemsCount, _pageSize * 3);

      // 已经到底：再触发不会发请求
      await pm.tryLoadNextPage();
      expect(pm.fetchedPages, [1, 2, 3, 4]);
    });
  });

  group('真实末页：最后一页不满 19 条', () {
    test('返回 7 条即判定到底，并记下最大页', () async {
      final pm = FakeThreadPM(initialPage: 1);
      pm.pages[1] = repliesFrom(1, _pageSize);
      pm.pages[2] = repliesFrom(20, 7);
      await pm.initialize();

      await pm.tryLoadNextPage();
      expect(pm.nextPageStateNotifier.value, isA<PageFullLoaded>());
      expect(pm.loadedPageRange.end, 2);
      expect(pm.totalItemsCount, _pageSize + 7);

      await pm.tryLoadNextPage();
      expect(pm.fetchedPages, [1, 2], reason: '已知最大页之后不应再请求');
    });
  });

  group('页间部分重复：第 2 页 5 条重复 + 15 条新的', () {
    late FakeForumPM pm;

    setUp(() {
      pm = FakeForumPM();
      pm.pages[1] = List<ThreadJson>.generate(20, (i) => threadJson(i + 1));
      pm.pages[2] = [
        ...List<ThreadJson>.generate(5, (i) => threadJson(16 + i)), // 16..20
        ...List<ThreadJson>.generate(15, (i) => threadJson(21 + i)), // 21..35
      ];
      pm.pages[3] = List<ThreadJson>.generate(20, (i) => threadJson(36 + i));
    });

    test('重复条目丢弃、新条目全部保留，页码继续前进', () async {
      await pm.initialize();
      expect(pm.totalItemsCount, 20);

      await pm.tryLoadNextPage();
      expect(pm.totalItemsCount, 35);
      expect(pm.loadedPageRange.end, 2);
      expect(pm.nextPageStateNotifier.value, isA<PageHasMore>());

      final ids = pm.allLoadedItems.map((t) => t.id).toList();
      expect(ids.length, 35);
      expect(ids.toSet().length, 35, reason: '不许出现重复 id');
      expect(ids.contains(16) && ids.contains(20), isTrue);
    });

    test('整页都是重复时页码依然前进，不会反复请求同一页', () async {
      pm.pages[2] = List<ThreadJson>.generate(20, (i) => threadJson(i + 1));
      await pm.initialize();

      await pm.tryLoadNextPage(); // 第 2 页全是重复
      expect(pm.loadedPageRange.end, 2, reason: '整页重复也要推进页码');
      expect(pm.totalItemsCount, 20, reason: '去重后没有新增内容');
      expect(pm.nextPageStateNotifier.value, isA<PageHasMore>());

      await pm.tryLoadNextPage();
      expect(pm.fetchedPages, [1, 2, 3]);
      expect(pm.totalItemsCount, 20 + 20, reason: '第 2 页全是重复，只有第 3 页的 20 条是新的');
    });
  });

  group('原有行为不变：状态转换 / 页码定位 / 刷新路径', () {
    test('每次翻页都经过一次 PageLoading，再落最终状态', () async {
      final pm = FakeThreadPM(initialPage: 1);
      pm.pages[1] = repliesFrom(1, _pageSize);
      pm.pages[2] = repliesFrom(20, _pageSize);
      pm.pages[3] = repliesFrom(39, _pageSize);
      final log = <String>[];
      pm.nextPageStateNotifier.addListener(
        () => log.add(pm.nextPageStateNotifier.value.runtimeType.toString()),
      );

      await pm.initialize();
      await pm.tryLoadNextPage();
      await pm.tryLoadNextPage();

      expect(log, [
        'PageLoading', 'PageHasMore', // initialize
        'PageLoading', 'PageHasMore', // 第 2 页
        'PageLoading', 'PageHasMore', // 第 3 页
      ]);
    });

    test('下标定位：页首/页尾/跨页取值', () async {
      final pm = FakeThreadPM(initialPage: 1);
      pm.pages[1] = repliesFrom(1, _pageSize);
      pm.pages[2] = repliesFrom(20, _pageSize);
      pm.pages[3] = repliesFrom(39, _pageSize);
      await pm.initialize();
      await pm.tryLoadNextPage();
      await pm.tryLoadNextPage();

      expect(pm.getFirstItemIndexByPage(2), _pageSize);
      expect(pm.getLastItemIndexByPage(3), _pageSize * 3 - 1);
      expect(pm.getItemByIndex(0)?.$1.id, 1);
      expect(pm.getItemByIndex(0)?.$2, 1);
      expect(pm.getItemByIndex(_pageSize * 3 - 1)?.$1.id, 57);
      expect(pm.getItemByIndex(_pageSize * 3 - 1)?.$2, 3);
      expect(pm.getItemByIndex(_pageSize * 3), isNull);
      expect(pm.pageRangeInfo[2], (_pageSize, _pageSize * 2 - 1));
    });

    test('刷新最后一页（forceLoadNextPage）：只返回新增条数', () async {
      final pm = FakeThreadPM(initialPage: 1);
      pm.pages[1] = repliesFrom(1, _pageSize);
      pm.pages[2] = repliesFrom(20, _pageSize);
      pm.pages[3] = repliesFrom(39, 7);
      await pm.initialize();
      await pm.tryLoadNextPage();
      await pm.tryLoadNextPage();
      expect(pm.nextPageStateNotifier.value, isA<PageFullLoaded>());
      expect(pm.totalItemsCount, _pageSize * 2 + 7);

      // 服务端这一页后来多了 5 条回复
      pm.pages[3] = repliesFrom(39, 12);
      final added = await pm.forceLoadNextPage();
      expect(added, 5);
      expect(pm.totalItemsCount, _pageSize * 2 + 12);
      expect(pm.loadedPageRange.end, 3);
      expect(pm.nextPageStateNotifier.value, isA<PageFullLoaded>());
    });
  });
}
