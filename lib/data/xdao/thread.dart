import 'package:lightdao/data/xdao/ref.dart';

import 'reply.dart';

class ThreadJson extends ReplyJson {
  final List<ReplyJson> replies; // 回复列表

  ThreadJson({
    required super.id,
    required super.fid,
    required super.replyCount,
    required super.img,
    required super.ext,
    required super.now,
    required super.userHash,
    required super.name,
    required super.title,
    required super.content,
    required super.sage,
    required super.admin,
    required super.hide,
    required this.replies,
  });

  factory ThreadJson.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('id') &&
        json.containsKey('fid') &&
        json.containsKey('ReplyCount') &&
        json.containsKey('img') &&
        json.containsKey('ext') &&
        json.containsKey('now') &&
        json.containsKey('user_hash') &&
        json.containsKey('name') &&
        json.containsKey('title') &&
        json.containsKey('content') &&
        json.containsKey('sage') &&
        json.containsKey('admin') &&
        json.containsKey('Hide') &&
        json.containsKey('Replies')) {
      return ThreadJson(
        id: json['id'] as int,
        fid: json['fid'] as int,
        replyCount: json['ReplyCount'] as int,
        img: json['img'] as String,
        ext: json['ext'] as String,
        now: json['now'] as String,
        userHash: json['user_hash'] as String,
        name: json['name'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        sage: json['sage'] as int != 0,
        admin: json['admin'] as int != 0,
        hide: json['Hide'] as int != 0,
        replies: (json['Replies'] as List)
            .map((reply) => ReplyJson.fromJson(reply))
            .toList(),
      );
    } else {
      throw ArgumentError('Invalid JSON format: $json');
    }
  }

  factory ThreadJson.fromReplyJson(ReplyJson reply, List<ReplyJson> replies) {
    return ThreadJson(
      id: reply.id,
      fid: reply.fid,
      replyCount: reply.replyCount,
      img: reply.img,
      ext: reply.ext,
      now: reply.now,
      userHash: reply.userHash,
      name: reply.name,
      title: reply.title,
      content: reply.content,
      sage: reply.sage,
      admin: reply.admin,
      hide: reply.hide,
      replies: replies,
    );
  }

  factory ThreadJson.fromRefHtml(RefHtml refHtml) {
    return ThreadJson(
      id: refHtml.id,
      fid: refHtml.fid,
      replyCount: refHtml.replyCount,
      img: refHtml.img,
      ext: refHtml.ext,
      now: refHtml.now,
      userHash: refHtml.userHash,
      name: refHtml.name,
      title: refHtml.title,
      content: refHtml.content,
      sage: refHtml.sage,
      admin: refHtml.admin,
      hide: refHtml.hide,
      replies: [], // 设置为空列表
    );
  }
}

final fakeThread = ThreadJson(
  admin: false,
  id: 11111111,
  fid: 1,
  replyCount: 0,
  img: '',
  ext: '',
  now: '2022-06-18(六)05:10:29',
  userHash: 'maybeYou',
  name: '无名氏',
  title: '无标题',
  content:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaa<br>bbbbbbbbbbbbbbbbbbbbbb<br>cccccvvvvvvvvvvvvcccccc',
  sage: false,
  hide: false,
  replies: [],
);
