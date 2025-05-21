import 'dart:convert';
import 'package:http/http.dart' as http;

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
Future<GcseSearchResult> googleCseSearch({
  required String q,
  String cx = 'a72793f0a2020430b',
  String key = 'AIzaSyD2OeVt3FHS98PqRzynqcKnCRzc47igpbM',
  int? start,
}) async {
  final params = {
    'q': q,
    'cx': cx,
    'key': key,
    'num': '10',
  };
  if (start != null) {
    params['start'] = start.toString();
  }

  final uri = Uri.https(
    'www.googleapis.com',
    '/customsearch/v1',
    params,
  );

  final response = await http.get(uri);
  if (response.statusCode == 200) {
    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    return GcseSearchResult.fromJson(jsonMap);
  } else {
    throw Exception(
        'Google CSE API error: ${response.statusCode} ${response.body}');
  }
}
