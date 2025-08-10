import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/trend_data.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/data/daily_trend.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/ui/widget/icon_text.dart';
import 'package:lightdao/ui/widget/reply_item.dart';
import 'package:lightdao/ui/widget/scaffold_accessory_builder.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/throttle.dart';
import 'package:lightdao/utils/time_parse.dart';
import 'package:lightdao/utils/xdao_api.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TrendPage extends StatefulWidget {
  final LRUCache<int, Future<RefHtml>>? refCache;
  const TrendPage({super.key, this.refCache});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends ScaffoldAccessoryBuilder<TrendPage> {
  DailyTrend? _dailyTrend;
  ReplyJson? _threadReply;
  String? _error;
  bool _isLoading = false;
  final _fetchRefThrottle = IntervalRunner<RefHtml>(
    interval: const Duration(milliseconds: 350),
  );
  final _refCache = LRUCache<int, RefHtml>(50);
  final _threadRefCache = LRUCache<int, Future<RefHtml>>(100);
  final _refFutureMap = <int, Future<RefHtml>>{};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTrend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final appState = Provider.of<MyAppState>(context, listen: false);

    try {
      final latestTrend = appState.setting.latestTrend;
      final now = DateTime.now().toUtc();

      if (latestTrend != null) {
        final fetchTime = latestTrend.fetchTime;
        final trendReply = latestTrend.reply;
        final trendTime = replyTimeToDateTime(trendReply.now);

        if (isSameDay(now, trendTime) ||
            (isSameDay(now.subtract(const Duration(days: 1)), trendTime) &&
                now.difference(fetchTime) <= const Duration(minutes: 30))) {
          DailyTrend? parsedTrend;
          try {
            parsedTrend = DailyTrend.fromContent(trendReply.content);
          } catch (e) {
            // silent fail
          }
          setState(() {
            _threadReply = trendReply;
            if (parsedTrend != null && parsedTrend.trends.isNotEmpty) {
              _dailyTrend = parsedTrend;
            }
            _isLoading = false;
          });
          return;
        }
      }

      final fetchedReply = await getLatestTrend(appState.getCurrentCookie());
      appState.setState((state) {
        state.setting.latestTrend = TrendData(
          fetchTime: now,
          reply: fetchedReply,
        );
      });

      DailyTrend? parsedTrend;
      try {
        parsedTrend = DailyTrend.fromContent(fetchedReply.content);
      } catch (e) {
        // silent fail
      }
      setState(() {
        _threadReply = fetchedReply;
        if (parsedTrend != null && parsedTrend.trends.isNotEmpty) {
          _dailyTrend = parsedTrend;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('趋势'),
            if (_dailyTrend != null)
              Text(
                DateFormat('yyyy-MM-dd').format(_dailyTrend!.date),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('说明'),
                  content: const Text('数据取自No.50248044'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        appState.navigateThreadPage2(context, 50248044, false);
                      },
                      child: const Text('查看原串'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('好的'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator() // 加载中
            : _error != null
            ? Padding(
                padding: EdgeInsets.all(breakpoint.gutters),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '获取趋势失败：$_error',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadTrend,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            : (_dailyTrend != null && _dailyTrend!.trends.isNotEmpty)
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final forumRowCount = appState.setting.isMultiColumn
                      ? (constraints.maxWidth / appState.setting.columnWidth)
                                .toInt() +
                            1
                      : 1;
                  return MasonryGridView.count(
                    padding: EdgeInsets.all(breakpoint.gutters),
                    controller: _scrollController,
                    cacheExtent: 10000,
                    crossAxisCount: forumRowCount,
                    mainAxisSpacing: breakpoint.gutters,
                    crossAxisSpacing: breakpoint.gutters,
                    itemCount: _dailyTrend!.trends.length,
                    itemBuilder: (context, index) {
                      final trend = _dailyTrend!.trends[index];
                      final cacheRef = _refCache.get(trend.threadId);
                      return Card(
                        shadowColor: Colors.transparent,
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () => appState.navigateThreadPage2(
                            context,
                            trend.threadId,
                            false,
                            thread: cacheRef == null
                                ? null
                                : ThreadJson.fromRefHtml(cacheRef),
                            fullThread: false,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(breakpoint.gutters),
                            child: cacheRef != null
                                ? getRefWidget(cacheRef, trend)
                                : FutureBuilder<RefHtml>(
                                    future: (() {
                                      var future =
                                          _refFutureMap[trend.threadId];
                                      if (future == null) {
                                        future = fetchRefFromHtml(
                                          trend.threadId,
                                          appState.getCurrentCookie(),
                                          throttle: _fetchRefThrottle,
                                        );
                                        _refFutureMap[trend.threadId] = future;
                                      }
                                      return future;
                                    }()),
                                    builder: (context, snapshot) {
                                      if (snapshot.error != null) {
                                        return ListTile(
                                          contentPadding: EdgeInsets.all(0),
                                          dense: true,
                                          title: Text(
                                            '串信息获取失败：${snapshot.error}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                ),
                                          ),
                                          subtitle: Text(
                                            '\n残留信息：${trend.content}',
                                          ),
                                          trailing: TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _refFutureMap[trend.threadId] =
                                                    fetchRefFromHtml(
                                                      trend.threadId,
                                                      appState
                                                          .getCurrentCookie(),
                                                      throttle:
                                                          _fetchRefThrottle,
                                                    );
                                              });
                                            },
                                            child: Text('重试'),
                                          ),
                                        );
                                      } else if (snapshot.connectionState ==
                                          ConnectionState.done) {
                                        _refCache.put(
                                          trend.threadId,
                                          snapshot.data!,
                                        );
                                        return getRefWidget(
                                          snapshot.data!,
                                          trend,
                                        );
                                      } else if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return ListTile(
                                          contentPadding: EdgeInsets.all(0),
                                          dense: true,
                                          leading:
                                              const CircularProgressIndicator(),
                                          subtitle: Text(trend.content),
                                        );
                                      }
                                      return Text('???');
                                    },
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
                child: ReplyItem(
                  threadJson: _threadReply!,
                  refCache: widget.refCache,
                  poUserHash: "WaKod1l",
                  contentNeedCollapsed: false,
                  throttle: _fetchRefThrottle,
                ),
              ),
      ),
    );
  }

  Widget getRefWidget(RefHtml ref, Trend trend) {
    final thread = ThreadJson.fromRefHtml(ref);
    _refCache.put(trend.threadId, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReplyItem(
          threadJson: thread,
          contentNeedCollapsed: false,
          inCardView: true,
          refCache: _threadRefCache,
          contentHeroTag: 'ThreadCard ${ref.id}',
          imageHeroTag: 'Image ${ref.img}${ref.ext}',
          topRightWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Builder(
                builder: (context) {
                  Color? color;
                  if (trend.rank == 1) {
                    color = Colors.amber.shade700;
                  } else if (trend.rank == 2) {
                    color = Colors.grey.shade700;
                  } else if (trend.rank == 3) {
                    color = Colors.brown.shade700;
                  } else {
                    color = Theme.of(context).colorScheme.primary;
                  }
                  return IconText(
                    icon: Icon(Icons.numbers, color: color),
                    text: Text(
                      trend.rank.toString(),
                      style: trend.rank <= 3
                          ? TextStyle(color: color, fontWeight: FontWeight.bold)
                          : null,
                    ),
                  );
                },
              ),
              IconText(
                icon: Icon(
                  Icons.whatshot_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                text: Text(trend.heat.toString()),
              ),
            ],
          ),
        ),
        Wrap(
          alignment: WrapAlignment.start,
          children: [
            Chip(
              label: Text(trend.board),
              labelPadding: EdgeInsets.zero,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              labelStyle: Theme.of(context).textTheme.labelSmall,
            ),
            if (trend.isNew)
              Chip(
                label: SizedBox(
                  height: 16,
                  width: 18,
                  child: Center(
                    child: Icon(size: 18, Icons.fiber_new_outlined),
                  ),
                ),
                labelPadding: EdgeInsets.zero,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ],
    );
  }

  @override
  List<Widget>? buildDrawerContent(BuildContext context) {
    return null;
  }

  @override
  Widget? buildFloatingActionButton(BuildContext anchorContext) {
    return null;
  }

  @override
  bool onReLocated(BuildContext anchorContext) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return true;
    }
    return false;
  }
}
