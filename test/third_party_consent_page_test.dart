import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/third_party_consent.dart';
import 'package:lightdao/ui/page/third_party_consent_page.dart';

/// 模拟按下系统返回键：安卓返回键与 iOS 侧滑返回都走这条 popRoute 通道。
Future<void> pressSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    SystemChannels.navigation.codec.encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// 一个「上一页」，用来把同意页压到它上面，才能验证返回键的拦截效果。
Widget buildHost({
  required bool firstRun,
  required ValueChanged<bool> onDecided,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ThirdPartyConsentPage(
                  firstRun: firstRun,
                  onDecided: onDecided,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('首次启动模式：显著写明不受X岛官方支持，并提供两个按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ThirdPartyConsentPage(onDecided: (_) {})),
    );

    expect(find.text(ThirdPartyConsentPage.unsupportedNotice), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '同意'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '不同意'), findsOneWidget);
    // 首次模式没有返回按钮
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('首次启动模式：系统返回键退不出去', (tester) async {
    await tester.pumpWidget(buildHost(firstRun: true, onDecided: (_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ThirdPartyConsentPage), findsOneWidget);

    await pressSystemBack(tester);

    expect(find.byType(ThirdPartyConsentPage), findsOneWidget, reason: '不能跳过');
    expect(find.text('open'), findsNothing, reason: '没有退回上一页');
  });

  testWidgets('点「同意」写入 true', (tester) async {
    final decided = <bool>[];
    await tester.pumpWidget(
      MaterialApp(home: ThirdPartyConsentPage(onDecided: decided.add)),
    );

    await tester.tap(find.widgetWithText(FilledButton, '同意'));
    await tester.pump();

    expect(decided, [true]);
  });

  testWidgets('点「不同意」写入 false', (tester) async {
    final decided = <bool>[];
    await tester.pumpWidget(
      MaterialApp(home: ThirdPartyConsentPage(onDecided: decided.add)),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '不同意'));
    await tester.pump();

    expect(decided, [false]);
  });

  testWidgets('从设置打开时允许返回，且选择后自己关掉页面', (tester) async {
    final decided = <bool>[];
    await tester.pumpWidget(buildHost(firstRun: false, onDecided: decided.add));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget, reason: '可以改主意，所以能返回');

    await pressSystemBack(tester);

    expect(find.byType(ThirdPartyConsentPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(decided, isEmpty, reason: '直接返回不算做出选择');
  });

  testWidgets('从设置打开时点「同意」写入 true 并关掉页面', (tester) async {
    final decided = <bool>[];
    await tester.pumpWidget(buildHost(firstRun: false, onDecided: decided.add));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '同意'));
    await tester.pumpAndSettle();

    expect(decided, [true]);
    expect(find.byType(ThirdPartyConsentPage), findsNothing);
  });

  testWidgets('说明里列出第三方服务器与X岛来源', (tester) async {
    // 清单每加一项，页面就长一段；顺序往下滚着找一个关键词时，
    // 后面的目标会因为滚动步长被跳过。所以把测试视口放高，
    // 让整页一次布局完，直接校验每个关键词都在页面上。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ThirdPartyConsentPage(onDecided: (_) {})),
    );

    for (final keyword in [
      'GitHub',
      'Google 自定义搜索',
      'api.nmb.best',
      'api.nmb.fastmirror.org',
      'https://www.nmbxd.com',
    ]) {
      expect(find.textContaining(keyword), findsWidgets, reason: keyword);
    }
  });

  testWidgets('清单新增服务时，页首标出新增的是哪几项', (tester) async {
    const newServices = [
      ThirdPartyService(
        id: kSearchServiceId,
        name: '串搜索（Google 自定义搜索）',
        summary: '搜索关键词会发给 www.googleapis.com，由 Google 返回搜索结果',
      ),
    ];
    // 「不同意的后果」在页面靠下，懒加载的 ListView 默认视口里还没建出来，
    // 把测试视口放高，整页一次布局完。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ThirdPartyConsentPage(
          onDecided: (_) {},
          newServices: newServices,
        ),
      ),
    );

    expect(find.textContaining('本说明新增了以下第三方服务'), findsOneWidget);
    expect(find.textContaining('串搜索（Google 自定义搜索）'), findsOneWidget);
    // 说清点「不同意」只影响新增的这几项
    expect(find.textContaining('点「不同意」只影响上面这几项'), findsOneWidget);
    // 「不同意的后果」也要点明这次只影响新增项
    expect(find.textContaining('这次点「不同意」只影响上面新增的这几项'), findsOneWidget);
    // 重新询问时不能再列「不能检查更新」这类整份说明的后果：
    // 读起来像「点下去旧的也没了」，与只影响新增项的语义相反
    expect(find.textContaining('不能检查更新'), findsNothing);
    // 重新确认同样只有「同意 / 不同意」两个选择
    expect(find.widgetWithText(FilledButton, '同意'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '不同意'), findsOneWidget);
  });

  testWidgets('没有新增项时不显示新增提示', (tester) async {
    // 「不同意的后果」在页面靠下，懒加载的 ListView 默认视口里还没建出来，
    // 把测试视口放高，整页一次布局完。
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: ThirdPartyConsentPage(onDecided: (_) {})),
    );

    expect(find.textContaining('本说明新增了'), findsNothing);
    expect(find.textContaining('这次点「不同意」'), findsNothing);
    // 首次启动仍然是整份说明的措辞，并列出全部后果
    expect(find.text('不同意也可以继续使用，且不影响主要功能：'), findsOneWidget);
    expect(find.textContaining('不能检查更新'), findsOneWidget);
  });
}
