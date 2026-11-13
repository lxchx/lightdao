import 'dart:ui';

import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/ui/page/more/about.dart';
import 'package:lightdao/ui/page/more/cookies_management.dart';
import 'package:lightdao/ui/page/more/filters.dart';
import 'package:lightdao/ui/page/more/replys.dart';
import 'package:lightdao/ui/page/more/setting.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/ui/widget/reply_item.dart';
import 'package:lightdao/ui/widget/top_bar.dart';
import 'package:lightdao/utils/uuid.dart';
import 'package:lightdao/utils/xdao_api.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/setting.dart';
import 'more/theme_selector.dart';

void settingFeedUuid(BuildContext context, MyAppState appState) async {
  final TextEditingController uuidController = TextEditingController(
    text: appState.setting.feedUuid,
  );
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('配置订阅ID'),
        content: TextField(
          controller: uuidController,
          decoration: InputDecoration(labelText: '订阅id'),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            onLongPress: () async {
              if (await Permission.phone.isGranted) {
                String uuid = await generateDeviceUuid();
                uuidController.text = uuid;
              } else {
                var status = await Permission.phone.request();
                if (status.isGranted) {
                  String uuid = await generateDeviceUuid();
                  uuidController.text = uuid;
                } else {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(content: Text('设备信息权限获取失败')),
                  );
                }
              }
            },
            child: Text('从设备信息生成一个(长按)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              appState.setState((_) {
                appState.setting.feedUuid = uuidController.text;
              });
              Navigator.pop(context);
            },
            child: Text('确定'),
          ),
        ],
      );
    },
  );
}

Widget starPage(BuildContext context) {
  final appState = Provider.of<MyAppState>(context);
  final breakpoint = Breakpoint.fromMediaQuery(context);
  final loaderOverlay = context.loaderOverlay;
  return StatefulBuilder(
    builder: (context, setState) => ReplysPage(
      title: "收藏",
      actions: [
        StatefulBuilder(
          builder: (context, setState) {
            return IconButton(
              tooltip: "与订阅同步",
              onPressed: () async {
                if (appState.setting.feedUuid == '') {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(content: Text("订阅uuid为空！")),
                  );
                  return;
                }

                final syncStatus = ValueNotifier('开始同步...');
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24.0),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh.withAlpha(85),
                            child: ValueListenableBuilder<String>(
                              valueListenable: syncStatus,
                              builder: (context, value, child) {
                                return Padding(
                                  padding: EdgeInsets.all(breakpoint.gutters),
                                  child: Text(
                                    value,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );

                // 状态变量
                var remoteOnly = <ReplyJson>[];
                var localOnly = <ReplyJsonWithPage>[];

                try {
                  // 拉取远程订阅数据
                  var page = 1;
                  var remoteFeeds = <ReplyJson>[];
                  int retryCount = 0;
                  const maxRetries = 5;
                  while (true) {
                    try {
                      syncStatus.value = '正在拉取远程订阅的第 $page 页...';
                      await Future.delayed(const Duration(milliseconds: 100));
                      final feedInfos = await getFeedInfos(
                        appState.setting.feedUuid,
                        page,
                      ).timeout(const Duration(seconds: 10));
                      if (feedInfos.isEmpty) break;
                      remoteFeeds.addAll(
                        feedInfos.map((feed) => ReplyJson.fromFeedInfo(feed)),
                      );
                      page += 1;
                      retryCount = 0; // Reset retry count on success
                    } catch (e) {
                      if (retryCount >= maxRetries) {
                        throw Exception('超过最大重试次数');
                      }
                      final retryDelay = Duration(
                        milliseconds: 100 * (1 << retryCount),
                      );
                      if (retryDelay.inSeconds >= 1) {
                        throw Exception('单页重试时间超过1秒');
                      }
                      syncStatus.value =
                          '拉取失败: $e，${retryDelay.inMilliseconds}ms后重试...';
                      await Future.delayed(retryDelay);
                      retryCount++;
                    }
                  }

                  // 比对远程和本地的订阅历史
                  final localFeeds = appState.setting.starHistory;

                  remoteOnly = remoteFeeds
                      .where(
                        (feed) => !localFeeds.any(
                          (local) => local.threadId == feed.id,
                        ),
                      )
                      .toList();

                  localOnly = localFeeds
                      .where(
                        (local) => !remoteFeeds.any(
                          (feed) => feed.id == local.threadId,
                        ),
                      )
                      .toList();

                  // 比对完成后关闭状态弹窗
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  syncStatus.value = '正在比对订阅数据...';

                  if (localOnly.isEmpty && remoteOnly.isEmpty) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text('本地云端数据一致')),
                    );
                    return;
                  }

                  // 动态设置默认同步策略
                  String? syncStrategy = remoteOnly.isNotEmpty
                      ? "cloud" // 如果有云端独有串，默认云端为主
                      : localOnly.isNotEmpty
                      ? "local" // 如果有本地独有串且云端没有，默认本地为主
                      : null; // 如果两者都不需要同步，保持null
                  bool dontDelete = true; // 默认保留独有串

                  await showDialog(
                    // ignore: use_build_context_synchronously
                    context: context,
                    builder: (context) {
                      return StatefulBuilder(
                        builder: (context, setState) {
                          // 检查是否需要显示同步选项和“不做删除”选项
                          bool shouldShowCloudToLocalOption() =>
                              remoteOnly.isNotEmpty || localOnly.isNotEmpty;
                          bool shouldShowLocalToCloudOption() =>
                              localOnly.isNotEmpty || remoteOnly.isNotEmpty;
                          bool shouldShowDontDeleteOption() {
                            if (syncStrategy == "cloud") {
                              return shouldShowCloudToLocalOption() &&
                                  localOnly.isNotEmpty;
                            } else {
                              return shouldShowLocalToCloudOption() &&
                                  remoteOnly.isNotEmpty;
                            }
                          }

                          // 动态生成操作描述
                          String getDescription() {
                            if (syncStrategy == "cloud") {
                              if (!shouldShowCloudToLocalOption()) {
                                return "无需同步，云端与本地已一致";
                              }
                              return shouldShowDontDeleteOption()
                                  ? dontDelete
                                        ? remoteOnly.isEmpty
                                              ? "什么也不做"
                                              : "下载${remoteOnly.length}条云端串到本地，本地不做删除"
                                        : remoteOnly.isEmpty
                                        ? "删除${localOnly.length}条仅在本地的串"
                                        : "下载${remoteOnly.length}条云端串到本地，同时删除${localOnly.length}条仅在本地的串"
                                  : "下载${remoteOnly.length}条云端串到本地";
                            } else {
                              if (!shouldShowLocalToCloudOption()) {
                                return "无需同步，本地与云端已一致";
                              }
                              return shouldShowDontDeleteOption()
                                  ? dontDelete
                                        ? localOnly.isEmpty
                                              ? "什么也不做"
                                              : "将${localOnly.length}条串同步到云端，云端不做删除"
                                        : localOnly.isEmpty
                                        ? "删除${remoteOnly.length}条仅在云端的串"
                                        : "将${localOnly.length}条串同步到云端，同时删除${remoteOnly.length}条仅在云端的串"
                                  : "将${localOnly.length}条串同步到云端";
                            }
                          }

                          // 返回动态生成的弹窗
                          return AlertDialog(
                            title: Text("同步订阅"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 同步策略选择
                                ListTile(
                                  title: Text(
                                    "同步操作",
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  dense: true,
                                ),
                                if (shouldShowCloudToLocalOption())
                                  RadioListTile<String>(
                                    value: "cloud",
                                    groupValue: syncStrategy,
                                    onChanged: (value) =>
                                        setState(() => syncStrategy = value),
                                    title: Text("本地👈云端"),
                                  ),
                                if (shouldShowLocalToCloudOption())
                                  RadioListTile<String>(
                                    value: "local",
                                    groupValue: syncStrategy,
                                    onChanged: (value) =>
                                        setState(() => syncStrategy = value),
                                    title: Text("本地👉云端"),
                                  ),

                                // 显示"不做删除"选项（仅当需要时显示）
                                if (shouldShowDontDeleteOption())
                                  CheckboxListTile(
                                    title: Text('不做删除'),
                                    value: dontDelete,
                                    onChanged: (value) => setState(
                                      () => dontDelete = value ?? false,
                                    ),
                                  ),

                                // 动态生成的操作描述
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Text(
                                    getDescription(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text("取消"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop({
                                  "syncStrategy": syncStrategy,
                                  "dontDelete": dontDelete,
                                }),
                                child: Text("确定"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ).then((result) async {
                    if (result == null) return;

                    // 根据用户选择执行操作
                    final isCloudPrimary = result["syncStrategy"] == "cloud";
                    final dontDelete = result["dontDelete"] == true;

                    loaderOverlay.show();

                    if (isCloudPrimary) {
                      if (!dontDelete) {
                        // 云端为主：删除本地独有，添加云端独有
                        appState.setState((_) {
                          appState.setting.starHistory.removeWhere(
                            (local) => localOnly.contains(local),
                          );
                        });
                      }
                      appState.setState((_) {
                        appState.setting.starHistory.insertAll(
                          0,
                          remoteOnly.map(
                            (thread) => ReplyJsonWithPage(
                              1,
                              0,
                              thread.id,
                              thread,
                              thread,
                            ),
                          ),
                        );
                      });
                    } else {
                      if (!dontDelete) {
                        // 本地为主：删除云端独有，添加本地独有
                        final totalToDelete = remoteOnly.length;
                        for (final entry in remoteOnly.asMap().entries) {
                          final index = entry.key;
                          final feed = entry.value;
                          int retryCount = 0;

                          while (true) {
                            try {
                              syncStatus.value =
                                  '正在删除第 ${index + 1}/$totalToDelete 个串...';
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );

                              await delFeed(appState.setting.feedUuid, feed.id);

                              break;
                            } catch (e) {
                              retryCount++;
                              if (retryCount > maxRetries) {
                                throw Exception(
                                  '删除项目 ${feed.id} 失败：已超过最大重试次数。',
                                );
                              }

                              final retryDelay = Duration(
                                milliseconds: 100 * (1 << (retryCount - 1)),
                              );

                              if (retryDelay.inSeconds >= 2) {
                                throw Exception('删除项目 ${feed.id} 失败：重试等待时间过长。');
                              }

                              syncStatus.value =
                                  '删除失败，${retryDelay.inMilliseconds}ms后重试 (第$retryCount次)...';
                              await Future.delayed(retryDelay);
                            }
                          }
                        }
                      }
                      final totalToAdd = localOnly.length;
                      for (final entry in localOnly.asMap().entries) {
                        final index = entry.key;
                        final feed = entry.value;
                        int retryCount = 0;

                        while (true) {
                          try {
                            syncStatus.value =
                                '正在添加第 ${index + 1}/$totalToAdd 个串...';
                            await Future.delayed(
                              const Duration(milliseconds: 100),
                            );

                            await addFeed(
                              appState.setting.feedUuid,
                              feed.threadId,
                            );

                            break;
                          } catch (e) {
                            retryCount++;
                            if (retryCount > maxRetries) {
                              throw Exception(
                                '添加项目 ${feed.threadId} 失败：已超过最大重试次数。',
                              );
                            }

                            final retryDelay = Duration(
                              milliseconds: 100 * (1 << (retryCount - 1)),
                            );

                            if (retryDelay.inSeconds >= 2) {
                              throw Exception(
                                '添加项目 ${feed.threadId} 失败：重试等待时间过长。',
                              );
                            }

                            syncStatus.value =
                                '添加失败，${retryDelay.inMilliseconds}ms后重试 (第$retryCount次)...';
                            await Future.delayed(retryDelay);
                          }
                        }
                      }
                    }

                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text('同步完成')),
                    );

                    loaderOverlay.hide();
                  });
                } catch (e) {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                } finally {
                  loaderOverlay.hide();
                }
              },
              icon: Icon(Icons.sync),
            );
          },
        ),
        IconButton(
          tooltip: "配置",
          onPressed: () => settingFeedUuid(context, appState),
          icon: Icon(Icons.manage_accounts),
        ),
      ],
      listDelegate: SliverChildBuilderDelegate((context, index) {
        final re = appState.setting.starHistory[index];
        return HistoryReply(
          re: re,
          contentHeroTag: 'ThreadCard ${re.thread.id}',
          onLongPress: () => showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('取消收藏？'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('保持收藏'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      appState.setState((_) {
                        appState.setting.starHistory.removeWhere(
                          (r) => r.threadId == re.threadId,
                        );
                      });
                      setState(() {});
                    },
                    child: Text('不再收藏'),
                  ),
                ],
              );
            },
          ),
          onTap: () => appState.navigateThreadPage2(
            context,
            re.threadId,
            false,
            thread: ThreadJson.fromReplyJson(re.thread, []),
          ),
        );
      }, childCount: appState.setting.starHistory.length),
    ),
  );
}

Widget replyPage(BuildContext context) {
  final appState = Provider.of<MyAppState>(context);
  return StatefulBuilder(
    builder: (context, setState) {
      return ReplysPage(
        title: "发言",
        listDelegate: SliverChildBuilderDelegate((context, index) {
          final re = appState.setting.replyHistory[index];
          return HistoryReply(
            re: re,
            onLongPress: () => showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('删除发言记录'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        appState.setState((_) {
                          appState.setting.replyHistory.removeWhere(
                            (r) => r.reply.id == re.reply.id,
                          );
                        });
                        setState(() {});
                      },
                      child: Text('删除'),
                    ),
                  ],
                );
              },
            ),
            onTap: () => appState.navigateThreadPage2(
              context,
              re.threadId,
              false,
              thread: ThreadJson.fromReplyJson(re.thread, []),
            ),
          );
        }, childCount: appState.setting.replyHistory.length),
      );
    },
  );
}

class MorePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = brightness == Brightness.dark;
    pageRoute({required Widget Function(BuildContext) builder}) {
      final setting = Provider.of<MyAppState>(context, listen: false).setting;
      if (setting.enableSwipeBack) {
        return SwipeablePageRoute(builder: builder);
      } else {
        return MaterialPageRoute(builder: builder);
      }
    }

    final TopBarMode topBarMode = topBarModeOf(
      context,
      fixedBottomBar: appState.setting.fixedBottomBar,
    );
    final List<Widget> tiles = <Widget>[
      Padding(
        padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        child: Card(
          shadowColor: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        pageRoute(
                          builder: (context) {
                            return starPage(context);
                          },
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.all(breakpoint.gutters),
                      child: Column(
                        children: [
                          Text(
                            appState.setting.starHistory.length.toString(),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text('收藏'),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: breakpoint.gutters / 2,
                  ),
                  child: VerticalDivider(width: 2),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        pageRoute(
                          builder: (context) => ReplysPage(
                            title: "发言",
                            listDelegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final re = appState.setting.replyHistory[index];
                                return HistoryReply(
                                  re: re,
                                  onTap: () => appState.navigateThreadPage2(
                                    context,
                                    re.threadId,
                                    false,
                                    thread: ThreadJson.fromReplyJson(
                                      re.thread,
                                      [],
                                    ),
                                  ),
                                );
                              },
                              childCount: appState.setting.replyHistory.length,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.all(breakpoint.gutters),
                      child: Column(
                        children: [
                          Text(
                            appState.setting.replyHistory.length.toString(),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text('发言'),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: breakpoint.gutters / 2,
                  ),
                  child: VerticalDivider(width: 2),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        pageRoute(
                          builder: (context) => StatefulBuilder(
                            builder: (context, setState) {
                              return ReplysPage(
                                title: "浏览",
                                listDelegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final re = appState.setting.viewHistory
                                        .getIndex(index);
                                    if (re != null) {
                                      return HistoryReply(
                                        re: re,
                                        contentHeroTag:
                                            'ThreadCard ${re.thread.id}',
                                        onLongPress: () => showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: Text('删除浏览记录？'),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                    appState.setState((_) {
                                                      appState
                                                          .setting
                                                          .viewHistory
                                                          .remove(re.threadId);
                                                    });
                                                    setState(() {});
                                                  },
                                                  child: Text('删除'),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        onTap: () =>
                                            appState.navigateThreadPage2(
                                              context,
                                              re.threadId,
                                              false,
                                              thread: ThreadJson.fromReplyJson(
                                                re.thread,
                                                [],
                                              ),
                                            ),
                                      );
                                    } else {
                                      return Text("?");
                                    }
                                  },
                                  childCount:
                                      appState.setting.viewHistory.length,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.all(breakpoint.gutters),
                      child: Column(
                        children: [
                          Text(
                            appState.setting.viewHistory.length.toString(),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text('浏览'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(height: breakpoint.gutters),
      ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        leading: Icon(Icons.color_lens_rounded),
        title: Text('主题选择'),
        onTap: () {
          final appState = Provider.of<MyAppState>(context, listen: false);
          final brightness = MediaQuery.of(context).platformBrightness;
          final isSysDarkMode = brightness == Brightness.dark;
          final isUserDarkMode = appState.setting.userSettingIsDarkMode;
          final followSysDarkMode = appState.setting.followedSysDarkMode;
          final initIndex = followSysDarkMode
              ? (isSysDarkMode ? 1 : 0)
              : (isUserDarkMode ? 1 : 0);
          Navigator.push(
            context,
            pageRoute(
              builder: (context) => ThemeSelectorPage(initIndex: initIndex),
            ),
          );
        },
        trailing: SizedBox(
          width: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('暗色', style: Theme.of(context).textTheme.labelSmall),
              SizedBox(width: 5),
              Switch(
                value: appState.setting.followedSysDarkMode
                    ? isDarkMode
                    : appState.setting.userSettingIsDarkMode,
                onChanged: (bool value) {
                  if (appState.setting.followedSysDarkMode) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('已取消跟随系统暗色模式')));
                    appState.setState((state) {
                      state.setting.followedSysDarkMode = false;
                    });
                  }
                  appState.setState((state) {
                    state.setting.userSettingIsDarkMode = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        leading: Icon(Icons.cookie),
        title: Text('饼干管理'),
        onTap: () {
          Navigator.push(
            context,
            pageRoute(builder: (context) => CookieManagementPage()),
          );
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        leading: Icon(Icons.visibility_off),
        title: Text('屏蔽管理'),
        onTap: () {
          Navigator.push(
            context,
            pageRoute(builder: (context) => FiltersManagementPage()),
          );
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        leading: Icon(Icons.manage_accounts),
        title: Text('用户系统'),
        onTap: () async {
          final uri = Uri.parse('https://www.nmbxd1.com/Member');
          await launchUrl(uri);
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        leading: Icon(Icons.settings),
        title: Text('设置'),
        onTap: () async {
          Navigator.push(
            context,
            pageRoute(builder: (context) => SettingsPage()),
          );
        },
      ),
      ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
        leading: Icon(Icons.info),
        title: Text('关于'),
        onTap: () async {
          PackageInfo packageInfo = await PackageInfo.fromPlatform();
          if (!context.mounted) return;
          Navigator.push(
            context,
            pageRoute(
              builder: (context) {
                final appState = Provider.of<MyAppState>(context);
                return AboutPage(appState: appState, packageInfo: packageInfo);
              },
            ),
          );
        },
      ),
    ];

    // 手机竖屏（底部导航）：与改动前完全一致（固定的 AppBar + 可滚动的列表）。
    // 这一页内容短，改动前顶栏也没跟手收起过，所以竖屏下始终固定。
    if (topBarMode == TopBarMode.phone) {
      return Scaffold(
        appBar: AppBar(title: Text('更多')),
        body: SafeArea(child: ListView(children: tiles)),
      );
    }

    // 侧栏导航模式：内容从顶栏下面滑过；顶栏固定时半透明 + 背景模糊，矮屏时
    // 纯色跟手隐藏（都由 top_bar.dart 判定）。
    final bool pinnedTopBar = topBarMode == TopBarMode.pinnedGlass;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (pinnedTopBar)
            glassTopBarHeader(
              extent: MediaQuery.paddingOf(context).top + kToolbarHeight,
              child: GlassTopBar(title: Text('更多')),
            )
          else
            solidTopBarSliver(context: context, title: Text('更多')),
          SliverSafeArea(
            top: false,
            sliver: SliverList(delegate: SliverChildListDelegate(tiles)),
          ),
        ],
      ),
    );
  }

  void settingUuid(MyAppState appState, BuildContext context) {
    {
      final TextEditingController uuidController = TextEditingController(
        text: appState.setting.feedUuid,
      );
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('配置订阅ID'),
            content: TextField(
              controller: uuidController,
              decoration: InputDecoration(labelText: '订阅id'),
            ),
            actions: [
              TextButton(
                onPressed: () {},
                onLongPress: () async {
                  if (await Permission.phone.isGranted) {
                    String uuid = await generateDeviceUuid();
                    uuidController.text = uuid;
                  } else {
                    var status = await Permission.phone.request();
                    if (status.isGranted) {
                      String uuid = await generateDeviceUuid();
                      uuidController.text = uuid;
                    } else {
                      scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(content: Text('设备信息权限获取失败')),
                      );
                    }
                  }
                },
                child: Text('从设备信息生成一个(长按)'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  appState.setState((_) {
                    appState.setting.feedUuid = uuidController.text;
                  });
                  Navigator.pop(context);
                },
                child: Text('确定'),
              ),
            ],
          );
        },
      );
    }
  }
}

class HistoryReply extends StatelessWidget {
  const HistoryReply({
    super.key,
    required this.re,
    this.onTap,
    this.contentHeroTag,
    this.onLongPress,
  });

  final ReplyJsonWithPage re;
  final void Function()? onTap;
  final void Function()? onLongPress;
  final Object? contentHeroTag;

  @override
  Widget build(BuildContext context) {
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: breakpoint.gutters,
              vertical: breakpoint.gutters / 2,
            ),
            child: Column(
              children: [
                ReplyItem(
                  threadJson: re.thread,
                  contentNeedCollapsed: true,
                  noMoreParse: true,
                  contentHeroTag: contentHeroTag,
                ),
                if (re.thread.id != re.reply.id)
                  Padding(
                    padding: EdgeInsets.only(
                      left: breakpoint.gutters / 2,
                      right: breakpoint.gutters / 2,
                      top: breakpoint.gutters / 2,
                    ),
                    child: Card.filled(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ReplyItem(
                          poUserHash: re.thread.userHash,
                          threadJson: re.reply,
                          contentNeedCollapsed: true,
                          noMoreParse: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters / 2),
          child: Divider(height: 2),
        ),
      ],
    );
  }
}
