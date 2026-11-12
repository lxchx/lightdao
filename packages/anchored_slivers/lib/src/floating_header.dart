import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';

/// A fixed-height header that scrolls away with the content and comes back
/// as soon as the user scrolls the other way, like a floating `SliverAppBar`,
/// but that is not fooled by scroll offset corrections.
///
/// An anchored sliver that is entered in the middle only estimates how much
/// content lies above it. When the real sizes turn out different it corrects
/// the scroll offset, sometimes by thousands of pixels, while nothing moves
/// on screen. A stock floating header reads that as "the user scrolled down
/// a lot" and hides. This header subtracts the corrections reported by
/// [controller], so it only reacts to scrolling the user can see.
///
/// Place it before the anchored sliver in the same scroll view and give both
/// the same [controller].
class SliverAnchoredFloatingHeader extends SingleChildRenderObjectWidget {
  const SliverAnchoredFloatingHeader({
    super.key,
    required this.controller,
    required this.extent,
    this.pinned = false,
    required Widget super.child,
  });

  /// The controller of the anchored sliver below this header.
  final SliverAnchorController controller;

  /// Height of the header. The child is laid out with exactly this height.
  final double extent;

  /// When true the header never scrolls away.
  final bool pinned;

  @override
  RenderSliverAnchoredFloatingHeader createRenderObject(BuildContext context) {
    return RenderSliverAnchoredFloatingHeader(
      controller: controller,
      extent: extent,
      pinned: pinned,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverAnchoredFloatingHeader renderObject,
  ) {
    renderObject
      ..controller = controller
      ..extent = extent
      ..pinned = pinned;
  }
}

/// Render object of [SliverAnchoredFloatingHeader].
class RenderSliverAnchoredFloatingHeader extends RenderSliverSingleBoxAdapter {
  RenderSliverAnchoredFloatingHeader({
    required SliverAnchorController controller,
    required double extent,
    bool pinned = false,
  })  : _controller = controller,
        _extent = extent,
        _pinned = pinned;

  SliverAnchorController get controller => _controller;
  SliverAnchorController _controller;
  set controller(SliverAnchorController value) {
    if (_controller == value) return;
    _controller = value;
    _lastCorrectionTotal = null;
    markNeedsLayout();
  }

  double get extent => _extent;
  double _extent;
  set extent(double value) {
    if (_extent == value) return;
    _extent = value;
    markNeedsLayout();
  }

  bool get pinned => _pinned;
  bool _pinned;
  set pinned(bool value) {
    if (_pinned == value) return;
    _pinned = value;
    markNeedsLayout();
  }

  /// How far the header is scrolled out of view, 0.0 .. [extent].
  double get hiddenExtent => _hidden;
  double _hidden = 0.0;

  double? _lastScrollOffset;
  double? _lastCorrectionTotal;
  double _childPosition = 0.0;

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    assert(constraints.axisDirection == AxisDirection.down);
    child?.layout(
      constraints.asBoxConstraints(minExtent: extent, maxExtent: extent),
      parentUsesSize: true,
    );

    final double total = _controller.correctionTotal;
    final double offset = constraints.scrollOffset;
    if (_lastScrollOffset != null) {
      // Movement the user can see: the change of the scroll offset minus
      // the part of it that was a correction. Positive = content moved up.
      double delta = (offset - _lastScrollOffset!) -
          (total - (_lastCorrectionTotal ?? total));
      // Like a stock floating header, only come back for the user's own
      // scrolling, not for a programmatic jump towards the start.
      if (delta < 0 &&
          constraints.userScrollDirection != ScrollDirection.forward) {
        delta = 0;
      }
      _hidden += delta;
    }
    _lastScrollOffset = offset;
    _lastCorrectionTotal = total;
    // Never hidden further than the content has scrolled: at the very top
    // the header sits in its natural place.
    _hidden = pinned ? 0.0 : _hidden.clamp(0.0, math.min(extent, offset));

    final double paintExtent =
        (extent - _hidden).clamp(0.0, constraints.remainingPaintExtent);
    final double layoutExtent =
        (extent - offset).clamp(0.0, constraints.remainingPaintExtent);
    _childPosition = paintExtent - extent;
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintOrigin: math.min(constraints.overlap, 0.0),
      paintExtent: paintExtent,
      layoutExtent: layoutExtent,
      maxPaintExtent: extent,
      maxScrollObstructionExtent: extent,
      hasVisualOverflow: true,
    );
    if (child != null) {
      (child!.parentData! as SliverPhysicalParentData).paintOffset =
          Offset(0.0, _childPosition);
    }
  }

  @override
  double childMainAxisPosition(RenderBox child) => _childPosition;
}
