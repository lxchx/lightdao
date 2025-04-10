import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/trend_data.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/ui/widget/reply_item.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/time_parse.dart';
import 'package:lightdao/utils/xdao_api.dart';
import 'package:provider/provider.dart';

class TrendPage extends StatefulWidget {
  final LRUCache<int, Future<RefHtml>>? refCache; 
  const TrendPage({super.key, this.refCache});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  ReplyJson? _reply;
  String? _error;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final appState = Provider.of<MyAppState>(context, listen: false);

    try {
      // 检查 latestTrend 是否存在
      final latestTrend = appState.setting.latestTrend;
      final now = DateTime.now().toUtc();

      if (latestTrend != null) {
        final fetchTime = latestTrend.fetchTime;
        final trendReply = latestTrend.reply;
        final trendTime = replyTimeToDateTime(trendReply.now);

        // 判断是否满足直接使用条件
        if (isSameDay(now, trendTime) ||
            (isSameDay(now.subtract(Duration(days: 1)), trendTime) &&
                now.difference(fetchTime) <= Duration(minutes: 30))) {
          setState(() {
            _reply = trendReply;
            _isLoading = false;
          });
          return;
        }
      }

      // 否则拉取最新数据
      final fetchedReply = await getLatestTrend(appState.getCurrentCookie());
      appState.setState((state) {
        state.setting.latestTrend = TrendData(fetchTime: now, reply: fetchedReply);
      });

      setState(() {
        _reply = fetchedReply;
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
        title: const Text('趋势'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('说明'),
                  content: const Text(
                    '数据取自No.50248044',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        appState.navigateThreadPage2(
                            context, 50248044, false);
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
                ? Column(
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
                  )
                : SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: breakpoint.gutters),
                    child: ReplyItem(
                      threadJson: _reply!,
                      refCache: widget.refCache,
                      poUserHash: "WaKod1l",
                      contentNeedCollapsed: false,
                    ),
                  ),
      ),
    );
  }
}
