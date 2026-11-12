# anchored_slivers

Slivers that keep what the user is looking at still while the content around it changes size.

> Status: prototype. The API may change.

With a regular `SliverList`, when an item above the viewport (for example in the cache area) changes height —
an image finishes loading, text is expanded — everything below it shifts, and the content on screen jumps.
The same happens when items are inserted at the top.

`SliverAnchoredList` and `SliverAnchoredMasonry` lay their children out *outwards from an anchor* instead of
downwards from the first child. The item under the anchor line (the middle of the viewport by default) stays
exactly where it is; size changes are absorbed above or below it.

They are ordinary slivers: put them in any `CustomScrollView` next to `SliverAppBar`,
`SliverPersistentHeader`, `SliverToBoxAdapter`, other lists, and so on. No custom scroll view, scroll
controller or physics is required.

## Usage

```dart
CustomScrollView(
  slivers: [
    const SliverAppBar(title: Text('Feed'), floating: true),
    SliverAnchoredList.builder(
      itemCount: posts.length,
      // Needed only to keep the position across insertions/removals,
      // exactly as with SliverList.
      findChildIndexCallback: (key) => indexOfPost((key as ValueKey<int>).value),
      itemBuilder: (context, index) =>
          PostTile(key: ValueKey(posts[index].id), post: posts[index]),
    ),
  ],
)
```

A masonry (waterfall) grid whose lane count follows the available width:

```dart
SliverAnchoredMasonry.extent(
  maxCrossAxisExtent: 240,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  delegate: SliverChildBuilderDelegate(
    (context, index) => Tile(key: ValueKey(items[index].id), item: items[index]),
    childCount: items.length,
  ),
)
```

Items fill the first row from the start, then each new item goes below the shortest lane. Every lane keeps its
item at the anchor line still, so the row of items across the middle of the screen does not move. When the lane
count changes (rotation, a split view opening), the layout is rebuilt around the item in the middle of that row.

### Anchor

`anchorAlignment` places the anchor line inside the visible part of the sliver: `0.0` leading edge, `0.5`
middle (default), `1.0` trailing edge.

A `SliverAnchorController` is optional:

```dart
final anchor = SliverAnchorController();

anchor.anchorIndex;              // index the last layout was anchored to
anchor.laneCount;                // lanes used by the last layout
anchor.pinnedIndex = 42;         // force an item to be the anchor while it is laid out
anchor.jumpToIndex(120, alignment: 0.5); // show item 120 in the middle
```

## Behaviour worth knowing

- When the anchor item itself changes size, its leading edge stays put.
- At scroll offset zero the leading edge stays put instead (content grows downwards), so no gap opens above the
  first item.
- The scroll offset is an estimate: it is not a reliable "pixels from the top". Use the controller to locate or
  restore a position.
- In the masonry grid an item never changes lane once placed, so after items above have been resized the layout
  can differ from a fresh top-down layout.

See `doc/design.md` for how it works and the full list of limitations.

## License

TBD — see `LICENSE`.
