import 'package:flutter/material.dart';
import 'package:lightdao/data/third_party_consent.dart';
import 'package:url_launcher/url_launcher.dart';

/// 第三方服务说明 / 同意页。
///
/// [firstRun] 为 true 时是首次启动模式：不可跳过——没有返回按钮，
/// 系统返回键也退不出去（PopScope canPop: false），必须选「同意」或
/// 「不同意」。选项由 [onDecided] 交给调用方写入设置。
/// 从设置页再次打开时 [firstRun] 为 false：允许返回，用户可以改主意。
class ThirdPartyConsentPage extends StatelessWidget {
  const ThirdPartyConsentPage({
    super.key,
    required this.onDecided,
    this.firstRun = true,
    this.newServices = const [],
  });

  /// 用户做出选择后回调：true = 同意，false = 不同意。
  final ValueChanged<bool> onDecided;

  /// 是否首次启动模式（不可跳过）。
  final bool firstRun;

  /// 清单里新增、用户还没同意过的服务项。
  ///
  /// 启动时如果发现之前同意过、但清单里多了新项，就带着新项再走一遍这一页，
  /// 页首会标出新增的是哪几项，让用户知道这次要确认什么。
  final List<ThirdPartyService> newServices;

  /// X岛官网，也是本客户端全部内容的来源。
  static const String xDaoHomeUrl = 'https://www.nmbxd.com';

  /// 「本客户端为第三方客户端」的醒目标题，测试与 README 都以此为准。
  static const String unsupportedNotice = '本客户端为第三方客户端，不受X岛官方支持';

  void _decide(BuildContext context, bool allowed) {
    onDecided(allowed);
    // 首次启动模式没有上一页，做出选择后由调用方切到首页。
    if (!firstRun) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !firstRun,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('第三方服务说明'),
          automaticallyImplyLeading: !firstRun,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    Card.filled(
                      color: colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          unsupportedNotice,
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (newServices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card.filled(
                        color: colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '本说明新增了以下第三方服务，需要你重新确认：',
                                style: textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final service in newServices)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '· ${service.name}：${service.summary}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                '点「不同意」只影响上面这几项：它们会被拦下，'
                                '你之前同意过的其他服务照常可用，之后也不会再追问。',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '氢岛（lightdao）是X岛的第三方客户端，由爱好者开发维护，'
                      '不是X岛官方出品，也不受X岛官方支持。',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '为了提供论坛浏览以外的功能（检查更新、串搜索、可选的加速线路），'
                      '本客户端会与X岛官方以外的服务器通信。首次使用前请先阅读下面的说明，'
                      '同意后才可以继续使用。',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '下面没有列到的都是X岛官方服务器，与本说明无关：'
                      'www.nmbxd.com、www.nmbxd1.com、图片 image.nmb.best、'
                      '公告 nmb.ovear.info。',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('会连接哪些第三方服务器'),
                    const _Item(
                      title: 'GitHub（api.github.com、github.com）',
                      body:
                          '用途：检查是否有新版本、下载新版本的安装包（app-release.apk）。'
                          '发出：网络 IP、客户端 User-Agent、版本接口与安装包的请求地址；'
                          '不会发送你的饼干、账号或浏览内容。',
                    ),
                    const _Item(
                      title: 'Google 自定义搜索（www.googleapis.com，由 Google 运营）',
                      body:
                          '用途：只在你使用「串搜索」时才会请求，用来按关键词搜索X岛上的串；'
                          '搜索由 Google 的自定义搜索接口完成，关键词与结果都经过 Google。'
                          '不使用搜索就不会连接它。'
                          '发出：你输入的搜索关键词、本客户端内置的搜索引擎编号与接口密钥、'
                          '网络 IP、User-Agent；不会发送你的饼干、账号或浏览历史。'
                          '搜索结果里的缩略图由客户端直接从图片所在的原站点加载。',
                    ),
                    const _Item(
                      title: 'api.nmb.best（第三方镜像线路）',
                      body:
                          '用途：在设置里选中它、或让「自动」测速选中它时，'
                          '看串、发串、拉取列表等请求会经过这台服务器。'
                          '发出：全部请求内容与请求头，包括你的饼干、IP、User-Agent。',
                    ),
                    const _Item(
                      title: 'api.nmb.fastmirror.org（第三方镜像线路）',
                      body:
                          '用途与上面相同：选中它之后，看串、发串等请求会经过这台服务器，'
                          '同样会经手你的饼干、IP、User-Agent 与全部请求内容。',
                    ),
                    const _Item(
                      title: '自定义线路（设置里「自定义」填写的域名）',
                      body:
                          '用途：如果你在设置里自己填了一条线路，看串、发串等请求会全部经过它；'
                          '这台服务器由你指定，本客户端无法得知它如何处理数据。',
                    ),
                    const _Item(
                      title: '「自动」测速',
                      body:
                          '用途：设置保持「自动」时，客户端会依次连上面每条线路测一次速度，'
                          '再挑最快的那条。测速请求本身也会发到第三方服务器。',
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('第三方会收到什么数据'),
                    const _Item(
                      title: '请求内容',
                      body:
                          '包括你正在看的串、板块与时间线，发出的回复和串，以及附带的表情、图片地址等；'
                          '经过第三方线路时这些内容对那台服务器是可见的。',
                    ),
                    const _Item(
                      title: '饼干与网络信息',
                      body:
                          '经过第三方线路时，登录用的饼干、网络 IP、User-Agent '
                          '都会被那台服务器看到，它可以用这些信息关联你的浏览行为。',
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('数据如何留存'),
                    Text(
                      '上述请求由各第三方服务器按它自己的策略处理与保存，本客户端'
                      '无法查看、修改或删除它们的日志，也不知道它们保存多久。'
                      'X岛无法保证这些第三方服务器上的数据安全，本客户端也不对'
                      '第三方服务器的行为负责。',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('内容来源'),
                    Text(
                      '本客户端显示的所有内容均来源于X岛，官网地址：',
                      style: textTheme.bodyMedium,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => launchUrl(Uri.parse(xDaoHomeUrl)),
                        child: const Text(xDaoHomeUrl),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _SectionTitle('不同意的后果'),
                    Text(
                      // 重新询问时点「不同意」只影响新增项，别让这里的措辞
                      // 读成「点下去这些旧功能也没了」。
                      newServices.isEmpty
                          ? '不同意也可以继续使用，且不影响主要功能：'
                          : '这次点「不同意」只影响上面新增的这几项，其余照旧：',
                      style: textTheme.bodyMedium,
                    ),
                    if (newServices.isEmpty) ...[
                      const _Item(
                        body:
                            '看时间线、看串、发串、看图、收藏等全部照常可用，请求只走X岛官方线路'
                            '（www.nmbxd.com、www.nmbxd1.com，图片走 image.nmb.best，'
                            '公告走 nmb.ovear.info）。',
                      ),
                      const _Item(
                        body:
                            '不能使用第三方镜像线路与自定义线路，也不会做自动测速选线；'
                            '你在设置里保存的线路不会被删除，同意后照原样生效。',
                      ),
                      const _Item(
                        body:
                            '不能检查更新，也不能下载更新包（需要访问 GitHub）。'
                            '想更新时可以在这里或设置里重新同意第三方服务。',
                      ),
                      const _Item(
                        body:
                            '不能使用串搜索：它要把搜索关键词发给 Google（www.googleapis.com）。'
                            '打开搜索页会说明原因，并给出去同意的入口。',
                      ),
                    ] else
                      // 重新询问时列「不能检查更新」这类话会读成「旧的也没了」，
                      // 这里只讲新增项与旧项各自的状态。
                      Text(
                        '上面新增的这几项在同意之前不会使用：相关功能会说明原因并给出去同意的入口；'
                        '你已经同意过的其他服务照常可用，之后也不会再为这几项追问。',
                        style: textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '点击「同意」表示你已阅读并接受上面的第三方服务说明；'
                      '之后也可以随时在设置 - 网络 - 第三方服务里修改。',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _decide(context, false),
                        child: const Text('不同意'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _decide(context, true),
                        child: const Text('同意'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(body, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
