import 'package:hive/hive.dart';
import 'package:lightdao/data/xdao/reply.dart';

part 'trend_data.g.dart';

@HiveType(typeId: 15)
class TrendData extends HiveObject {
  @HiveField(0)
  final DateTime fetchTime;

  @HiveField(1)
  final ReplyJson reply;

  TrendData({required this.fetchTime, required this.reply});
}
