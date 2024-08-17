import 'package:hive/hive.dart';
import 'package:lightdao/data/xdao/feed_info.dart';
import 'package:lightdao/data/xdao/post.dart';

class ReplyJson {
  final int id; // 回复id
  final int fid; // 版面id
  final int replyCount; // 回复数量
  final String img; // 图片相对地址
  final String ext; // 图片扩展名
  final String now; // 发串时间，格式：2022-06-18(六)05:10:29
  final String userHash; // 发串的饼干或红名名称
  final String name; // 一般是“无名氏”的名称
  final String title; // 一般是“无标题”的标题
  final String content; // 串的内容，使用 HTML
  final bool sage; // 是否被 SAGE
  final bool admin; // 是否为红名小会员
  final bool hide; // 隐藏状态

  ReplyJson({
    required this.id,
    required this.fid,
    required this.replyCount,
    required this.img,
    required this.ext,
    required this.now,
    required this.userHash,
    required this.name,
    required this.title,
    required this.content,
    required this.sage,
    required this.admin,
    required this.hide,
  });

  factory ReplyJson.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('id') &&
        json.containsKey('img') &&
        json.containsKey('ext') &&
        json.containsKey('now') &&
        json.containsKey('user_hash') &&
        json.containsKey('name') &&
        json.containsKey('content') &&
        json.containsKey('admin')) {
      return ReplyJson(
        id: json['id'] as int,
        fid: json['fid'] as int? ?? -1,
        replyCount: json['ReplyCount'] as int? ?? -1,
        img: json['img'] as String,
        ext: json['ext'] as String,
        now: json['now'] as String,
        userHash: json['user_hash'] as String,
        name: json['name'] as String,
        title: json['title'] as String? ?? '无标题',
        content: json['content'] as String,
        sage: (json['sage'] as int? ?? 0) != 0,
        admin: json['admin'] as int != 0,
        hide: (json['Hide'] as int? ?? 0) != 0,
      );
    } else {
      throw ArgumentError('Invalid JSON format');
    }
  }

  factory ReplyJson.fromPost(Post post) {
    return ReplyJson(
      id: post.id,
      fid: post.resto,
      replyCount: 0,
      img: '',
      ext: '',
      now: post.now,
      userHash: post.userHash,
      name: post.name == '' ? '无名氏' : post.name,
      title: post.title == '' ? '无标题' : post.title,
      content: post.content,
      sage: post.sage,
      admin: post.admin,
      hide: false,
    );
  }

  factory ReplyJson.fromFeedInfo(FeedInfo feedInfo) {
    return ReplyJson(
      id: int.parse(feedInfo.id),
      fid: int.parse(feedInfo.fid),
      replyCount: int.parse(feedInfo.replyCount),
      img: feedInfo.img,
      ext: feedInfo.ext,
      now: feedInfo.now,
      userHash: feedInfo.userHash,
      name: feedInfo.name == '' ? '无名氏' : feedInfo.name,
      title: feedInfo.title == '' ? '无标题' : feedInfo.title,
      content: feedInfo.content,
      sage: false,
      admin: feedInfo.admin == '1',
      hide: feedInfo.hide == '1',
    );
  }
}

class ReplyJsonAdapter extends TypeAdapter<ReplyJson> {
  @override
  final int typeId = 7;

  @override
  ReplyJson read(BinaryReader reader) {
    return ReplyJson(
      id: reader.readInt(),
      fid: reader.readInt(),
      replyCount: reader.readInt(),
      img: reader.readString(),
      ext: reader.readString(),
      now: reader.readString(),
      userHash: reader.readString(),
      name: reader.readString(),
      title: reader.readString(),
      content: reader.readString(),
      sage: reader.readBool(),
      admin: reader.readBool(),
      hide: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, ReplyJson obj) {
    writer.writeInt(obj.id);
    writer.writeInt(obj.fid);
    writer.writeInt(obj.replyCount);
    writer.writeString(obj.img);
    writer.writeString(obj.ext);
    writer.writeString(obj.now);
    writer.writeString(obj.userHash);
    writer.writeString(obj.name);
    writer.writeString(obj.title);
    writer.writeString(obj.content);
    writer.writeBool(obj.sage);
    writer.writeBool(obj.admin);
    writer.writeBool(obj.hide);
  }
}
