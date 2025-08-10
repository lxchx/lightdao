import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/setting.dart';

class ThemeSelectorPage extends StatefulWidget {
  final int initIndex;

  const ThemeSelectorPage({super.key, this.initIndex = 0});

  @override
  State<ThemeSelectorPage> createState() => _ThemeSelectorPageState();
}

class _ThemeSelectorPageState extends State<ThemeSelectorPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('主题选择'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '浅色', icon: Icon(Icons.light_mode)),
            Tab(text: '暗色', icon: Icon(Icons.dark_mode)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ThemeListView(isDarkModeSeleted: false),
          ThemeListView(isDarkModeSeleted: true),
        ],
      ),
    );
  }
}

class ThemeListView extends StatelessWidget {
  final bool isDarkModeSeleted;
  ThemeListView({required this.isDarkModeSeleted});
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    var customColor = isDarkModeSeleted
        ? appState.setting.darkModeCustomThemeColor
        : appState.setting.lightModeCustomThemeColor;
    return ListView(
      children: [
        DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final brightness = MediaQuery.of(context).platformBrightness;
            final isSysDarkMode = brightness == Brightness.dark;
            final isUserDarkMode = appState.setting.userSettingIsDarkMode;
            final followSysDarkMode = appState.setting.followedSysDarkMode;
            final isAppDarkMode = followSysDarkMode
                ? isSysDarkMode
                : isUserDarkMode;
            final colorScheme = isAppDarkMode ? darkDynamic : lightDynamic;
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: appState.setting.dynamicThemeColor
                    ? colorScheme?.primary
                    : colorScheme?.secondaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.0),
                  onTap: () {
                    if (lightDynamic == null && darkDynamic == null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("本设备不支持动态取色！")));
                      return;
                    }
                    if (!appState.setting.dynamicThemeColor) {
                      appState.setState((state) async {
                        state.setting.dynamicThemeColor = true;
                      });
                    }
                  },
                  child: SizedBox(
                    height: 50,
                    child: Center(
                      child: Text(
                        '动态取色',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: appState.setting.dynamicThemeColor
                              ? colorScheme?.onPrimary
                              : colorScheme?.onSecondaryContainer,
                          fontWeight: appState.setting.dynamicThemeColor
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        ColorSelectListTile(
          isDarkModeSeleted: isDarkModeSeleted,
          name: 'Tips粉',
          color: Color.fromARGB(255, 241, 98, 100),
        ),
        ColorSelectListTile(
          isDarkModeSeleted: isDarkModeSeleted,
          name: '水鸭青',
          color: Color.fromARGB(255, 0, 150, 136),
        ),
        ColorSelectListTile(
          isDarkModeSeleted: isDarkModeSeleted,
          name: '天空蓝',
          color: Color.fromARGB(255, 100, 140, 204),
        ),
        ColorSelectListTile(
          isDarkModeSeleted: isDarkModeSeleted,
          name: '伊藤橙',
          color: Color.fromARGB(255, 255, 153, 0),
        ),
        ColorSelectListTile(
          isDarkModeSeleted: isDarkModeSeleted,
          name: '淡雅紫',
          color: Color.fromARGB(255, 102, 106, 178),
        ),
        InkWell(
          onLongPress: () async {
            await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('选择颜色'),
                  content: SingleChildScrollView(
                    child: StatefulBuilder(
                      builder: (context, setState) => ColorPicker(
                        color: customColor,
                        onColorChanged: (Color color) {
                          setState(() {
                            customColor = color;
                            appState.setState((_) {
                              if (isDarkModeSeleted) {
                                appState.setting.darkModeCustomThemeColor =
                                    color;
                                appState.setting.darkModeThemeColor = color;
                              } else {
                                appState.setting.lightModeCustomThemeColor =
                                    color;
                                appState.setting.lightModeThemeColor = color;
                              }
                            });
                          });
                        },
                        borderRadius: 22,
                        heading: Text('颜色'),
                        subheading: Text('色调'),
                      ),
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('确定'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
          child: ColorSelectListTile(
            isDarkModeSeleted: isDarkModeSeleted,
            name: '自定义(长按修改)',
            color: customColor,
          ),
        ),
      ],
    );
  }
}

class ColorSelectListTile extends StatelessWidget {
  const ColorSelectListTile({
    super.key,
    required this.isDarkModeSeleted,
    required this.color,
    required this.name,
  });

  final bool isDarkModeSeleted;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final selected =
        !appState.setting.dynamicThemeColor &&
        (isDarkModeSeleted && appState.setting.darkModeThemeColor == color ||
            !isDarkModeSeleted &&
                appState.setting.lightModeThemeColor == color);
    return ListTile(
      trailing: selected ? Icon(Icons.check) : null,
      leading: Icon(Icons.circle, color: color),
      title: Text(name),
      onTap: () {
        if (!isDarkModeSeleted) {
          if (appState.setting.lightModeThemeColor == color &&
              !appState.setting.dynamicThemeColor) {
            return;
          }
          appState.setState((state) {
            state.setting.lightModeThemeColor = color;
          });
        } else {
          if (appState.setting.darkModeThemeColor == color &&
              !appState.setting.dynamicThemeColor) {
            return;
          }
          appState.setState((state) {
            state.setting.darkModeThemeColor = color;
          });
        }
        if (appState.setting.dynamicThemeColor) {
          appState.setState((state) {
            state.setting.dynamicThemeColor = false;
          });
        }
      },
    );
  }
}
