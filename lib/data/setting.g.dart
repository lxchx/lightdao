// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CookieSettingAdapter extends TypeAdapter<CookieSetting> {
  @override
  final int typeId = 0;

  @override
  CookieSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CookieSetting(
      cookieHash: fields[0] as String,
      name: fields[1] as String,
      displayName: fields[2] == null ? '' : fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CookieSetting obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.cookieHash)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.displayName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookieSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FavoredItemAdapter extends TypeAdapter<FavoredItem> {
  @override
  final int typeId = 18;

  @override
  FavoredItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoredItem(
      id: fields[0] as int,
      type: fields[1] as FavoredItemType,
    );
  }

  @override
  void write(BinaryWriter writer, FavoredItem obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoredItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LightDaoSettingAdapter extends TypeAdapter<LightDaoSetting> {
  @override
  final int typeId = 1;

  @override
  LightDaoSetting read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LightDaoSetting(
      cookies: fields[0] == null
          ? []
          : (fields[0] as List).cast<CookieSetting>(),
      currentCookie: fields[1] == null ? -1 : fields[1] as int,
      refCollapsing: fields[2] == null ? 3 : fields[2] as int,
      refPoping: fields[3] == null ? 3 : fields[3] as int,
      followedSysDarkMode: fields[4] == null ? true : fields[4] as bool,
      userSettingIsDarkMode: fields[5] == null ? false : fields[5] as bool,
      isCardView: fields[6] == null ? false : fields[6] as bool,
      collapsedLen: fields[7] == null ? 100 : fields[7] as int,
      lightModeThemeColor: fields[8] == null
          ? const Color.fromARGB(255, 241, 98, 100)
          : fields[8] as Color,
      darkModeThemeColor: fields[9] == null
          ? const Color.fromARGB(255, 241, 98, 100)
          : fields[9] as Color,
      dynamicThemeColor: fields[10] == null ? false : fields[10] as bool,
      viewHistory: fields[11] as LRUCache<int, ReplyJsonWithPage>?,
      replyHistory: fields[12] == null
          ? []
          : (fields[12] as List).cast<ReplyJsonWithPage>(),
      starHistory: fields[13] == null
          ? []
          : (fields[13] as List).cast<ReplyJsonWithPage>(),
      lightModeCustomThemeColor: fields[14] == null
          ? const Color.fromARGB(255, 96, 125, 138)
          : fields[14] as Color,
      darkModeCustomThemeColor: fields[15] == null
          ? const Color.fromARGB(255, 96, 125, 138)
          : fields[15] as Color,
      threadUserData: fields[16] == null
          ? {}
          : (fields[16] as Map).cast<int, ThreadUserData>(),
      selectIcon: fields[17] == null ? 0 : fields[17] as int,
      feedUuid: fields[18] == null ? '' : fields[18] as String,
      useAmoledBlack: fields[19] == null ? false : fields[19] as bool,
      fontSizeFactor: fields[20] == null ? 1.0 : fields[20] as double,
      dividerBetweenReply: fields[21] == null ? false : fields[21] as bool,
      cacheTimelines: fields[22] == null
          ? []
          : (fields[22] as List).cast<Timeline>(),
      cacheForumLists: fields[23] == null
          ? []
          : (fields[23] as List).cast<ForumList>(),
      fixedBottomBar: fields[24] == null ? false : fields[24] as bool,
      displayExactTime: fields[25] == null ? false : fields[25] as bool,
      favoredForums: fields[26] == null
          ? []
          : (fields[26] as List).cast<Forum>(),
      threadFilters: fields[27] == null
          ? []
          : (fields[27] as List).cast<ThreadFilter>(),
      latestTrend: fields[28] as TrendData?,
      dragToDissmissImage: fields[29] == null ? true : fields[29] as bool,
      dontShowFilttedForumInTimeLine: fields[30] == null
          ? true
          : fields[30] as bool,
      phrases: fields[31] == null ? [] : (fields[31] as List).cast<Phrase>(),
      enableSwipeBack: fields[32] == null ? false : fields[32] as bool,
      initForumOrTimelineId: fields[33] == null ? 1 : fields[33] as int,
      initIsTimeline: fields[34] == null ? true : fields[34] as bool,
      initForumOrTimelineName: fields[35] == null
          ? '综合线'
          : fields[35] as String,
      predictiveBack: fields[36] == null ? false : fields[36] as bool,
      columnWidth: fields[37] == null ? 445 : fields[37] as double,
      isMultiColumn: fields[38] == null ? true : fields[38] as bool,
      seenNoticeDate: fields[40] == null ? 0 : fields[40] as int,
      phraseWidth: fields[41] == null ? 175 : fields[41] as int,
      fetchTimeout: fields[42] == null ? 3 : fields[42] as int,
      favoredItems: fields[43] == null
          ? []
          : (fields[43] as List).cast<FavoredItem>(),
      forumFontSizeFactor: fields[44] == null ? 1.0 : fields[44] as double,
      checkUpdateOnLaunch: fields[45] == null ? true : fields[45] as bool,
      viewPoOnlyHistory: fields[39] as LRUCache<int, ReplyJsonWithPage>?,
    );
  }

  @override
  void write(BinaryWriter writer, LightDaoSetting obj) {
    writer
      ..writeByte(46)
      ..writeByte(0)
      ..write(obj.cookies)
      ..writeByte(1)
      ..write(obj.currentCookie)
      ..writeByte(2)
      ..write(obj.refCollapsing)
      ..writeByte(3)
      ..write(obj.refPoping)
      ..writeByte(4)
      ..write(obj.followedSysDarkMode)
      ..writeByte(5)
      ..write(obj.userSettingIsDarkMode)
      ..writeByte(6)
      ..write(obj.isCardView)
      ..writeByte(7)
      ..write(obj.collapsedLen)
      ..writeByte(8)
      ..write(obj.lightModeThemeColor)
      ..writeByte(9)
      ..write(obj.darkModeThemeColor)
      ..writeByte(10)
      ..write(obj.dynamicThemeColor)
      ..writeByte(11)
      ..write(obj.viewHistory)
      ..writeByte(12)
      ..write(obj.replyHistory)
      ..writeByte(13)
      ..write(obj.starHistory)
      ..writeByte(14)
      ..write(obj.lightModeCustomThemeColor)
      ..writeByte(15)
      ..write(obj.darkModeCustomThemeColor)
      ..writeByte(16)
      ..write(obj.threadUserData)
      ..writeByte(17)
      ..write(obj.selectIcon)
      ..writeByte(18)
      ..write(obj.feedUuid)
      ..writeByte(19)
      ..write(obj.useAmoledBlack)
      ..writeByte(20)
      ..write(obj.fontSizeFactor)
      ..writeByte(21)
      ..write(obj.dividerBetweenReply)
      ..writeByte(22)
      ..write(obj.cacheTimelines)
      ..writeByte(23)
      ..write(obj.cacheForumLists)
      ..writeByte(24)
      ..write(obj.fixedBottomBar)
      ..writeByte(25)
      ..write(obj.displayExactTime)
      ..writeByte(26)
      ..write(obj.favoredForums)
      ..writeByte(27)
      ..write(obj.threadFilters)
      ..writeByte(28)
      ..write(obj.latestTrend)
      ..writeByte(29)
      ..write(obj.dragToDissmissImage)
      ..writeByte(30)
      ..write(obj.dontShowFilttedForumInTimeLine)
      ..writeByte(31)
      ..write(obj.phrases)
      ..writeByte(32)
      ..write(obj.enableSwipeBack)
      ..writeByte(33)
      ..write(obj.initForumOrTimelineId)
      ..writeByte(34)
      ..write(obj.initIsTimeline)
      ..writeByte(35)
      ..write(obj.initForumOrTimelineName)
      ..writeByte(36)
      ..write(obj.predictiveBack)
      ..writeByte(37)
      ..write(obj.columnWidth)
      ..writeByte(38)
      ..write(obj.isMultiColumn)
      ..writeByte(39)
      ..write(obj.viewPoOnlyHistory)
      ..writeByte(40)
      ..write(obj.seenNoticeDate)
      ..writeByte(41)
      ..write(obj.phraseWidth)
      ..writeByte(42)
      ..write(obj.fetchTimeout)
      ..writeByte(43)
      ..write(obj.favoredItems)
      ..writeByte(44)
      ..write(obj.forumFontSizeFactor)
      ..writeByte(45)
      ..write(obj.checkUpdateOnLaunch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LightDaoSettingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ThreadUserDataAdapter extends TypeAdapter<ThreadUserData> {
  @override
  final int typeId = 5;

  @override
  ThreadUserData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ThreadUserData(
      tid: fields[0] as int,
      replyCookieName: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ThreadUserData obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.tid)
      ..writeByte(1)
      ..write(obj.replyCookieName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadUserDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FavoredItemTypeAdapter extends TypeAdapter<FavoredItemType> {
  @override
  final int typeId = 17;

  @override
  FavoredItemType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FavoredItemType.forum;
      case 1:
        return FavoredItemType.timeline;
      default:
        return FavoredItemType.forum;
    }
  }

  @override
  void write(BinaryWriter writer, FavoredItemType obj) {
    switch (obj) {
      case FavoredItemType.forum:
        writer.writeByte(0);
        break;
      case FavoredItemType.timeline:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoredItemTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
