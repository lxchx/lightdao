import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/update_policy.dart';

void main() {
  group('resolveUpdatePolicy 由 checkUpdateOnLaunch 推导', () {
    test('老开关为 true 时推导为自动检查', () {
      expect(
        resolveUpdatePolicy(
          storedPolicy: null,
          legacyCheckUpdateOnLaunch: true,
        ),
        UpdatePolicy.check,
      );
    });

    test('老开关为 false 时推导为永不检查', () {
      expect(
        resolveUpdatePolicy(
          storedPolicy: null,
          legacyCheckUpdateOnLaunch: false,
        ),
        UpdatePolicy.never,
      );
    });

    test('推导出的档位在非 Android 平台上也不受安装能力影响', () {
      // 自动检查 / 永不检查都不需要安装 APK，平台不影响结果
      expect(
        resolveUpdatePolicy(
          storedPolicy: null,
          legacyCheckUpdateOnLaunch: true,
          isAndroid: false,
        ),
        UpdatePolicy.check,
      );
      expect(
        resolveUpdatePolicy(
          storedPolicy: null,
          legacyCheckUpdateOnLaunch: false,
          isAndroid: false,
        ),
        UpdatePolicy.never,
      );
    });
  });

  group('resolveUpdatePolicy 读取已存储的值', () {
    test('0/1/2 与三档一一对应，且不再受老开关影响', () {
      expect(
        resolveUpdatePolicy(storedPolicy: 0, legacyCheckUpdateOnLaunch: false),
        UpdatePolicy.auto,
      );
      expect(
        resolveUpdatePolicy(storedPolicy: 1, legacyCheckUpdateOnLaunch: false),
        UpdatePolicy.check,
      );
      expect(
        resolveUpdatePolicy(storedPolicy: 2, legacyCheckUpdateOnLaunch: true),
        UpdatePolicy.never,
      );
    });

    test('非法值退回按老开关推导', () {
      expect(
        resolveUpdatePolicy(storedPolicy: 9, legacyCheckUpdateOnLaunch: true),
        UpdatePolicy.check,
      );
      expect(
        resolveUpdatePolicy(storedPolicy: 9, legacyCheckUpdateOnLaunch: false),
        UpdatePolicy.never,
      );
    });
  });

  group('resolveUpdatePolicy 平台降级', () {
    test('非 Android 平台上自动更新退化为自动检查', () {
      expect(
        resolveUpdatePolicy(
          storedPolicy: UpdatePolicy.auto.value,
          legacyCheckUpdateOnLaunch: true,
          isAndroid: false,
        ),
        UpdatePolicy.check,
      );
    });

    test('Android 平台上自动更新保持自动更新', () {
      expect(
        resolveUpdatePolicy(
          storedPolicy: UpdatePolicy.auto.value,
          legacyCheckUpdateOnLaunch: true,
          isAndroid: true,
        ),
        UpdatePolicy.auto,
      );
    });
  });

  group('resolveConsentedUpdatePolicy 未同意第三方服务', () {
    test('拒绝时无论存了哪一档都返回永不检查', () {
      for (final stored in [null, 0, 1, 2, 9]) {
        expect(
          resolveConsentedUpdatePolicy(
            thirdPartyConsented: false,
            storedPolicy: stored,
            legacyCheckUpdateOnLaunch: true,
          ),
          UpdatePolicy.never,
          reason: 'storedPolicy=$stored',
        );
      }
    });

    test('拒绝时不走到老开关的推导（老开关为 true 也不检查）', () {
      expect(
        resolveConsentedUpdatePolicy(
          thirdPartyConsented: false,
          storedPolicy: null,
          legacyCheckUpdateOnLaunch: true,
        ),
        UpdatePolicy.never,
      );
    });
  });

  group('resolveConsentedUpdatePolicy 已同意第三方服务', () {
    test('与 resolveUpdatePolicy 的结果一致', () {
      for (final stored in [null, 0, 1, 2]) {
        for (final legacy in [true, false]) {
          for (final isAndroid in [true, false]) {
            expect(
              resolveConsentedUpdatePolicy(
                thirdPartyConsented: true,
                storedPolicy: stored,
                legacyCheckUpdateOnLaunch: legacy,
                isAndroid: isAndroid,
              ),
              resolveUpdatePolicy(
                storedPolicy: stored,
                legacyCheckUpdateOnLaunch: legacy,
                isAndroid: isAndroid,
              ),
              reason: 'stored=$stored legacy=$legacy android=$isAndroid',
            );
          }
        }
      }
    });

    test('已同意时照常按存储值解析', () {
      expect(
        resolveConsentedUpdatePolicy(
          thirdPartyConsented: true,
          storedPolicy: UpdatePolicy.check.value,
          legacyCheckUpdateOnLaunch: false,
        ),
        UpdatePolicy.check,
      );
    });
  });

  group('UpdatePolicy 常量', () {
    test('持久化值与档位一一对应', () {
      expect(UpdatePolicy.fromValue(0), UpdatePolicy.auto);
      expect(UpdatePolicy.fromValue(1), UpdatePolicy.check);
      expect(UpdatePolicy.fromValue(2), UpdatePolicy.never);
      expect(UpdatePolicy.fromValue(null), isNull);
      expect(UpdatePolicy.fromValue(3), isNull);
    });

    test('档位名与副文案存在', () {
      expect(UpdatePolicy.auto.label, '自动更新');
      expect(UpdatePolicy.check.label, '自动检查');
      expect(UpdatePolicy.never.label, '永不检查');
      for (final policy in UpdatePolicy.values) {
        expect(policy.description, isNotEmpty);
      }
    });
  });
}
