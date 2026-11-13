import 'dart:math';

import 'package:intl/intl.dart';

DateTime replyTimeToDateTime(String timeStr) {
  String cleanedTimeStr = timeStr.replaceAll(RegExp(r'\(.*?\)'), ' ');
  return DateFormat('yyyy-MM-dd HH:mm:ss').parseUtc(cleanedTimeStr);
}

String parseJsonTimeStr(String timeStr, {bool displayExactTime = false}) {
  final time = replyTimeToDateTime(timeStr);

  if (displayExactTime) {
    return DateFormat('yyyy/MM/dd HH:mm').format(time);
  }

  // 用东八区时间
  DateTime now = DateTime.now().toUtc().add(Duration(hours: 8));
  DateTime todayStart = DateTime.utc(now.year, now.month, now.day);
  DateTime yesterdayStart = todayStart.subtract(Duration(days: 1));
  DateTime dayBeforeYesterdayStart = todayStart.subtract(Duration(days: 2));

  // 服务器时钟可能比本机快几秒（刚发出的回复、时钟有偏差时都会这样），
  // 差值要夹到 0，否则界面会出现 "-4秒前"。
  //
  // 只处理负数这一种情况；"今天 00:00:00 被算成昨天"是另一个边界，
  // 属于既有行为，本次不动。
  final diff = now.difference(time);

  String result;
  if (diff.inSeconds < 60) {
    result = '${max(0, diff.inSeconds)}秒前';
  } else if (diff.inMinutes < 60) {
    result = '${diff.inMinutes}分钟前';
  } else if (time.isAfter(todayStart)) {
    result =
        '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  } else if (time.isAfter(yesterdayStart)) {
    result =
        '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  } else if (time.isAfter(dayBeforeYesterdayStart)) {
    result =
        '前天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  } else if (now.year == time.year) {
    result =
        '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  } else {
    result =
        '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  return result;
}
