// 审计用例（已转为正向断言）：饼干管理页删除饼干后的「当前账号」下标。
//
// 原始复现见 flutter-scroll/dist/lightdao-bugs-20261113.md（BUG-F）。
// currentCookie 存的是列表下标，删除任意一项后都必须仍然指向同一个账号。
// 运行：flutter test test/audit/cookie_audit_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/ui/page/more/cookies_management.dart';
import 'package:lightdao/ui/page/thread.dart' show ReplyJsonWithPage;
import 'package:lightdao/utils/kv_store.dart';
import 'package:provider/provider.dart';

class FakeAppState extends MyAppState {
  FakeAppState() {
    setting = LightDaoSetting.withAppDefaults(
      cookies: [],
      currentCookie: -1,
      replyHistory: [],
      starHistory: [],
      lightModeCustomThemeColor: const Color.fromARGB(255, 96, 125, 138),
      darkModeCustomThemeColor: const Color.fromARGB(255, 96, 125, 138),
      threadUserData: {},
      feedUuid: '',
      favoredForums: [],
      threadFilters: [],
      phrases: mergePhraseLists([], xDaoPhrases),
      favoredItems: [],
      baseCdn: 'auto',
      refCdn: 'auto',
      viewHistory: LRUCache<int, ReplyJsonWithPage>(100),
      viewPoOnlyHistory: LRUCache<int, ReplyJsonWithPage>(100),
    );
  }

  @override
  Future<void> saveSettings() async {}

  @override
  Future<void> loadSettings() async {}
}

/// 准备 [count] 个饼干（A/B/C…），当前使用第 [current] 个，并打开饼干管理页。
Future<FakeAppState> pumpCookiePage(
  WidgetTester tester, {
  int count = 3,
  required int current,
}) async {
  final appState = FakeAppState();
  appState.setting.cookies = [
    for (var i = 0; i < count; i++)
      CookieSetting(
        cookieHash: 'hash${String.fromCharCode(65 + i)}',
        name: 'cookie-${String.fromCharCode(65 + i)}',
        displayName: '',
      ),
  ];
  appState.setting.currentCookie = current;

  await tester.pumpWidget(
    ChangeNotifierProvider<MyAppState>.value(
      value: appState,
      child: MaterialApp(home: CookieManagementPage()),
    ),
  );
  await tester.pump();
  return appState;
}

/// 点第 [index] 个卡片上的删除按钮（UI 入口：饼干管理页的垃圾桶图标）。
Future<void> tapDelete(WidgetTester tester, int index) async {
  await tester.tap(find.byIcon(Icons.delete).at(index));
  await tester.pump();
}

void main() {
  group('BUG-F 删除饼干后 currentCookie 必须仍然指向同一个账号 (audit #3)', () {
    testWidgets('删除当前账号之前的饼干 → 当前账号不变', (tester) async {
      final appState = await pumpCookiePage(tester, current: 2); // 使用 cookie-C

      await tapDelete(tester, 0); // 删 cookie-A

      expect(appState.setting.cookies.length, 2);
      expect(appState.setting.currentCookie, 1);
      expect(
        appState.getCurrentCookie(),
        'hashC',
        reason: '删掉别的饼干不应改变当前账号；越界会静默变成匿名态',
      );
    });

    testWidgets('删除当前账号之后的饼干 → 当前账号不变', (tester) async {
      final appState = await pumpCookiePage(tester, current: 0); // 使用 cookie-A

      await tapDelete(tester, 2); // 删 cookie-C

      expect(appState.setting.currentCookie, 0);
      expect(appState.getCurrentCookie(), 'hashA');
    });

    testWidgets('删除当前账号本身 → 退回列表第一项', (tester) async {
      final appState = await pumpCookiePage(tester, current: 1); // 使用 cookie-B

      await tapDelete(tester, 1); // 删 cookie-B

      expect(appState.setting.currentCookie, 0);
      expect(appState.getCurrentCookie(), 'hashA');
    });

    testWidgets('删到一个不剩 → currentCookie = -1（未登录）', (tester) async {
      final appState = await pumpCookiePage(tester, count: 1, current: 0);

      await tapDelete(tester, 0);

      expect(appState.setting.cookies, isEmpty);
      expect(appState.setting.currentCookie, -1);
      expect(appState.getCurrentCookie(), isNull);
    });
  });
}
