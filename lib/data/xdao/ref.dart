import 'reply.dart';
import 'package:html/dom.dart';

typedef RefJson = ReplyJson;

class RefHtml extends RefJson {
  final int threadId;

  RefHtml({
    required this.threadId,
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
  });

  factory RefHtml.fromReplyJson(ReplyJson replyJson) {
    return RefHtml(
      threadId: -1,
      id: replyJson.id,
      fid: replyJson.fid,
      replyCount: replyJson.replyCount,
      img: replyJson.img,
      ext: replyJson.ext,
      now: replyJson.now,
      userHash: replyJson.userHash,
      name: replyJson.name,
      title: replyJson.title,
      content: replyJson.content,
      sage: replyJson.sage,
      admin: replyJson.admin,
      hide: replyJson.hide,
    );
  }

  factory RefHtml.fromHtml(Document doc) {
    // 提取 href 属性并解析 threadId
    final href =
        doc.querySelector('.h-threads-info-id')?.attributes['href'] ?? '';
    int threadId = -1;
    // 判断 href 是否包含 '/t/{threadId}'
    final regex = RegExp(r'/t/(\d+)');
    final match = regex.firstMatch(href);
    if (match != null) {
      threadId = int.parse(match.group(1) ?? '-1');
    }
    final id = int.parse(
      doc.querySelector('.h-threads-info-id')?.text.replaceAll('No.', '') ??
          '0',
    );
    final title = doc.querySelector('.h-threads-info-title')?.text ?? '无标题';
    final name = doc.querySelector('.h-threads-info-email')?.text ?? '无名氏';
    final userHash =
        doc.querySelector('.h-threads-info-uid')?.text.substring(3) ?? '';
    final now = doc.querySelector('.h-threads-info-createdat')?.text ?? '';
    final content = doc.querySelector('.h-threads-content')?.innerHtml ?? '';
    final sage =
        doc.querySelector('.h-threads-tips')?.text.contains('SAGE') ?? false;

    // 判断是否为 Admin
    final adminElement =
        doc.querySelector('.h-threads-info-uid font[color="red"]');
    final admin = adminElement != null;

    // 提取图片链接
    final imageAnchor = doc.querySelector('.h-threads-img-a');
    final imgUrl = imageAnchor?.attributes['href'] ?? '';

    // 提取图片扩展名
    String img = '';
    String ext = '';
    if (imgUrl.isNotEmpty) {
      img = imgUrl.split('image/').last.split('.').first;
      ext = '.${imgUrl.split('.').last}';
    }

    return RefHtml(
      threadId: threadId,
      id: id,
      fid: -1,
      replyCount: -1,
      img: img,
      ext: ext,
      now: now,
      userHash: userHash,
      name: name,
      title: title,
      content: content,
      sage: sage,
      admin: admin,
      hide: false,
    );
  }
}
