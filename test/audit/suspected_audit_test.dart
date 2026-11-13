// 审计用例：审计报告「疑似问题」一节的纯函数级测试。
//
// 对应 flutter-scroll/dist/lightdao-bugs-20261113.md 的疑似 #4 / #6 / #8 /
// #9 / #10 / #11 / #12。运行：flutter test test/audit/suspected_audit_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/ui/page/more/cookies_management.dart';
import 'package:lightdao/ui/page/more/setting.dart';
import 'package:lightdao/ui/page/thread2.dart';
import 'package:lightdao/utils/xdao_api.dart';

/// 一份最小的合法串页响应（字段名与服务端一致）。
String threadJsonString({int replyCount = 418}) {
  return '{"id":62389876,"fid":4,"ReplyCount":$replyCount,"img":"","ext":"",'
      '"now":"2026-11-13(四)10:00:00","user_hash":"tips","name":"无名氏",'
      '"title":"无标题","content":"串内容","sage":0,"admin":0,"Hide":0,'
      '"Replies":[]}';
}

void main() {
  group('疑似#4 仅看Po模式跳页要用 Po 的 manager', () {
    test('Po 模式下跳页 manager 必须带 isPoOnly', () {
      final manager = buildJumpTargetPageManager(
        threadId: 63452788,
        page: 5,
        cookie: 'hashA',
        poOnly: true,
      );

      expect(manager.isPoOnly, isTrue, reason: '否则跳过去拿到的是整串回复');
      expect(manager.initialPage, 5);
      expect(manager.threadId, 63452788);
    });

    test('普通模式的跳页 manager 不带 isPoOnly', () {
      final manager = buildJumpTargetPageManager(
        threadId: 1,
        page: 2,
        cookie: null,
        poOnly: false,
      );

      expect(manager.isPoOnly, isFalse);
      expect(manager.initialPage, 2);
    });
  });
  group('疑似#6 getThread 的页码校验', () {
    test('page <= 0 时抛 ArgumentError（不发请求）', () async {
      await expectLater(
        () => getThread(63452788, 0, null),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => getThread(63452788, -1, null),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => getThreadPoOnly(63452788, 0, null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
  group('疑似#8 坏缓存不应让该页永远打不开', () {
    test('缓存解析函数：合法内容正常解析', () {
      final thread = parseThreadJsonBody(threadJsonString());
      expect(thread.id, 62389876);
      expect(thread.replyCount, 418);
      expect(thread.replies, isEmpty);
    });

    test('缓存解析函数：坏内容会抛，调用方据此删缓存回源', () {
      // 半截 JSON / 网关 HTML 错误页
      expect(
        () => parseThreadJsonBody('<html>502 Bad Gateway</html>'),
        throwsA(isA<XDaoApiMsgException>()),
      );
      // 服务端错误 JSON
      expect(
        () => parseThreadJsonBody('{"success":false,"error":"必须登入领取饼干"}'),
        throwsA(isA<XDaoApiNotSuccussException>()),
      );
      // 结构对但缺字段
      expect(
        () => parseThreadJsonBody('{"id":1}'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
  group('疑似#9 订阅接口的成功判定不应抛 FormatException', () {
    test('JSON 字符串 / 裸文本都能判定成功', () {
      expect(responseSaysSuccess('"订阅大成功→_→"', '订阅大成功→_→'), isTrue);
      expect(responseSaysSuccess('订阅大成功→_→', '订阅大成功→_→'), isTrue);
      expect(responseSaysSuccess('  订阅大成功→_→ ', '订阅大成功→_→'), isTrue);
      expect(responseSaysSuccess('"取消订阅成功!"', '取消订阅成功!'), isTrue);
    });

    test('别的文案判定为失败，且不抛异常', () {
      expect(responseSaysSuccess('"订阅失败"', '订阅大成功→_→'), isFalse);
      expect(
        responseSaysSuccess('<html>502 Bad Gateway</html>', '订阅大成功→_→'),
        isFalse,
      );
      expect(responseSaysSuccess('', '订阅大成功→_→'), isFalse);
    });
  });
  group('疑似#10 二维码相册分支：解析失败不该抛未捕获异常', () {
    test('合法二维码内容解析出 (name, cookie)', () {
      final parsed = parseCookieQrCode(
        '{"name":"my phone","cookie":"AbCdEf1234567890"}',
      );
      expect(parsed, ('my phone', 'AbCdEf1234567890'));
    });

    test('非 JSON / 缺字段 / 空内容都返回 null（调用方提示"无效的二维码格式"）', () {
      expect(parseCookieQrCode(null), isNull);
      expect(parseCookieQrCode(''), isNull);
      expect(parseCookieQrCode('   '), isNull, reason: '取消选图后拿到的是空串');
      expect(parseCookieQrCode('https://nmb.best'), isNull);
      expect(parseCookieQrCode('{"name":"x"}'), isNull);
      expect(parseCookieQrCode('{"cookie":"y"}'), isNull);
      expect(parseCookieQrCode('{"name":"","cookie":"y"}'), isNull);
      expect(parseCookieQrCode('[1,2,3]'), isNull);
    });
  });
  group('疑似#12 拉取超时不接受小于 1 的值', () {
    test('合法输入原样返回', () {
      expect(parseFetchTimeoutSeconds('10'), 10);
      expect(parseFetchTimeoutSeconds(' 1 '), 1);
      expect(parseFetchTimeoutSeconds('600'), 600, reason: '不设上限');
    });

    test('0 / 负数 / 非数字都拒绝写入', () {
      expect(parseFetchTimeoutSeconds('0'), isNull);
      expect(parseFetchTimeoutSeconds('-5'), isNull);
      expect(parseFetchTimeoutSeconds(''), isNull);
      expect(parseFetchTimeoutSeconds('abc'), isNull);
      expect(parseFetchTimeoutSeconds('1.5'), isNull);
    });
  });
}
