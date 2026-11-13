import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.pumpWidget(
      MaterialApp(home: ThirdPartyConsentPage(onDecided: (_) {})),
    );

    final scrollable = find.byType(Scrollable).first;
    for (final keyword in [
      'GitHub',
      'api.nmb.best',
      'api.nmb.fastmirror.org',
    ]) {
      await tester.scrollUntilVisible(
        find.textContaining(keyword),
        300,
        scrollable: scrollable,
      );
      expect(find.textContaining(keyword), findsWidgets, reason: keyword);
    }
    await tester.scrollUntilVisible(
      find.textContaining('https://www.nmbxd.com'),
      300,
      scrollable: scrollable,
    );
    expect(find.textContaining('https://www.nmbxd.com'), findsWidgets);
  });
}
