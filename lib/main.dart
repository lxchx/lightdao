//import 'package:dynamic_app_icon_flutter/dynamic_app_icon.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:lightdao/data/const_data.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/data/third_party_consent.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/data/trend_data.dart';
import 'package:lightdao/data/update_policy.dart';
import 'package:lightdao/data/xdao/forum.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/timeline.dart';
import 'package:lightdao/ui/page/app_page.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/ui/page/more/about.dart';
import 'package:lightdao/ui/page/third_party_consent_page.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/utils/frame_log.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/update_checker.dart';
import 'package:lightdao/utils/update_downloader.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:provider/provider.dart';
import 'package:variable_app_icon/variable_app_icon.dart';

import 'data/global_storage.dart';
import 'data/setting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installFrameLog();
  // 小白条通知栏沉浸
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  Hive.registerAdapter(CookieSettingAdapter());
  Hive.registerAdapter(LightDaoSettingAdapter());
  Hive.registerAdapter(MaterialColorAdapter());
  Hive.registerAdapter(ColorAdapter());
  Hive.registerAdapter(LRUCacheAdapter<int, ReplyJsonWithPage>());
  Hive.registerAdapter(ReplyJsonAdapter());
  Hive.registerAdapter(ReplyJsonWithPageAdapter());
  Hive.registerAdapter(ThreadUserDataAdapter());
  Hive.registerAdapter(TimelineAdapter());
  Hive.registerAdapter(ForumListAdapter());
  Hive.registerAdapter(ForumAdapter());
  Hive.registerAdapter(ForumThreadFilterAdapter());
  Hive.registerAdapter(IdThreadFilterAdapter());
  Hive.registerAdapter(UserHashFilterAdapter());
  Hive.registerAdapter(TrendDataAdapter());
  Hive.registerAdapter(PhraseAdapter());
  Hive.registerAdapter(FavoredItemTypeAdapter());
  Hive.registerAdapter(FavoredItemAdapter());

  MyAppState myAppState = MyAppState();
  await myAppState.loadSettings();
  VariableAppIcon.androidAppIconIds = appIconsNamesList;
  runApp(MyApp(myAppState: myAppState));
}

class MyApp extends StatelessWidget {
  final MyAppState myAppState;
  const MyApp({super.key, required this.myAppState});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => myAppState,
      child: Builder(
        builder: (context) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              final brightness = MediaQuery.of(context).platformBrightness;
              final isDarkMode = brightness == Brightness.dark;
              final appState = Provider.of<MyAppState>(context);
              final fixedLightColorScheme = ColorScheme.fromSeed(
                seedColor: appState.setting.lightModeThemeColor,
                brightness: Brightness.light,
              );
              final fixedDarkColorScheme = ColorScheme.fromSeed(
                seedColor: appState.setting.darkModeThemeColor,
                brightness: Brightness.dark,
              );
              // 为什么不直接用lightDynamic和darkDynamic呢？
              // 因为这两个调色盘不够丰富，Card颜色和背景颜色会混在一起
              final dynamicLightColorScheme = lightDynamic == null
                  ? null
                  : ColorScheme.fromSeed(
                      seedColor: lightDynamic.primary,
                      brightness: Brightness.light,
                    );
              final dynamicDarkColorScheme = darkDynamic == null
                  ? null
                  : ColorScheme.fromSeed(
                      seedColor: darkDynamic.primary,
                      brightness: Brightness.dark,
                    );
              return App(
                key: Key('LightDaoApp'),
                appState: appState,
                lightColorScheme: appState.setting.dynamicThemeColor
                    ? (dynamicLightColorScheme ?? fixedLightColorScheme)
                    : fixedLightColorScheme,
                darkColorScheme: appState.setting.dynamicThemeColor
                    ? (dynamicDarkColorScheme ?? fixedDarkColorScheme)
                    : fixedDarkColorScheme,
                isDarkMode: isDarkMode,
              );
            },
          );
        },
      ),
    );
  }
}

class App extends StatelessWidget {
  const App({
    super.key,
    required this.appState,
    required this.lightColorScheme,
    required this.darkColorScheme,
    required this.isDarkMode,
  });

  final MyAppState appState;
  final ColorScheme lightColorScheme;
  final ColorScheme darkColorScheme;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final backGroundBlack = appState.setting.useAmoledBlack
        ? Colors.black
        : null;
    final Brightness iconBrightness = isDarkMode
        ? Brightness.light
        : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
      child: GlobalLoaderOverlay(
        child: MaterialApp(
          title: '氢岛',
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            pageTransitionsTheme: appState.setting.predictiveBack
                ? const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android:
                          PredictiveBackPageTransitionsBuilder(),
                    },
                  )
                : null,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: backGroundBlack,
            pageTransitionsTheme: appState.setting.predictiveBack
                ? const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android:
                          PredictiveBackPageTransitionsBuilder(),
                    },
                  )
                : null,
            appBarTheme: AppBarTheme(backgroundColor: backGroundBlack),
          ),
          themeMode: appState.setting.followedSysDarkMode
              ? (isDarkMode ? ThemeMode.dark : ThemeMode.light)
              : (appState.setting.userSettingIsDarkMode
                    ? ThemeMode.dark
                    : ThemeMode.light),
          home: _AppRoot(),
        ),
      ),
    );
  }
}

/// 启动入口：当前清单里还有没问过用户的第三方服务时先显示同意页。
///
/// 没问过的情况有两种：第一次启动（什么都没问过），以及清单里新增了服务
/// （新增的 id 没问过）。问过之后再也不会重复问——包括用户点了「不同意」的那些项。
///
/// 时间线、板块、更新检查这些网络请求都在 [MyHomePage] 的 initState 里，
/// 决定之前 [MyHomePage] 根本不会被创建，请求也就不会发出去。
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final setting = appState.setting;
    // 门禁只看「当前清单里还有没有没问过的项」，见 [shouldAskConsent]。
    if (shouldAskConsent(setting.askedServices)) {
      final unaskedServices = setting.pendingThirdPartyServices;
      // 清单里有没问过的项：首次启动时是整份清单，清单新增服务后只有新增的那几项。
      // 只有后者才需要在页首标出「新增了哪几项」；首次启动看到的就是整份说明。
      // 用户在这里点「不同意」只把这几项记成「问过」，之前同意过的服务照常可用。
      return ThirdPartyConsentPage(
        newServices: setting.askedServices.isEmpty ? const [] : unaskedServices,
        onDecided: (allowed) {
          // 写入后 applyNetworkSettings 会立刻按新的同意状态重设线路。
          appState.recordConsentPageDecision(allowed);
        },
      );
    }
    return MyHomePage();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static final threadUrlRegex = RegExp(
    r'(https?:\/\/)?www\.nmbxd1?\.com\/(m\/)?t\/(\d+)',
  );
  String lastClipBoardData = '';
  bool isDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readClipboard();
    final appState = Provider.of<MyAppState>(context, listen: false);
    Future.delayed(Duration(milliseconds: 100), () async {
      appState.tryFetchTimelines(scaffoldMessengerKey);
      appState.tryFetchForumLists(scaffoldMessengerKey);
      await _checkUpdateOnLaunch(appState);
    });
  }

  /// 启动时的更新检查，按设置里的「更新策略」分档处理：
  /// - 永不检查：不检查；
  /// - 自动检查：发现新版本时提示去关于页更新（与引入更新策略之前一致）；
  /// - 自动更新：发现新版本时在后台静默下载安装包，下载完成后提示安装，
  ///   下载失败则退回「自动检查」的提示。
  /// 非 Android 平台没有安装 APK 的能力，由 [resolveUpdatePolicy] 把
  /// 自动更新退化成自动检查。
  Future<void> _checkUpdateOnLaunch(MyAppState appState) async {
    final policy = appState.setting.effectiveUpdatePolicy;
    if (policy == UpdatePolicy.never) {
      return;
    }
    try {
      final updateInfo = await UpdateChecker.checkUpdate();
      if (updateInfo == null || !updateInfo.hasUpdate) {
        return;
      }
      if (policy == UpdatePolicy.auto) {
        await _autoDownloadUpdate(appState, updateInfo);
      } else {
        await _showUpdateAvailableHint(appState, updateInfo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('检查更新失败: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 「自动检查」档的提示：告诉用户有新版本，并可一键跳到关于页手动更新。
  Future<void> _showUpdateAvailableHint(
    MyAppState appState,
    UpdateInfo updateInfo,
  ) async {
    if (!mounted) return;
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('发现新版本: ${updateInfo.latestVersion}, 请到关于页面更新'),
        action: SnackBarAction(
          label: '跳转到关于',
          onPressed: () => Navigator.push(
            context,
            appState.createPageRoute(
              builder: (context) =>
                  AboutPage(appState: appState, packageInfo: packageInfo),
            ),
          ),
        ),
      ),
    );
  }

  /// 「自动更新」档：后台静默下载新版本安装包，下载完成后提示安装。
  ///
  /// 下载失败时不弹错误，而是退回「自动检查」的提示，用户仍可去关于页手动更新。
  Future<void> _autoDownloadUpdate(
    MyAppState appState,
    UpdateInfo updateInfo,
  ) async {
    String? savePath;
    try {
      savePath = await UpdateDownloader.downloadApk(updateInfo: updateInfo);
    } catch (e) {
      // 下载失败时 savePath 保持为 null，下面退回「自动检查」的提示
      debugPrint('自动下载新版本失败: $e');
    }
    if (!mounted) return;
    final apkPath = savePath;
    if (apkPath == null) {
      await _showUpdateAvailableHint(appState, updateInfo);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // 需要用户点「安装」，停留久一点
        duration: const Duration(seconds: 10),
        content: Text('新版本 ${updateInfo.latestVersion} 已下载'),
        action: SnackBarAction(
          label: '安装',
          onPressed: () {
            UpdateDownloader.installApk(apkPath).catchError((error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('安装失败: $error'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage();
  }

  Future<void> _readClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null) {
      final clipText = data.text;
      if (clipText != null && clipText != lastClipBoardData) {
        final threadIdMatch = threadUrlRegex.firstMatch(clipText);
        if (threadIdMatch == null) return;
        final threadId = int.tryParse(threadIdMatch.group(3) ?? '');
        if (threadId == null || !mounted) return;
        if (!isDialogShown) {
          setState(() {
            isDialogShown = true;
          });
          showDialog<void>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('检测到串链接'),
                content: SingleChildScrollView(
                  child: ListBody(children: <Widget>[Text('是否需要跳转到对应串？')]),
                ),
                actions: <Widget>[
                  TextButton(
                    child: Text('取消(本链接不再提示)'),
                    onPressed: () {
                      lastClipBoardData = clipText;
                      setState(() {
                        isDialogShown = false;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('取消'),
                    onPressed: () {
                      setState(() {
                        isDialogShown = false;
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('确认'),
                    onPressed: () async {
                      lastClipBoardData = clipText;
                      final appState = Provider.of<MyAppState>(
                        context,
                        listen: false,
                      );
                      appState.navigateThreadPage2(context, threadId, true);
                      setState(() {
                        isDialogShown = false;
                      });
                    },
                  ),
                ],
              );
            },
          ).then((_) {
            setState(() {
              isDialogShown = false;
            });
          });
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readClipboard();
    }
  }
}
