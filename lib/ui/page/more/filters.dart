import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:provider/provider.dart';

class FiltersManagementPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);

    // 获取所有的过滤器
    List<ThreadFilter> filters = appState.setting.threadFilters;

    return Scaffold(
      appBar: AppBar(title: const Text('屏蔽管理')),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];

          // 根据不同的过滤器类型显示相应的信息
          String filterInfo;
          String filterTitle;
          if (filter is ForumThreadFilter) {
            filterInfo =
                appState.forumMap[filter.fid]?.getShowName() ??
                '(id: ${filter.fid})';
            filterTitle = "时间线版面";
          } else if (filter is IdThreadFilter) {
            filterInfo = "No.${filter.id}";
            filterTitle = "单串/回复屏蔽";
          } else if (filter is UserHashFilter) {
            filterInfo = filter.userHash;
            filterTitle = "饼干屏蔽";
          } else {
            filterInfo = "未知类型";
            filterTitle = "未知类型";
          }

          return Padding(
            padding: EdgeInsets.symmetric(vertical: breakpoint.gutters / 4),
            child: Card(
              child: ListTile(
                title: Text(filterTitle),
                subtitle: Text(filterInfo),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    appState.removeFilter(filter);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
