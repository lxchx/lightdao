import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/update_policy.dart';

/// 构造一个只关心第三方服务同意状态与更新策略的设置对象。
LightDaoSetting buildSetting({bool? thirdPartyConsent, int? updatePolicy}) {
  return LightDaoSetting.withAppDefaults(
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
    thirdPartyConsent: thirdPartyConsent,
  )..updatePolicy = updatePolicy;
}

void main() {
  group('thirdPartyConsent 的取值', () {
    test('全新安装 / 老用户升级上来时是 null（尚未询问）', () {
      expect(buildSetting().thirdPartyConsent, isNull);
    });

    test('同意与拒绝分别存为 true / false', () {
      expect(buildSetting(thirdPartyConsent: true).thirdPartyConsent, isTrue);
      expect(buildSetting(thirdPartyConsent: false).thirdPartyConsent, isFalse);
    });
  });

  group('effectiveUpdatePolicy 在未同意时不检查更新', () {
    test('尚未询问（null）时按永不检查处理', () {
      // 老用户升级上来字段是 null：在用户做出选择之前也不许连 GitHub。
      expect(buildSetting().effectiveUpdatePolicy, UpdatePolicy.never);
    });

    test('拒绝时即使开着自动检查也不检查', () {
      expect(
        buildSetting(
          thirdPartyConsent: false,
          updatePolicy: UpdatePolicy.check.value,
        ).effectiveUpdatePolicy,
        UpdatePolicy.never,
      );
    });
  });

  group('effectiveUpdatePolicy 在已同意时照常解析', () {
    test('按存储的更新策略档位生效', () {
      expect(
        buildSetting(
          thirdPartyConsent: true,
          updatePolicy: UpdatePolicy.check.value,
        ).effectiveUpdatePolicy,
        UpdatePolicy.check,
      );
      expect(
        buildSetting(
          thirdPartyConsent: true,
          updatePolicy: UpdatePolicy.never.value,
        ).effectiveUpdatePolicy,
        UpdatePolicy.never,
      );
    });

    test('未存过策略时按老开关推导（默认开启 → 自动检查）', () {
      expect(
        buildSetting(thirdPartyConsent: true).effectiveUpdatePolicy,
        UpdatePolicy.check,
      );
    });
  });
}
