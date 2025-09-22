import 'dart:convert';

import 'package:lightdao/data/xdao/reply.dart';

class FeedInfo {
  final String id;
  final String userId;
  final String fid;
  final String replyCount;
  final List<int> recentReplies;
  final String category;
  final String fileId;
  final String img;
  final String ext;
  final String now;
  final String userHash;
  final String name;
  final String email;
  final String title;
  final String content;
  final String status;
  final String admin;
  final String hide;
  final String po;
  FeedInfo({
    required this.id,
    required this.userId,
    required this.fid,
    required this.replyCount,
    required this.recentReplies,
    required this.category,
    required this.fileId,
    required this.img,
    required this.ext,
    required this.now,
    required this.userHash,
    required this.name,
    required this.email,
    required this.title,
    required this.content,
    required this.status,
    required this.admin,
    required this.hide,
    required this.po,
  });
  factory FeedInfo.fromJson(Map<String, dynamic> json) {
    return FeedInfo(
      id: json['id'],
      userId: json['user_id'] ?? '',
      fid: json['fid'],
      replyCount: json['reply_count'] ?? '0',
      recentReplies: json['recent_replies'] != null
          ? (jsonDecode(json['recent_replies']) as List<dynamic>)
                .map((e) => int.parse(e.toString()))
                .toList()
          : [],
      category: json['category'] ?? '',
      fileId: json['file_id'] ?? '',
      img: json['img'],
      ext: json['ext'],
      now: json['now'],
      userHash: json['user_hash'],
      name: json['name'],
      email: json['email'],
      title: json['title'],
      content: json['content'],
      status: json['status'] ?? '',
      admin: json['admin'] ?? '0',
      hide: json['hide'] ?? '0',
      po: json['po'] ?? '',
    );
  }
  factory FeedInfo.fromReplyJson(ReplyJson reply) {
    return FeedInfo(
      id: reply.id.toString(),
      userId: '',
      fid: reply.fid.toString(),
      replyCount: reply.replyCount.toString(),
      recentReplies: [],
      category: '',
      fileId: '',
      img: reply.img,
      ext: reply.ext,
      now: reply.now,
      userHash: reply.userHash,
      name: reply.name,
      email: '',
      title: reply.title,
      content: reply.content,
      status: '',
      admin: reply.admin ? '1' : '0',
      hide: reply.hide ? '1' : '0',
      po: '',
    );
  }
}
