//import 'package:dynamic_app_icon_flutter/dynamic_app_icon.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/const_data.dart';
import 'package:lightdao/data/setting.dart';
import 'package:provider/provider.dart';
import 'package:variable_app_icon/variable_app_icon.dart';

class IconSelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final selectedIconIndex = appState.setting.selectIcon;

    return Scaffold(
      appBar: AppBar(
        title: Text('选择应用图标'),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        double parentWidth = constraints.maxWidth; // 根据宽度计算crossAxisCount
        int crossAxisCount = parentWidth ~/ 150 + 1;
        return GridView.builder(
          padding: const EdgeInsets.all(16.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          itemCount: appIcons.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () async {
                appState.setState((_) {
                  appState.setting.selectIcon = index;
                });
                await VariableAppIcon.changeAppIcon(
                    androidIconId: appIcons[index].$1);
              },
              child: GridTile(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedIconIndex == index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3.0,
                    ),
                  ),
                  child: Image.asset(appIcons[index].$2),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
