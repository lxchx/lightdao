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
}
