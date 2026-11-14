// 同意流程：首次询问 / 清单新增后的重新询问 / 设置里改主意，分别写什么。
//
// 关键约束：重新询问时点「不同意」只把新增项记成「问过」，不能连带撤销
// 之前同意过的项，也不能下次启动再问一遍。
// 运行：flutter test test/third_party_consent_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/third_party_consent.dart';

class FakeAppState extends MyAppState {
  FakeAppState({
    List<String> askedServices = const [],
    List<String> consentedServices = const [],
  }) {
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
      phrases: [],
      favoredItems: [],
      baseCdn: 'auto',
      refCdn: 'auto',
      askedServices: askedServices,
      consentedServices: consentedServices,
    );
  }

  @override
  Future<void> saveSettings() async {}

  @override
  Future<void> loadSettings() async {}
}

/// 只有「更新检查 + 第三方线路」的旧清单：用来模拟清单新增串搜索之后的老用户。
const List<String> oldAsked = [kUpdateServiceId, kCdnServiceId];

void main() {
  // FakeAppState 构造 MyAppState 时会建 PersistentKVStore（走 path_provider 的
  // MethodChannel），需要已初始化的 Flutter binding，所以用 testWidgets。
  testWidgets('首次询问点「同意」：问过与同意都写入整份清单', (tester) async {
    final appState = FakeAppState();

    expect(
      appState.setting.pendingThirdPartyServices,
      isNotEmpty,
      reason: '还没问过',
    );
    appState.recordConsentPageDecision(true);

    expect(appState.setting.askedServices, allThirdPartyServiceIds());
    expect(appState.setting.consentedServices, allThirdPartyServiceIds());
    expect(appState.setting.pendingThirdPartyServices, isEmpty, reason: '不会再问');
    for (final id in allThirdPartyServiceIds()) {
      expect(appState.isServiceAllowed(id), isTrue, reason: id);
    }
  });

  testWidgets('首次询问点「不同意」：算问过、一项都没同意，下次不再问', (tester) async {
    final appState = FakeAppState();

    appState.recordConsentPageDecision(false);

    expect(appState.setting.askedServices, allThirdPartyServiceIds());
    expect(appState.setting.consentedServices, isEmpty);
    expect(appState.setting.pendingThirdPartyServices, isEmpty, reason: '不再追问');
    for (final id in allThirdPartyServiceIds()) {
      expect(appState.isServiceAllowed(id), isFalse, reason: id);
    }
  });

  testWidgets('重新询问时点「不同意」：旧的项照常可用，新增项被拦，之后不再问', (tester) async {
    // 老用户：问过也同意了旧清单，清单里后来又加了串搜索。
    final appState = FakeAppState(
      askedServices: oldAsked,
      consentedServices: oldAsked,
    );
    expect(
      appState.setting.pendingThirdPartyServices.map((service) => service.id),
      [kSearchServiceId],
      reason: '只有新增项需要问',
    );

    appState.recordConsentPageDecision(false);

    // 新增项记成「问过」，但没同意
    expect(
      appState.setting.askedServices,
      containsAll(allThirdPartyServiceIds()),
    );
    expect(appState.isServiceAllowed(kSearchServiceId), isFalse);
    // 旧的项一条都没被撤销
    expect(appState.setting.consentedServices, oldAsked);
    expect(appState.isServiceAllowed(kUpdateServiceId), isTrue);
    expect(appState.isServiceAllowed(kCdnServiceId), isTrue);
    // 下次启动不再追问
    expect(appState.setting.pendingThirdPartyServices, isEmpty);
  });

  testWidgets('重新询问时点「同意」：整份清单都写进问过与同意', (tester) async {
    final appState = FakeAppState(
      askedServices: oldAsked,
      consentedServices: oldAsked,
    );

    appState.recordConsentPageDecision(true);

    expect(appState.setting.askedServices, allThirdPartyServiceIds());
    expect(appState.setting.consentedServices, allThirdPartyServiceIds());
    expect(appState.isServiceAllowed(kSearchServiceId), isTrue);
    expect(appState.setting.pendingThirdPartyServices, isEmpty);
  });

  testWidgets('设置里改主意：同意则整份同意，不同意则撤销全部', (tester) async {
    final appState = FakeAppState();

    appState.setThirdPartyConsentFromSettings(true);
    expect(appState.isServiceAllowed(kSearchServiceId), isTrue);
    expect(appState.isServiceAllowed(kCdnServiceId), isTrue);

    appState.setThirdPartyConsentFromSettings(false);
    expect(appState.setting.consentedServices, isEmpty);
    expect(appState.isServiceAllowed(kSearchServiceId), isFalse);
    expect(appState.isServiceAllowed(kCdnServiceId), isFalse);
    // 撤销也算问过：不会再弹同意页
    expect(appState.setting.pendingThirdPartyServices, isEmpty);
  });

  testWidgets('重置 App 配置保留这两组同意项', (tester) async {
    final appState = FakeAppState(
      askedServices: oldAsked,
      consentedServices: [kUpdateServiceId],
    );

    appState.resetAppSettings();

    expect(appState.setting.askedServices, oldAsked);
    expect(appState.setting.consentedServices, [kUpdateServiceId]);
  });
}
