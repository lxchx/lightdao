import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lightdao/utils/time_parse.dart';

void main() {
  group('parseJsonTimeStr', () {
    test('should return "几秒前" for very recent timestamps', () {
      String nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      expect(parseJsonTimeStr(nowStr), '0秒前');
    });
    test('should return "几分钟前" for timestamps within the last hour', () {
      String minutesAgoStr = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.now().subtract(Duration(minutes: 30)));
      expect(parseJsonTimeStr(minutesAgoStr), '30分钟前');
    });
    test('should return "今天 时:分" for timestamps today', () {
      String hoursAgoStr = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.now().subtract(Duration(hours: 5)));
      expect(parseJsonTimeStr(hoursAgoStr), matches(RegExp(r'今天 \d{2}:\d{2}')));
    });
    test(
        'should return "几小时前" for timestamps within the last 24 hours but not today',
        () {
      String yesterdayStr = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.now().subtract(Duration(hours: 23)));
      expect(parseJsonTimeStr(yesterdayStr), '23小时前');
    });
    test(
        'should return "MM-DD 时:分" for timestamps within the same year but not today',
        () {
      String pastMonthStr = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.now().subtract(Duration(days: 30)));
      expect(parseJsonTimeStr(pastMonthStr),
          matches(RegExp(r'\d{2}-\d{2} \d{2}:\d{2}')));
    });
    test('should return "yyyy-MM-DD" for timestamps from previous years', () {
      String pastYearStr = '2022-11-01 12:00:00';
      expect(parseJsonTimeStr(pastYearStr), '2022-11-01');
    });
    test('should return "yyyy-MM-DD" for timestamps from previous years', () {
      String pastYearStr = '2024-11-13(三)23:58:53';
      print(parseJsonTimeStr(pastYearStr));
    });
  });
}
