import 'dart:async';

import 'package:app_installer/app_installer.dart';
import 'package:breakpoint/breakpoint.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lightdao/data/const_data.dart';
import 'package:lightdao/data/setting.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:lightdao/utils/update_checker.dart';
import 'package:lightdao/ui/widget/fading_scroll_view.dart';
import 'package:url_launcher/url_launcher.dart';

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
      appBar: AppBar(title: Text('关于')),
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
                      Text('美观、现代的X岛第三方客户端', style: TextStyle(fontSize: 16.0)),
                    ],
                  ),
                ),
              ),
            ),
            ListTile(
              title: Text('版本'),
              subtitle: Text(
                '${packageInfo.version} (${packageInfo.buildNumber})',
              ),
              trailing: TextButton(
                child: Text('检查更新'),
                onPressed: () => _checkForUpdates(context),
              ),
              onTap: () => _checkForUpdates(context),
            ),
            ListTile(title: Text('作者'), subtitle: Text('9ionKfO')),
            ListTile(
              title: Text('项目地址'),
              subtitle: Text('https://github.com/lxchx/lightdao'),
              onTap: () =>
                  launchUrl(Uri.parse('https://github.com/lxchx/lightdao')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      final updateInfo = await UpdateChecker.checkUpdate();
      if (!context.mounted) return;
      if (updateInfo != null && updateInfo.hasUpdate) {
        _showUpdateDialog(context, updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已经是最新版本'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('检查更新失败: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showUpdateDialog(BuildContext context, UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 ${updateInfo.latestVersion}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: FadingScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: updateInfo.updateLog,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                  selectable: true,
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(Uri.parse(href));
                    }
                  },
                ),
                // 底部添加一些空间
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text('复制下载链接'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: updateInfo.downloadUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已复制下载链接'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: Text('下载'),
            onPressed: () => _downloadUpdate(context, updateInfo),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate(
    BuildContext context,
    UpdateInfo updateInfo,
  ) async {
    String? savePath;
    bool isDownloading = true;
    String? errorMessage;
    double progress = 0.0;
    bool downloadComplete = false;
    late StateSetter dialogSetState;
    final initCompleter = Completer<void>();
    final cancelToken = CancelToken();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          if (!initCompleter.isCompleted) {
            initCompleter.complete();
          }
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) {
                return;
              }
              // 当对话框关闭时取消下载
              if (isDownloading && !cancelToken.isCancelled) {
                cancelToken.cancel('用户取消下载');
              }
              Navigator.pop(context);
            },
            child: AlertDialog(
              title: Text(
                isDownloading ? '正在下载更新' : (downloadComplete ? '下载完成' : '下载失败'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDownloading) ...[
                    LinearProgressIndicator(value: progress), // 使用进度变量
                    SizedBox(height: 16),
                    Text('${(progress * 100).toStringAsFixed(1)}%'), // 使用进度变量
                  ] else if (downloadComplete && savePath != null) ...[
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(height: 16),
                    Text('下载完成，可以安装了'),
                  ] else
                    SingleChildScrollView(
                      child: SelectableText(
                        errorMessage ??
                            (savePath == null ? '无法获取下载路径' : '下载失败：$savePath'),
                      ),
                    ),
                ],
              ),
              actions: [
                if (downloadComplete && savePath != null) ...[
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      AppInstaller.installApk(savePath!).catchError((error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Expanded(child: Text('安装失败: $error')),
                                TextButton(
                                  onPressed: () {
                                    AppInstaller.installApk(savePath!);
                                  },
                                  child: Text('重试'),
                                ),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      });
                    },
                    child: Text('打开'),
                  ),
                ],
                TextButton(
                  onPressed: () {
                    if (isDownloading && !cancelToken.isCancelled) {
                      cancelToken.cancel('用户取消下载');
                    }
                    Navigator.pop(context);
                  },
                  child: Text('关闭'),
                ),
              ],
            ),
          );
        },
      ),
    );

    // 等待对话框初始化完成
    await initCompleter.future;

    try {
      // 开始下载
      savePath = await UpdateChecker.downloadUpdate(
        url: updateInfo.downloadUrl,
        version: updateInfo.latestVersion,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (total != -1 && context.mounted) {
            // 更新进度显示
            dialogSetState(() {
              progress = received / total; // 更新进度变量
              if (received == total && savePath != null) {
                isDownloading = false;
                downloadComplete = true; // 标记下载完成
              }
            });
          }
        },
      );

      if (savePath == null && context.mounted && !cancelToken.isCancelled) {
        dialogSetState(() {
          isDownloading = false;
          downloadComplete = false;
          errorMessage = '下载失败：无法获取保存路径';
        });
      } else {
        dialogSetState(() {
          isDownloading = false;
          downloadComplete = true;
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      // 如果是用户取消导致的异常，不显示错误
      if (cancelToken.isCancelled) {
        return;
      }
      dialogSetState(() {
        isDownloading = false;
        downloadComplete = false;
        errorMessage = '下载失败：${e.toString()}';
      });
    }
  }
}
