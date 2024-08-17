//import 'package:dynamic_app_icon_flutter/dynamic_app_icon.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:lightdao/data/const_data.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/data/trend_data.dart';
import 'package:lightdao/data/xdao/forum.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/timeline.dart';
import 'package:lightdao/ui/page/forum.dart';
import 'package:flutter/material.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:loader_overlay/loader_overlay.dart';

import 'package:provider/provider.dart';
import 'package:variable_app_icon/variable_app_icon.dart';

import 'data/global_storage.dart';
import 'data/setting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 小白条通知栏沉浸
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
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

  MyAppState myAppState = MyAppState();
  await myAppState.loadSettings();
  VariableAppIcon.androidAppIconIds = appIconsNamesList;
  runApp(MyApp(
    myAppState: myAppState,
  ));
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
                isDarkMode: isDarkMode);
          });
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
    final backGroundBlack =
        appState.setting.useAmoledBlack ? Colors.black : null;
    return GlobalLoaderOverlay(
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
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static final threadUrlRegex =
      RegExp(r'(https?:\/\/)?www\.nmbxd1?\.com\/t\/(\d+)');
  String lastClipBoardData = '';
  bool isDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readClipboard();
    final appState = Provider.of<MyAppState>(context, listen: false);
    Future.delayed(Duration(milliseconds: 100), () {
      appState.tryFetchTimelines(scaffoldMessengerKey);
      appState.tryFetchForumLists(scaffoldMessengerKey);
    });
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return ForumPage();
  }

  Future<void> _readClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null) {
      final clipText = data.text;
      if (clipText != null && clipText != lastClipBoardData) {
        final threadIdMatch = threadUrlRegex.firstMatch(clipText);
        if (threadIdMatch == null) return;
        final threadId = int.tryParse(threadIdMatch.group(2) ?? '');
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
                  child: ListBody(
                    children: <Widget>[
                      Text('是否需要跳转到对应串？'),
                    ],
                  ),
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
                      context.loaderOverlay.show();
                      final appState =
                          Provider.of<MyAppState>(context, listen: false);
                      appState.navigateThreadPage(context, threadId, true);
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
