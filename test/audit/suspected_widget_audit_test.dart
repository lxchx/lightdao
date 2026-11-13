// 审计用例：审计报告「疑似问题」一节的定点测试（不修的产品行为不做断言）。
//
// 对应 flutter-scroll/dist/lightdao-bugs-20261113.md 的疑似 #1 / #3 等。
// 运行：flutter test test/audit/suspected_widget_audit_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/data/phrase.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/ui/page/thread.dart' show ReplyJsonWithPage;
import 'package:lightdao/ui/page/xdao_image_viewer.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:provider/provider.dart';

class FakeAppState extends MyAppState {
  FakeAppState() {
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
    );
  }

  @override
  Future<void> saveSettings() async {}

  @override
  Future<void> loadSettings() async {}
}

void main() {
  group('疑似#1 图片查看器的空列表 / 越界下标', () {
    testWidgets('空图片列表：不崩，页面自动关掉', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => XdaoImageViewer(
                        imageNames: const <String>[],
                        initIndex: 0,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(XdaoImageViewer), findsNothing, reason: '空列表要自动关掉');
      expect(find.text('open'), findsOneWidget, reason: '回到上一页');
    });

    testWidgets('initIndex 越界：不抛 RangeError', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MyAppState>.value(
          value: FakeAppState(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => XdaoImageViewer(
                          imageNames: const ['only.jpg'],
                          initIndex: 9,
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      // 不能用 pumpAndSettle：图片加载指示器是永不静止的动画
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.takeException(),
        isNull,
        reason: '越界下标会让 build 抛 RangeError',
      );
      expect(find.byType(XdaoImageViewer), findsOneWidget, reason: '越界不应把页面关掉');

      await tester.pumpWidget(const SizedBox());
    });

    test('clampImageIndex 的边界', () {
      expect(clampImageIndex(0, 1), 0);
      expect(clampImageIndex(-1, 3), 0, reason: 'indexOf 未命中时是 -1');
      expect(clampImageIndex(9, 3), 2);
      expect(clampImageIndex(1, 3), 1);
      expect(clampImageIndex(5, 0), 0, reason: '空列表返回 0，由调用方先判长度');
    });
  });
}
