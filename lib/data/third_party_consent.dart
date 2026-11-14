/// 第三方服务清单：客户端会连接、且不属于X岛官方的服务。
///
/// 每一项有一个稳定的字符串 id，写进设置的 [LightDaoSetting.consentedServices]。
/// id 一旦发版就不要改（改了等于让所有用户重新同意一次）；新增服务时往清单里
/// 追加一项即可，启动时会因为「清单里有用户没同意过的 id」而重新询问一次。
///
/// 清单顺序就是同意页里的顺序，也是提示「新增了哪几项」时的顺序。
class ThirdPartyService {
  const ThirdPartyService({
    required this.id,
    required this.name,
    required this.summary,
  });

  /// 稳定的服务 id，写进设置里。
  final String id;

  /// 给用户看的名字，用在「本说明新增了……」的提示里。
  final String name;

  /// 一句话说清它是什么，同样用在提示里。
  final String summary;
}

/// 更新检查（安装包在 GitHub release 上）。
const String kUpdateServiceId = 'update';

/// 第三方镜像线路、自定义线路与「自动」测速：它们都会让看串/发串的请求
/// 经过X岛官方以外的服务器。
const String kCdnServiceId = 'cdn';

/// 串搜索（Google 自定义搜索，www.googleapis.com）。
const String kSearchServiceId = 'google_cse';

/// 当前这一版说明里的全部第三方服务。
const List<ThirdPartyService> kThirdPartyServices = [
  ThirdPartyService(
    id: kUpdateServiceId,
    name: 'GitHub 更新检查',
    summary: '检查是否有新版本、下载安装包（api.github.com、github.com）',
  ),
  ThirdPartyService(
    id: kCdnServiceId,
    name: '第三方镜像线路',
    summary:
        '看串、发串的请求可能经过 api.nmb.best、api.nmb.fastmirror.org，'
        '或你自己填写的线路；「自动」测速会依次连接各条线路',
  ),
  ThirdPartyService(
    id: kSearchServiceId,
    name: '串搜索（Google 自定义搜索）',
    summary: '搜索关键词会发给 www.googleapis.com，由 Google 返回搜索结果',
  ),
];

/// 当前清单里的全部服务 id，用户在同意页点「同意」时整份写入设置。
List<String> allThirdPartyServiceIds() => [
  for (final service in kThirdPartyServices) service.id,
];

/// 当前清单里、还没问过用户的服务项（按清单顺序）。
///
/// 「问过」和「同意」是两件事，分别记在
/// [LightDaoSetting.askedServices] 与 [LightDaoSetting.consentedServices]：
/// 用户可以在被问过之后选择不同意某一项，那就不能再拿「没同意过」当
/// 「没问过」反复追问他。
List<ThirdPartyService> unaskedThirdPartyServices(List<String> askedServices) {
  final asked = askedServices.toSet();
  return [
    for (final service in kThirdPartyServices)
      if (!asked.contains(service.id)) service,
  ];
}

/// 某一项服务能不能用：用户同意过这一项。
///
/// 清单新增服务后，新增项不在同意过的集合里，所以被拦下；
/// 已经同意过的旧项不受影响。
bool isServiceConsented({
  required List<String> consentedServices,
  required String serviceId,
}) => consentedServices.contains(serviceId);

/// 启动时该不该问一次：当前清单里有还没问过用户的项。
///
/// 这里只看「问过没有」，不看「同意没有」：首次启动时什么都没问过，
/// 会问一次；用户拒绝之后这些项都算问过，不会再问；清单以后新增服务时，
/// 新增的 id 没问过，于是再问一次——只把新增项标出来。
bool shouldAskConsent(List<String> askedServices) =>
    unaskedThirdPartyServices(askedServices).isNotEmpty;

/// 需要先同意第三方服务才能做的事，被拒绝时抛出。
///
/// 抛出来而不是静默返回空结果：调用方忘了在界面上提示时，
/// 用户至少能看到一条明确的失败原因，而不是「没有结果」。
class ThirdPartyConsentRequiredException implements Exception {
  const ThirdPartyConsentRequiredException(this.service);

  /// 需要同意的服务名，例如「串搜索」。
  final String service;

  @override
  String toString() => '需要使用第三方服务「$service」，请先在「设置 - 网络 - 第三方服务」里同意第三方服务';
}
