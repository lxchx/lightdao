import 'package:breakpoint/breakpoint.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/const_data.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/ui/page/more/icon_select.dart';
import 'package:lightdao/ui/page/debug/tsukuyomi_test.dart';
import 'package:lightdao/ui/page/debug/reply_dialog.dart';
import 'package:provider/provider.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';

import '../../../data/setting.dart';

class ForumOrTimeline {
  final int id;
  final String name;
  final bool isTimeline;

  ForumOrTimeline({
    required this.id,
    required this.name,
    required this.isTimeline,
  });
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    const baseCdnPresets = [
      'auto',
      'https://nmbxd.com',
      'https://nmbxd1.com',
      'https://api.nmb.fastmirror.org',
    ];
    const refCdnPresets = ['auto', 'https://nmbxd.com', 'https://nmbxd1.com'];
    String cdnLabel(String value) => value == 'auto' ? '自动' : value;

    Future<void> pickCdn({required bool isBase}) async {
      final presets = isBase ? baseCdnPresets : refCdnPresets;
      final current = isBase
          ? appState.setting.baseCdn
          : appState.setting.refCdn;
      String? selected = current;
      String? customValue;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController(
            text: current != 'auto' && !presets.contains(current)
                ? current
                : '',
          );
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(isBase ? '设置默认请求CDN' : '设置引用请求CDN'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...List.generate(presets.length, (index) {
                        final value = presets[index];
                        return RadioListTile<String>(
                          value: value,
                          groupValue: selected,
                          title: Text(cdnLabel(value)),
                          onChanged: (v) {
                            setState(() {
                              selected = v;
                              customValue = null;
                              controller.text = '';
                            });
                          },
                        );
                      }),
                      RadioListTile<String>(
                        value: 'custom',
                        groupValue: selected,
                        title: Text('自定义'),
                        onChanged: (v) {
                          setState(() {
                            selected = v;
                          });
                        },
                      ),
                      if (selected == 'custom')
                        TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: '以 https:// 开头的完整域名',
                            errorText: () {
                              final text = controller.text.trim();
                              if (text.isEmpty) return null;
                              if (!text.toLowerCase().startsWith('https://')) {
                                return '必须以 https:// 开头';
                              }
                              return null;
                            }(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      if (isBase)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '此设置影响看串、发串等请求，错误配置可能导致无法读取数据。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      final useCustom = selected == 'custom';
                      if (useCustom) {
                        final trimmed = controller.text.trim();
                        if (!trimmed.toLowerCase().startsWith('https://')) {
                          return;
                        }
                        customValue = trimmed;
                      }
                      final result = useCustom
                          ? customValue ?? current
                          : selected ?? current;
                      if (isBase) {
                        appState.setState((state) {
                          state.setting.baseCdn = result;
                        });
                      } else {
                        appState.setState((state) {
                          state.setting.refCdn = result;
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: Text('确定'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    pageRoute({required Widget Function(BuildContext) builder}) {
      final setting = Provider.of<MyAppState>(context, listen: false).setting;
      if (setting.enableSwipeBack) {
        return SwipeablePageRoute(builder: builder);
      } else {
        return MaterialPageRoute(builder: builder);
      }
    }

    final forumOrTimelines = [
      ...appState.setting.cacheTimelines.map(
        (timeline) => ForumOrTimeline(
          id: timeline.id,
          name: timeline.getShowName(),
          isTimeline: true,
        ),
      ),
      ...appState.setting.cacheForumLists
          .expand((forumList) => forumList.forums)
          .map(
            (forum) => ForumOrTimeline(
              id: forum.id,
              name: forum.getShowName(),
              isTimeline: false,
            ),
          ),
    ];

    final currentForumOrTimelineIndex = forumOrTimelines.indexWhere(
      (forumOrTimeline) =>
          forumOrTimeline.id == appState.setting.initForumOrTimelineId &&
          forumOrTimeline.isTimeline == appState.setting.initIsTimeline,
    );
    var currentForumOrTimeline = currentForumOrTimelineIndex == -1
        ? null
        : forumOrTimelines[currentForumOrTimelineIndex];

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: ListView(
        children: [
          // 个性化
          SettingsSection(
            title: Text('个性化'),
            children: [
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '暗色模式跟随系统',
                switchValue: appState.setting.followedSysDarkMode,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.followedSysDarkMode = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '板块使用卡片风格',
                switchValue: appState.setting.isCardView,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.isCardView = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '暗色模式使用纯黑',
                switchValue: appState.setting.useAmoledBlack,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.useAmoledBlack = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '回复之间的分割线',
                switchValue: appState.setting.dividerBetweenReply,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.dividerBetweenReply = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '看图页中拖拽退出',
                switchValue: appState.setting.dragToDissmissImage,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.dragToDissmissImage = value;
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('氢岛图标选择'),
                trailing: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(appIcons[appState.setting.selectIcon].$2),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    pageRoute(builder: (context) => IconSelectionPage()),
                  );
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '侧滑返回',
                subtitle: '除了看图页',
                switchValue: appState.setting.enableSwipeBack,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.enableSwipeBack = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '预测性返回',
                subtitle: '安卓14以上支持，仅在侧滑返回关闭时有效果',
                switchValue: appState.setting.predictiveBack,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.predictiveBack = value;
                  });
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('启动版面设置'),
                trailing: SizedBox(
                  height: 45,
                  width: 150,
                  child: DropdownButton2<ForumOrTimeline?>(
                    isExpanded: true,
                    customButton: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Align(
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: HtmlWidget(
                              currentForumOrTimeline?.name ?? '（请设置）',
                            ),
                          ),
                        ),
                      ),
                    ),
                    value: currentForumOrTimeline,
                    alignment: AlignmentDirectional.centerEnd,
                    iconStyleData: IconStyleData(iconSize: 0),
                    underline: SizedBox.shrink(),
                    buttonStyleData: ButtonStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                      ),
                      elevation: 0,
                    ),
                    onChanged: (cur) {
                      if (cur != null) {
                        appState.setState((state) {
                          state.setting.initForumOrTimelineId = cur.id;
                          state.setting.initIsTimeline = cur.isTimeline;
                          state.setting.initForumOrTimelineName = cur.name;
                        });
                      }
                    },
                    items: forumOrTimelines
                        .map(
                          (forumOrTimeline) =>
                              DropdownMenuItem<ForumOrTimeline?>(
                                value: forumOrTimeline,
                                child: HtmlWidget(forumOrTimeline.name),
                              ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          // 显示
          SettingsSection(
            title: Text('显示'),
            children: [
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '固定底栏&顶栏',
                switchValue: appState.setting.fixedBottomBar,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.fixedBottomBar = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '启用分栏布局',
                subtitle: '在宽屏设备上显示多列内容',
                switchValue: appState.setting.isMultiColumn,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.isMultiColumn = value;
                  });
                },
              ),
              SettingsTile.sliderTile(
                contentPadding: breakpoint.gutters,
                title: '分栏宽度(${appState.setting.columnWidth.toInt()}px)',
                min: 300,
                max: 800,
                value: appState.setting.columnWidth,
                divisions: 10,
                onChanged: (double value) {
                  appState.setState((state) {
                    state.setting.columnWidth = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '显示精确时间',
                subtitle: '格式: YYYY/MM/DD hh:mm',
                switchValue: appState.setting.displayExactTime,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.displayExactTime = value;
                  });
                },
              ),
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '屏蔽的板块在时间线上不再出现',
                subtitle: '屏蔽后和开关此选项都需要在刷新时间线后才生效',
                switchValue: appState.setting.dontShowFilttedForumInTimeLine,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.dontShowFilttedForumInTimeLine = value;
                  });
                },
              ),
              SettingsTile.sliderTile(
                contentPadding: breakpoint.gutters,
                title: '第${appState.setting.refCollapsing}层引用折叠',
                min: 1,
                max: 10,
                value: appState.setting.refCollapsing.toDouble(),
                divisions: 9,
                onChanged: (double value) {
                  appState.setState((state) {
                    state.setting.refCollapsing = value.toInt();
                  });
                },
              ),
              SettingsTile.sliderTile(
                contentPadding: breakpoint.gutters,
                title: '每${appState.setting.refPoping}层引用弹窗',
                min: 1,
                max: 20,
                value: appState.setting.refPoping.toDouble(),
                divisions: 19,
                onChanged: (double value) {
                  appState.setState((state) {
                    state.setting.refPoping = value.toInt();
                  });
                },
              ),
              SettingsTile.sliderTile(
                contentPadding: breakpoint.gutters,
                title: '板块和引用长度超过${appState.setting.collapsedLen}时折叠',
                min: 100,
                max: 3100,
                value: appState.setting.collapsedLen.toDouble(),
                divisions: 15,
                onChanged: (double value) {
                  appState.setState((state) {
                    state.setting.collapsedLen = value.toInt();
                  });
                },
              ),
              SettingsTile.sliderTile(
                contentPadding: breakpoint.gutters,
                title:
                    '串内字体大小缩放（${appState.setting.fontSizeFactor.toStringAsFixed(1)}）',
                min: 0.7,
                max: 1.3,
                value: appState.setting.fontSizeFactor,
                divisions: 6,
                onChanged: (double value) {
                  appState.setState((state) {
                    state.setting.fontSizeFactor = value;
                  });
                },
              ),
              SettingsTile.sliderTile(
                contentPadding: breakpoint.gutters,
                title:
                    '论坛页字体大小缩放（${appState.setting.forumFontSizeFactor.toStringAsFixed(1)}）',
                min: 0.7,
                max: 1.3,
                value: appState.setting.forumFontSizeFactor,
                divisions: 6,
                onChanged: (double value) {
                  appState.setState((state) {
                    state.setting.forumFontSizeFactor = value;
                  });
                },
              ),
              SettingsTile.sliderTile(
                contentPadding: breakpoint.gutters,
                title: '表情栏列宽度（${appState.setting.phraseWidth}）',
                subtitle: '值越小表情栏列数越多',
                min: 75,
                max: 250,
                value: appState.setting.phraseWidth.toDouble(),
                divisions: 35,
                onChanged: (double value) {
                  appState.setState((state) {
                    state.setting.phraseWidth = value.toInt();
                  });
                },
              ),
            ],
          ),
          // 网络
          SettingsSection(
            title: Text('网络'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('默认请求CDN'),
                subtitle: Text('影响看串/发串等请求，建议保持自动'),
                trailing: Text(
                  cdnLabel(appState.setting.baseCdn),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () => pickCdn(isBase: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('引用请求CDN'),
                subtitle: Text('影响引用加载'),
                trailing: Text(
                  cdnLabel(appState.setting.refCdn),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                onTap: () => pickCdn(isBase: false),
              ),
            ],
          ),
          // 功能
          SettingsSection(
            title: Text('功能'),
            children: [
              SettingsTile.switchTile(
                contentPadding: breakpoint.gutters,
                title: '启动时检查更新',
                subtitle: '关闭后启动时不再自动检查新版本',
                switchValue: appState.setting.checkUpdateOnLaunch,
                onToggle: (bool value) {
                  appState.setState((state) {
                    state.setting.checkUpdateOnLaunch = value;
                  });
                },
              ),
              SettingsTile.inputTile(
                contentPadding: breakpoint.gutters,
                title: '拉取超时',
                subtitle: '单位为秒',
                value: appState.setting.fetchTimeout.toString(),
                onChanged: (String value) {
                  final intValue = int.tryParse(value);
                  if (intValue != null) {
                    appState.setState((state) {
                      state.setting.fetchTimeout = intValue;
                    });
                  }
                },
              ),
            ],
          ),
          SettingsSection(
            title: Text('高级'),
            children: [
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('刷新时间线和板块列表的缓存(长按)'),
                onLongPress: () {
                  appState.setState((_) {
                    appState.setting.cacheTimelines.clear();
                    appState.tryFetchTimelines(scaffoldMessengerKey);
                    appState.setting.cacheForumLists.clear();
                    appState.tryFetchForumLists(scaffoldMessengerKey);
                  });
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(content: Text('清除成功，正在刷新...')),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('重置自带表情的顺序(长按)'),
                subtitle: Text('自定义的表情会放在最后'),
                onLongPress: () {
                  appState.setState((_) {
                    appState.setting.phrases.removeWhere(
                      (phrase) => phrase.canEdit == false,
                    );
                    appState.setting.phrases.insertAll(0, xDaoPhrases);
                  });
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(content: Text('重置成功')),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('重置App配置(长按)'),
                subtitle: Text('重置所有App配置为默认值，保留用户数据'),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('确认重置'),
                      content: Text('这将重置所有App配置为默认值，但保留您的用户数据（如收藏、历史记录等）'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            appState.resetAppSettings();
                            appState.setState((_) {
                              appState.setting.cacheTimelines.clear();
                              appState.tryFetchTimelines(scaffoldMessengerKey);
                              appState.setting.cacheForumLists.clear();
                              appState.tryFetchForumLists(scaffoldMessengerKey);
                            });
                            Navigator.pop(context);
                            scaffoldMessengerKey.currentState?.showSnackBar(
                              SnackBar(content: Text('App配置已重置')),
                            );
                          },
                          child: Text('确定'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('备份数据'),
                onTap: () async {
                  try {
                    // 打开保存文件对话框
                    final timeStr = DateTime.now()
                        .toString()
                        .substring(0, 10)
                        .replaceAll('-', '');
                    String? filePath = await FilePicker.platform
                        .getDirectoryPath(
                          dialogTitle: '选择保存路径',
                          lockParentWindow: true,
                        );

                    if (filePath != null) {
                      final destinationPath = join(
                        filePath,
                        'lightdao_backup_$timeStr.hive',
                      );
                      await appState.exportSettingToFile(destinationPath);
                      scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(content: Text('保存成功（$destinationPath）')),
                      );
                    } else {
                      scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(content: Text('操作已取消')),
                      );
                    }
                  } catch (e) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text('发生错误: $e')),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('恢复备份'),
                onTap: () async {
                  try {
                    // 打开选择文件对话框
                    String? filePath = await FilePicker.platform
                        .pickFiles(dialogTitle: '选择备份文件')
                        .then((result) => result?.files.single.path);

                    if (filePath != null) {
                      await appState.importSettingFromFile(filePath);

                      scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(content: Text('恢复成功（$filePath）')),
                      );
                    } else {
                      scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(content: Text('操作已取消')),
                      );
                    }
                  } catch (e) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text('发生错误: $e')),
                    );
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: breakpoint.gutters,
                ),
                title: Text('调试'),
                onTap: () async {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('选择调试页面'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text('TsukuyomiList 测试'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                pageRoute(
                                  builder: (context) =>
                                      const TsukuyomiTestPage(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            title: const Text('弹窗全屏测试'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                pageRoute(
                                  builder: (context) =>
                                      const ReplyDialogTestPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsSection extends StatelessWidget {
  final Widget? title;
  final List<Widget> children;

  SettingsSection({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: breakpoint.gutters,
            ),
            dense: true,
            title: title!,
            titleTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ...children,
      ],
    );
  }
}

class SettingsTile {
  static Widget inputTile({
    required String title,
    String? subtitle,
    required String value,
    required ValueChanged<String> onChanged,
    required double contentPadding,
  }) {
    return Builder(
      builder: (context) {
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: contentPadding),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          leadingAndTrailingTextStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          trailing: Text(value),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                final controller = TextEditingController(text: value);
                return AlertDialog(
                  title: Text(title),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        onChanged(controller.text);
                        Navigator.of(context).pop();
                      },
                      child: Text('确定'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  static Widget switchTile({
    required String title,
    String? subtitle,
    required bool switchValue,
    required ValueChanged<bool> onToggle,
    required double contentPadding,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: contentPadding),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: switchValue,
      onChanged: onToggle,
    );
  }

  static Widget sliderTile({
    required String title,
    String? subtitle,
    required double min,
    required double max,
    required double value,
    int? divisions,
    required ValueChanged<double> onChanged,
    required double contentPadding,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: contentPadding),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Slider(
            min: min,
            max: max,
            value: value,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
