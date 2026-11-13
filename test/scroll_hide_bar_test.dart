import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lightdao/ui/widget/scroll_hide_bar.dart';

class _Host extends StatefulWidget {
  const _Host({required this.fixed});
  final bool fixed;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final hide = ScrollHideController(vsync: this);
  @override
  void dispose() {
    hide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: hide.handleNotification,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                key: const Key('top'),
                floating: true,
                pinned: widget.fixed,
                title: const Text('title'),
              ),
              SliverAnchoredList.builder(
                itemCount: 200,
                itemBuilder: (c, i) =>
                    SizedBox(height: 80, child: Text('item $i')),
              ),
            ],
          ),
        ),
        bottomNavigationBar: ScrollHideBottomBar(
          key: const Key('bottom'),
          controller: hide,
          height: 60,
          fixed: widget.fixed,
          child: const ColoredBox(color: Colors.red),
        ),
      ),
    );
  }
}

void main() {
  double bottomH(WidgetTester t) =>
      t.getSize(find.byKey(const Key('bottom'))).height;
  double topBottom(WidgetTester t) =>
      // A sliver that paints nothing is reported as offstage by the viewport.
      (t.renderObject(find.byKey(const Key('top'), skipOffstage: false))
              as RenderSliver)
          .geometry!
          .paintExtent;

  testWidgets('bars follow the finger one-to-one and settle on release', (
    t,
  ) async {
    await t.pumpWidget(const _Host(fixed: false));
    expect(bottomH(t), 60);
    expect(topBottom(t), 56);

    final g = await t.startGesture(const Offset(200, 300));
    await g.moveBy(const Offset(0, -30)); // crosses touch slop
    await t.pump();
    final h0 = bottomH(t), top0 = topBottom(t);
    await g.moveBy(const Offset(0, -15));
    await t.pump();
    // 15 px of scroll: both bars retract by 15 px.
    expect(h0 - bottomH(t), closeTo(15, 0.01));
    expect(top0 - topBottom(t), closeTo(15, 0.01));
    expect(bottomH(t), greaterThan(0));

    // Reverse: they come back by the same amount.
    await g.moveBy(const Offset(0, 10));
    await t.pump();
    expect(bottomH(t), closeTo(h0 - 5, 0.01));
    expect(topBottom(t), closeTo(top0 - 5, 0.01));

    await g.moveBy(const Offset(0, -40));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(bottomH(t), anyOf(0.0, 60.0)); // settled to an end, never halfway

    // Scroll far down then back: fully hidden, then fully shown.
    await t.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await t.pumpAndSettle();
    expect(bottomH(t), 0);
    expect(topBottom(t), lessThanOrEqualTo(0));
    // Pump between moves like a real drag: the floating app bar reads the
    // scroll direction at layout time.
    final g2 = await t.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await g2.moveBy(const Offset(0, 20));
      await t.pump();
    }
    await g2.up();
    await t.pumpAndSettle();
    expect(bottomH(t), 60);
    expect(topBottom(t), 56);
    expect(t.takeException(), isNull);
  });

  testWidgets('fixed setting keeps both bars', (t) async {
    await t.pumpWidget(const _Host(fixed: true));
    await t.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await t.pumpAndSettle();
    expect(bottomH(t), 60);
    expect(topBottom(t), 56);
  });
}
