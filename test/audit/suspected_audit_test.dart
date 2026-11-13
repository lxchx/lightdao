// 审计用例：审计报告「疑似问题」一节的纯函数级测试。
//
// 对应 flutter-scroll/dist/lightdao-bugs-20261113.md 的疑似 #4 / #6 / #8 /
// #9 / #10 / #11 / #12。运行：flutter test test/audit/suspected_audit_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/ui/page/thread2.dart';
import 'package:lightdao/utils/xdao_api.dart';

void main() {
  group('疑似#4 仅看Po模式跳页要用 Po 的 manager', () {
    test('Po 模式下跳页 manager 必须带 isPoOnly', () {
      final manager = buildJumpTargetPageManager(
        threadId: 63452788,
        page: 5,
        cookie: 'hashA',
        poOnly: true,
      );

      expect(manager.isPoOnly, isTrue, reason: '否则跳过去拿到的是整串回复');
      expect(manager.initialPage, 5);
      expect(manager.threadId, 63452788);
    });

    test('普通模式的跳页 manager 不带 isPoOnly', () {
      final manager = buildJumpTargetPageManager(
        threadId: 1,
        page: 2,
        cookie: null,
        poOnly: false,
      );

      expect(manager.isPoOnly, isFalse);
      expect(manager.initialPage, 2);
    });
  });
  group('疑似#6 getThread 的页码校验', () {
    test('page <= 0 时抛 ArgumentError（不发请求）', () async {
      await expectLater(
        () => getThread(63452788, 0, null),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => getThread(63452788, -1, null),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => getThreadPoOnly(63452788, 0, null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
