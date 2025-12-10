import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lightdao/data/xdao/feed_info.dart';
import 'package:lightdao/data/xdao/forum.dart';
import 'package:lightdao/data/xdao/notice_info.dart';
import 'package:lightdao/data/xdao/post.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/data/xdao/timeline.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/utils/throttle.dart';

const String defaultBaseCdn = 'https://api.nmb.best';
const String defaultPostHost = 'https://www.nmbxd.com';
const String defaultLastPostHost = 'https://www.nmbxd1.com';
const String defaultRefCdn = 'https://www.nmbxd1.com';
const List<String> baseCdnCandidates = [
  defaultBaseCdn,
  'https://nmbxd.com',
  'https://nmbxd1.com',
  'https://api.nmb.fastmirror.org',
];
const List<String> refCdnCandidates = [
  'https://nmbxd.com',
  'https://nmbxd1.com',
];

String _baseCdn = defaultBaseCdn;
String _refCdn = defaultRefCdn;
bool _baseIsAuto = false;
bool _refIsAuto = false;
bool _autoSelectingCdns = false;

String get resolvedBaseCdn => _baseCdn;
String get resolvedRefCdn => _refCdn;

void applyCdnSetting({required String baseCdn, required String refCdn}) {
  _baseIsAuto = _isAuto(baseCdn);
  _refIsAuto = _isAuto(refCdn);
  _baseCdn = _normalizeCdn(baseCdn, defaultBaseCdn);
  _refCdn = _normalizeCdn(refCdn, defaultRefCdn);
  if (_baseIsAuto || _refIsAuto) {
    unawaited(_autoSelectCdns());
  }
}

String _normalizeCdn(String value, String fallback) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || _isAuto(trimmed)) {
    return fallback;
  }
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

bool _isAuto(String value) => value.trim().toLowerCase() == 'auto';

Future<void> _autoSelectCdns() async {
  if (_autoSelectingCdns) return;
  _autoSelectingCdns = true;
  try {
    if (_baseIsAuto) {
      final bestBase = await _selectBestCdn(
        baseCdnCandidates,
        (host) => Uri.parse('$host/${_apiSegment(host)}/getForumList'),
      );
      if (bestBase != null) {
        _baseCdn = bestBase;
      }
    }
    if (_refIsAuto) {
      final bestRef = await _selectBestCdn(
        refCdnCandidates,
        (host) => Uri.parse(
          '$host/Home/Forum/ref',
        ).replace(queryParameters: {'id': '1'}),
      );
      if (bestRef != null) {
        _refCdn = bestRef;
      }
    }
  } finally {
    _autoSelectingCdns = false;
  }
}

Future<String?> _selectBestCdn(
  List<String> candidates,
  Uri Function(String host) buildTestUri,
) async {
  final durations = <int, String>{};
  for (final host in candidates) {
    final normalized = _normalizeCdn(host, host);
    final uri = buildTestUri(normalized);
    final sw = Stopwatch()..start();
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 || response.statusCode == 403) {
        durations[sw.elapsedMilliseconds] = normalized;
      }
    } catch (_) {
      // ignore failures and try next
    }
  }
  if (durations.isEmpty) return null;
  final bestElapsed = durations.keys.reduce((a, b) => a < b ? a : b);
  return durations[bestElapsed];
}

String _apiSegment(String host) {
  return host.contains('nmbxd') ? 'Api' : 'api';
}

Uri _buildApiUri(String endpoint, {Map<String, String>? queryParameters}) {
  final host = _baseCdn;
  return Uri.parse(
    '$host/${_apiSegment(host)}/$endpoint',
  ).replace(queryParameters: queryParameters);
}

Uri _buildPostUri(String endpoint, {Map<String, String>? queryParameters}) {
  final host = _baseCdn.toLowerCase().contains('api.nmb.best')
      ? defaultPostHost
      : _baseCdn;
  return Uri.parse(
    '$host/Home/Forum/$endpoint',
  ).replace(queryParameters: queryParameters);
}

Uri _buildRefHtmlUri(int refId) {
  return Uri.parse(
    '$_refCdn/Home/Forum/ref',
  ).replace(queryParameters: {'id': refId.toString()});
}

Uri _buildLastPostUri() {
  final host = _baseCdn.toLowerCase().contains('api.nmb.best')
      ? defaultLastPostHost
      : _baseCdn;
  return Uri.parse('$host/${_apiSegment(host)}/getLastPost');
}

class XDaoApiExeption implements Exception {}

class XDaoApiMsgException implements XDaoApiExeption {
  final String msg;
  XDaoApiMsgException(String rawMsg) : msg = _tryDecodeUnicode(rawMsg);

  static String _tryDecodeUnicode(String input) {
    try {
      // 尝试将字符串作为JSON字符串解析，这会自动处理Unicode转义
      return json.decode(input);
    } catch (e) {
      return input;
    }
  }

  @override
  String toString() => 'XDaoApiMsgException: $msg';
}

class XDaoApiNotSuccussException implements XDaoApiExeption {
  final String msg;
  XDaoApiNotSuccussException(this.msg);

  @override
  String toString() => 'X岛返回的消息: $msg';
}

List<dynamic> getOKJsonList(String mayJsonStr) {
  try {
    final jsonData = json.decode(mayJsonStr);
    if (jsonData is Map) {
      if (jsonData.containsKey('success') &&
          jsonData['success'] == false &&
          jsonData.containsKey('error')) {
        throw XDaoApiNotSuccussException(jsonData['error']);
      } else {
        throw XDaoApiMsgException(mayJsonStr);
      }
    } else if (jsonData is List) {
      return jsonData;
    } else {
      throw XDaoApiMsgException(mayJsonStr);
    }
  } on FormatException {
    throw XDaoApiMsgException(mayJsonStr);
  }
}

Map<String, dynamic> getOKJsonMap(String mayJsonStr) {
  try {
    final jsonData = json.decode(mayJsonStr);
    if (jsonData is Map<String, dynamic>) {
      if (jsonData.containsKey('success') &&
          jsonData['success'] == false &&
          jsonData.containsKey('error')) {
        throw XDaoApiNotSuccussException(jsonData['error']);
      }
      return jsonData;
    } else {
      throw XDaoApiMsgException(mayJsonStr);
    }
  } on FormatException {
    throw XDaoApiMsgException(mayJsonStr);
  }
}

Future<List<ForumList>> fetchForumList() async {
  final response = await http.get(
    _buildApiUri('getForumList'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  );

  if (response.statusCode == 200) {
    final data = getOKJsonList(response.body);
    try {
      final List<ForumList> forumLists = data
          .map((e) => ForumList.fromJson(e))
          .toList();
      return forumLists;
    } catch (e) {
      throw Exception(
        'Failed to build ForumList from json str: ${e.toString()}',
      );
    }
  } else {
    throw Exception('Failed to load forum_list: ${response.statusCode}');
  }
}

Future<List<Timeline>> fetchTimelines() async {
  final response = await http.get(
    _buildApiUri('getTimelineList'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  );

  if (response.statusCode == 200) {
    final data = getOKJsonList(response.body);
    try {
      final timelines = data.map((json) => Timeline.fromJson(json)).toList();
      return timelines;
    } catch (e) {
      throw Exception(
        'Failed to build List<Timeline> from json str: ${e.toString()}',
      );
    }
  } else {
    throw Exception('Failed to load timeline_list: ${response.statusCode}');
  }
}

Future<List<ThreadJson>> fetchForumThreads(
  int forumId,
  int page,
  String? cookie,
) async {
  if (page <= 0) {
    throw ArgumentError('Page number must be greater than 0');
  }

  late Map<String, String>? headers;
  if (cookie != null) {
    headers = {'Cookie': 'userhash=$cookie'};
  } else {
    headers = null;
  }

  final response = await http.get(
    _buildApiUri(
      'showf',
      queryParameters: {'id': forumId.toString(), 'page': page.toString()},
    ),
    headers: headers,
  ) /*.timeout(Duration(seconds: 10))*/;

  if (response.statusCode == 200) {
    final List<dynamic> data = getOKJsonList(response.body);
    try {
      final List<ThreadJson> threads = data
          .map((json) => ThreadJson.fromJson(json))
          .toList();
      return threads;
    } catch (e) {
      throw Exception(
        'Failed to build List<ThreadJson> from json str: ${e.toString()}',
      );
    }
  } else {
    throw Exception('Failed to load threads: ${response.statusCode}');
  }
}

Future<List<ThreadJson>> fetchTimelineThreads(
  int timelineId,
  int page,
  String? cookie,
) async {
  if (page <= 0) {
    throw ArgumentError('Page number must be greater than 0');
  }

  late Map<String, String>? headers;
  if (cookie != null) {
    headers = {'Cookie': 'userhash=$cookie'};
  } else {
    headers = null;
  }

  final response = await http.get(
    _buildApiUri(
      'timeline',
      queryParameters: {'id': timelineId.toString(), 'page': page.toString()},
    ),
    headers: headers,
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = getOKJsonList(response.body);
    try {
      final List<ThreadJson> threads = data
          .map((json) => ThreadJson.fromJson(json))
          .toList();
      return threads;
    } catch (e) {
      throw Exception(
        'Failed to build List<ThreadJson> from json str: ${e.toString()}',
      );
    }
  } else {
    throw Exception('Failed to load threads: ${response.statusCode}');
  }
}

//Future<int> shouldGetFromCacheOrHttp(int threadId, int page) async {
//  final maxPage = await ThreadInfoStorage.getMaxPage(threadId);
//  if (maxPage != null && maxPage >= page) {
//    if (maxPage > page) {
//      return 1; // from cache
//    } else {
//      return 3; // from http, but cache could be placeholder
//    }
//  }
//  return 2; // from http
//}

Future<ThreadJson> _getThreadGeneric(
  String endpoint,
  int threadId,
  int page,
  String? cookie, {
  bool forceFromWeb = false,
}) async {
  final url = _buildApiUri(
    endpoint,
    queryParameters: {'id': threadId.toString(), 'page': page.toString()},
  );

  if (!forceFromWeb) {
    // 1. 从cache拿
    final threadJsonFile = await MyThreadCacheManager().getFileFromCache(
      url.toString(),
    );
    while (threadJsonFile != null) {
      final threadJsonStr = await threadJsonFile.file.readAsString();
      final data = getOKJsonMap(threadJsonStr);
      final thread = ThreadJson.fromJson(data);
      if (thread.replyCount ~/ 19 + 1 <= page) {
        // 可能有更新，需要从Http拉取
        break;
      }
      return thread;
    }
  }

  // 2. 从http拿
  late Map<String, String>? headers;
  if (cookie != null) {
    headers = {'Cookie': 'userhash=$cookie'};
  } else {
    headers = null;
  }

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    final data = getOKJsonMap(response.body);
    final thread = ThreadJson.fromJson(data);
    MyThreadCacheManager().putFile(url.toString(), response.bodyBytes);
    return thread;
  } else {
    throw Exception(
      'Failed to fetch thread, http status code: ${response.statusCode}',
    );
  }
}

Future<ThreadJson> getThread(
  int threadId,
  int page,
  String? cookie, {
  bool forceFromWeb = false,
}) async {
  return _getThreadGeneric(
    'thread',
    threadId,
    page,
    cookie,
    forceFromWeb: forceFromWeb,
  );
}

Future<ThreadJson> getThreadPoOnly(
  int threadId,
  int page,
  String? cookie, {
  bool forceFromWeb = false,
}) async {
  return _getThreadGeneric(
    'po',
    threadId,
    page,
    cookie,
    forceFromWeb: forceFromWeb,
  );
}

//Future<ThreadJson> getThreadFromCache(
//    int threadId, int page, String? cookie) async {
//  final url = Uri.parse('https://api.nmb.best/api/thread').replace(
//      queryParameters: {'id': threadId.toString(), 'page': page.toString()});
//  late Map<String, String>? headers;
//  if (cookie != null) {
//    headers = {
//      'Cookie': 'userhash=$cookie',
//    };
//  } else {
//    headers = null;
//  }
//  final threadJsonFile = await MyThreadCacheManager().getSingleFile(
//    url.toString(),
//    headers: headers,
//  );
//  final threadJsonStr = await threadJsonFile.readAsString();
//  final data = getOKJsonMap(threadJsonStr);
//  final thread = ThreadJson.fromJson(data);
//  return thread;
//}

//Future<ThreadJson> getThreadFromHttp(
//    int threadId, int page, String? cookie) async {
//  final url = Uri.parse('https://api.nmb.best/api/thread').replace(
//      queryParameters: {'id': threadId.toString(), 'page': page.toString()});
//  late Map<String, String>? headers;
//  if (cookie != null) {
//    headers = {
//      'Cookie': 'userhash=$cookie',
//    };
//  } else {
//    headers = null;
//  }
//
//  final response = await http.get(
//    url,
//    headers: headers,
//  );
//
//  if (response.statusCode == 200) {
//    final data = getOKJsonMap(response.body);
//    final thread = ThreadJson.fromJson(data);
//    return thread;
//  } else {
//    throw Exception(
//        'Failed to fetch thread, http status code: ${response.statusCode}');
//  }
//}

//Throttle _fetchRefThrottle = Throttle(milliseconds: 100);

//Future<RefJson> fetchRef(int threadId, String? cookie) async {
//  Completer<RefJson> refCompleter = Completer<RefJson>();
//  //_fetchRefThrottle.run(() async {
//  final url =
//      Uri.parse('https://api.nmb.best/api/ref').replace(queryParameters: {
//    'id': threadId.toString(),
//  });
//  late Map<String, String>? headers;
//  if (cookie != null) {
//    headers = {
//      'Cookie': 'userhash=$cookie',
//    };
//  } else {
//    headers = null;
//  }
//
//  final refJsonFile = await MyThreadCacheManager().getSingleFile(
//    url.toString(),
//    headers: headers,
//  );
//  final refJsonStr = await refJsonFile.readAsString();
//  final data = getOKJsonMap(refJsonStr);
//  final ref = RefJson.fromJson(data);
//  refCompleter.complete(ref);
//  //});
//  return refCompleter.future;
//}

Future<RefJson> fetchRef(int refId, String? cookie) async {
  final url = _buildApiUri('ref', queryParameters: {'id': refId.toString()});
  late Map<String, String>? headers;
  if (cookie != null) {
    headers = {'Cookie': 'userhash=$cookie'};
  } else {
    headers = null;
  }

  final refJsonFile = await MyThreadCacheManager().getSingleFile(
    url.toString(),
    headers: headers,
  );
  final refJsonStr = await refJsonFile.readAsString();
  final data = getOKJsonMap(refJsonStr);
  return RefJson.fromJson(data);
}

final fetchRefThrottle = IntervalRunner<RefHtml>(
  interval: Duration(milliseconds: 150),
);
Future<RefHtml> fetchRefFromHtml(
  int refId,
  String? cookie, {
  IntervalRunner<RefHtml>? throttle,
}) async {
  final runner = throttle ?? fetchRefThrottle;
  return runner.run(() async {
    //print('${DateTime.now()} 排到了refId: $refId');
    final url = _buildRefHtmlUri(refId);

    late Map<String, String>? headers;
    if (cookie != null) {
      headers = {'Cookie': 'userhash=$cookie'};
    } else {
      headers = null;
    }

    File? responseFile;
    try {
      responseFile = await MyThreadCacheManager().getSingleFile(
        url.toString(),
        headers: headers,
      );
    } on HttpException catch (e) {
      if (e.message.contains('statusCode: 429')) {
        await Future.delayed(Duration(seconds: 1));
        responseFile = responseFile = await MyThreadCacheManager()
            .getSingleFile(url.toString(), headers: headers);
      }
    }

    if (responseFile == null) {
      throw Exception('获取串失败');
    }
    final responseBody = await responseFile.readAsString();

    try {
      // 尝试解析为 JSON
      final jsonData = json.decode(responseBody);
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('info')) {
        throw XDaoApiNotSuccussException(jsonData['info']);
      } else {
        throw XDaoApiMsgException(responseBody);
      }
    } on FormatException {
      // 如果 JSON 解析失败，尝试解析为 HTML
      final document = parse(responseBody);

      // 查找 class="error" 的元素
      final errorElement = document.querySelector('.error');
      if (errorElement != null) {
        final errorMessage = errorElement.text.trim();
        throw XDaoApiNotSuccussException(errorMessage);
      }

      // 如果没有找到错误信息，则继续解析为 RefHtml
      try {
        return RefHtml.fromHtml(document);
      } catch (e) {
        throw Exception('串不存在');
      }
    }
  });
}

Future<Post> postThread({
  required String content,
  required int fid,
  String name = '',
  String title = '',
  File? image,
  bool water = true,
  required String cookie,
}) async {
  final url = _buildPostUri('doPostThread.html');
  await _sendRequest(
    url,
    {
      'content': content,
      'fid': fid.toString(),
      'name': name,
      'title': title,
      'water': water ? "1" : "0",
    },
    image,
    cookie,
  );
  return getLastPost(cookie);
}

Future<Post> replyThread({
  required String content,
  required int threadId,
  String name = '',
  String title = '',
  File? image,
  bool water = true,
  required String cookie,
}) async {
  final url = _buildPostUri('doReplyThread.html');
  await _sendRequest(
    url,
    {
      'content': content,
      'resto': threadId.toString(),
      'name': name,
      'title': title,
      'water': water ? "1" : "0",
    },
    image,
    cookie,
  );
  return getLastPost(cookie);
}

Future<void> _sendRequest(
  Uri url,
  Map<String, String> fields,
  File? image,
  String cookie,
) async {
  var request = http.MultipartRequest('POST', url);
  request.fields.addAll(fields);
  if (image != null) {
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
  }
  request.headers['Cookie'] = 'userhash=$cookie';

  var response = await request.send();
  if (response.statusCode == 307) {
    final newUrl = response.headers['location'];
    if (newUrl != null) {
      request = http.MultipartRequest('POST', Uri.parse(newUrl));
      request.fields.addAll(fields);
      if (image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }
      request.headers['Cookie'] = 'userhash=$cookie';
      response = await request.send();
    }
  }

  final responseBody = await response.stream.bytesToString();
  if (response.statusCode == 200) {
    final document = parse(responseBody);
    final successElement = document.querySelector('.success');
    if (successElement != null) {
      print('操作成功');
    } else {
      final errorElement = document.querySelector('.error');
      if (errorElement != null) {
        throw XDaoApiNotSuccussException(errorElement.text.trim());
      } else {
        throw XDaoApiMsgException('未知错误');
      }
    }
  } else {
    throw XDaoApiMsgException('请求失败，状态码：${response.statusCode}');
  }
}

Future<Post> getLastPost(String? cookie) async {
  final url = _buildLastPostUri();
  late Map<String, String>? headers;
  if (cookie != null) {
    headers = {'Cookie': 'userhash=$cookie'};
  } else {
    headers = null;
  }
  final response = await http.get(url, headers: headers);
  if (response.statusCode == 200) {
    final data = getOKJsonMap(response.body);
    return Post.fromJson(data);
  } else {
    throw XDaoApiMsgException('请求失败，状态码：${response.statusCode}');
  }
}

Future<List<FeedInfo>> getFeedInfos(String uuid, int page) async {
  final response = await http.get(
    _buildApiUri(
      'feed',
      queryParameters: {'uuid': uuid, 'page': page.toString()},
    ),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  );
  if (response.statusCode == 200) {
    if (response.body.trim() == '') {
      return [];
    }
    final List<dynamic> data = json.decode(response.body);
    return data.map((e) => FeedInfo.fromJson(e)).toList();
  } else {
    throw Exception('Failed to load feed info: ${response.statusCode}');
  }
}

Future<void> addFeed(String uuid, int tid) async {
  final response = await http.post(
    _buildApiUri(
      'addFeed',
      queryParameters: {'uuid': uuid, 'tid': tid.toString()},
    ),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  );
  if (response.statusCode == 200) {
    if (jsonDecode(response.body.trim()) == '订阅大成功→_→') {
      return;
    } else {
      throw XDaoApiMsgException(response.body);
    }
  } else {
    throw Exception('Failed to add feed: ${response.statusCode}');
  }
}

Future<void> delFeed(String uuid, int tid) async {
  final response = await http.post(
    _buildApiUri(
      'delFeed',
      queryParameters: {'uuid': uuid, 'tid': tid.toString()},
    ),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  );
  if (response.statusCode == 200) {
    if (jsonDecode(response.body.trim()) == '取消订阅成功!') {
      return;
    } else {
      throw XDaoApiMsgException(response.body);
    }
  } else {
    throw Exception('Failed to delete feed: ${response.statusCode}');
  }
}

Future<ReplyJson> getLatestTrend(String? cookie) async {
  const int trendThreadId = 50248044;

  ThreadJson firstPageThread = await getThread(
    trendThreadId,
    1,
    cookie,
    forceFromWeb: true,
  );

  final int lastPage = (firstPageThread.replyCount / 19).ceil();

  ThreadJson lastPageThread = await getThread(
    trendThreadId,
    lastPage,
    cookie,
    forceFromWeb: true,
  );

  final ReplyJson latestReply = lastPageThread.replies.last;

  return latestReply;
}

CacheManager noticeCacheManager = CacheManager(
  Config(
    'notice',
    stalePeriod: const Duration(minutes: 30),
    maxNrOfCacheObjects: 1,
  ),
);

Future<NoticeInfo> getNotice() async {
  try {
    final file = await noticeCacheManager.getSingleFile(
      'https://nmb.ovear.info/nmb-notice.json',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    final jsonStr = await file.readAsString();
    final data = getOKJsonMap(jsonStr);

    return NoticeInfo.fromJson(data);
  } catch (e) {
    throw Exception('获取公告失败: ${e.toString()}');
  }
}
