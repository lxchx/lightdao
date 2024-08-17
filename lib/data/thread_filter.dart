import 'package:hive/hive.dart';
import 'package:lightdao/data/xdao/reply.dart';

part 'thread_filter.g.dart';

/// 基类：ThreadFilter
abstract class ThreadFilter extends HiveObject {
  /// 判断一个线程是否被过滤
  bool filter(ReplyJson reply);
}

/// ForumThreadFilter：通过 fid 过滤
@HiveType(typeId: 12)
class ForumThreadFilter extends ThreadFilter {
  @HiveField(0)
  final int fid;

  ForumThreadFilter({required this.fid});

  @override
  bool filter(ReplyJson reply) {
    return reply.fid == fid;
  }
}

/// IdThreadFilter：通过 id 过滤
@HiveType(typeId: 13)
class IdThreadFilter extends ThreadFilter {
  @HiveField(0)
  final int id;

  IdThreadFilter({required this.id});

  @override
  bool filter(ReplyJson reply) {
    return reply.id == id;
  }
}

/// UserHashFilter：通过 userHash 过滤
@HiveType(typeId: 14)
class UserHashFilter extends ThreadFilter {
  @HiveField(0)
  final String userHash;

  UserHashFilter({required this.userHash});

  @override
  bool filter(ReplyJson reply) {
    return reply.userHash == userHash;
  }
}
