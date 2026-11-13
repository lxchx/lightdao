import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/utils/time_parse.dart';

// 这些用例把「现在」钉死，所以跑测试那台机器是几点、在哪个时区，都不影响
// 结果；同一个输入永远得到同一个字符串。
//
// 「现在」给的是一个真实时刻（UTC），被测代码内部会换算成东八区墙上时间，
// 也就是 2026-11-14 15:00:00——服务端时间串用的就是这个口径。
void main() {
  final DateTime now = DateTime.utc(2026, 11, 14, 7); // 东八区 2026-11-14 15:00

  group('parseJsonTimeStr', () {
    test('一分钟以内显示秒', () {
      expect(parseJsonTimeStr('2026-11-14 15:00:00', now: now), '0秒前');
      expect(parseJsonTimeStr('2026-11-14 14:59:30', now: now), '30秒前');
    });

    test('服务器时钟比本机快时不显示负数', () {
      // 服务端时间比「现在」还晚 5 秒，差值要夹到 0。
      expect(parseJsonTimeStr('2026-11-14 15:00:05', now: now), '0秒前');
    });

    test('一小时以内显示分钟', () {
      expect(parseJsonTimeStr('2026-11-14 14:30:00', now: now), '30分钟前');
      expect(parseJsonTimeStr('2026-11-14 14:01:00', now: now), '59分钟前');
    });

    test('今天更早的时间显示「今天 时:分」', () {
      expect(parseJsonTimeStr('2026-11-14 10:00:00', now: now), '今天 10:00');
      expect(parseJsonTimeStr('2026-11-14 00:30:00', now: now), '今天 00:30');
    });

    test('昨天的时间显示「昨天 时:分」', () {
      expect(parseJsonTimeStr('2026-11-13 20:00:00', now: now), '昨天 20:00');
    });

    test('前天的时间显示「前天 时:分」', () {
      expect(parseJsonTimeStr('2026-11-12 20:00:00', now: now), '前天 20:00');
    });

    test('今年更早的日期显示「月-日 时:分」', () {
      expect(parseJsonTimeStr('2026-10-15 09:05:00', now: now), '10-15 09:05');
    });

    test('往年的日期显示「年-月-日 时:分」', () {
      expect(
        parseJsonTimeStr('2022-11-01 12:00:00', now: now),
        '2022-11-01 12:00',
      );
    });

    test('带星期后缀的时间串也能解析', () {
      // 服务端串里会夹一个「(三)」，解析前要先去掉。
      expect(
        parseJsonTimeStr('2024-11-13(三)23:58:53', now: now),
        '2024-11-13 23:58',
      );
    });

    test('displayExactTime 时直接给完整时间，不做相对换算', () {
      expect(
        parseJsonTimeStr(
          '2026-11-14 10:00:00',
          now: now,
          displayExactTime: true,
        ),
        '2026/11/14 10:00',
      );
    });
  });
}
