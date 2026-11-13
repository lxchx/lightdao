// 审计用例（已转为正向断言）：分页引擎 PageManager / ThreadPageManager 的状态机。
//
// 原始复现见 flutter-scroll/dist/lightdao-bugs-20261113.md；
// 修复前这些用例断言「正确行为」会失败，现在是回归网。
// 运行：flutter test test/audit/page_manager_audit_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/utils/page_manager.dart';
import 'package:lightdao/utils/xdao_api.dart';

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

/// 可控返回值的串页管理器（覆盖 fetchPage，不触碰网络）。
class FakeThreadPM extends ThreadPageManager {
  FakeThreadPM({required super.initialPage}) : super(threadId: 1, cookie: null);

  final Map<int, List<ReplyJson>> pages = {};
  final List<int> fetchedPages = [];

  @override
  Future<List<ReplyJson>> fetchPage(int page) async {
    fetchedPages.add(page);
    return List<ReplyJson>.from(pages[page] ?? const <ReplyJson>[]);
  }
}

/// 带去重的假管理器：直接用 ForumPageManager（它已经混入了
/// DeduplicatingPageManagerMixin[ThreadJson, int]），只把 fetchPage
/// 换成内存数据。
///
/// 不在测试里自己 `with DeduplicatingPageManagerMixin`：mixin 的私有成员
/// 跨库时会和 PageManager 的同名私有成员冲突
/// （private_collision_in_mixin_application）。
class FakeDedupPM extends ForumPageManager {
  FakeDedupPM() : super(forumId: 1);

  final Map<int, List<ThreadJson>> pages = {};
  final List<int> fetchedPages = [];

  @override
  Future<List<ThreadJson>> fetchPage(int page) async {
    fetchedPages.add(page);
    return List<ThreadJson>.from(pages[page] ?? const <ThreadJson>[]);
  }
}

void main() {
  group('BUG-I 总页数公式：整除 19 时不能多算一页 (audit #1)', () {
    test('真实录制数据：线程 62389876 ReplyCount=418', () {
      // 每页 20 条 = 1 条 tips + 19 条回复；418 = 19 * 22
      expect(threadPageCount(418), 22);
    });

    test('边界值 0/1/18/19/20/38 都按 ceil 口径且至少 1 页', () {
      expect(threadPageCount(0), 1, reason: 'replyCount=0 时不能算出 0 页');
      expect(threadPageCount(1), 1);
      expect(threadPageCount(18), 1);
      expect(threadPageCount(19), 1, reason: '整除 19 时不应多算一页');
      expect(threadPageCount(20), 2);
      expect(threadPageCount(38), 2);
    });
  });
  group('BUG-D 空页后状态必须复位 (audit #2)', () {
    test('最后一页正好装满 + 下一页为空 → PageFullLoaded', () async {
      final pm = FakeThreadPM(initialPage: 1);
      pm.pages[1] = List<ReplyJson>.generate(19, (i) => reply(i + 1));
      pm.pages[2] = const <ReplyJson>[]; // 「只有 Tips 的页」被 fetchPage 折成 []
      await pm.initialize();
      expect(pm.nextPageStateNotifier.value, isA<PageHasMore>());

      final added = await pm.forceLoadNextPage();
      expect(added, 0);
      expect(
        pm.nextPageStateNotifier.value,
        isA<PageFullLoaded>(),
        reason: '空页后停在 PageLoading：底部永久骨架、刷新按钮与滚动加载全部早退',
      );
      expect(pm.totalItemsCount, 19);
    });

    test('空页之后再点刷新，也不应卡回 PageLoading', () async {
      final pm = FakeThreadPM(initialPage: 1);
      pm.pages[1] = List<ReplyJson>.generate(19, (i) => reply(i + 1));
      pm.pages[2] = const <ReplyJson>[];
      await pm.initialize();

      await pm.forceLoadNextPage();
      await pm.forceLoadNextPage();
      expect(pm.nextPageStateNotifier.value, isA<PageFullLoaded>());
    });
  });
  group('BUG-E 整页重复时仍要推进页码 (audit #4)', () {
    test('第 2 页全是已见条目 → 第 3 页仍能翻到', () async {
      final pm = FakeDedupPM();
      pm.pages[1] = [threadJson(1), threadJson(2), threadJson(3)];
      pm.pages[2] = [threadJson(1), threadJson(2), threadJson(3)];
      pm.pages[3] = [threadJson(4), threadJson(5)];
      await pm.initialize();

      await pm.tryLoadNextPage(); // 第 2 页全是重复
      expect(pm.fetchedPages, [1, 2]);
      expect(pm.loadedPageRange.end, 2, reason: '整页重复也要推进已加载页码');
      expect(pm.nextPageStateNotifier.value, isA<PageHasMore>());

      await pm.tryLoadNextPage();
      expect(pm.fetchedPages, [1, 2, 3], reason: '不应反复请求第 2 页');
      expect(pm.allLoadedItems.map((t) => t.id).toList(), [1, 2, 3, 4, 5]);
    });
  });

  group('BUG-J 页间部分重复：只去重、不截断 (audit #4)', () {
    test('第 2 页 5 条重复 + 15 条新条目', () async {
      final pm = FakeDedupPM();
      pm.pages[1] = List.generate(20, (i) => threadJson(i + 1)); // 1..20
      pm.pages[2] = [
        ...List.generate(5, (i) => threadJson(16 + i)), // 16..20：与第 1 页重复
        ...List.generate(15, (i) => threadJson(21 + i)), // 21..35：新条目
      ];
      pm.pages[3] = List.generate(20, (i) => threadJson(36 + i)); // 36..55
      await pm.initialize();

      await pm.tryLoadNextPage();
      expect(pm.allLoadedItems.length, 35, reason: '重复条目丢弃、新条目全部保留');
      expect(pm.loadedPageRange.end, 2);
      expect(
        pm.nextPageStateNotifier.value,
        isA<PageHasMore>(),
        reason: '服务器返回满页就不能判定末页',
      );

      await pm.tryLoadNextPage();
      expect(pm.fetchedPages, [1, 2, 3]);
      expect(pm.allLoadedItems.length, 55);
    });
  });
  group('BUG-K 上一页返回空时必须收敛 (audit #5)', () {
    test('中间页为空 → 记为失败，不再重复请求同一页', () async {
      final pm = FakeThreadPM(initialPage: 3);
      pm.pages[3] = List<ReplyJson>.generate(19, (i) => reply(i + 100));
      pm.pages[2] = const <ReplyJson>[];
      await pm.initialize();
      expect(pm.previousPageStateNotifier.value, isA<PageHasMore>());

      await pm.tryLoadPreviousPage();
      expect(
        pm.previousPageStateNotifier.value,
        isA<PageError>(),
        reason: '停在 PageHasMore 会让「加载前页」每次点击都重发同一个请求',
      );

      // 没有 ignoreError 时不应再发请求
      await pm.tryLoadPreviousPage();
      expect(pm.fetchedPages.where((p) => p == 2).length, 1);
      expect(pm.loadedPageRange.start, 3);
    });

    test('第 1 页为空 → PageFullLoaded（前面确实没有内容）', () async {
      final pm = FakeThreadPM(initialPage: 2);
      pm.pages[2] = List<ReplyJson>.generate(19, (i) => reply(i + 100));
      pm.pages[1] = const <ReplyJson>[];
      await pm.initialize();

      await pm.tryLoadPreviousPage();
      expect(pm.previousPageStateNotifier.value, isA<PageFullLoaded>());
      expect(pm.loadedPageRange.start, 2);
    });

    test('前页有数据时行为不变：插入成功且页码前移', () async {
      final pm = FakeThreadPM(initialPage: 3);
      pm.pages[3] = List<ReplyJson>.generate(19, (i) => reply(i + 100));
      pm.pages[2] = List<ReplyJson>.generate(19, (i) => reply(i + 200));
      await pm.initialize();

      await pm.tryLoadPreviousPage();
      expect(pm.previousPageStateNotifier.value, isA<PageHasMore>());
      expect(pm.loadedPageRange.start, 2);
      expect(pm.totalItemsCount, 38);
    });
  });
}
