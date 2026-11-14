// 第三方服务清单与「问过哪些项 / 同意过哪些项」的判定。
//
// 清单以后还会加服务，所以这两件事分开记：
// - askedServices：问过用户哪几项（问过就不再追问，哪怕他点了不同意）；
// - consentedServices：用户同意过哪几项（决定功能能不能用）。
// 运行：flutter test test/utils/third_party_consent_service_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lightdao/data/third_party_consent.dart';
import 'package:lightdao/utils/google_cse_api.dart';
import 'package:lightdao/utils/xdao_cdn.dart';

void main() {
  group('清单本身', () {
    test('每一项都有非空的 id 与名字，id 不重复', () {
      final ids = <String>{};
      for (final service in kThirdPartyServices) {
        expect(service.id, isNotEmpty);
        expect(service.name, isNotEmpty);
        expect(service.summary, isNotEmpty);
        expect(ids.add(service.id), isTrue, reason: 'id 重复：${service.id}');
      }
    });

    test('更新检查、第三方线路、串搜索都在清单里', () {
      final ids = allThirdPartyServiceIds();
      expect(ids, contains(kUpdateServiceId));
      expect(ids, contains(kCdnServiceId));
      expect(ids, contains(kSearchServiceId));
      final search = kThirdPartyServices.firstWhere(
        (service) => service.id == kSearchServiceId,
      );
      expect(search.name, contains('搜索'));
      expect(search.summary, contains('www.googleapis.com'));
    });
  });

  group('isServiceConsented：只看同意过的项', () {
    test('在同意过的集合里才可用', () {
      expect(
        isServiceConsented(
          consentedServices: allThirdPartyServiceIds(),
          serviceId: kSearchServiceId,
        ),
        isTrue,
      );
      expect(
        isServiceConsented(
          consentedServices: [kUpdateServiceId, kCdnServiceId],
          serviceId: kSearchServiceId,
        ),
        isFalse,
      );
      expect(
        isServiceConsented(consentedServices: [], serviceId: kSearchServiceId),
        isFalse,
      );
    });
  });

  group('shouldAskConsent：只看问过没有', () {
    test('什么都没问过：要问，且整份清单都算没问过', () {
      expect(shouldAskConsent([]), isTrue);
      expect(
        unaskedThirdPartyServices([]).map((service) => service.id),
        allThirdPartyServiceIds(),
      );
    });

    test('问过整份清单：不再问', () {
      expect(shouldAskConsent(allThirdPartyServiceIds()), isFalse);
      expect(unaskedThirdPartyServices(allThirdPartyServiceIds()), isEmpty);
    });

    test('清单新增服务：只问新增的那几项', () {
      final asked = [kUpdateServiceId, kCdnServiceId];
      expect(shouldAskConsent(asked), isTrue);
      expect(unaskedThirdPartyServices(asked).map((service) => service.id), [
        kSearchServiceId,
      ]);
    });

    test('拒绝过的项也算问过，不会再追问', () {
      // 用户上次在重新询问时点了不同意：新增的 id 记进了 asked，consented 没变。
      final asked = allThirdPartyServiceIds();
      final consented = [kUpdateServiceId, kCdnServiceId];
      expect(shouldAskConsent(asked), isFalse);
      expect(
        isServiceConsented(
          consentedServices: consented,
          serviceId: kSearchServiceId,
        ),
        isFalse,
      );
    });
  });

  group('新增项被拦时，已经同意过的旧项不受影响', () {
    test('同意过旧清单：线路仍按保存值走，搜索不可用', () {
      final consented = [kUpdateServiceId, kCdnServiceId];
      final cdn = resolveEffectiveCdnSetting(
        thirdPartyConsented: isServiceConsented(
          consentedServices: consented,
          serviceId: kCdnServiceId,
        ),
        storedBaseCdn: 'https://api.nmb.best',
        storedRefCdn: 'https://api.nmb.fastmirror.org',
      );
      expect(cdn.baseCdn, 'https://api.nmb.best');
      expect(cdn.refCdn, 'https://api.nmb.fastmirror.org');
      expect(
        isServiceConsented(
          consentedServices: consented,
          serviceId: kSearchServiceId,
        ),
        isFalse,
      );
    });

    test('一项都没同意：线路固定走官方，不做测速', () {
      final cdn = resolveEffectiveCdnSetting(
        thirdPartyConsented: isServiceConsented(
          consentedServices: [],
          serviceId: kCdnServiceId,
        ),
        storedBaseCdn: xdaoCdnAuto,
        storedRefCdn: xdaoCdnAuto,
      );
      expect(cdn.baseCdn, officialBaseCdn);
      expect(cdn.refCdn, officialRefCdn);
    });
  });

  group('googleCseSearch 的同意守卫', () {
    test('没同意串搜索时抛异常，且一个请求都不发出去', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });

      await expectLater(
        googleCseSearch(q: '测试关键词', allowed: false, client: client),
        throwsA(isA<ThirdPartyConsentRequiredException>()),
      );
      expect(requests, 0, reason: '未同意时不能发请求');
    });

    test('已同意时按关键词请求一次，只带搜索参数', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final body = jsonEncode({
          'searchInformation': {'totalResults': '0'},
          'items': [],
        });
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final result = await googleCseSearch(
        q: '测试关键词',
        allowed: true,
        client: client,
      );

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.url.host, 'www.googleapis.com');
      expect(request.url.path, '/customsearch/v1');
      expect(request.url.queryParameters['q'], '测试关键词');
      expect(request.headers.containsKey('cookie'), isFalse);
      expect(result.items, isEmpty);
    });
  });
}
