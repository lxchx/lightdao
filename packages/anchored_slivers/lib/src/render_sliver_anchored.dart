import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'controller.dart';

const double _eps = precisionErrorTolerance;

/// How fast a lane that is misaligned with the leading edge is pulled back
/// into place, as a fraction of the distance scrolled in the same frame.
const double _absorbRate = 0.5;

/// Parent data used by [RenderSliverAnchoredMasonry].
///
/// [lane] and [offset] are the source of truth for where a child sits. They
/// are kept separately from [layoutOffset] because the framework element
/// rewrites [layoutOffset] when children move between indices.
class SliverAnchoredParentData extends SliverMultiBoxAdaptorParentData {
  /// Zero-based lane (column) this child was placed in.
  int? lane;

  /// Main-axis offset assigned by the last layout.
  double? offset;

  /// Index this child had at the last layout.
  int? lastIndex;
}

class _Lanes {
  _Lanes(int n, double seam, [List<double?>? starts])
      : top = List<double>.generate(n, (int i) => starts?[i] ?? seam),
        end = List<double>.generate(n, (int i) => starts?[i] ?? seam),
        used = List<bool>.filled(n, false);

  final List<double> top;
  final List<double> end;
  final List<bool> used;

  int get length => top.length;

  /// Shortest lane; ties go to the lowest lane (fills left to right).
  int argminEnd() {
    int best = 0;
    for (int i = 1; i < length; i++) {
      if (end[i] < end[best] - _eps) best = i;
    }
    return best;
  }

  /// Mirror image of [argminEnd] for laying out backwards.
  int argmaxTop() {
    int best = 0;
    for (int i = 1; i < length; i++) {
      if (top[i] >= top[best] - _eps) best = i;
    }
    return best;
  }

  double appendOffset(int l, double spacing) =>
      used[l] ? end[l] + spacing : end[l];

  double prependOffset(int l, double extent, double spacing) =>
      (used[l] ? top[l] - spacing : top[l]) - extent;

  void add(int l, double offset, double extent) {
    if (!used[l]) {
      top[l] = offset;
      end[l] = offset + extent;
      used[l] = true;
    } else {
      top[l] = math.min(top[l], offset);
      end[l] = math.max(end[l], offset + extent);
    }
  }

  double get minEnd => end.reduce(math.min);
  double get maxTop => top.reduce(math.max);

  double get minUsedTop {
    double v = double.infinity;
    for (int i = 0; i < length; i++) {
      if (used[i]) v = math.min(v, top[i]);
    }
    return v;
  }

  double get maxUsedEnd {
    double v = double.negativeInfinity;
    for (int i = 0; i < length; i++) {
      if (used[i]) v = math.max(v, end[i]);
    }
    return v;
  }
}

/// A sliver that lays box children out in one or more lanes and keeps the
/// children around an anchor line visually still when other children change
/// size.
///
/// With one lane this is an anchored list; with several it is an anchored
/// masonry grid. Layout proceeds outwards from one anchor child per lane
/// instead of downwards from the first child, so a size change above the
/// anchor is absorbed above it. The scroll offset is only corrected (through
/// [SliverGeometry.scrollOffsetCorrection]) when the leading edge has to be
/// reconciled with offset zero.
class RenderSliverAnchoredMasonry extends RenderSliverMultiBoxAdaptor {
  RenderSliverAnchoredMasonry({
    required super.childManager,
    int? crossAxisCount = 1,
    double? maxCrossAxisExtent,
    double mainAxisSpacing = 0.0,
    double crossAxisSpacing = 0.0,
    double anchorAlignment = 0.5,
    SliverAnchorController? controller,
  })  : assert((crossAxisCount == null) != (maxCrossAxisExtent == null)),
        _crossAxisCount = crossAxisCount,
        _maxCrossAxisExtent = maxCrossAxisExtent,
        _mainAxisSpacing = mainAxisSpacing,
        _crossAxisSpacing = crossAxisSpacing,
        _anchorAlignment = anchorAlignment {
    this.controller = controller;
  }

  int? get crossAxisCount => _crossAxisCount;
  int? _crossAxisCount;
  set crossAxisCount(int? value) {
    if (_crossAxisCount == value) return;
    _crossAxisCount = value;
    markNeedsLayout();
  }

  double? get maxCrossAxisExtent => _maxCrossAxisExtent;
  double? _maxCrossAxisExtent;
  set maxCrossAxisExtent(double? value) {
    if (_maxCrossAxisExtent == value) return;
    _maxCrossAxisExtent = value;
    markNeedsLayout();
  }

  double get mainAxisSpacing => _mainAxisSpacing;
  double _mainAxisSpacing;
  set mainAxisSpacing(double value) {
    if (_mainAxisSpacing == value) return;
    _mainAxisSpacing = value;
    markNeedsLayout();
  }

  double get crossAxisSpacing => _crossAxisSpacing;
  double _crossAxisSpacing;
  set crossAxisSpacing(double value) {
    if (_crossAxisSpacing == value) return;
    _crossAxisSpacing = value;
    markNeedsLayout();
  }

  /// Where the anchor line sits inside the visible part of this sliver:
  /// 0.0 is the leading edge, 1.0 the trailing edge.
  double get anchorAlignment => _anchorAlignment;
  double _anchorAlignment;
  set anchorAlignment(double value) {
    if (_anchorAlignment == value) return;
    _anchorAlignment = value;
    markNeedsLayout();
  }

  SliverAnchorController? get controller => _controller;
  SliverAnchorController? _controller;
  set controller(SliverAnchorController? value) {
    if (_controller == value) return;
    _controller?.detach(this);
    _controller = value;
    value?.attach(this);
  }

  // ---- state carried between layouts -------------------------------------

  final Map<int, int> _laneMemo = <int, int>{};
  int? _lastLaneCount;
  double _lastStride = 0.0;
  double _lastLaneWidth = 0.0;
  double _lastCrossExtent = 0.0;
  double? _lastScrollOffset;
  ({int index, double alignment})? _pendingJump;

  /// Index of the main anchor child chosen by the last layout.
  int? get anchorIndex => _anchorIndex;
  int? _anchorIndex;

  /// Lane count used by the last layout.
  int? get laneCount => _lastLaneCount;

  /// Number of scroll offset corrections requested so far. Diagnostic only.
  int debugCorrectionCount = 0;

  /// Number of times lanes were re-seeded because the lane count changed.
  int debugReseedCount = 0;

  /// Requests that [index] be laid out with its leading edge at [alignment]
  /// of the visible part of this sliver on the next layout.
  void jumpToIndex(int index, {double alignment = 0.0}) {
    _pendingJump = (index: index, alignment: alignment);
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! SliverAnchoredParentData) {
      child.parentData = SliverAnchoredParentData();
    }
  }

  SliverAnchoredParentData _pd(RenderBox child) =>
      child.parentData! as SliverAnchoredParentData;

  @override
  double childCrossAxisPosition(RenderBox child) =>
      (_pd(child).lane ?? 0) * _lastStride;

  int _computeLaneCount(double crossExtent) {
    final int? count = _crossAxisCount;
    if (count != null) return math.max(1, count);
    final double maxExtent = math.max(1.0, _maxCrossAxisExtent!);
    return math.max(
      1,
      ((crossExtent + _crossAxisSpacing) / (maxExtent + _crossAxisSpacing) -
              _eps)
          .ceil(),
    );
  }

  bool _stated(SliverAnchoredParentData pd, int n) =>
      pd.lane != null && pd.offset != null && pd.lane! < n;

  void _place(RenderBox child, int lane, double offset, _Lanes lanes) {
    final SliverAnchoredParentData pd = _pd(child);
    pd.lane = lane;
    pd.offset = offset;
    lanes.add(lane, offset, paintExtentOf(child));
  }

  _Lanes _measure(int n, double seam) {
    final _Lanes lanes = _Lanes(n, seam);
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      lanes.add(pd.lane!, pd.offset!, paintExtentOf(c));
    }
    return lanes;
  }

  void _shift(List<double> perLane) {
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      pd.offset = pd.offset! + perLane[pd.lane!];
    }
  }

  void _commit(int n, double stride, double laneWidth, double crossExtent) {
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      pd.layoutOffset = pd.offset;
      pd.lastIndex = pd.index;
      _laneMemo[pd.index!] = pd.lane!;
    }
    _lastLaneCount = n;
    _lastStride = stride;
    _lastLaneWidth = laneWidth;
    _lastCrossExtent = crossExtent;
  }

  /// Drops children that are separated from [ref] by a gap in the indices.
  void _collectNonContiguous(RenderBox ref) {
    if (indexOf(lastChild!) - indexOf(firstChild!) + 1 == childCount) return;
    int before = 0;
    int after = 0;
    RenderBox run = ref;
    for (RenderBox? c = childBefore(ref); c != null; c = childBefore(c)) {
      if (indexOf(c) == indexOf(run) - 1 && before == 0) {
        run = c;
      } else {
        before++;
      }
    }
    run = ref;
    for (RenderBox? c = childAfter(ref); c != null; c = childAfter(c)) {
      if (indexOf(c) == indexOf(run) + 1 && after == 0) {
        run = c;
      } else {
        after++;
      }
    }
    if (before > 0 || after > 0) collectGarbage(before, after);
  }

  double _distance(double line, double offset, double extent) {
    if (line < offset) return offset - line;
    if (line >= offset + extent) return line - (offset + extent) + _eps;
    return 0.0;
  }

  /// The child an observer would call "the anchor" after this layout: the
  /// pinned child if it is laid out, else the middle one (by index) of the
  /// children nearest the anchor line in each lane.
  int? _reportAnchor(int n, double line, int? pinnedIndex) {
    final List<int?> nearest = List<int?>.filled(n, null);
    final List<double> best = List<double>.filled(n, double.infinity);
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      if (pd.index == pinnedIndex) return pinnedIndex;
      final double d = _distance(line, pd.offset!, paintExtentOf(c));
      if (d < best[pd.lane!]) {
        best[pd.lane!] = d;
        nearest[pd.lane!] = pd.index;
      }
    }
    final List<int> candidates = nearest.whereType<int>().toList()..sort();
    return candidates.isEmpty ? null : candidates[(candidates.length - 1) ~/ 2];
  }

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final double crossExtent = constraints.crossAxisExtent;
    final int n = _computeLaneCount(crossExtent);
    final double laneWidth =
        math.max(0.0, (crossExtent - _crossAxisSpacing * (n - 1)) / n);
    final double stride = laneWidth + _crossAxisSpacing;
    final BoxConstraints cc =
        constraints.asBoxConstraints(crossAxisExtent: laneWidth);
    final double spacing = _mainAxisSpacing;

    final double scrollOffset = constraints.scrollOffset;
    final double cacheStart = scrollOffset + constraints.cacheOrigin;
    final double cacheEnd = cacheStart + constraints.remainingCacheExtent;
    final double visibleStart =
        scrollOffset + math.max(0.0, constraints.overlap);
    final double visibleEnd = math.max(
        visibleStart, scrollOffset + constraints.remainingPaintExtent);
    final double line =
        visibleStart + (visibleEnd - visibleStart) * _anchorAlignment;

    final int? oldN = _lastLaneCount;
    final double oldStride = _lastStride;
    final double oldLaneWidth = _lastLaneWidth;
    final double oldCrossExtent = _lastCrossExtent;
    // childCrossAxisPosition reads these; keep them current from here on.
    _lastStride = stride;

    // ---- explicit jump / first layout ------------------------------------
    final ({int index, double alignment})? jump = _pendingJump;
    _pendingJump = null;
    ({int index, double offset})? seed;
    if (jump != null) {
      seed = (
        index: jump.index,
        offset: visibleStart + (visibleEnd - visibleStart) * jump.alignment,
      );
    } else if (firstChild != null) {
      // A scroll jump that left every live child far outside the cache
      // window: start over from an estimated index instead of building
      // everything in between.
      double minTop = double.infinity;
      double maxEnd = double.negativeInfinity;
      for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
        final double? o = _pd(c).offset;
        if (o == null) continue;
        minTop = math.min(minTop, o);
        maxEnd = math.max(maxEnd, o + paintExtentOf(c));
      }
      final double slack = constraints.viewportMainAxisExtent;
      final double? last = _lastScrollOffset;
      if (scrollOffset <= _eps &&
          indexOf(firstChild!) > 0 &&
          last != null &&
          last - scrollOffset > slack / 2) {
        // A discontinuous jump to the very start (jumpTo(0), the end of an
        // animateTo(0)): the caller wants the first item, not whatever the
        // estimated offsets say is there.
        seed = (index: 0, offset: 0.0);
      } else if (minTop.isFinite && maxEnd > minTop) {
        final double average = (maxEnd - minTop) / childCount;
        if (minTop > cacheEnd + slack) {
          final int first = indexOf(firstChild!);
          final int index = scrollOffset <= _eps
              ? 0
              : math.max(
                  0, first - ((minTop - scrollOffset) / average).ceil());
          seed = (index: index, offset: index == 0 ? 0.0 : scrollOffset);
        } else if (maxEnd < cacheStart - slack) {
          final int last = indexOf(lastChild!);
          int index = last + 1 + ((scrollOffset - maxEnd) / average).floor();
          index = math.min(index, childManager.childCount - 1);
          if (index > last) seed = (index: index, offset: scrollOffset);
        }
      }
    }
    if (seed != null && firstChild != null) {
      collectGarbage(childCount, 0);
    }
    bool fresh = false;
    if (firstChild == null) {
      _laneMemo.clear();
      int index = seed?.index ?? 0;
      double offset = seed?.offset ?? 0.0;
      if (index < 0) index = 0;
      if (!addInitialChild(index: index, layoutOffset: offset)) {
        offset = 0.0;
        if (index == 0 || !addInitialChild()) {
          geometry = SliverGeometry.zero;
          _anchorIndex = null;
          _lastLaneCount = n;
          _lastLaneWidth = laneWidth;
          _lastCrossExtent = crossExtent;
          _lastScrollOffset = scrollOffset;
          childManager.didFinishLayout();
          return;
        }
      }
      final SliverAnchoredParentData pd = _pd(firstChild!);
      pd.lane = 0;
      pd.offset = offset;
      pd.lastIndex = pd.index;
      fresh = true;
    }

    // ---- choose anchors from the previous layout's geometry ---------------
    final int selN = (oldN != null && !fresh) ? oldN : n;
    final int? pinnedIndex = _controller?.pinnedIndex;

    // Rough reference: the placed child nearest the anchor line.
    RenderBox? ref;
    double refDistance = double.infinity;
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      if (!_stated(pd, selN)) continue;
      // The pinned child wins outright: after a head insertion it may no
      // longer be contiguous with the children above it, and it is the run
      // around *it* that has to survive.
      if (pinnedIndex != null && pd.index == pinnedIndex) {
        ref = c;
        break;
      }
      final double d = fresh ? 0.0 : _distance(line, pd.offset!, paintExtentOf(c));
      if (d < refDistance) {
        refDistance = d;
        ref = c;
      }
    }
    if (ref == null) {
      ref = firstChild!;
      final SliverAnchoredParentData pd = _pd(ref);
      pd.lane = 0;
      pd.offset = pd.layoutOffset ?? 0.0;
    }
    _collectNonContiguous(ref);

    final List<RenderBox?> anchors = List<RenderBox?>.filled(selN, null);
    final List<double> best = List<double>.filled(selN, double.infinity);
    final List<bool> seen = List<bool>.filled(selN, false);
    final bool firstIsZero = indexOf(firstChild!) == 0;
    RenderBox? pinned;
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      if (!_stated(pd, selN)) continue;
      final int l = pd.lane!;
      if (pinnedIndex != null && pd.index == pinnedIndex) {
        anchors[l] = c;
        best[l] = -2.0;
        pinned = c;
        seen[l] = true;
        continue;
      }
      if (!seen[l]) {
        seen[l] = true;
        // A lane whose leading edge is on screen keeps that edge still.
        if (firstIsZero && !fresh && pd.offset! >= visibleStart - _eps) {
          anchors[l] = c;
          best[l] = -1.0;
          continue;
        }
      }
      if (best[l] < 0) continue;
      final double d = fresh ? 0.0 : _distance(line, pd.offset!, paintExtentOf(c));
      if (d < best[l]) {
        best[l] = d;
        anchors[l] = c;
      }
    }
    RenderBox main;
    if (pinned != null) {
      main = pinned;
    } else {
      final List<RenderBox> candidates = <RenderBox>[
        for (final RenderBox? a in anchors)
          if (a != null) a,
      ]..sort((RenderBox a, RenderBox b) => indexOf(a).compareTo(indexOf(b)));
      main = candidates.isEmpty ? ref : candidates[(candidates.length - 1) ~/ 2];
    }
    final double mainOldOffset = _pd(main).offset!;

    // Keep the lane memo aligned with index shifts (e.g. head insertion).
    final int? mainLastIndex = _pd(main).lastIndex;
    if (mainLastIndex != null && mainLastIndex != indexOf(main)) {
      final int d = indexOf(main) - mainLastIndex;
      final Map<int, int> shifted = <int, int>{
        for (final MapEntry<int, int> e in _laneMemo.entries)
          if (e.key + d >= 0) e.key + d: e.value,
      };
      _laneMemo
        ..clear()
        ..addAll(shifted);
    }

    _Lanes lanes;
    if (selN != n) {
      // ---- lane count changed: re-seed around the main anchor -------------
      debugReseedCount++;
      _laneMemo.clear();
      final SliverAnchoredParentData mpd = _pd(main);
      final double fraction = oldCrossExtent <= 0
          ? 0.0
          : (mpd.lane! * oldStride + oldLaneWidth / 2) / oldCrossExtent;
      final int newLane = (fraction * n).floor().clamp(0, n - 1);
      lanes = _Lanes(n, mainOldOffset);
      main.layout(cc, parentUsesSize: true);
      _place(main, newLane, mainOldOffset, lanes);
      for (RenderBox? c = childAfter(main); c != null; c = childAfter(c)) {
        c.layout(cc, parentUsesSize: true);
        final int l = lanes.argminEnd();
        _place(c, l, lanes.appendOffset(l, spacing), lanes);
      }
      for (RenderBox? c = childBefore(main); c != null; c = childBefore(c)) {
        c.layout(cc, parentUsesSize: true);
        final int l = lanes.argmaxTop();
        _place(c, l, lanes.prependOffset(l, paintExtentOf(c), spacing), lanes);
      }
    } else {
      // ---- pass A: stack every live child in index order ------------------
      final List<double?> starts = List<double?>.filled(n, null);
      final List<double?> anchorOld = List<double?>.filled(n, null);
      for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
        final SliverAnchoredParentData pd = _pd(c);
        if (_stated(pd, n)) starts[pd.lane!] ??= pd.offset;
      }
      for (int l = 0; l < n; l++) {
        final RenderBox? a = anchors[l];
        if (a != null) anchorOld[l] = _pd(a).offset;
      }
      final _Lanes provisional = _Lanes(n, mainOldOffset, starts);
      for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
        c.layout(cc, parentUsesSize: true);
        final SliverAnchoredParentData pd = _pd(c);
        final int l = _stated(pd, n) ? pd.lane! : provisional.argminEnd();
        _place(c, l, provisional.appendOffset(l, spacing), provisional);
      }
      // ---- pass B: slide each lane so its anchor is where it was ----------
      final List<double> deltas = List<double>.filled(n, 0.0);
      bool any = false;
      for (int l = 0; l < n; l++) {
        final RenderBox? a = anchors[l];
        if (a == null) continue;
        deltas[l] = anchorOld[l]! - _pd(a).offset!;
        if (deltas[l] != 0.0) any = true;
      }
      if (any) _shift(deltas);
      lanes = _measure(n, mainOldOffset);
    }

    // ---- extend backwards -------------------------------------------------
    while (true) {
      final int index = indexOf(firstChild!);
      if (index == 0) break;
      if (lanes.maxTop <= cacheStart + _eps) break;
      final RenderBox? child =
          insertAndLayoutLeadingChild(cc, parentUsesSize: true);
      if (child == null) break;
      int? l = _laneMemo[index - 1];
      if (l == null || l >= n) l = lanes.argmaxTop();
      _place(child, l, lanes.prependOffset(l, paintExtentOf(child), spacing),
          lanes);
    }

    // ---- extend forwards --------------------------------------------------
    bool reachedEnd = false;
    while (lanes.minEnd < cacheEnd - _eps) {
      final RenderBox? child =
          insertAndLayoutChild(cc, after: lastChild, parentUsesSize: true);
      if (child == null) {
        reachedEnd = true;
        break;
      }
      final int l = lanes.argminEnd();
      _place(child, l, lanes.appendOffset(l, spacing), lanes);
    }

    // ---- collect garbage --------------------------------------------------
    final List<int> perLane = List<int>.filled(n, 0);
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      perLane[_pd(c).lane!]++;
    }
    int leading = 0;
    int trailing = 0;
    for (RenderBox? c = firstChild; c != null; c = childAfter(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      if (perLane[pd.lane!] > 1 &&
          pd.offset! + paintExtentOf(c) <= cacheStart - _eps) {
        // Remember where it was so that scrolling back restores the lane.
        _laneMemo[pd.index!] = pd.lane!;
        perLane[pd.lane!]--;
        leading++;
      } else {
        break;
      }
    }
    for (RenderBox? c = lastChild; c != null; c = childBefore(c)) {
      final SliverAnchoredParentData pd = _pd(c);
      if (leading + trailing + 1 < childCount &&
          perLane[pd.lane!] > 1 &&
          pd.offset! >= cacheEnd + _eps) {
        perLane[pd.lane!]--;
        trailing++;
      } else {
        break;
      }
    }
    if (leading > 0 || trailing > 0) {
      collectGarbage(leading, trailing);
      if (trailing > 0) reachedEnd = false;
      lanes = _measure(n, mainOldOffset);
    }

    // ---- reconcile the leading edge ---------------------------------------
    double correction = 0.0;
    final int firstIndex = indexOf(firstChild!);
    if (firstIndex == 0) {
      if (scrollOffset <= _eps) {
        // The leading edge is on screen: every lane starts at zero.
        final List<double> deltas = <double>[
          for (int l = 0; l < n; l++) lanes.used[l] ? -lanes.top[l] : 0.0,
        ];
        if (deltas.any((double d) => d != 0.0)) {
          _shift(deltas);
          lanes = _measure(n, 0.0);
        }
      } else {
        // Which lane is reconciled must not depend on the anchor: a
        // correction moves the anchor line, and a different choice on the
        // next pass would correct back again.
        final int refLane = _pd(firstChild!).lane!;
        final double refTop = lanes.top[refLane];
        if (refTop.abs() > _eps) {
          correction = math.max(-refTop, -scrollOffset);
        }
        if (correction.abs() <= _eps) {
          correction = 0.0;
          // Other lanes drift back towards zero while the user scrolls, so
          // that they are aligned by the time the leading edge shows up.
          final double budget =
              ((_lastScrollOffset ?? scrollOffset) - scrollOffset).abs() *
                  _absorbRate;
          if (budget > 0) {
            final List<double> deltas = List<double>.filled(n, 0.0);
            bool any = false;
            for (int l = 0; l < n; l++) {
              if (!lanes.used[l] || lanes.top[l].abs() <= _eps) continue;
              deltas[l] = (-lanes.top[l]).clamp(-budget, budget);
              any = true;
            }
            if (any) {
              _shift(deltas);
              lanes = _measure(n, 0.0);
            }
          }
        }
      }
    } else if (lanes.minUsedTop <= _eps) {
      // Children exist above, but there is no scroll extent left for them.
      final double average =
          (lanes.maxUsedEnd - lanes.minUsedTop) / childCount;
      correction = -lanes.minUsedTop + math.max(1.0, firstIndex * average);
    }

    if (correction != 0.0) {
      debugCorrectionCount++;
      _controller?.didCorrect(correction);
      _shift(List<double>.filled(n, correction));
      _commit(n, stride, laneWidth, crossExtent);
      if (_lastScrollOffset != null) {
        _lastScrollOffset = _lastScrollOffset! + correction;
      }
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      childManager.didFinishLayout();
      return;
    }

    // ---- geometry ----------------------------------------------------------
    _commit(n, stride, laneWidth, crossExtent);
    _lastScrollOffset = scrollOffset;
    final int? previousAnchor = _anchorIndex;
    _anchorIndex = _reportAnchor(n, line, pinnedIndex);
    if (_anchorIndex != previousAnchor || n != oldN) {
      _controller?.didChangeAnchor();
    }

    final double leadingOffset = lanes.minUsedTop;
    final double endOffset = lanes.maxUsedEnd;
    final double estimatedMax = reachedEnd
        ? endOffset
        : math.max(
            endOffset,
            childManager.estimateMaxScrollOffset(
              constraints,
              firstIndex: indexOf(firstChild!),
              lastIndex: indexOf(lastChild!),
              leadingScrollOffset: leadingOffset,
              trailingScrollOffset: endOffset,
            ),
          );
    final double paintFrom = math.min(leadingOffset, endOffset);
    final double paintExtent =
        calculatePaintOffset(constraints, from: paintFrom, to: endOffset);
    final double cacheExtent =
        calculateCacheOffset(constraints, from: paintFrom, to: endOffset);
    final double targetEndForPaint =
        scrollOffset + constraints.remainingPaintExtent;
    geometry = SliverGeometry(
      scrollExtent: estimatedMax,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMax,
      hasVisualOverflow: endOffset > targetEndForPaint ||
          scrollOffset > 0.0 ||
          leadingOffset < scrollOffset,
    );
    if (estimatedMax == endOffset) {
      childManager.setDidUnderflow(true);
    }
    childManager.didFinishLayout();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('laneCount', _lastLaneCount))
      ..add(IntProperty('anchorIndex', _anchorIndex))
      ..add(DoubleProperty('anchorAlignment', _anchorAlignment))
      ..add(IntProperty('corrections', debugCorrectionCount));
  }
}

/// A [RenderSliverAnchoredMasonry] with a single lane: a drop-in counterpart
/// of [RenderSliverList] that keeps the anchor child still.
class RenderSliverAnchoredList extends RenderSliverAnchoredMasonry {
  RenderSliverAnchoredList({
    required super.childManager,
    super.anchorAlignment,
    super.controller,
  }) : super(crossAxisCount: 1);
}
