import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/third_party_consent.dart';
import 'package:lightdao/data/update_policy.dart';

/// 构造一个只关心第三方服务同意状态与更新策略的设置对象。
///
/// 两个集合默认都是「整份清单都问过、都同意」，这样这些用例只关注各自要验的那一层。
LightDaoSetting buildSetting({
  List<String>? askedServices,
  List<String>? consentedServices,
  int? updatePolicy,
}) {
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
    askedServices: askedServices ?? allThirdPartyServiceIds(),
    consentedServices: consentedServices ?? allThirdPartyServiceIds(),
  )..updatePolicy = updatePolicy;
}

void main() {
  group('effectiveUpdatePolicy 在没同意更新检查时不检查', () {
    test('全新安装（什么都没同意）时按永不检查处理', () {
      expect(
        buildSetting(
          askedServices: [],
          consentedServices: [],
        ).effectiveUpdatePolicy,
        UpdatePolicy.never,
      );
    });

    test('同意过整份说明但没同意更新检查这一项：也不检查', () {
      expect(
        buildSetting(
          consentedServices: [kCdnServiceId, kSearchServiceId],
          updatePolicy: UpdatePolicy.check.value,
        ).effectiveUpdatePolicy,
        UpdatePolicy.never,
      );
    });
  });

  group('effectiveUpdatePolicy 在同意更新检查后照常解析', () {
    test('按存储的更新策略档位生效', () {
      expect(
        buildSetting(
          updatePolicy: UpdatePolicy.check.value,
        ).effectiveUpdatePolicy,
        UpdatePolicy.check,
      );
      expect(
        buildSetting(
          updatePolicy: UpdatePolicy.never.value,
        ).effectiveUpdatePolicy,
        UpdatePolicy.never,
      );
    });

    test('未存过策略时按老开关推导（默认开启 → 自动检查）', () {
      expect(buildSetting().effectiveUpdatePolicy, UpdatePolicy.check);
    });
  });

  group('各项服务各自判定', () {
    test('同意过当前清单：三项都可用，没有待询问的项', () {
      final setting = buildSetting();
      for (final service in kThirdPartyServices) {
        expect(
          setting.hasConsentedService(service.id),
          isTrue,
          reason: service.id,
        );
        expect(setting.hasAskedService(service.id), isTrue, reason: service.id);
      }
      expect(setting.pendingThirdPartyServices, isEmpty);
    });

    test('同意过旧清单：新增项不可用，旧项照旧可用', () {
      final setting = buildSetting(
        askedServices: [kUpdateServiceId, kCdnServiceId],
        consentedServices: [kUpdateServiceId, kCdnServiceId],
      );
      expect(setting.hasConsentedService(kUpdateServiceId), isTrue);
      expect(setting.hasConsentedService(kCdnServiceId), isTrue);
      expect(setting.hasConsentedService(kSearchServiceId), isFalse);
      expect(setting.pendingThirdPartyServices.map((service) => service.id), [
        kSearchServiceId,
      ]);
    });

    test('一项都没同意：三项都不可用', () {
      final setting = buildSetting(askedServices: [], consentedServices: []);
      for (final service in kThirdPartyServices) {
        expect(
          setting.hasConsentedService(service.id),
          isFalse,
          reason: service.id,
        );
      }
    });
  });
}
