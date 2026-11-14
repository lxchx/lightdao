// 搜索页的第三方服务拦截：未同意不发请求，同意后正常搜索。
// 运行：flutter test test/search_consent_test.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/third_party_consent.dart';
import 'package:lightdao/ui/page/search.dart';
import 'package:lightdao/ui/page/thread.dart' show ReplyJsonWithPage;
import 'package:lightdao/utils/google_cse_api.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:provider/provider.dart';

/// 只关心设置与同意状态的 AppState，不落盘、不加载。
class FakeAppState extends MyAppState {
  FakeAppState({List<String>? askedServices, List<String>? consentedServices}) {
    setting = LightDaoSetting.withAppDefaults(
      cookies: [],
      currentCookie: -1,
      replyHistory: [],
      starHistory: [],
      lightModeCustomThemeColor: const Color.fromARGB(255, 96, 125, 138),
      darkModeCustomThemeColor: const Color.fromARGB(255, 96, 125, 138),
      threadUserData: {},
      feedUuid: '',
      favoredForums: [],
      threadFilters: [],
      phrases: mergePhraseLists([], xDaoPhrases),
      favoredItems: [],
      baseCdn: 'auto',
      refCdn: 'auto',
      viewHistory: LRUCache<int, ReplyJsonWithPage>(100),
      viewPoOnlyHistory: LRUCache<int, ReplyJsonWithPage>(100),
      askedServices: askedServices ?? allThirdPartyServiceIds(),
      consentedServices: consentedServices ?? allThirdPartyServiceIds(),
    );
  }

  @override
  Future<void> saveSettings() async {}

  @override
  Future<void> loadSettings() async {}
}

/// 记录搜索请求的假客户端：一条结果、不足一页，所以只会请求一次。
class SearchRequests {
  final List<Uri> urls = [];

  http.Client get client => MockClient((request) async {
    urls.add(request.url);
    final body = jsonEncode({
      'searchInformation': {'totalResults': '1'},
      'items': [
        {
          'title': '第一个串',
          'link': 'https://www.nmbxd1.com/t/123',
          'htmlSnippet': '搜索摘要',
        },
      ],
    });
    return http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

void main() {
  late http.Client originalClient;

  setUp(() {
    originalClient = searchHttpClient;
  });

  tearDown(() {
    searchHttpClient = originalClient;
  });

  Future<void> pumpSearch(WidgetTester tester, MyAppState appState) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<MyAppState>.value(
        value: appState,
        child: MaterialApp(home: SearchPage(query: '测试关键词')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('未同意第三方服务：不发任何请求，提示并给出去设置的入口', (tester) async {
    final requests = SearchRequests();
    searchHttpClient = requests.client;
    final appState = FakeAppState(consentedServices: []);

    await pumpSearch(tester, appState);

    expect(requests.urls, isEmpty, reason: '未同意时不能连 Google');
    expect(find.text(SearchPage.consentRequiredTitle), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '去设置'), findsOneWidget);
    expect(find.text('第一个串'), findsNothing);
  });

  testWidgets('还没问过用户时同样不发请求', (tester) async {
    final requests = SearchRequests();
    searchHttpClient = requests.client;
    final appState = FakeAppState(askedServices: [], consentedServices: []);

    await pumpSearch(tester, appState);

    expect(requests.urls, isEmpty);
    expect(find.text(SearchPage.consentRequiredTitle), findsOneWidget);
  });

  testWidgets('同意过不含搜索的旧清单：新增项同样被拦', (tester) async {
    final requests = SearchRequests();
    searchHttpClient = requests.client;
    final appState = FakeAppState(
      askedServices: [kUpdateServiceId, kCdnServiceId],
      consentedServices: [kUpdateServiceId, kCdnServiceId],
    );

    await pumpSearch(tester, appState);

    expect(requests.urls, isEmpty, reason: '串搜索这一项还没同意过');
    expect(find.text(SearchPage.consentRequiredTitle), findsOneWidget);
  });

  testWidgets('已同意第三方服务：打开搜索页直接搜索', (tester) async {
    final requests = SearchRequests();
    searchHttpClient = requests.client;
    final appState = FakeAppState();

    await pumpSearch(tester, appState);

    expect(requests.urls, hasLength(1));
    final url = requests.urls.single;
    expect(url.host, 'www.googleapis.com');
    expect(url.path, '/customsearch/v1');
    expect(url.queryParameters['q'], '测试关键词');
    expect(find.text('第一个串'), findsOneWidget);
    expect(find.text(SearchPage.consentRequiredTitle), findsNothing);
  });
}
