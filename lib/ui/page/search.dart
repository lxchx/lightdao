import 'dart:async';

import 'package:breakpoint/breakpoint.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/third_party_consent.dart';
import 'package:lightdao/ui/page/more/setting.dart';
import 'package:lightdao/utils/page_manager.dart';
import 'package:provider/provider.dart';
import 'package:tsukuyomi_list/tsukuyomi_list.dart';

class SearchPage extends StatefulWidget {
  final String query;

  const SearchPage({super.key, required this.query});

  /// 未同意第三方服务时的提示标题。
  static const String consentRequiredTitle = '串搜索需要第三方服务';

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late TextEditingController _controller;
  final _scrollController = TsukuyomiListScrollController();

  /// 分页管理器。没同意第三方服务时保持为 null：
  /// 没有管理器就没有请求，搜索页打开也不会连 Google。
  CSEPageManager? _pageManager;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<MyAppState>(context, listen: false);
    _controller = TextEditingController(text: widget.query);
    _scrollController.addListener(_onScroll);
    if (_isSearchAllowed(appState)) {
      _startSearch(widget.query, rebuild: false);
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  /// 串搜索走 Google 自定义搜索，属第三方服务，要对应那一项被同意过才可用。
  bool _isSearchAllowed(MyAppState appState) =>
      appState.isServiceAllowed(kSearchServiceId);

  void _onScroll() {
    if (!mounted) return;
    final manager = _pageManager;
    if (manager == null) return;
    // 距底部不到一个屏幕高度时加载下一页
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <=
        position.viewportDimension) {
      manager.tryLoadNextPage();
    }
  }

  /// 新建分页管理器并拉第一页。
  ///
  /// 只有这一项服务被同意过时才会调用；[rebuild] 为 false 时用于 initState
  /// （那里不能 setState）。
  void _startSearch(String query, {bool rebuild = true}) {
    final appState = Provider.of<MyAppState>(context, listen: false);
    final manager = CSEPageManager(
      query: query,
      searchAllowed: true,
      timeout: Duration(seconds: appState.setting.fetchTimeout),
    );
    if (rebuild) {
      setState(() {
        _pageManager = manager;
      });
    } else {
      _pageManager = manager;
    }
    Future.microtask(() async {
      await manager.initialize();
      if (!mounted) return;
      // 预加载下一页
      manager.tryLoadNextPage();
    });
  }

  void _onSubmitted(String value) {
    final appState = Provider.of<MyAppState>(context, listen: false);
    if (!_isSearchAllowed(appState)) {
      // 没同意就不发请求，页面上的说明本身就是提示。
      return;
    }
    _startSearch(value);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return Scaffold(
      appBar: AppBar(
        title: IntrinsicHeight(
          child: Center(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索',
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _onSubmitted(_controller.text),
                ),
              ),
              style: TextStyle(fontSize: 18),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSubmitted,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isSearchAllowed(appState)
            ? _buildResults(context, breakpoint)
            : _buildConsentRequired(context, appState),
      ),
    );
  }

  /// 没同意时整页说明原因，并给出可以操作的去处：不静默失败。
  Widget _buildConsentRequired(BuildContext context, MyAppState appState) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        Card.filled(
          color: colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              SearchPage.consentRequiredTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '串搜索用 Google 自定义搜索（www.googleapis.com）按关键词搜索X岛上的串，'
          '要把你输入的搜索关键词发给 Google，属于第三方服务。'
          '你没有同意第三方服务，所以这次不会发出任何请求。',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  appState.createPageRoute(
                    builder: (context) => SettingsPage(),
                  ),
                ),
                child: Text('去设置'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('在「设置 - 网络 - 第三方服务」里同意后，回到这里就能搜索。', style: textTheme.bodySmall),
      ],
    );
  }

  Widget _buildResults(BuildContext context, Breakpoint breakpoint) {
    final manager = _pageManager;
    if (manager == null) {
      // 同意是在别处做出的（例如从这里去设置同意后返回）：页面已经允许搜索，
      // 但管理器还没建过，补上一次搜索，不要停在一张空白页上。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pageManager != null) return;
        _startSearch(widget.query);
      });
      return const Center(child: CircularProgressIndicator());
    }
    return ValueListenableBuilder(
      valueListenable: manager.nextPageStateNotifier,
      builder: (context, _, __) {
        final itemCount = manager.totalItemsCount;
        if (itemCount == 0 &&
            manager.nextPageStateNotifier.value is! PageLoading) {
          return const Center(child: Text('没有结果噢(´・ω・`)'));
        }
        return TsukuyomiList.builder(
          controller: _scrollController,
          cacheExtent: MediaQuery.of(context).size.height * 1.5,
          itemCount: itemCount + 1,
          itemBuilder: (context, index) {
            if (index == itemCount) {
              return ValueListenableBuilder<PageState>(
                valueListenable: manager.nextPageStateNotifier,
                builder: (context, state, _) {
                  return switch (state) {
                    PageLoading() => Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: breakpoint.gutters,
                        vertical: breakpoint.gutters / 2,
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    PageFullLoaded() => Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: breakpoint.gutters,
                        vertical: breakpoint.gutters / 2,
                      ),
                      child: const Center(child: Text('到底了(　ﾟ 3ﾟ)')),
                    ),
                    PageError(error: final err, retry: final retry) => ListTile(
                      textColor: Theme.of(context).colorScheme.error,
                      title: Text(
                        err is TimeoutException ? '加载超时' : '加载失败: $err',
                      ),
                      onTap: () => setState(() => retry()),
                      trailing: TextButton.icon(
                        onPressed: () => setState(() => retry()),
                        label: Text('重试'),
                        icon: Icon(Icons.refresh),
                      ),
                    ),
                    PageHasMore() => const SizedBox.shrink(),
                  };
                },
              );
            }
            final (item, _, _) = manager.getItemByIndex(index)!;
            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: breakpoint.gutters,
              ),
              trailing: item.imageUrl != null
                  ? CachedNetworkImage(
                      cacheManager: MyImageCacheManager(),
                      imageUrl: item.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : null,
              title: Text(item.title),
              subtitle: HtmlWidget(item.htmlSnippet),
              onTap: () {
                final appState = Provider.of<MyAppState>(
                  context,
                  listen: false,
                );
                final link = item.link;
                final threadIdReg = RegExp(r'/t/(\d+)');
                final pageReg = RegExp(r'[?&]page=(\d+)');
                /*final replyIdReg = RegExp(r'[?&]r=(\d+)');*/
                final threadIdMatch = threadIdReg.firstMatch(link);
                final pageMatch = pageReg.firstMatch(link);
                /*final replyIdMatch = replyIdReg.firstMatch(link);*/

                if (threadIdMatch == null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('无法识别串号')));
                  return;
                }
                final threadId = int.parse(threadIdMatch.group(1)!);
                final startPage = pageMatch != null
                    ? int.parse(pageMatch.group(1)!)
                    : null;

                appState.navigateThreadPage2(
                  context,
                  threadId,
                  false,
                  startPage: startPage,
                  // 搜索出来的 startReplyId 效果不是很好，暂时不用
                  // startReplyId: startReplyId,
                );
              },
            );
          },
        );
      },
    );
  }
}
