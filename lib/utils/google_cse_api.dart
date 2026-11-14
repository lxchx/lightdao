import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lightdao/data/third_party_consent.dart';

/// 搜索请求用的 HTTP 客户端。
///
/// 单独留一个可替换的实例，测试里换成假客户端就能断言「有没有发请求」，
/// 不用真的连 www.googleapis.com。
http.Client searchHttpClient = http.Client();

/// 单条搜索结果
class GcseItem {
  final String title;
  final String link;
  final String htmlSnippet;
  final String? imageUrl;

  GcseItem({
    required this.title,
    required this.link,
    required this.htmlSnippet,
    this.imageUrl,
  });

  factory GcseItem.fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    // 尝试从 pagemap.cse_image[0].src 获取图片
    if (json['pagemap'] != null &&
        json['pagemap']['cse_image'] != null &&
        json['pagemap']['cse_image'] is List &&
        json['pagemap']['cse_image'].isNotEmpty) {
      imageUrl = json['pagemap']['cse_image'][0]['src'];
    }
    return GcseItem(
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      htmlSnippet: json['htmlSnippet'] ?? '',
      imageUrl: imageUrl,
    );
  }
}

/// 搜索结果
class GcseSearchResult {
  final int totalResults;
  final int nextStartIndex;
  final List<GcseItem> items;

  GcseSearchResult({
    required this.totalResults,
    required this.nextStartIndex,
    required this.items,
  });

  factory GcseSearchResult.fromJson(Map<String, dynamic> json) {
    int total = 0;
    int nextStart = -1;
    List<GcseItem> items = [];

    // 解析 totalResults
    if (json['searchInformation'] != null &&
        json['searchInformation']['totalResults'] != null) {
      total =
          int.tryParse(json['searchInformation']['totalResults'].toString()) ??
          0;
    }

    // 解析 nextPage 的 startIndex
    if (json['queries'] != null &&
        json['queries']['nextPage'] != null &&
        json['queries']['nextPage'] is List &&
        json['queries']['nextPage'].isNotEmpty) {
      nextStart = json['queries']['nextPage'][0]['startIndex'] ?? -1;
    }

    // 解析 items
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .map((e) => GcseItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return GcseSearchResult(
      totalResults: total,
      nextStartIndex: nextStart,
      items: items,
    );
  }
}

/// 调用 Google CSE API
///
/// [allowed] 是第三方服务的同意结果（见 [resolveSearchAllowed]）：
/// 没同意就直接抛 [ThirdPartyConsentRequiredException]，一个字节都不发出去。
/// 放在这一层而不是只放在界面上，是为了任何调用路径都发不出请求。
///
/// 只发搜索关键词、客户端内置的搜索引擎编号与密钥、页码，
/// 不带饼干、userhash 或任何登录信息。
Future<GcseSearchResult> googleCseSearch({
  required String q,
  required bool allowed,
  String cx = 'a72793f0a2020430b',
  String key = 'AIzaSyD2OeVt3FHS98PqRzynqcKnCRzc47igpbM',
  int? start,
  http.Client? client,
}) async {
  if (!allowed) {
    throw const ThirdPartyConsentRequiredException('串搜索');
  }

  final params = {'q': q, 'cx': cx, 'key': key, 'num': '10'};
  if (start != null) {
    params['start'] = start.toString();
  }

  final uri = Uri.https('www.googleapis.com', '/customsearch/v1', params);

  final response = await (client ?? searchHttpClient).get(uri);
  if (response.statusCode == 200) {
    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    return GcseSearchResult.fromJson(jsonMap);
  } else {
    throw Exception(
      'Google CSE API error: ${response.statusCode} ${response.body}',
    );
  }
}
