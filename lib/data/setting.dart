import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/data/trend_data.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/ui/page/thread2.dart';
import 'package:lightdao/utils/status.dart';
import 'package:lightdao/data/xdao/timeline.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:lightdao/utils/xdao_api.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

import 'xdao/forum.dart';

part 'setting.g.dart';

@HiveType(typeId: 0)
class CookieSetting extends HiveObject {
  @HiveField(0)
  String cookieHash;

  @HiveField(1)
  String name;

  @HiveField(2, defaultValue: '')
  String displayName;

  String getShowName() {
    if (displayName != '') {
      return '$displayName ($name)';
    } else {
      return name;
    }
  }

  CookieSetting(
      {required this.cookieHash,
      required this.name,
      required this.displayName});
}

@HiveType(typeId: 1)
class LightDaoSetting extends HiveObject {
  @HiveField(0, defaultValue: [])
  List<CookieSetting> cookies;

  @HiveField(1, defaultValue: -1)
  int currentCookie;

  @HiveField(2, defaultValue: 3)
  int refCollapsing;

  @HiveField(3, defaultValue: 3)
  int refPoping;

  @HiveField(4, defaultValue: true)
  bool followedSysDarkMode;

  @HiveField(5, defaultValue: false)
  bool userSettingIsDarkMode;

  @HiveField(6, defaultValue: false)
  bool isCardView;

  @HiveField(7, defaultValue: 100)
  int collapsedLen;

  @HiveField(8, defaultValue: Color.fromARGB(255, 241, 98, 100))
  Color lightModeThemeColor;

  @HiveField(9, defaultValue: Color.fromARGB(255, 241, 98, 100))
  Color darkModeThemeColor;

  @HiveField(10, defaultValue: false)
  bool dynamicThemeColor;

  @HiveField(11)
  LRUCache<int, ReplyJsonWithPage> viewHistory;

  @HiveField(12, defaultValue: [])
  List<ReplyJsonWithPage> replyHistory;

  @HiveField(13, defaultValue: [])
  List<ReplyJsonWithPage> starHistory;

  @HiveField(14, defaultValue: Color.fromARGB(255, 96, 125, 138))
  Color lightModeCustomThemeColor;

  @HiveField(15, defaultValue: Color.fromARGB(255, 96, 125, 138))
  Color darkModeCustomThemeColor;

  @HiveField(16, defaultValue: {})
  Map<int, ThreadUserData> threadUserData;

  @HiveField(17, defaultValue: 0)
  int selectIcon;

  @HiveField(18, defaultValue: '')
  String feedUuid;

  @HiveField(19, defaultValue: false)
  bool useAmoledBlack;

  @HiveField(20, defaultValue: 1.0)
  double fontSizeFactor;

  @HiveField(21, defaultValue: false)
  bool dividerBetweenReply;

  @HiveField(22, defaultValue: [])
  List<Timeline> cacheTimelines;

  @HiveField(23, defaultValue: [])
  List<ForumList> cacheForumLists;

  @HiveField(24, defaultValue: false)
  bool fixedBottomBar;

  @HiveField(25, defaultValue: false)
  bool displayExactTime;

  @HiveField(26, defaultValue: [])
  List<Forum> favoredForums;

  @HiveField(27, defaultValue: [])
  List<ThreadFilter> threadFilters;

  // 上次fetch时间，最新趋势
  @HiveField(28, defaultValue: null)
  TrendData? latestTrend;

  @HiveField(29, defaultValue: true)
  bool dragToDissmissImage;

  @HiveField(30, defaultValue: true)
  bool dontShowFilttedForumInTimeLine;

  @HiveField(31, defaultValue: [])
  List<Phrase> phrases;

  @HiveField(32, defaultValue: false)
  bool enableSwipeBack;

  @HiveField(33, defaultValue: 1)
  int initForumOrTimelineId;

  @HiveField(34, defaultValue: true)
  bool initIsTimeline;

  @HiveField(35, defaultValue: '综合线')
  String initForumOrTimelineName;

  @HiveField(36, defaultValue: false)
  bool predictiveBack;

  // 分栏宽度
  @HiveField(37, defaultValue: 445)
  double columnWidth;

  // 是否分栏
  @HiveField(38, defaultValue: true)
  bool isMultiColumn;

  LightDaoSetting({
    required this.cookies,
    required this.currentCookie,
    required this.refCollapsing,
    required this.refPoping,
    required this.followedSysDarkMode,
    required this.userSettingIsDarkMode,
    required this.isCardView,
    required this.collapsedLen,
    required this.lightModeThemeColor,
    required this.darkModeThemeColor,
    required this.dynamicThemeColor,
    LRUCache<int, ReplyJsonWithPage>? viewHistory,
    required this.replyHistory,
    required this.starHistory,
    required this.lightModeCustomThemeColor,
    required this.darkModeCustomThemeColor,
    required this.threadUserData,
    required this.selectIcon,
    required this.feedUuid,
    required this.useAmoledBlack,
    required this.fontSizeFactor,
    required this.dividerBetweenReply,
    required this.cacheTimelines,
    required this.cacheForumLists,
    required this.fixedBottomBar,
    required this.displayExactTime,
    required this.favoredForums,
    required this.threadFilters,
    required this.latestTrend,
    required this.dragToDissmissImage,
    required this.dontShowFilttedForumInTimeLine,
    required this.phrases,
    required this.enableSwipeBack,
    required this.initForumOrTimelineId,
    required this.initIsTimeline,
    required this.initForumOrTimelineName,
    required this.predictiveBack,
    required this.columnWidth,
    required this.isMultiColumn,
  }) : viewHistory = viewHistory ?? LRUCache<int, ReplyJsonWithPage>(5000);
}

class MaterialColorAdapter extends TypeAdapter<MaterialColor> {
  @override
  final typeId = 3;

  @override
  MaterialColor read(BinaryReader reader) {
    final value = reader.readInt();
    return Colors.primaries.firstWhere((color) => color.value == value,
        orElse: () => Colors.green);
  }

  @override
  void write(BinaryWriter writer, MaterialColor obj) {
    writer.writeInt(obj.value);
  }
}

class ColorAdapter extends TypeAdapter<Color> {
  @override
  final typeId = 4;

  @override
  Color read(BinaryReader reader) {
    return Color(reader.readUint32());
  }

  @override
  void write(BinaryWriter writer, Color obj) {
    writer.writeUint32(obj.value);
  }
}

@HiveType(typeId: 5)
class ThreadUserData {
  @HiveField(0)
  final int tid;

  @HiveField(1)
  final String replyCookieName;

  ThreadUserData({
    required this.tid,
    required this.replyCookieName,
  });

  ThreadUserData copyWith({
    int? tid,
    String? replyCookieName,
  }) {
    return ThreadUserData(
      tid: tid ?? this.tid,
      replyCookieName: replyCookieName ?? this.replyCookieName,
    );
  }
}

class MyAppState with ChangeNotifier {
  final _store = PersistentKVStore<int, LightDaoSetting>('SettingsProvider');
  late LightDaoSetting setting;
  Map<int, Forum> forumMap = {};
  SimpleStatus fetchTimelinesStatus = SimpleStatus.completed;
  SimpleStatus fetchForumsStatus = SimpleStatus.completed;

  void setState(void Function(MyAppState state) fun) async {
    fun(this);
    notifyListeners();
    await saveSettings();
  }

  Future<void> exportSettingToFile(String filePath) async {
    await _store.exportToFile(filePath);
  }

  Future<void> importSettingFromFile(String filePath) async {
    await _store.importFromFile(filePath);
    loadSettings();
  }

  void updateForumMap(List<ForumList> forumLists) {
    forumMap = {
      for (var forum in forumLists.expand((forumList) => forumList.forums))
        forum.id: forum
    };
    notifyListeners();
  }

  String? getCurrentCookie() {
    return setting.cookies
        .safeElementAtOrNull(setting.currentCookie)
        ?.cookieHash;
  }

  bool isStared(int threadId) {
    return setting.starHistory.any((rply) => rply.threadId == threadId);
  }

  void tryFetchTimelines(
      GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey) {
    if (setting.cacheTimelines.isEmpty &&
        fetchTimelinesStatus != SimpleStatus.loading) {
      fetchTimelinesStatus = SimpleStatus.loading;
      fetchTimelines()
          .timeout(Duration(seconds: 5))
          .then((timelines) => setState((_) async {
                fetchTimelinesStatus = SimpleStatus.completed;
                setting.cacheTimelines.addAll(timelines);
                notifyListeners();
                await saveSettings();
              }))
          .catchError((err) {
        fetchTimelinesStatus = SimpleStatus.error;
        notifyListeners();
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text('拉取时间线错误： ${err.toString()}'),
              action: SnackBarAction(
                label: '重试',
                onPressed: () => tryFetchTimelines(scaffoldMessengerKey),
              )),
        );
      });
    }
  }

  void tryFetchForumLists(
      GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey) {
    if (setting.cacheForumLists.isEmpty &&
        fetchForumsStatus != SimpleStatus.loading) {
      fetchForumsStatus = SimpleStatus.loading;
      fetchForumList()
          .timeout(Duration(seconds: 5))
          .then((forumlists) => setState((_) async {
                fetchForumsStatus = SimpleStatus.completed;
                setting.cacheForumLists.addAll(forumlists);
                forumMap = {
                  for (var forum
                      in forumlists.expand((forumList) => forumList.forums))
                    forum.id: forum
                };
                notifyListeners();
                await saveSettings();
              }))
          .catchError((err) {
        fetchForumsStatus = SimpleStatus.completed;
        notifyListeners();
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
              content: Text('拉取板块错误： ${err.toString()}'),
              action: SnackBarAction(
                label: '重试',
                onPressed: () => tryFetchForumLists(scaffoldMessengerKey),
              )),
        );
      });
    } else if (forumMap.isEmpty &&
        fetchForumsStatus == SimpleStatus.completed) {
      forumMap = {
        for (var forum
            in setting.cacheForumLists.expand((forumList) => forumList.forums))
          forum.id: forum
      };
      notifyListeners();
    }
  }

  /// 过滤时间线线程，返回是否过滤以及过滤类型
  (bool, ThreadFilter?) filterTimeLineThread(ReplyJson reply) {
    for (var filter in setting.threadFilters) {
      if (filter.filter(reply)) {
        return (true, filter);
      }
    }
    return (false, null);
  }

  /// 过滤普通回复，忽略 ForumThreadFilter
  (bool, ThreadFilter?) filterCommonReply(ReplyJson reply) {
    for (var filter in setting.threadFilters) {
      if (filter is! ForumThreadFilter && filter.filter(reply)) {
        return (true, filter);
      }
    }
    return (false, null);
  }

  void removeFilter(ThreadFilter filterToRemove) {
    setting.threadFilters.removeWhere((filter) {
      if (filter is ForumThreadFilter && filterToRemove is ForumThreadFilter) {
        saveSettings();
        notifyListeners();
        return filter.fid == filterToRemove.fid;
      } else if (filter is IdThreadFilter && filterToRemove is IdThreadFilter) {
        saveSettings();
        notifyListeners();
        return filter.id == filterToRemove.id;
      } else if (filter is UserHashFilter && filterToRemove is UserHashFilter) {
        saveSettings();
        notifyListeners();
        return filter.userHash == filterToRemove.userHash;
      }
      return false;
    });
  }

  Future<void> loadSettings() async {
    final tmpsetting = await _store.get(0);
    setting = tmpsetting ??
        LightDaoSetting(
          cookies: [],
          currentCookie: -1,
          refCollapsing: 2,
          refPoping: 3,
          followedSysDarkMode: true,
          userSettingIsDarkMode: false,
          isCardView: true,
          collapsedLen: 100,
          lightModeThemeColor: Color.fromARGB(255, 241, 98, 100),
          darkModeThemeColor: Color.fromARGB(255, 241, 98, 100),
          dynamicThemeColor: false,
          viewHistory: LRUCache<int, ReplyJsonWithPage>(5000),
          replyHistory: [],
          starHistory: [],
          lightModeCustomThemeColor: Color.fromARGB(255, 96, 125, 138),
          darkModeCustomThemeColor: Color.fromARGB(255, 96, 125, 138),
          threadUserData: {},
          selectIcon: 0,
          feedUuid: '',
          useAmoledBlack: false,
          fontSizeFactor: 1.0,
          dividerBetweenReply: false,
          cacheTimelines: [],
          cacheForumLists: [],
          fixedBottomBar: false,
          displayExactTime: false,
          favoredForums: [],
          threadFilters: [],
          latestTrend: null,
          dragToDissmissImage: true,
          dontShowFilttedForumInTimeLine: true,
          phrases: [],
          enableSwipeBack: false,
          initForumOrTimelineId: 1,
          initIsTimeline: true,
          initForumOrTimelineName: '综合线',
          predictiveBack: false,
          columnWidth: 445,
          isMultiColumn: true,
        );
    setting.phrases = mergePhraseLists(setting.phrases, xDaoPhrases);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    return _store.put(0, setting);
  }

  Future<void> navigateThreadPage2(
      BuildContext context, int threadId, bool popIfFinish,
      {ThreadJson? thread, bool? fullThread}) async {
    final threadHistory = setting.viewHistory.get(threadId);
    pageRoute({
      required Widget Function(BuildContext) builder,
    }) {
      if (setting.enableSwipeBack) {
        return SwipeablePageRoute(builder: builder);
      } else {
        return MaterialPageRoute(builder: builder);
      }
    }

    if (threadHistory != null) {
      if (popIfFinish) Navigator.pop(context);
      Navigator.push(
        context,
        pageRoute(
          builder: (context) => ThreadPage2(
            headerThread: ThreadJson.fromReplyJson(threadHistory.thread, []),
            startPage: threadHistory.page,
            startReplyId: threadHistory.reply.id,
          ),
        ),
      );
    } else if (thread != null) {
      if (popIfFinish) Navigator.pop(context);
      Navigator.push(
        context,
        pageRoute(
          builder: (context) => ThreadPage2(
            headerThread: thread,
            startPage: 1,
            isCompletePage: fullThread ?? false,
          ),
        ),
      );
    } else {
      context.loaderOverlay.show();
      final thread = getThread(threadId, 1, getCurrentCookie());
      thread.then((thread) {
        if (popIfFinish) Navigator.pop(context);
        context.loaderOverlay.hide();
        Navigator.push(
          context,
          pageRoute(
            builder: (context) => ThreadPage2(
              headerThread: thread,
              startPage: 1,
              isCompletePage: true,
            ),
          ),
        );
      }).catchError((error) {
        if (popIfFinish) Navigator.pop(context);
        context.loaderOverlay.hide();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString()),
        ));
      });
    }
  }
}

extension SafeElementAtOrNull<E> on List<E> {
  E? safeElementAtOrNull(int index) {
    if (index < 0 || index >= length) {
      return null;
    }
    return this[index];
  }
}
