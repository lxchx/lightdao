import 'package:lightdao/utils/xdao_api.dart';
import 'package:test/test.dart';

void main() {
  group('parseRefHtmlBody', () {
    test('错误页（必须登入领取饼干）抛出异常，不会被当成引用内容', () {
      const body = '''
<html><body><div class="system-message"><h1>:(</h1>
<p class="error">必须登入领取饼干后才可以访问</p>
<p class="detail"></p></div></body></html>''';
      expect(
        () => parseRefHtmlBody(body),
        throwsA(
          isA<XDaoApiNotSuccussException>().having(
            (e) => e.msg,
            'msg',
            contains('必须登入领取饼干'),
          ),
        ),
      );
    });

    test('正常引用页解析成功', () {
      const body = '''
<html><body><div class="h-threads-item">
<span class="h-threads-info-title">无标题</span>
<span class="h-threads-info-email">无名氏</span>
<span class="h-threads-info-createdat">2024-05-15(三)00:15:12</span>
<span class="h-threads-info-uid">ID:abcdefg</span>
<a href="/t/100?r=123" class="h-threads-info-id">No.123</a>
<div class="h-threads-content">正文</div>
</div></body></html>''';
      final ref = parseRefHtmlBody(body);
      expect(ref.id, 123);
      expect(ref.userHash, 'abcdefg');
      expect(ref.content.trim(), '正文');
    });
  });
}
