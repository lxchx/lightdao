import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:lightdao/utils/xdao_cdn.dart';

final http.Client _httpClient = http.Client();

const String defaultBaseCdn = 'https://api.nmb.best';
const String defaultPostHost = 'https://www.nmbxd.com';
const String defaultLastPostHost = 'https://www.nmbxd1.com';
const String defaultRefCdn = 'https://www.nmbxd1.com';

/// 串页每页的回复条数：服务端每页固定 1 条 tips + 19 条回复。
///
/// 页数换算只认这一个口径（page_manager.dart 也走 [threadPageCount]），
/// 别再手写 `replyCount ~/ 19 + 1`——整除时会多算一页。
const int _repliesPerPage = 19;

/// 串的总页数。
///
/// - 整除 [_repliesPerPage] 时不多算一页：418 条回复 = 22 页，不是 23 页；
/// - [replyCount] 为 0 时至少 1 页（0 页会让调用方去请求不存在的第 0 页）。
int threadPageCount(int replyCount) =>
    max(1, (replyCount / _repliesPerPage).ceil());

const List<String> baseCdnCandidates = xdaoBaseCdns;
const List<String> refCdnCandidates = xdaoRefCdns;

String _baseCdn = defaultBaseCdn;
String _refCdn = defaultRefCdn;
bool _baseIsAuto = false;
bool _refIsAuto = false;
bool _autoSelectingCdns = false;

String get resolvedBaseCdn => _baseCdn;
String get resolvedRefCdn => _refCdn;

bool _isRedirectStatusCode(int statusCode) {
  return statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;
}

String _toggleWww(String host) {
  final normalized = host.toLowerCase();
  if (normalized.startsWith('www.')) {
    return normalized.substring(4);
  }
  return 'www.$normalized';
}

Set<String> _buildCookieRedirectHostAllowlist(Uri initialUri) {
  final allowlist = <String>{};

  void addHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return;
    allowlist.add(normalized);
    allowlist.add(_toggleWww(normalized));
  }

  // Known hosts (from base/ref cdn lists + posting hosts)
  for (final url in [...baseCdnCandidates, ...refCdnCandidates]) {
    addHost(Uri.tryParse(url)?.host ?? '');
  }
  addHost(Uri.tryParse(defaultPostHost)?.host ?? '');
  addHost(Uri.tryParse(defaultLastPostHost)?.host ?? '');

  // User-configured hosts (custom mirrors)
  addHost(initialUri.host);
  addHost(Uri.tryParse(_baseCdn)?.host ?? '');
  addHost(Uri.tryParse(_refCdn)?.host ?? '');
  return allowlist;
}

Future<http.Response> _getWithCookiePreservedRedirects(
  Uri uri, {
  Map<String, String>? headers,
  int maxRedirects = 5,
}) async {
  var currentUri = uri;
  final allowlist = _buildCookieRedirectHostAllowlist(currentUri);
  final requestHeaders = headers == null
      ? null
      : Map<String, String>.of(headers);

  for (var i = 0; i <= maxRedirects; i++) {
    final request = http.Request('GET', currentUri)
      ..followRedirects = false
      ..maxRedirects = 0;
    if (requestHeaders != null) {
      request.headers.addAll(requestHeaders);
    }
    final response = await http.Response.fromStream(
      await _httpClient.send(request),
    );

    if (!_isRedirectStatusCode(response.statusCode)) {
      return response;
    }

    final location = response.headers['location'];
    if (location == null) {
      return response;
    }

    final nextUri = currentUri.resolve(location);
    if (nextUri.scheme.toLowerCase() != 'https') {
      return response;
    }

    final nextHost = nextUri.host.toLowerCase();
    if (requestHeaders != null &&
        requestHeaders.containsKey('Cookie') &&
        !allowlist.contains(nextHost)) {
      throw XDaoApiMsgException('重定向到不受信任的域名：$nextHost');
    }

    currentUri = nextUri;
  }

  throw XDaoApiMsgException('重定向次数过多');
}

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

/// 性能测量用：编译时传 --dart-define=LD_BENCH_HOST=http://10.0.2.2:8766
/// 就把 JSON 接口指到本机的录制回放服务（flutter-scroll/tools/
/// xdao_replay_server.py），让每次测量看到同一份内容。正常构建为空，不生效。
const String _benchHost = String.fromEnvironment('LD_BENCH_HOST');

Uri _buildApiUri(String endpoint, {Map<String, String>? queryParameters}) {
  final host = _benchHost.isNotEmpty ? _benchHost : _baseCdn;
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

  final response = await _getWithCookiePreservedRedirects(
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

  final queryParameters = {
    'id': timelineId.toString(),
    'page': page.toString(),
  };

  final response = await _getWithCookiePreservedRedirects(
    _buildApiUri('timeline', queryParameters: queryParameters),
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

/// 解析接口返回的串页 JSON。
///
/// 解析失败会抛出（缓存内容坏了 / 网关返回了错误页），调用方据此决定
/// 删缓存回源还是把错误抛给上层。
ThreadJson parseThreadJsonBody(String body) {
  return ThreadJson.fromJson(getOKJsonMap(body));
}

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
    // 1. 从cache拿。解析不出来（半截 JSON、代理/网关的错误页）就先删掉缓存
    //    再回源——否则一条坏缓存会让这一页在整个 stalePeriod 内一直打不开。
    //    对照 fetchRefFromHtml 已经这么做了。
    final cacheKey = url.toString();
    final threadJsonFile = await MyThreadCacheManager().getFileFromCache(
      cacheKey,
    );
    if (threadJsonFile != null) {
      try {
        final threadJsonStr = await threadJsonFile.file.readAsString();
        final data = getOKJsonMap(threadJsonStr);
        final thread = ThreadJson.fromJson(data);
        if (threadPageCount(thread.replyCount) <= page) {
          // 可能有更新，需要从Http拉取
        } else {
          return thread;
        }
      } catch (_) {
        await MyThreadCacheManager().removeFile(cacheKey);
      }
    }
  }

  // 2. 从http拿
  late Map<String, String>? headers;
  if (cookie != null) {
    headers = {'Cookie': 'userhash=$cookie'};
  } else {
    headers = null;
  }

  final response = await _getWithCookiePreservedRedirects(
    url,
    headers: headers,
  );

  if (response.statusCode == 200) {
    final thread = parseThreadJsonBody(response.body);
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

    // 1. 从cache拿。只有能解析成功的内容才算命中；旧版本会把
    //    "必须登入领取饼干" 之类的错误页也缓存下来，这里顺手清掉并重新拉取。
    final cacheKey = url.toString();
    final cached = await MyThreadCacheManager().getFileFromCache(cacheKey);
    if (cached != null) {
      try {
        return parseRefHtmlBody(await cached.file.readAsString());
      } catch (_) {
        await MyThreadCacheManager().removeFile(cacheKey);
      }
    }

    // 2. 从http拿。引用站可能 30x 到另一个域名（www.nmbxd.com ->
    //    www.nmbxd1.com），默认的跟随重定向会丢掉 Cookie，需登录的板块
    //    就会返回 "必须登入领取饼干"，所以这里必须手动带着 Cookie 跟随。
    var response = await _getWithCookiePreservedRedirects(
      url,
      headers: headers,
    );
    if (response.statusCode == 429) {
      await Future.delayed(Duration(seconds: 1));
      response = await _getWithCookiePreservedRedirects(url, headers: headers);
    }
    if (response.statusCode != 200) {
      throw Exception('获取串失败: ${response.statusCode}');
    }

    // 解析失败（错误页）会抛出，不写入缓存
    final ref = parseRefHtmlBody(utf8.decode(response.bodyBytes));
    unawaited(MyThreadCacheManager().putFile(cacheKey, response.bodyBytes));
    return ref;
  });
}

/// 解析引用页的响应体。错误页（JSON 的 info，或 HTML 里 class="error"
/// 的提示，如 "必须登入领取饼干"）会抛出异常，调用方据此决定不缓存。
RefHtml parseRefHtmlBody(String responseBody) {
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
  var currentUrl = url;
  final allowlist = _buildCookieRedirectHostAllowlist(currentUrl);

  for (var i = 0; i <= 5; i++) {
    final request = http.MultipartRequest('POST', currentUrl)
      ..followRedirects = false
      ..maxRedirects = 0;
    request.fields.addAll(fields);
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    request.headers['Cookie'] = 'userhash=$cookie';

    final response = await request.send();

    if (_isRedirectStatusCode(response.statusCode)) {
      final location = response.headers['location'];
      if (location == null) {
        throw XDaoApiMsgException('请求被重定向但缺少 Location');
      }

      final nextUrl = currentUrl.resolve(location);
      if (nextUrl.scheme.toLowerCase() != 'https') {
        throw XDaoApiMsgException('请求被重定向到非 https 地址：$nextUrl');
      }

      final nextHost = nextUrl.host.toLowerCase();
      if (!allowlist.contains(nextHost)) {
        throw XDaoApiMsgException('重定向到不受信任的域名：$nextHost');
      }

      currentUrl = nextUrl;
      continue;
    }

    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final document = parse(responseBody);
      final successElement = document.querySelector('.success');
      if (successElement != null) {
        print('操作成功');
        return;
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

  throw XDaoApiMsgException('重定向次数过多');
}

Future<Post> getLastPost(String? cookie) async {
  final url = _buildLastPostUri();
  late Map<String, String>? headers;
  if (cookie != null) {
    headers = {'Cookie': 'userhash=$cookie'};
  } else {
    headers = null;
  }
  final response = await _getWithCookiePreservedRedirects(
    url,
    headers: headers,
  );
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

  final int lastPage = threadPageCount(firstPageThread.replyCount);

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
