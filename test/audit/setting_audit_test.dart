// 审计用例（已转为正向断言）：设置页「重置App配置」的重置范围。
//
// 原始复现见 flutter-scroll/dist/lightdao-bugs-20261113.md（BUG-H）。
// 按钮文案承诺"重置所有App配置为默认值"，CDN 也属于 App 配置
// （配错 CDN 时，重置正是最需要的自救手段），所以要一起回到 auto；
// 饼干 / 历史这类用户数据仍然保留。
// 运行：flutter test test/audit/setting_audit_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/ui/page/thread.dart' show ReplyJsonWithPage;
import 'package:lightdao/utils/kv_store.dart';

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
      askedServices: [],
      consentedServices: [],
      viewHistory: LRUCache<int, ReplyJsonWithPage>(100),
      viewPoOnlyHistory: LRUCache<int, ReplyJsonWithPage>(100),
    );
  }

  @override
  Future<void> saveSettings() async {}

  @override
  Future<void> loadSettings() async {}
}

ReplyJson _reply(int id) => ReplyJson(
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

ReplyJsonWithPage _historyEntry() {
  final reply = _reply(1);
  return ReplyJsonWithPage(1, 0, 1, reply, reply);
}

void main() {
  group('BUG-H 重置App配置应把 CDN 也恢复默认 (audit #10)', () {
    // 用 testWidgets 而不是 test：FakeAppState 构造 MyAppState 时会建
    // PersistentKVStore（走 path_provider 的 MethodChannel），需要 Flutter
    // binding 已初始化。
    testWidgets('用户自定义 CDN 后重置，baseCdn / refCdn 都回到 auto', (tester) async {
      final appState = FakeAppState();
      appState.setting.baseCdn = 'https://my.custom.example';
      appState.setting.refCdn = 'https://my.custom.example';

      appState.resetAppSettings();

      expect(appState.setting.baseCdn, 'auto');
      expect(appState.setting.refCdn, 'auto');
    });

    testWidgets('重置仍然保留饼干与浏览历史', (tester) async {
      final appState = FakeAppState();
      appState.setting.cookies = [
        CookieSetting(cookieHash: 'hashA', name: 'cookie-A', displayName: ''),
      ];
      appState.setting.currentCookie = 0;
      appState.setting.viewHistory.put(1, _historyEntry());

      appState.resetAppSettings();

      expect(appState.setting.cookies.length, 1);
      expect(appState.setting.currentCookie, 0);
      expect(appState.getCurrentCookie(), 'hashA');
      expect(appState.setting.viewHistory.length, 1);
    });
  });
}
