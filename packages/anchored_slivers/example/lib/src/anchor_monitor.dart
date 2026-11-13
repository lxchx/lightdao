import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Samples a [SliverAnchorController] after layout and notifies when the
/// reported values change.
///
/// The controller only reports after a layout pass, so the values cannot be
/// read during build. This monitor reads them in a post-frame callback, which
/// is also what the package documentation suggests. It re-reads for a couple
/// of frames so two-pass layouts settle, and it stops scheduling frames as
/// soon as the values stop changing, which keeps `pumpAndSettle` happy.
class AnchorMonitor extends ChangeNotifier {
  AnchorMonitor({required this.controller, required this.scrollController}) {
    scrollController.addListener(_onScroll);
    poke();
  }

  final SliverAnchorController controller;
  final ScrollController scrollController;

  int? _anchorIndex;
  int? _laneCount;
  double _offset = 0.0;
  int _framesLeft = 0;
  bool _scheduled = false;
  bool _disposed = false;

  /// Index of the child the last layout anchored to, or null before the first
  /// layout (and while no anchored sliver is mounted).
  int? get anchorIndex => _anchorIndex;

  /// Number of lanes used by the last layout (null until the first layout).
  int? get laneCount => _laneCount;

  /// Scroll offset of the attached scroll view, in logical pixels.
  double get offset => _offset;

  /// Asks for a re-read over the next [frames] frames.
  void poke({int frames = 2}) {
    if (frames > _framesLeft) _framesLeft = frames;
    _schedule();
  }

  void _onScroll() => poke(frames: 1);

  void _schedule() {
    if (_scheduled || _disposed || _framesLeft <= 0) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    _scheduled = false;
    if (_disposed) return;
    if (_framesLeft > 0) _framesLeft--;
    if (_read()) {
      notifyListeners();
      if (_framesLeft < 1) _framesLeft = 1;
    }
    _schedule();
  }

  bool _read() {
    final int? anchor = controller.anchorIndex;
    final int? lanes = controller.laneCount;
    final double offset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;
    final bool changed =
        anchor != _anchorIndex ||
        lanes != _laneCount ||
        (offset - _offset).abs() > 0.25;
    _anchorIndex = anchor;
    _laneCount = lanes;
    _offset = offset;
    return changed;
  }

  @override
  void dispose() {
    _disposed = true;
    scrollController.removeListener(_onScroll);
    super.dispose();
  }
}
