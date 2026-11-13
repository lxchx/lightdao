import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

// A floating app bar above an anchored list, entered in the middle (as a
// "jump to page" does), then dragged back up in small steps. Once the bar is
// fully shown it must stay fully shown; records its paint extent per frame.
Future<List<double>> dragUp(
  WidgetTester t, {
  required Widget Function(
          List<Widget> slivers, ScrollController sc, SliverAnchorController ac)
      shell,
  required double Function() shown,
}) async {
  final ScrollController sc = ScrollController();
  final SliverAnchorController ac = SliverAnchorController();
  // The items above the entry point are much taller than the ones built
  // first, so the scroll offset estimated for them is too small and has to
  // be corrected while the user scrolls back up.
  double h(int i) => i < 12 ? 700.0 : 90.0;
  await t.pumpWidget(MaterialApp(
    home: shell(<Widget>[
      SliverAnchoredList.builder(
        controller: ac,
        itemCount: 200,
        itemBuilder: (_, int i) =>
            SizedBox(key: ValueKey<int>(i), height: h(i), child: Text('$i')),
      ),
    ], sc, ac),
  ));
  ac.jumpToIndex(14);
  await t.pump();
  await t.pump();
  final TestGesture g = await t.startGesture(const Offset(400, 300));
  final List<double> out = <double>[];
  for (int i = 0; i < 600; i++) {
    await g.moveBy(const Offset(0, 14));
    await t.pump(const Duration(milliseconds: 16));
    out.add(shown());
  }
  // ignore: avoid_print
  print('trace: ${out.map((double x) => x.round()).join(' ')}');
  await g.up();
  await t.pumpAndSettle();
  return out;
}

int dips(List<double> v, double full) {
  int n = 0;
  bool reached = false;
  for (final double x in v) {
    if (x >= full - 0.5) {
      reached = true;
    } else if (reached) {
      n++;
    }
  }
  return n;
}

void main() {
  testWidgets('red path: floating SliverAppBar dips on scroll corrections',
      (WidgetTester t) async {
    final List<double> v = await dragUp(
      t,
      shell: (List<Widget> slivers, ScrollController sc, _) => CustomScrollView(
        controller: sc,
        slivers: <Widget>[
          const SliverAppBar(floating: true, title: Text('bar')),
          ...slivers,
        ],
      ),
      shown: () => t
          .renderObject<RenderSliver>(
              find.byType(SliverAppBar, skipOffstage: false))
          .geometry!
          .paintExtent,
    );
    final int c = t
        .renderObject<RenderSliverAnchoredMasonry>(
            find.byType(SliverAnchoredList, skipOffstage: false))
        .debugCorrectionCount;
    // ignore: avoid_print
    print('corrections=$c dips=${dips(v, kToolbarHeight)} min-after-full='
        '${v.skipWhile((double x) => x < kToolbarHeight - 0.5).fold<double>(kToolbarHeight, (double a, double b) => a < b ? a : b)}');
    expect(c, greaterThan(0));
    expect(dips(v, kToolbarHeight), greaterThan(0));
  });

  testWidgets('SliverAnchoredFloatingHeader ignores scroll corrections',
      (WidgetTester t) async {
    RenderSliverAnchoredFloatingHeader header() => t.renderObject(
        find.byType(SliverAnchoredFloatingHeader, skipOffstage: false));
    late ScrollController ctl;
    final List<double> v = await dragUp(
      t,
      shell: (List<Widget> slivers, ScrollController sc,
          SliverAnchorController ac) {
        ctl = sc;
        return CustomScrollView(
          controller: sc,
          slivers: <Widget>[
            SliverAnchoredFloatingHeader(
              controller: ac,
              extent: kToolbarHeight,
              child: AppBar(primary: false, title: const Text('bar')),
            ),
            ...slivers,
          ],
        );
      },
      shown: () => header().geometry!.paintExtent,
    );
    final int c = t
        .renderObject<RenderSliverAnchoredMasonry>(
            find.byType(SliverAnchoredList, skipOffstage: false))
        .debugCorrectionCount;
    // ignore: avoid_print
    print('fixed: corrections=$c dips=${dips(v, kToolbarHeight)}');
    expect(c, greaterThan(0));
    expect(dips(v, kToolbarHeight), 0);

    // Still follows the finger: at the top now; drag down hides it 1:1,
    // drag back shows it 1:1, and the bar is painted where it is reported.
    expect(ctl.offset, greaterThan(kToolbarHeight));
    final TestGesture g = await t.startGesture(const Offset(400, 300));
    await g.moveBy(const Offset(0, -30)); // touch slop
    await t.pump();
    final double base = header().geometry!.paintExtent;
    await g.moveBy(const Offset(0, -20));
    await t.pump();
    expect(header().geometry!.paintExtent, closeTo(base - 20, 0.01));
    await g.moveBy(const Offset(0, -300));
    await t.pump();
    expect(header().geometry!.paintExtent, 0.0);
    await g.moveBy(const Offset(0, 25));
    await t.pump();
    expect(header().geometry!.paintExtent, closeTo(25, 0.01));
    expect(t.getTopLeft(find.byType(AppBar)).dy, closeTo(25 - kToolbarHeight, 0.01));
    await g.up();
    await t.pumpAndSettle();
  });
}
