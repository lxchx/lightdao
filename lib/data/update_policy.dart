/// 更新策略：应用启动时如何检查 / 处理新版本。
///
/// 持久化在 `LightDaoSetting.updatePolicy`（`@HiveField(48)`）里，
/// 0 = 自动更新、1 = 自动检查、2 = 永不检查。
///
/// 老版本的用户数据没有这个字段（为 null），此时按老的
/// `checkUpdateOnLaunch` 开关推导，见 [resolveUpdatePolicy]。
enum UpdatePolicy {
  /// 启动时检查，有新版本时自动在后台下载，下载完成后提示安装。
  auto(value: 0, label: '自动更新', description: '启动时检查，有新版本自动在后台下载，完成后提示安装'),

  /// 启动时检查，有新版本时提示（与引入本设置之前的行为一致）。
  check(value: 1, label: '自动检查', description: '启动时检查，有新版本时提示'),

  /// 不自动检查，只在关于页手动检查。
  never(value: 2, label: '永不检查', description: '只在关于页手动检查');

  const UpdatePolicy({
    required this.value,
    required this.label,
    required this.description,
  });

  /// 持久化的整数值。
  final int value;

  /// 界面上显示的档位名。
  final String label;

  /// 界面上的副文案，说明这一档的具体行为。
  final String description;

  /// 按持久化的整数值查找档位；null 或非法值返回 null。
  static UpdatePolicy? fromValue(int? value) {
    for (final policy in UpdatePolicy.values) {
      if (policy.value == value) {
        return policy;
      }
    }
    return null;
  }
}

/// 解析实际生效的更新策略。
///
/// 这是纯函数（不碰 Hive、不读平台信息），方便直接单测：
/// - [storedPolicy] 合法时直接采用；
/// - 为 null（老用户升级上来的数据、或全新安装）或非法值时，按老的
///   [legacyCheckUpdateOnLaunch] 开关推导：true → [UpdatePolicy.check]，
///   false → [UpdatePolicy.never]；
/// - 非 Android 平台没有安装 APK 的能力，[UpdatePolicy.auto] 退化成
///   [UpdatePolicy.check]（照常提示，但不自动下载）。
UpdatePolicy resolveUpdatePolicy({
  required int? storedPolicy,
  required bool legacyCheckUpdateOnLaunch,
  bool isAndroid = true,
}) {
  final resolved =
      UpdatePolicy.fromValue(storedPolicy) ??
      (legacyCheckUpdateOnLaunch ? UpdatePolicy.check : UpdatePolicy.never);
  if (!isAndroid && resolved == UpdatePolicy.auto) {
    return UpdatePolicy.check;
  }
  return resolved;
}

/// 叠加「第三方服务同意状态」后的更新策略。
///
/// 检查更新（api.github.com）和下载安装包（GitHub release）都要访问
/// 第三方服务器，所以没同意时一律是 [UpdatePolicy.never]：启动不检查、
/// 不自动下载，关于页也不能手动检查。同意后才按 [resolveUpdatePolicy]
/// 正常解析。和它一样是纯函数，方便单测。
UpdatePolicy resolveConsentedUpdatePolicy({
  required bool thirdPartyConsented,
  required int? storedPolicy,
  required bool legacyCheckUpdateOnLaunch,
  bool isAndroid = true,
}) {
  if (!thirdPartyConsented) {
    return UpdatePolicy.never;
  }
  return resolveUpdatePolicy(
    storedPolicy: storedPolicy,
    legacyCheckUpdateOnLaunch: legacyCheckUpdateOnLaunch,
    isAndroid: isAndroid,
  );
}
