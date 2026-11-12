import 'dart:math' as math;

import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';

import 'anchor_line.dart';
import 'anchor_monitor.dart';
import 'demo_card.dart';
import 'demo_images.dart';
import 'demo_keys.dart';
import 'status_bar.dart';

/// How many cards the list starts with.
const int _initialItemCount = 300;

/// The item the "Jump to 150" button targets.
const int _jumpTarget = 150;

/// A [SliverAnchoredList] with a switch that swaps in a plain [SliverList] for
/// comparison.
class AnchoredListPage extends StatefulWidget {
  const AnchoredListPage({super.key, required this.images});

  final DemoImageStore images;

  @override
  State<AnchoredListPage> createState() => _AnchoredListPageState();
}

class _AnchoredListPageState extends State<AnchoredListPage> {
  static const double _anchorAlignment = 0.5;

  final SliverAnchorController _anchor = SliverAnchorController();
  final ScrollController _scroll = ScrollController();
  late final AnchorMonitor _monitor = AnchorMonitor(
    controller: _anchor,
    scrollController: _scroll,
  );

  /// Ids in display order. "Prepend 20" adds negative ids above item 0.
  List<int> _ids = List<int>.generate(_initialItemCount, (int i) => i);
  int _nextPrependedId = -1;
  bool _anchored = true;
  int _resizeGeneration = 0;

  /// Last anchor index seen while the anchored sliver was mounted. Kept so
  /// "Resize above" still knows where the anchor was after the switch is
  /// turned off.
  int? _lastAnchor;

  @override
  void initState() {
    super.initState();
    widget.images.addListener(_onImagesChanged);
  }

  @override
  void dispose() {
    widget.images.removeListener(_onImagesChanged);
    _monitor.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onImagesChanged() => _monitor.poke();

  int? _currentAnchor() {
    final int? live = _anchor.anchorIndex;
    if (live != null) _lastAnchor = live;
    return _lastAnchor;
  }

  // ---- actions -----------------------------------------------------------

  /// Changes the fake image height of the five items above the anchor.
  void _resizeAbove() {
    final int? anchor = _currentAnchor();
    if (anchor == null) return;
    _resizeGeneration++;
    widget.images.randomize(<int>[
      for (int index = anchor - 5; index < anchor; index++)
        if (index >= 0 && index < _ids.length) _ids[index],
    ], generation: _resizeGeneration);
    _monitor.poke(frames: 3);
  }

  void _prepend() {
    setState(() {
      final List<int> added = <int>[
        for (int i = 0; i < 20; i++) _nextPrependedId--,
      ];
      _ids = <int>[...added, ..._ids];
    });
    _monitor.poke(frames: 3);
  }

  void _jumpTo150() {
    _anchor.jumpToIndex(_jumpTarget, alignment: _anchorAlignment);
    _monitor.poke(frames: 3);
  }

  void _setAnchored(bool value) {
    _currentAnchor();
    setState(() => _anchored = value);
    _monitor.poke(frames: 3);
  }

  // ---- builders ----------------------------------------------------------

  int? _indexOfKey(Key key) {
    if (key is! ValueKey<int>) return null;
    final int index = _ids.indexOf(key.value);
    return index < 0 ? null : index;
  }

  Widget _buildItem(BuildContext context, int index) {
    final int id = _ids[index];
    // Schedules the fake image load the first time the card is built; a no-op
    // afterwards and when loading is disabled.
    widget.images.ensureScheduled(id);
    return DemoCard(
      key: ValueKey<int>(id),
      id: id,
      imageHeight: widget.images.heightOf(id),
      imageLoaded: widget.images.isLoaded(id),
    );
  }

  Widget _sliver() {
    if (!_anchored) {
      return SliverList.builder(
        key: const ValueKey<String>('plain-list'),
        itemCount: _ids.length,
        findChildIndexCallback: _indexOfKey,
        itemBuilder: _buildItem,
      );
    }
    return SliverAnchoredList.builder(
      key: const ValueKey<String>('anchored-list'),
      controller: _anchor,
      anchorAlignment: _anchorAlignment,
      itemCount: _ids.length,
      findChildIndexCallback: _indexOfKey,
      itemBuilder: _buildItem,
    );
  }

  Widget _appBar(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SliverAppBar(
      pinned: true,
      // Narrow screens give most of the bar to the controls.
      title: Text(
        MediaQuery.sizeOf(context).width < 400
            ? 'List'
            : (_anchored ? 'List · anchored' : 'List · plain'),
        style: text.titleMedium,
      ),
      actions: <Widget>[
        Tooltip(
          message: _anchored
              ? 'Anchored layout: on (tap to compare with a plain list)'
              : 'Anchored layout: off',
          child: Switch(
            key: DemoKeys.listAnchoredToggle,
            value: _anchored,
            onChanged: _setAnchored,
          ),
        ),
        IconButton(
          key: DemoKeys.listResizeAbove,
          onPressed: _resizeAbove,
          icon: const Icon(Icons.height),
          tooltip: 'Resize 5 items above the anchor',
        ),
        IconButton(
          key: DemoKeys.listPrepend,
          onPressed: _prepend,
          icon: const Icon(Icons.playlist_add),
          tooltip: 'Prepend 20 items',
        ),
        IconButton(
          key: DemoKeys.listJump,
          onPressed: _anchored ? _jumpTo150 : null,
          icon: const Icon(Icons.vertical_align_center),
          tooltip: 'Jump to item 150',
        ),
      ],
    );
  }

  Widget _statusBar() {
    return StatusBar(
      prefix: 'list',
      entries: <(String, String)>[
        ('mode', _anchored ? 'anchored' : 'plain'),
        ('anchorIndex', '${_monitor.anchorIndex ?? '-'}'),
        ('offset', _monitor.offset.toStringAsFixed(0)),
        ('items', '${_ids.length}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.images,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      // Cards stay readable on a wide window: the list is
                      // centred and capped, the app bar still spans the width.
                      final double side = math.max(
                        12.0,
                        (constraints.maxWidth - 900) / 2,
                      );
                      return CustomScrollView(
                        controller: _scroll,
                        slivers: <Widget>[
                          _appBar(context),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(side, 12, side, 16),
                            sliver: _sliver(),
                          ),
                        ],
                      );
                    },
                  ),
                  const AnchorLineOverlay(
                    leadingInset: kToolbarHeight,
                    alignment: _anchorAlignment,
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: _monitor,
              builder: (BuildContext context, Widget? child) => _statusBar(),
            ),
          ],
        );
      },
    );
  }
}
