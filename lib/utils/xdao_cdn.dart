const String xdaoCdnAuto = 'auto';

/// 官方 Base 线路（X岛自己的服务器）：未同意第三方服务时固定走这条。
const String officialBaseCdn = 'https://www.nmbxd.com';

/// 官方 Ref 线路（X岛自己的服务器）：未同意第三方服务时固定走这条。
const String officialRefCdn = 'https://www.nmbxd1.com';

/// Base CDN list (for JSON API).
///
/// NOTE: Some entries may redirect (30x). Network layer must preserve cookie
/// during redirects for login-required endpoints (e.g. timeline id=2).
///
/// 列表里 `api.nmb.best`、`api.nmb.fastmirror.org` 是第三方线路，
/// 只有用户同意第三方服务后才可能被用到，见 [resolveEffectiveCdnSetting]。
const List<String> xdaoBaseCdns = [
  'https://api.nmb.best',
  'https://www.nmbxd.com',
  'https://www.nmbxd1.com',
  'https://api.nmb.fastmirror.org',
];

/// Ref CDN list (for HTML ref pages: /Home/Forum/ref?id=...).
const List<String> xdaoRefCdns = [
  'https://www.nmbxd.com',
  'https://www.nmbxd1.com',
];

/// 实际生效的 CDN 线路：由同意状态与保存的设置共同决定。
class EffectiveCdnSetting {
  const EffectiveCdnSetting({required this.baseCdn, required this.refCdn});

  final String baseCdn;
  final String refCdn;
}

/// 由「是否同意第三方服务」和用户保存的线路设置，得出实际要用的 base/ref。
///
/// 纯函数（不读 Hive、不发请求），方便单测：
/// - 未同意（拒绝或尚未询问）：固定走官方线路，既不会选中第三方镜像，
///   也不会因为保存值是 [xdaoCdnAuto] 而触发测速——测速本身要依次连各条
///   线路，其中就包含第三方服务器；
/// - 已同意：照用户保存的值走（含自动测速、自定义线路）。
///
/// 未同意时只是不采用保存值，不删它，同意后原设置照原样生效。
EffectiveCdnSetting resolveEffectiveCdnSetting({
  required bool thirdPartyConsented,
  required String storedBaseCdn,
  required String storedRefCdn,
}) {
  if (!thirdPartyConsented) {
    return const EffectiveCdnSetting(
      baseCdn: officialBaseCdn,
      refCdn: officialRefCdn,
    );
  }
  return EffectiveCdnSetting(baseCdn: storedBaseCdn, refCdn: storedRefCdn);
}
