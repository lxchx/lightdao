import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Heights {
  Heights(int count, double Function(int) h)
      : values = List<ValueNotifier<double>>.generate(
            count, (int i) => ValueNotifier<double>(h(i)));
  final List<ValueNotifier<double>> values;
  ValueNotifier<double> operator [](int i) => values[i];
}

Widget item(int id, ValueNotifier<double> h) {
  return ValueListenableBuilder<double>(
    key: ValueKey<int>(id),
    valueListenable: h,
    builder: (_, double v, __) => SizedBox(height: v, child: Text('$id')),
  );
}

Widget host(List<Widget> slivers, {ScrollController? controller, double? width}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: CustomScrollView(controller: controller, slivers: slivers),
      ),
    ),
  );
}

// skipOffstage: false also finds children in the cache area.
Finder byId(int id) => find.byKey(ValueKey<int>(id), skipOffstage: false);
double top(WidgetTester t, int id) => t.getTopLeft(byId(id)).dy;
double left(WidgetTester t, int id) => t.getTopLeft(byId(id)).dx;
bool present(int id) => byId(id).evaluate().isNotEmpty;

void main() {
  group('SliverAnchoredList', () {
    late Heights h;
    late ScrollController sc;
    late SliverAnchorController ac;

    setUp(() {
      h = Heights(100, (_) => 100);
      sc = ScrollController();
      ac = SliverAnchorController();
    });

    Widget anchored() => host(<Widget>[
          SliverAnchoredList.builder(
            controller: ac,
            itemCount: 100,
            itemBuilder: (_, int i) => item(i, h[i]),
          ),
        ], controller: sc);

    testWidgets('red path: plain SliverList jumps', (WidgetTester t) async {
      await t.pumpWidget(host(<Widget>[
        SliverList.builder(itemCount: 100, itemBuilder: (_, int i) => item(i, h[i])),
      ], controller: sc));
      sc.jumpTo(3000);
      await t.pump();
      final double before = top(t, 33);
      h[28].value = 300;
      await t.pump();
      expect((top(t, 33) - before).abs(), greaterThan(100));
    });

    testWidgets('off-screen item above grows / shrinks', (WidgetTester t) async {
      await t.pumpWidget(anchored());
      sc.jumpTo(3000);
      await t.pump();
      expect(ac.anchorIndex, 33);
      final double before = top(t, 33);
      final double before31 = top(t, 31);
      h[28].value = 300;
      await t.pump();
      expect(top(t, 33), moreOrLessEquals(before, epsilon: 0.5));
      expect(top(t, 31), moreOrLessEquals(before31, epsilon: 0.5));
      h[28].value = 10;
      h[29].value = 5;
      await t.pump();
      expect(top(t, 33), moreOrLessEquals(before, epsilon: 0.5));
      expect(top(t, 35), moreOrLessEquals(before + 200, epsilon: 0.5));
    });

    testWidgets('visible item above the anchor grows', (WidgetTester t) async {
      await t.pumpWidget(anchored());
      sc.jumpTo(3000);
      await t.pump();
      final double before = top(t, 33);
      h[31].value = 180;
      await t.pump();
      expect(top(t, 33), moreOrLessEquals(before, epsilon: 0.5));
      expect(top(t, 31), moreOrLessEquals(before - 280, epsilon: 0.5));
    });

    testWidgets('anchor itself resizes: its top stays', (WidgetTester t) async {
      await t.pumpWidget(anchored());
      sc.jumpTo(3000);
      await t.pump();
      final double before = top(t, 33);
      h[33].value = 400;
      await t.pump();
      expect(top(t, 33), moreOrLessEquals(before, epsilon: 0.5));
      expect(top(t, 34), moreOrLessEquals(before + 400, epsilon: 0.5));
    });

    testWidgets('at the top the leading edge stays put', (WidgetTester t) async {
      await t.pumpWidget(anchored());
      h[1].value = 250;
      await t.pump();
      expect(top(t, 0), 0);
      expect(sc.offset, 0);
      expect(top(t, 2), 350);
    });

    testWidgets('offsets reconcile when scrolling back to the top',
        (WidgetTester t) async {
      await t.pumpWidget(anchored());
      sc.jumpTo(3000);
      await t.pump();
      h[28].value = 300;
      h[29].value = 20;
      await t.pump();
      for (int i = 0; i < 80; i++) {
        sc.jumpTo((sc.offset - 90).clamp(0, double.infinity));
        await t.pump();
        if (present(0) && top(t, 0) >= 0) break;
      }
      sc.jumpTo(0);
      await t.pump();
      await t.pump();
      expect(sc.offset, 0);
      expect(top(t, 0), moreOrLessEquals(0, epsilon: 0.5));
      expect(top(t, 1), moreOrLessEquals(100, epsilon: 0.5));
    });

    testWidgets('reaches the true end', (WidgetTester t) async {
      await t.pumpWidget(anchored());
      sc.jumpTo(3000);
      await t.pump();
      h[28].value = 300;
      await t.pump();
      for (int i = 0; i < 200 && sc.offset < sc.position.maxScrollExtent; i++) {
        sc.jumpTo(sc.position.maxScrollExtent);
        await t.pump();
      }
      expect(present(99), isTrue);
      expect(top(t, 99) + 100, moreOrLessEquals(600, epsilon: 0.5));
    });

    testWidgets('head insertion keeps the anchor (keys + findChildIndexCallback)',
        (WidgetTester t) async {
      List<int> ids = List<int>.generate(60, (int i) => i);
      final ValueNotifier<double> fixed = ValueNotifier<double>(100);
      late StateSetter setState;
      await t.pumpWidget(StatefulBuilder(builder: (_, StateSetter s) {
        setState = s;
        final List<int> current = ids;
        return host(<Widget>[
          SliverAnchoredList.builder(
            controller: ac,
            itemCount: current.length,
            findChildIndexCallback: (Key k) {
              final int i = current.indexOf((k as ValueKey<int>).value);
              return i < 0 ? null : i;
            },
            itemBuilder: (_, int i) => item(current[i], fixed),
          ),
        ], controller: sc);
      }));
      sc.jumpTo(2000);
      await t.pump();
      final double before = top(t, 23);
      setState(() => ids = <int>[for (int i = 0; i < 15; i++) 1000 + i, ...ids]);
      await t.pump();
      expect(top(t, 23), moreOrLessEquals(before, epsilon: 0.5));
      expect(ac.anchorIndex, 38);
      // And a small prepend, overlapping the live range.
      setState(() => ids = <int>[2000, 2001, ...ids]);
      await t.pump();
      expect(top(t, 23), moreOrLessEquals(before, epsilon: 0.5));
      // Removal above.
      setState(() => ids = ids.sublist(5));
      await t.pump();
      expect(top(t, 23), moreOrLessEquals(before, epsilon: 0.5));
    });

    testWidgets('works between other slivers', (WidgetTester t) async {
      await t.pumpWidget(MaterialApp(
        home: CustomScrollView(controller: sc, slivers: <Widget>[
          const SliverAppBar(pinned: true, expandedHeight: 200, title: Text('t')),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
          SliverAnchoredList.builder(
            controller: ac,
            itemCount: 100,
            itemBuilder: (_, int i) => item(i, h[i]),
          ),
          SliverList.builder(
              itemCount: 20,
              itemBuilder: (_, int i) => SizedBox(height: 50, child: Text('tail$i'))),
        ]),
      ));
      sc.jumpTo(3320);
      await t.pump();
      final int a = ac.anchorIndex!;
      final double before = top(t, a);
      h[a - 4].value = 333;
      h[a - 2].value = 7;
      await t.pump();
      expect(top(t, a), moreOrLessEquals(before, epsilon: 0.5));
      // Scroll into the trailing sliver and back to the start.
      sc.jumpTo(sc.position.maxScrollExtent);
      await t.pump();
      sc.jumpTo(sc.position.maxScrollExtent);
      await t.pump();
      expect(find.text('tail19'), findsOneWidget);
      sc.jumpTo(0);
      await t.pump();
      await t.pump();
      expect(top(t, 0), moreOrLessEquals(320, epsilon: 0.5));
    });

    testWidgets('holds while dragging and during a fling', (WidgetTester t) async {
      await t.pumpWidget(anchored());
      sc.jumpTo(3000);
      await t.pump();
      final TestGesture g = await t.startGesture(const Offset(400, 300));
      await g.moveBy(const Offset(0, -60));
      await t.pump();
      final double before = top(t, 34);
      h[29].value = 260;
      await t.pump();
      expect(top(t, 34), moreOrLessEquals(before, epsilon: 0.5));
      await g.moveBy(const Offset(0, -10));
      await t.pump();
      expect(top(t, 34), moreOrLessEquals(before - 10, epsilon: 0.5));
      await g.up();
      await t.pumpAndSettle();

      await t.fling(find.byType(CustomScrollView), const Offset(0, 300), 2000);
      await t.pump(const Duration(milliseconds: 16));
      double last = sc.offset;
      for (int i = 0; i < 40; i++) {
        final int? a = ac.anchorIndex;
        if (i == 5 && a != null && a > 6) h[a - 5].value = 400;
        await t.pump(const Duration(milliseconds: 16));
        final double now = sc.offset;
        // A correction may relabel the offset, but the fling keeps going up.
        if (i != 5 && i != 6) expect(now, lessThanOrEqualTo(last + 0.5));
        last = now;
      }
      await t.pumpAndSettle();
    });

    testWidgets('jumpToIndex and pinnedIndex', (WidgetTester t) async {
      await t.pumpWidget(anchored());
      ac.jumpToIndex(70);
      await t.pump();
      expect(top(t, 70), moreOrLessEquals(0, epsilon: 0.5));
      ac.jumpToIndex(40, alignment: 0.5);
      await t.pump();
      expect(top(t, 40), moreOrLessEquals(300, epsilon: 0.5));
      ac.pinnedIndex = 44;
      await t.pump();
      final double before = top(t, 44);
      h[42].value = 10;
      await t.pump();
      expect(ac.anchorIndex, 44);
      expect(top(t, 44), moreOrLessEquals(before, epsilon: 0.5));
    });

    testWidgets('fuzz: anchor never moves, children never overlap',
        (WidgetTester t) async {
      await t.pumpWidget(anchored());
      int seed = 12345;
      int next(int n) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed % n;
      }

      sc.jumpTo(4000);
      await t.pump();
      for (int step = 0; step < 300; step++) {
        if (next(3) == 0) {
          sc.jumpTo((sc.offset + next(700) - 350)
              .clamp(0.0, sc.position.maxScrollExtent));
          await t.pump();
          continue;
        }
        final int a = ac.anchorIndex!;
        if (sc.offset <= 0 || !present(a)) continue;
        final double before = top(t, a);
        for (int k = 0; k < 3; k++) {
          final int target = a - 8 + next(16);
          if (target == a || target < 0 || target > 99) continue;
          h[target].value = 20.0 + next(300);
        }
        await t.pump();
        if (present(0) && top(t, 0) >= -0.5) continue; // leading edge pinned
        expect(top(t, a), moreOrLessEquals(before, epsilon: 0.5),
            reason: 'step $step anchor $a');
        // Contiguity of what is on screen.
        for (int i = a - 2; i < a + 2; i++) {
          if (i < 0 || !present(i) || !present(i + 1)) continue;
          expect(top(t, i + 1), moreOrLessEquals(top(t, i) + h[i].value, epsilon: 0.5));
        }
      }
    });
  });

  group('SliverAnchoredMasonry', () {
    late Heights h;
    late ScrollController sc;
    late SliverAnchorController ac;

    setUp(() {
      h = Heights(300, (int i) => 80.0 + (i * 37 % 7) * 30);
      sc = ScrollController();
      ac = SliverAnchorController();
    });

    Widget masonry({double? width, int? count, double? maxExtent}) => host(<Widget>[
          if (count != null)
            SliverAnchoredMasonry.count(
              controller: ac,
              crossAxisCount: count,
              delegate: SliverChildBuilderDelegate(
                  (_, int i) => item(i, h[i]),
                  childCount: 300),
            )
          else
            SliverAnchoredMasonry.extent(
              controller: ac,
              maxCrossAxisExtent: maxExtent!,
              delegate: SliverChildBuilderDelegate(
                  (_, int i) => item(i, h[i]),
                  childCount: 300),
            ),
        ], controller: sc, width: width);

    /// Ids of visible items crossing the horizontal line at [y].
    List<int> rowAt(WidgetTester t, double y) {
      final List<int> out = <int>[];
      for (int i = 0; i < 300; i++) {
        if (!present(i)) continue;
        final Rect r = t.getRect(byId(i));
        if (r.top <= y && r.bottom > y) out.add(i);
      }
      return out;
    }

    testWidgets('placement rule: first row, then shortest lane',
        (WidgetTester t) async {
      await t.pumpWidget(masonry(count: 4));
      final List<double> ends = List<double>.filled(4, 0);
      for (int i = 0; i < 20; i++) {
        int lane = 0;
        for (int l = 1; l < 4; l++) {
          if (ends[l] < ends[lane]) lane = l;
        }
        if (ends[lane] >= 600 + 250) break;
        expect(left(t, i), moreOrLessEquals(lane * 200.0, epsilon: 0.5), reason: 'item $i');
        expect(top(t, i), moreOrLessEquals(ends[lane], epsilon: 0.5), reason: 'item $i');
        ends[lane] += h[i].value;
      }
    });

    testWidgets('row at the anchor line stays when items above resize',
        (WidgetTester t) async {
      await t.pumpWidget(masonry(count: 4));
      sc.jumpTo(3000);
      await t.pump();
      final List<int> row = rowAt(t, 300);
      expect(row.length, 4);
      final Map<int, double> before = <int, double>{for (final int i in row) i: top(t, i)};
      final int lo = row.reduce((int a, int b) => a < b ? a : b);
      // Resize a bunch of items above the row (visible and cached).
      int changed = 0;
      for (int i = lo - 1; i > lo - 14; i--) {
        if (!present(i)) continue;
        h[i].value = h[i].value + (i.isEven ? 90 : -40);
        changed++;
      }
      expect(changed, greaterThan(4));
      await t.pump();
      for (final int i in row) {
        expect(top(t, i), moreOrLessEquals(before[i]!, epsilon: 0.5), reason: 'item $i');
      }
    });

    testWidgets('scrolling back to the top realigns every lane',
        (WidgetTester t) async {
      await t.pumpWidget(masonry(count: 4));
      sc.jumpTo(3000);
      await t.pump();
      final int lo = rowAt(t, 300).reduce((int a, int b) => a < b ? a : b);
      for (int i = lo - 1; i > lo - 10; i--) {
        if (present(i)) h[i].value += 75.0 + i % 3 * 20;
      }
      await t.pump();
      while (sc.offset > 0) {
        sc.jumpTo((sc.offset - 80).clamp(0.0, double.infinity));
        await t.pump();
      }
      await t.pump();
      expect(sc.offset, 0);
      for (int i = 0; i < 4; i++) {
        expect(top(t, i), moreOrLessEquals(0, epsilon: 0.5));
      }
      // No overlaps anywhere on screen.
      final List<Rect> rects = <Rect>[
        for (int i = 0; i < 60; i++)
          if (present(i)) t.getRect(byId(i)),
      ];
      for (int a = 0; a < rects.length; a++) {
        for (int b = a + 1; b < rects.length; b++) {
          expect(rects[a].deflate(0.5).overlaps(rects[b].deflate(0.5)), isFalse);
        }
      }
    });

    for (final (double from, double to) in <(double, double)>[
      (800, 480),
      (800, 320),
      (800, 160),
      (320, 800),
    ]) {
      testWidgets('lane count change $from -> $to keeps the centre row in view',
          (WidgetTester t) async {
        await t.pumpWidget(masonry(width: from, maxExtent: 160));
        sc.jumpTo(3000);
        await t.pump();
        final int lanesBefore = ac.laneCount!;
        final List<int> row = rowAt(t, 300);
        final int a = ac.anchorIndex!;
        expect(row, contains(a));
        final double before = top(t, a);

        await t.pumpWidget(masonry(width: to, maxExtent: 160));
        await t.pump();
        expect(ac.laneCount, isNot(lanesBefore));
        expect(top(t, a), moreOrLessEquals(before, epsilon: 0.5));
        const Rect viewport = Rect.fromLTWH(0, 0, 800, 600);
        int visible = 0;
        for (final int i in row) {
          if (present(i) && t.getRect(byId(i)).overlaps(viewport)) {
            visible++;
          }
        }
        if (ac.laneCount! >= 2 || row.length <= 3) {
          expect(visible, row.length, reason: 'row $row');
        } else {
          expect(visible, greaterThanOrEqualTo(2), reason: 'row $row');
        }
        // Layout is still gap-free and overlap-free.
        final List<Rect> rects = <Rect>[
          for (int i = 0; i < 300; i++)
            if (present(i)) t.getRect(byId(i)),
        ];
        for (int x = 0; x < rects.length; x++) {
          for (int y = x + 1; y < rects.length; y++) {
            expect(rects[x].deflate(0.5).overlaps(rects[y].deflate(0.5)), isFalse);
          }
        }
        // Still scrollable both ways without errors.
        sc.jumpTo(sc.offset + 900);
        await t.pump();
        sc.jumpTo(0);
        await t.pump();
        await t.pump();
        expect(top(t, 0), moreOrLessEquals(0, epsilon: 0.5));
      });
    }

    testWidgets('width change without lane change keeps lane anchors',
        (WidgetTester t) async {
      await t.pumpWidget(masonry(width: 800, count: 4));
      sc.jumpTo(3000);
      await t.pump();
      final List<int> row = rowAt(t, 300);
      final Map<int, double> before = <int, double>{for (final int i in row) i: top(t, i)};
      await t.pumpWidget(masonry(width: 600, count: 4));
      for (final int i in row) {
        expect(top(t, i), moreOrLessEquals(before[i]!, epsilon: 0.5));
      }
    });
  });
}
