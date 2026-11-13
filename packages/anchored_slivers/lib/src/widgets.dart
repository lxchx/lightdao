import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'render_sliver_anchored.dart';

/// Element shared by the anchored slivers.
class SliverAnchoredElement extends SliverMultiBoxAdaptorElement {
  SliverAnchoredElement(super.widget);

  @override
  void performRebuild() {
    super.performRebuild();
    // The base element rewrites children's layout offsets when it rebuilds;
    // a layout pass restores them from the anchored state.
    renderObject.markNeedsLayout();
  }
}

/// A sliver list that keeps the item at the anchor line visually still when
/// items around it change size, are inserted, or are removed.
///
/// It is used exactly like [SliverList]. To keep positions across insertions
/// and removals, give children keys and provide
/// [SliverChildBuilderDelegate.findChildIndexCallback].
class SliverAnchoredList extends SliverMultiBoxAdaptorWidget {
  const SliverAnchoredList({
    super.key,
    required super.delegate,
    this.anchorAlignment = 0.5,
    this.controller,
  });

  SliverAnchoredList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    this.anchorAlignment = 0.5,
    this.controller,
  }) : super(
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            findChildIndexCallback: findChildIndexCallback,
            childCount: itemCount,
            addAutomaticKeepAlives: addAutomaticKeepAlives,
            addRepaintBoundaries: addRepaintBoundaries,
            addSemanticIndexes: addSemanticIndexes,
          ),
        );

  SliverAnchoredList.list({
    super.key,
    required List<Widget> children,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    this.anchorAlignment = 0.5,
    this.controller,
  }) : super(
          delegate: SliverChildListDelegate(
            children,
            addAutomaticKeepAlives: addAutomaticKeepAlives,
            addRepaintBoundaries: addRepaintBoundaries,
            addSemanticIndexes: addSemanticIndexes,
          ),
        );

  /// Where the anchor line sits inside the visible part of the sliver: 0.0 is
  /// the leading edge, 0.5 the middle, 1.0 the trailing edge. The item under
  /// the line is the anchor.
  final double anchorAlignment;

  /// Optional controller to read the anchor, pin it, or jump to an index.
  final SliverAnchorController? controller;

  @override
  SliverMultiBoxAdaptorElement createElement() => SliverAnchoredElement(this);

  @override
  RenderSliverAnchoredList createRenderObject(BuildContext context) {
    return RenderSliverAnchoredList(
      childManager: context as SliverMultiBoxAdaptorElement,
      anchorAlignment: anchorAlignment,
      controller: controller,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverAnchoredList renderObject) {
    renderObject
      ..anchorAlignment = anchorAlignment
      ..controller = controller;
  }

  @override
  void didUnmountRenderObject(RenderSliverAnchoredList renderObject) {
    renderObject.controller = null;
  }
}

/// A masonry (waterfall) sliver with the same anchoring as
/// [SliverAnchoredList].
///
/// Items fill the first row from the start, then each item goes below the
/// shortest lane. Every lane keeps its item at the anchor line still, so the
/// row of items across the anchor line does not move when items above change
/// size. When the lane count changes, the layout is rebuilt around the item
/// in the middle of that row, which keeps its position on screen.
class SliverAnchoredMasonry extends SliverMultiBoxAdaptorWidget {
  /// Creates a masonry sliver with a fixed number of lanes.
  const SliverAnchoredMasonry.count({
    super.key,
    required super.delegate,
    required int this.crossAxisCount,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.anchorAlignment = 0.5,
    this.controller,
  }) : maxCrossAxisExtent = null;

  /// Creates a masonry sliver whose lanes are at most [maxCrossAxisExtent]
  /// wide; the lane count follows the available cross-axis extent.
  const SliverAnchoredMasonry.extent({
    super.key,
    required super.delegate,
    required double this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.anchorAlignment = 0.5,
    this.controller,
  }) : crossAxisCount = null;

  final int? crossAxisCount;
  final double? maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  /// See [SliverAnchoredList.anchorAlignment].
  final double anchorAlignment;

  final SliverAnchorController? controller;

  @override
  SliverMultiBoxAdaptorElement createElement() => SliverAnchoredElement(this);

  @override
  RenderSliverAnchoredMasonry createRenderObject(BuildContext context) {
    return RenderSliverAnchoredMasonry(
      childManager: context as SliverMultiBoxAdaptorElement,
      crossAxisCount: crossAxisCount,
      maxCrossAxisExtent: maxCrossAxisExtent,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      anchorAlignment: anchorAlignment,
      controller: controller,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverAnchoredMasonry renderObject) {
    renderObject
      ..crossAxisCount = crossAxisCount
      ..maxCrossAxisExtent = maxCrossAxisExtent
      ..mainAxisSpacing = mainAxisSpacing
      ..crossAxisSpacing = crossAxisSpacing
      ..anchorAlignment = anchorAlignment
      ..controller = controller;
  }

  @override
  void didUnmountRenderObject(RenderSliverAnchoredMasonry renderObject) {
    renderObject.controller = null;
  }
}
