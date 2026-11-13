import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder byId(int id) => find.byKey(ValueKey<int>(id), skipOffstage: false);
bool present(int id) => byId(id).evaluate().isNotEmpty;

class Rng {
  Rng(this.seed);
  int seed;
  int next(int n) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return (seed >> 8) % n;
  }
}

Widget box(int id, ValueNotifier<double> h, {Axis axis = Axis.vertical}) {
  return ValueListenableBuilder<double>(
    key: ValueKey<int>(id),
    valueListenable: h,
    builder: (_, double v, __) => axis == Axis.vertical
        ? SizedBox(height: v, child: Text('$id'))
        : SizedBox(width: v, child: Text('$id')),
  );
}

void main() {
  const Rect viewport = Rect.fromLTWH(0, 0, 800, 600);

  // One tree walk instead of one finder per id.
  Map<int, Rect> rects(WidgetTester t, int count) {
    final Map<int, Rect> out = <int, Rect>{};
    for (final Element e in find
        .byType(ValueListenableBuilder<double>, skipOffstage: false)
        .evaluate()) {
      final RenderBox box = e.renderObject! as RenderBox;
      out[(e.widget.key! as ValueKey<int>).value] =
          box.localToGlobal(Offset.zero) & box.size;
    }
    return out;
  }

  void expectNoOverlap(Map<int, Rect> r, String reason) {
    final List<MapEntry<int, Rect>> e = r.entries.toList();
    for (int a = 0; a < e.length; a++) {
      for (int b = a + 1; b < e.length; b++) {
        final int ka = e[a].key;
        final int kb = e[b].key;
        expect(e[a].value.deflate(0.5).overlaps(e[b].value.deflate(0.5)), isFalse,
            reason: '$reason: $ka overlaps $kb');
      }
    }
  }

  for (final int lanes in <int>[1, 3, 5]) {
    for (final int seed in <int>[1, 7, 99]) {
      testWidgets('fuzz lanes=$lanes seed=$seed', (WidgetTester t) async {
        const int count = 400;
        final Rng rng = Rng(seed);
        final List<ValueNotifier<double>> h = List<ValueNotifier<double>>.generate(
            count, (_) => ValueNotifier<double>(40.0 + rng.next(260)));
        final ScrollController sc = ScrollController();
        final SliverAnchorController ac = SliverAnchorController();
        await t.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: CustomScrollView(controller: sc, slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
            SliverAnchoredMasonry.count(
              controller: ac,
              crossAxisCount: lanes,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              delegate: SliverChildBuilderDelegate((_, int i) => box(i, h[i]),
                  childCount: count),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 150)),
          ]),
        ));
        for (int step = 0; step < 400; step++) {
          final int action = rng.next(10);
          if (action < 3) {
            sc.jumpTo((sc.offset + rng.next(1200) - 600)
                .clamp(0.0, sc.position.maxScrollExtent));
            await t.pump();
          } else if (action == 3) {
            sc.jumpTo(rng.next(3) == 0
                ? 0.0
                : rng.next(sc.position.maxScrollExtent.toInt() + 1).toDouble());
            await t.pump();
          } else {
            // Resize items that do not touch the anchor line; everything
            // touching the line must stay exactly where it is.
            final Map<int, Rect> before = rects(t, count);
            final List<int> row = <int>[
              for (final MapEntry<int, Rect> e in before.entries)
                if (e.value.top <= 300 && e.value.bottom > 300) e.key,
            ];
            if (row.isEmpty) continue;
            final int lo = row.reduce((int a, int b) => a < b ? a : b);
            final int hi = row.reduce((int a, int b) => a > b ? a : b);
            for (int k = 0; k < 4; k++) {
              final int target = rng.next(2) == 0 ? lo - 1 - rng.next(12) : hi + 1 + rng.next(12);
              if (target < 0 || target >= count || row.contains(target)) continue;
              h[target].value = 20.0 + rng.next(320);
            }
            final double offsetBefore = sc.offset;
            await t.pump();
            final Map<int, Rect> after = rects(t, count);
            final bool nearStart = after[0] != null && after[0]!.top > -700;
            if (!nearStart && offsetBefore > 150 + 600) {
              for (final int i in row) {
                expect(after[i]!.top, moreOrLessEquals(before[i]!.top, epsilon: 0.5),
                    reason: 'step $step item $i (row $row)');
              }
            }
          }
          expect(t.takeException(), isNull, reason: 'step $step');
          final Map<int, Rect> now = rects(t, count);
          expectNoOverlap(now, 'step $step');
          // The viewport is never left blank while content exists.
          final double off = sc.offset;
          if (off > 150 && off < sc.position.maxScrollExtent - 150) {
            expect(now.values.any((Rect r) => r.overlaps(viewport)), isTrue,
                reason: 'blank viewport at step $step offset $off');
          }
        }
        // End state: go to the top, everything lines up again.
        sc.jumpTo(0);
        await t.pump();
        await t.pump();
        final Map<int, Rect> end = rects(t, count);
        for (int i = 0; i < lanes; i++) {
          expect(end.containsKey(i), isTrue,
              reason: 'item $i missing; offset ${sc.offset}; have ${end.keys.toList()..sort()}');
          expect(end[i]!.top, moreOrLessEquals(150, epsilon: 0.5), reason: 'item $i');
        }
        // And to the very end.
        for (int i = 0; i < 50; i++) {
          sc.jumpTo(sc.position.maxScrollExtent);
          await t.pump();
        }
        expect(present(count - 1), isTrue);
        final Map<int, Rect> tail = rects(t, count);
        final double maxBottom =
            tail.values.map((Rect r) => r.bottom).reduce((double a, double b) => a > b ? a : b);
        expect(maxBottom, moreOrLessEquals(600 - 150, epsilon: 0.5));
      });
    }
  }

  testWidgets('reverse: true', (WidgetTester t) async {
    final List<ValueNotifier<double>> h =
        List<ValueNotifier<double>>.generate(100, (_) => ValueNotifier<double>(100));
    final ScrollController sc = ScrollController();
    final SliverAnchorController ac = SliverAnchorController();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: CustomScrollView(reverse: true, controller: sc, slivers: <Widget>[
        SliverAnchoredList.builder(
            controller: ac, itemCount: 100, itemBuilder: (_, int i) => box(i, h[i])),
      ]),
    ));
    expect(t.getRect(byId(0)).bottom, 600);
    sc.jumpTo(3000);
    await t.pump();
    final int a = ac.anchorIndex!;
    final Rect before = t.getRect(byId(a));
    h[a - 4].value = 300; // below the anchor on screen, earlier in the list
    await t.pump();
    // In a reversed list the item's leading edge is its bottom edge.
    expect(t.getRect(byId(a)).bottom, moreOrLessEquals(before.bottom, epsilon: 0.5));
  });

  testWidgets('horizontal', (WidgetTester t) async {
    final List<ValueNotifier<double>> h =
        List<ValueNotifier<double>>.generate(100, (_) => ValueNotifier<double>(100));
    final ScrollController sc = ScrollController();
    final SliverAnchorController ac = SliverAnchorController();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: CustomScrollView(scrollDirection: Axis.horizontal, controller: sc, slivers: <Widget>[
        SliverAnchoredList.builder(
            controller: ac,
            itemCount: 100,
            itemBuilder: (_, int i) => box(i, h[i], axis: Axis.horizontal)),
      ]),
    ));
    sc.jumpTo(3000);
    await t.pump();
    final int a = ac.anchorIndex!;
    final double before = t.getRect(byId(a)).left;
    h[a - 5].value = 333;
    await t.pump();
    expect(t.getRect(byId(a)).left, moreOrLessEquals(before, epsilon: 0.5));
  });

  testWidgets('empty, short, growing and shrinking lists', (WidgetTester t) async {
    int count = 0;
    final ScrollController sc = ScrollController();
    late StateSetter setState;
    final ValueNotifier<double> h = ValueNotifier<double>(100);
    await t.pumpWidget(StatefulBuilder(builder: (_, StateSetter s) {
      setState = s;
      return Directionality(
        textDirection: TextDirection.ltr,
        child: CustomScrollView(controller: sc, slivers: <Widget>[
          SliverAnchoredList.builder(itemCount: count, itemBuilder: (_, int i) => box(i, h)),
          const SliverToBoxAdapter(child: SizedBox(height: 50, child: Text('footer'))),
        ]),
      );
    }));
    expect(t.getRect(find.text('footer')).top, 0);
    setState(() => count = 3);
    await t.pump();
    expect(t.getRect(find.text('footer')).top, 300);
    expect(sc.position.maxScrollExtent, 0);
    setState(() => count = 50);
    await t.pump();
    sc.jumpTo(sc.position.maxScrollExtent);
    await t.pump();
    sc.jumpTo(sc.position.maxScrollExtent);
    await t.pump();
    expect(find.text('footer'), findsOneWidget);
    // Shrink the list while at the end.
    setState(() => count = 8);
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(present(7), isTrue);
    expect(t.getRect(find.text('footer')).bottom, moreOrLessEquals(600, epsilon: 0.5));
    setState(() => count = 0);
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(t.getRect(find.text('footer')).top, 0);
  });

  testWidgets('keep-alive children survive and do not break layout', (WidgetTester t) async {
    final ScrollController sc = ScrollController();
    await t.pumpWidget(MaterialApp(
      home: Material(
        child: CustomScrollView(controller: sc, slivers: <Widget>[
          SliverAnchoredList.builder(
            itemCount: 100,
            itemBuilder: (_, int i) => SizedBox(
              key: ValueKey<int>(i),
              height: 100,
              child: i == 3 ? const TextField() : Text('$i'),
            ),
          ),
        ]),
      ),
    ));
    await t.enterText(find.byType(TextField), 'kept');
    await t.pump();
    sc.jumpTo(5000);
    await t.pump();
    sc.jumpTo(2000);
    await t.pump();
    sc.jumpTo(0);
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('kept'), findsOneWidget);
    expect(t.getRect(byId(3)).top, moreOrLessEquals(300, epsilon: 0.5));
  });

  testWidgets('controller: notifies, survives sliver replacement, no-ops when detached',
      (WidgetTester t) async {
    final SliverAnchorController c = SliverAnchorController();
    expect(c.jumpToIndex(3), isFalse);
    int notifications = 0;
    c.addListener(() => notifications++);
    final ScrollController sc = ScrollController();
    Widget build({required bool wrapped}) {
      final Widget scroll = CustomScrollView(controller: sc, slivers: <Widget>[
        SliverAnchoredMasonry.count(
          controller: c,
          crossAxisCount: 2,
          delegate: SliverChildBuilderDelegate(
              (_, int i) => SizedBox(height: 50, child: Text('$i')),
              childCount: 400),
        ),
      ]);
      return Directionality(
        textDirection: TextDirection.ltr,
        child: wrapped ? Row(children: <Widget>[Expanded(child: scroll)]) : scroll,
      );
    }

    await t.pumpWidget(build(wrapped: false));
    await t.pump();
    expect(notifications, greaterThan(0));
    final int n0 = notifications;
    sc.jumpTo(2000);
    await t.pump();
    await t.pump();
    expect(notifications, greaterThan(n0));
    await t.pumpWidget(build(wrapped: true)); // new element, same controller
    expect(t.takeException(), isNull);
    expect(c.isAttached, isTrue);
    expect(c.jumpToIndex(100), isTrue);
    await t.pump();
    expect(c.anchorIndex, isNotNull);
  });

  testWidgets('animateTo lands on its target while items resize', (WidgetTester t) async {
    final List<ValueNotifier<double>> h =
        List<ValueNotifier<double>>.generate(100, (_) => ValueNotifier<double>(100));
    final ScrollController sc = ScrollController();
    await t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: CustomScrollView(controller: sc, slivers: <Widget>[
        SliverAnchoredList.builder(itemCount: 100, itemBuilder: (_, int i) => box(i, h[i])),
      ]),
    ));
    sc.jumpTo(3000);
    await t.pump();
    sc.animateTo(5000, duration: const Duration(milliseconds: 300), curve: Curves.linear);
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    h[30].value = 400;
    await t.pump(const Duration(milliseconds: 100));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(sc.offset, 5000);
  });
}
