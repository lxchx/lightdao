import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/utils/xdao_cdn.dart';

void main() {
  group('resolveEffectiveCdnSetting 未同意第三方服务', () {
    test('拒绝时固定走官方线路，忽略保存的第三方镜像', () {
      final result = resolveEffectiveCdnSetting(
        thirdPartyConsented: false,
        storedBaseCdn: 'https://api.nmb.best',
        storedRefCdn: 'https://api.nmb.fastmirror.org',
      );
      expect(result.baseCdn, officialBaseCdn);
      expect(result.refCdn, officialRefCdn);
      expect(result.baseCdn, 'https://www.nmbxd.com');
      expect(result.refCdn, 'https://www.nmbxd1.com');
    });

    test('保存值为「自动」时不传 auto，避免触发测速选线', () {
      // 「自动」会把每一条线路都连一次，其中包含第三方服务器。
      final result = resolveEffectiveCdnSetting(
        thirdPartyConsented: false,
        storedBaseCdn: xdaoCdnAuto,
        storedRefCdn: xdaoCdnAuto,
      );
      expect(result.baseCdn, isNot(xdaoCdnAuto));
      expect(result.refCdn, isNot(xdaoCdnAuto));
      expect(result.baseCdn, officialBaseCdn);
      expect(result.refCdn, officialRefCdn);
    });

    test('保存的自定义线路也不采用', () {
      final result = resolveEffectiveCdnSetting(
        thirdPartyConsented: false,
        storedBaseCdn: 'https://my.mirror.example',
        storedRefCdn: 'https://my.mirror.example',
      );
      expect(result.baseCdn, officialBaseCdn);
      expect(result.refCdn, officialRefCdn);
    });

    test('未同意时无论保存值是什么，结果都一样', () {
      const stored = [
        xdaoCdnAuto,
        'https://api.nmb.best',
        'https://api.nmb.fastmirror.org',
        'https://www.nmbxd.com',
        'https://www.nmbxd1.com',
        'https://my.mirror.example',
      ];
      for (final base in stored) {
        for (final ref in stored) {
          final result = resolveEffectiveCdnSetting(
            thirdPartyConsented: false,
            storedBaseCdn: base,
            storedRefCdn: ref,
          );
          expect(
            result.baseCdn,
            officialBaseCdn,
            reason: 'base=$base ref=$ref',
          );
          expect(result.refCdn, officialRefCdn, reason: 'base=$base ref=$ref');
        }
      }
    });
  });

  group('resolveEffectiveCdnSetting 已同意第三方服务', () {
    test('照保存值走，自动测速与自定义线路都保留', () {
      expect(
        resolveEffectiveCdnSetting(
          thirdPartyConsented: true,
          storedBaseCdn: xdaoCdnAuto,
          storedRefCdn: 'https://api.nmb.fastmirror.org',
        ).baseCdn,
        xdaoCdnAuto,
      );
      expect(
        resolveEffectiveCdnSetting(
          thirdPartyConsented: true,
          storedBaseCdn: xdaoCdnAuto,
          storedRefCdn: 'https://api.nmb.fastmirror.org',
        ).refCdn,
        'https://api.nmb.fastmirror.org',
      );
      expect(
        resolveEffectiveCdnSetting(
          thirdPartyConsented: true,
          storedBaseCdn: 'https://my.mirror.example',
          storedRefCdn: 'https://www.nmbxd1.com',
        ).baseCdn,
        'https://my.mirror.example',
      );
    });

    test('保存值原样返回，不被改写', () {
      const base = 'https://api.nmb.best';
      const ref = 'https://www.nmbxd.com';
      final result = resolveEffectiveCdnSetting(
        thirdPartyConsented: true,
        storedBaseCdn: base,
        storedRefCdn: ref,
      );
      expect(result.baseCdn, base);
      expect(result.refCdn, ref);
    });
  });

  group('官方线路常量', () {
    test('官方线路就是 X岛自己的服务器', () {
      expect(officialBaseCdn, 'https://www.nmbxd.com');
      expect(officialRefCdn, 'https://www.nmbxd1.com');
      // 官方线路必须在候选列表里，否则测速和重定向白名单会对不上
      expect(xdaoBaseCdns, contains(officialBaseCdn));
      expect(xdaoRefCdns, contains(officialRefCdn));
    });
  });
}
