import 'dart:async';

import 'package:breakpoint/breakpoint.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/utils/page_manager.dart';
import 'package:provider/provider.dart';
import 'package:tsukuyomi_list/tsukuyomi_list.dart';

class SearchPage extends StatefulWidget {
  final String query;

  const SearchPage({super.key, required this.query});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late TextEditingController _controller;
  late CSEPageManager _pageManager;
  final _scrollController = TsukuyomiListScrollController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<MyAppState>(context, listen: false);
    _controller = TextEditingController(text: widget.query);
    _pageManager = CSEPageManager(query: widget.query, timeout: Duration(seconds: appState.setting.fetchTimeout));
    Future.microtask(() async {
      await _pageManager.initialize();
      if (!mounted) return;
      // 预加载下一页
      _pageManager.tryLoadNextPage();
    });
    _scrollController.addListener(() {
      if (!mounted) return;
      // 距底部不到一个屏幕高度时加载下一页
      final position = _scrollController.position;
      final maxScrollExtent = position.maxScrollExtent;
      final currentPixels = position.pixels;
      final viewportDimension = position.viewportDimension;
      if (maxScrollExtent - currentPixels <= viewportDimension) {
        _pageManager.tryLoadNextPage();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  void _onSubmitted(String value) async {
    final appState = Provider.of<MyAppState>(context, listen: false);
    setState(() {
      // 重建分页管理器
      _pageManager = CSEPageManager(query: value, timeout: Duration(seconds: appState.setting.fetchTimeout));
    });
    await _pageManager.initialize();
    if (!mounted) return;
    _pageManager.tryLoadNextPage();
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
        child: ValueListenableBuilder(
          valueListenable: _pageManager.nextPageStateNotifier,
          builder: (context, _, __) {
            final itemCount = _pageManager.totalItemsCount;
            if (itemCount == 0 && _pageManager.nextPageStateNotifier.value is! PageLoading) {
              return const Center(
                child: Text('没有结果噢(´・ω・`)'),
              );
            }
            return TsukuyomiList.builder(
              controller: _scrollController,
              cacheExtent: MediaQuery.of(context).size.height * 1.5,
              itemCount: itemCount + 1,
              itemBuilder: (context, index) {
            if (index == itemCount) {
              return ValueListenableBuilder<PageState>(
                valueListenable: _pageManager.nextPageStateNotifier,
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
                        title: Text(err is TimeoutException ? '加载超时' : '加载失败: $err'),
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
            final (item, _, _) = _pageManager.getItemByIndex(index)!;
            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                      horizontal: breakpoint.gutters),
              trailing: item.imageUrl != null
                  ? CachedNetworkImage(
                      cacheManager: MyImageCacheManager(),
                      imageUrl: item.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover)
                  : null,
              title: Text(item.title),
              subtitle: HtmlWidget(item.htmlSnippet),
              onTap: () {
                final link = item.link;
                final threadIdReg = RegExp(r'/t/(\d+)');
                final pageReg = RegExp(r'[?&]page=(\d+)');
                /*final replyIdReg = RegExp(r'[?&]r=(\d+)');*/
                final threadIdMatch = threadIdReg.firstMatch(link);
                final pageMatch = pageReg.firstMatch(link);
                /*final replyIdMatch = replyIdReg.firstMatch(link);*/

                if (threadIdMatch == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('无法识别串号')),
                  );
                  return;
                }
                final threadId = int.parse(threadIdMatch.group(1)!);
                final startPage =
                    pageMatch != null ? int.parse(pageMatch.group(1)!) : null;

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
        ),
      ),
    );
  }
}
