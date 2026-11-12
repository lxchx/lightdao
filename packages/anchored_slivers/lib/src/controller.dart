import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'render_sliver_anchored.dart';

/// Reads and steers the anchor of a [SliverAnchoredList] or
/// [SliverAnchoredMasonry].
///
/// A controller drives one sliver at a time. It notifies its listeners after
/// a frame in which [anchorIndex] or [laneCount] changed.
class SliverAnchorController extends ChangeNotifier {
  RenderSliverAnchoredMasonry? _render;
  int? _pinnedIndex;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Whether a sliver is currently using this controller.
  bool get isAttached => _render != null;

  /// Index of the child the last layout was anchored to, or null before the
  /// first layout.
  int? get anchorIndex => _render?.anchorIndex;

  /// Number of lanes used by the last layout (always 1 for a list).
  int? get laneCount => _render?.laneCount;

  /// When non-null, the child with this index is used as the anchor for as
  /// long as it is laid out, regardless of where the anchor line falls.
  int? get pinnedIndex => _pinnedIndex;
  set pinnedIndex(int? value) {
    if (_pinnedIndex == value) return;
    _pinnedIndex = value;
    _render?.markNeedsLayout();
  }

  /// Lays the sliver out around [index], placing the item's leading edge at
  /// [alignment] of the visible part of the sliver (0.0 leading, 1.0
  /// trailing). Works for items that are not built yet and does not need to
  /// know their scroll offset.
  ///
  /// Returns false, and does nothing, when no sliver is attached.
  bool jumpToIndex(int index, {double alignment = 0.0}) {
    final RenderSliverAnchoredMasonry? render = _render;
    if (render == null) return false;
    render.jumpToIndex(index, alignment: alignment);
    return true;
  }

  /// Called by the render object. Not for application use.
  ///
  /// The most recently attached sliver wins: when a sliver is replaced within
  /// one frame, the new one attaches before the old one is unmounted.
  void attach(RenderSliverAnchoredMasonry render) {
    _render = render;
  }

  /// Called by the render object. Not for application use.
  void detach(RenderSliverAnchoredMasonry render) {
    if (_render == render) _render = null;
  }

  /// Sum of every scroll offset correction the attached slivers asked for.
  ///
  /// A correction moves the scroll offset without moving anything on screen.
  /// Whoever derives behaviour from scroll offset deltas (a floating header,
  /// for example) subtracts the change of this value to see only real
  /// scrolling. See [SliverAnchoredFloatingHeader].
  double get correctionTotal => _correctionTotal;
  double _correctionTotal = 0.0;

  /// Called by the render object when it requests a scroll offset
  /// correction. Not for application use.
  void didCorrect(double correction) {
    _correctionTotal += correction;
  }

  /// Called by the render object when a layout changed [anchorIndex] or
  /// [laneCount]. Listeners are notified after the frame, because they
  /// usually rebuild widgets.
  void didChangeAnchor() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
