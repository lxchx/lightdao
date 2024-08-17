import 'package:hive/hive.dart';

part 'forum.g.dart';

@HiveType(typeId: 10)
class Forum extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int fgroup;

  @HiveField(2)
  final int sort;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String showName;

  @HiveField(5)
  final String msg;

  @HiveField(6)
  final int interval;

  @HiveField(7)
  final int safeMode;

  @HiveField(8)
  final int autoDelete;

  @HiveField(9)
  final int threadCount;

  @HiveField(10)
  final int permissionLevel;

  @HiveField(11)
  final int forumFuseId;

  @HiveField(12)
  final String createdAt;

  @HiveField(13)
  final String updatedAt;

  @HiveField(14)
  final String status;

  Forum({
    required this.id,
    required this.fgroup,
    required this.sort,
    required this.name,
    required this.showName,
    required this.msg,
    required this.interval,
    required this.safeMode,
    required this.autoDelete,
    required this.threadCount,
    required this.permissionLevel,
    required this.forumFuseId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  String getShowName() {
    return showName.isEmpty ? name : showName;
  }

  factory Forum.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('id') &&
        json.containsKey('fgroup') &&
        json.containsKey('sort') &&
        json.containsKey('name') &&
        json.containsKey('showName') &&
        json.containsKey('msg') &&
        json.containsKey('interval') &&
        json.containsKey('safe_mode') &&
        json.containsKey('auto_delete') &&
        json.containsKey('thread_count') &&
        json.containsKey('permission_level') &&
        json.containsKey('forum_fuse_id') &&
        json.containsKey('createdAt') &&
        json.containsKey('updateAt') &&
        json.containsKey('status')) {
      return Forum(
        id: int.parse(json['id']),
        fgroup: int.parse(json['fgroup']),
        sort: int.parse(json['sort']),
        name: json['name'],
        showName: json['showName'],
        msg: json['msg'],
        interval: int.parse(json['interval']),
        safeMode: int.parse(json['safe_mode']),
        autoDelete: int.parse(json['auto_delete']),
        threadCount: int.parse(json['thread_count']),
        permissionLevel: int.parse(json['permission_level']),
        forumFuseId: int.parse(json['forum_fuse_id']),
        createdAt: json['createdAt'],
        updatedAt: json['updateAt'],
        status: json['status'],
      );
    } else {
      throw ArgumentError('Invalid JSON format for Forum');
    }
  }
}

@HiveType(typeId: 11)
class ForumList extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int sort;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String status;

  @HiveField(4)
  final List<Forum> forums;

  ForumList({
    required this.id,
    required this.sort,
    required this.name,
    required this.status,
    required this.forums,
  });

  factory ForumList.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('id') &&
        json.containsKey('sort') &&
        json.containsKey('name') &&
        json.containsKey('status') &&
        json.containsKey('forums')) {
      var forumsFromJson = json['forums'] as List;
      List<Forum> forumList = forumsFromJson
          .where((forum) => forum.containsKey('name') && forum['name'] != '时间线')
          .map((forum) => Forum.fromJson(forum))
          .toList();

      return ForumList(
        id: int.parse(json['id']),
        sort: int.parse(json['sort']),
        name: json['name'],
        status: json['status'],
        forums: forumList,
      );
    } else {
      throw ArgumentError('Invalid JSON format for ForumList');
    }
  }
}
