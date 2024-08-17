import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/const_data.dart';
import 'package:lightdao/data/setting.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.appState,
    required this.packageInfo,
  });

  final MyAppState appState;
  final PackageInfo packageInfo;

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('关于'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
          children: [
            Card.filled(
              child: Padding(
                padding: EdgeInsets.all(breakpoint.gutters),
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 展示app图标
                      Image.asset(
                        appIcons[appState.setting.selectIcon].$2,
                        width: 160.0,
                        height: 160.0,
                      ),
                      SizedBox(height: breakpoint.gutters),
                      // 展示app设计理念
                      Text(
                        '美观、现代的X岛第三方客户端',
                        style: TextStyle(fontSize: 16.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ListTile(
              title: Text('版本'),
              subtitle:
                  Text('${packageInfo.version} (${packageInfo.buildNumber})'),
            ),
            ListTile(
              title: Text('作者'),
              subtitle: Text('9ionKfO'),
            ),
          ],
        ),
      ),
    );
  }
}
