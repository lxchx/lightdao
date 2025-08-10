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

  String result;
  if (now.difference(time).inSeconds < 60) {
    result = '${now.difference(time).inSeconds}秒前';
  } else if (now.difference(time).inMinutes < 60) {
    result = '${now.difference(time).inMinutes}分钟前';
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
