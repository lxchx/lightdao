import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Reproduction for the reported "first post lands in the right column after
// 1 -> 2 lanes" behaviour. The viewport is 400x600 with 80px tall items, so
// with two lanes a card is 200px wide and the lanes start at x=0 and x=200.

const int _itemCount = 20;

Widget _host(int lanes) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 400,
        height: 600,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAnchoredMasonry.count(
              crossAxisCount: lanes,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => SizedBox(
                  key: ValueKey<int>(index),
                  height: 80,
                  child: Text('$index'),
                ),
                childCount: _itemCount,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Finder _byId(int id) => find.byKey(ValueKey<int>(id), skipOffstage: false);
double _dx(WidgetTester t, int id) => t.getTopLeft(_byId(id)).dx;
double _dy(WidgetTester t, int id) => t.getTopLeft(_byId(id)).dy;

void main() {
  testWidgets('one lane -> two lanes at the top keeps the first item left',
      (WidgetTester t) async {
    t.view.physicalSize = const Size(400, 600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(_host(1));
    // One lane: everything is stacked in the (only) lane at x=0.
    expect(_dx(t, 0), 0.0);
    expect(_dx(t, 1), 0.0);
    expect(_dy(t, 0), 0.0);

    await t.pumpWidget(_host(2));
    await t.pump();

    // Same head order a freshly built two-lane grid has: item 0 in the left
    // lane (x=0), item 1 in the right lane (x=204 = lane width 196 + 8pt gap).
    expect(_dx(t, 0), 0.0, reason: 'first item must stay in the left lane');
    expect(_dx(t, 1), 204.0, reason: 'second item takes the right lane');
    expect(_dy(t, 0), 0.0);
  });

  testWidgets('two lanes -> one lane at the top keeps the index order',
      (WidgetTester t) async {
    t.view.physicalSize = const Size(400, 600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(_host(2));
    expect(_dx(t, 0), 0.0);
    expect(_dx(t, 1), 204.0);

    await t.pumpWidget(_host(1));
    await t.pump();

    expect(_dx(t, 0), 0.0);
    expect(_dx(t, 1), 0.0);
    expect(_dy(t, 1), greaterThan(_dy(t, 0)));
    expect(_dy(t, 1), lessThanOrEqualTo(88.0 + 0.5),
        reason: 'item 1 must sit directly below item 0, as a fresh one-lane '
            'layout puts it (80 + 8pt spacing)');
  });

  testWidgets('one lane -> three lanes at the top fills lanes in index order',
      (WidgetTester t) async {
    t.view.physicalSize = const Size(400, 600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(_host(1));

    await t.pumpWidget(_host(3));
    await t.pump();

    // Three lanes are 128 wide with an 8pt gap, so a fresh grid puts items
    // 0/1/2 at x = 0 / 136 / 272 on the first row.
    expect(_dx(t, 0), 0.0);
    expect(_dx(t, 1), 136.0);
    expect(_dx(t, 2), 272.0);
    expect(_dy(t, 0), 0.0);
    expect(_dy(t, 1), 0.0);
    expect(_dy(t, 2), 0.0);
  });
}
