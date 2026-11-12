import 'package:anchored_slivers/anchored_slivers.dart';
import 'package:flutter/material.dart';

import 'anchor_line.dart';
import 'anchor_monitor.dart';
import 'demo_card.dart';
import 'demo_images.dart';
import 'demo_keys.dart';
import 'status_bar.dart';

/// Number of cards in the masonry.
const int _itemCount = 300;

/// Height of the extra app bar row that holds the controls.
const double _controlsHeight = 56;

/// Gap between cards in the masonry, main and cross axis.
const double _spacing = 12;

/// A [SliverAnchoredMasonry] whose lane count changes with the available
/// width: drag the slider, or open the side panel to squeeze it.
class AnchoredMasonryPage extends StatefulWidget {
  const AnchoredMasonryPage({super.key, required this.images});

  final DemoImageStore images;

  @override
  State<AnchoredMasonryPage> createState() => _AnchoredMasonryPageState();
}

class _AnchoredMasonryPageState extends State<AnchoredMasonryPage> {
  static const double _anchorAlignment = 0.5;

  final SliverAnchorController _anchor = SliverAnchorController();
  final ScrollController _scroll = ScrollController();
  late final AnchorMonitor _monitor = AnchorMonitor(
    controller: _anchor,
    scrollController: _scroll,
  );

  bool _sidePanel = false;
  double _maxCrossAxisExtent = 200;
  int _resizeGeneration = 0;
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

  /// setState plus an anchor re-read: `laneCount` only changes on a layout that
  /// no scroll caused, so the monitor would otherwise report the old value.
  void _update(VoidCallback mutate) {
    setState(mutate);
    _monitor.poke(frames: 3);
  }

  int? _currentAnchor() {
    final int? live = _anchor.anchorIndex;
    if (live != null) _lastAnchor = live;
    return _lastAnchor;
  }

  /// Changes the fake image height of the five items above the anchor.
  void _resizeAbove() {
    final int? anchor = _currentAnchor();
    if (anchor == null) return;
    _resizeGeneration++;
    widget.images.randomize(<int>[
      for (int index = anchor - 5; index < anchor; index++)
        if (index >= 0 && index < _itemCount) index,
    ], generation: _resizeGeneration);
    _monitor.poke(frames: 3);
  }

  // ---- builders ----------------------------------------------------------

  Widget _buildItem(BuildContext context, int index) {
    widget.images.ensureScheduled(index);
    return DemoCard(
      key: ValueKey<int>(index),
      id: index,
      imageHeight: widget.images.heightOf(index),
      imageLoaded: widget.images.isLoaded(index),
    );
  }

  Widget _appBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      title: Text('Masonry', style: theme.textTheme.titleMedium),
      actions: <Widget>[
        IconButton(
          key: DemoKeys.masonryResizeAbove,
          onPressed: _resizeAbove,
          icon: const Icon(Icons.height),
          tooltip: 'Resize 5 items above the anchor',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_controlsHeight),
        child: _controls(theme),
      ),
    );
  }

  Widget _controls(ThemeData theme) {
    return SizedBox(
      height: _controlsHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // The panel squeezes the app bar too, so the labels only fit while
          // there is room for them.
          final bool showLabels = constraints.maxWidth >= 320;
          return Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(
              children: <Widget>[
                Switch(
                  key: DemoKeys.masonrySidePanel,
                  value: _sidePanel,
                  onChanged: (bool value) => _update(() => _sidePanel = value),
                ),
                if (showLabels) ...<Widget>[
                  Text('Side panel', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 12),
                  Text(
                    'col ≤ ${_maxCrossAxisExtent.round()}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  const SizedBox(width: 4),
                Expanded(
                  child: Slider(
                    key: DemoKeys.masonryMaxExtent,
                    min: 120,
                    max: 400,
                    divisions: 28,
                    value: _maxCrossAxisExtent,
                    onChanged: (double value) =>
                        _update(() => _maxCrossAxisExtent = value),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusBar() {
    return StatusBar(
      prefix: 'masonry',
      entries: <(String, String)>[
        ('laneCount', '${_monitor.laneCount ?? '-'}'),
        ('anchorIndex', '${_monitor.anchorIndex ?? '-'}'),
        ('offset', _monitor.offset.toStringAsFixed(0)),
        ('panel', _sidePanel ? 'on' : 'off'),
      ],
    );
  }

  Widget _content(BuildContext context) {
    return Stack(
      children: <Widget>[
        CustomScrollView(
          controller: _scroll,
          slivers: <Widget>[
            _appBar(context),
            SliverPadding(
              padding: const EdgeInsets.all(_spacing),
              sliver: SliverAnchoredMasonry.extent(
                controller: _anchor,
                anchorAlignment: _anchorAlignment,
                maxCrossAxisExtent: _maxCrossAxisExtent,
                mainAxisSpacing: _spacing,
                crossAxisSpacing: _spacing,
                delegate: SliverChildBuilderDelegate(
                  _buildItem,
                  childCount: _itemCount,
                ),
              ),
            ),
          ],
        ),
        const AnchorLineOverlay(
          leadingInset: kToolbarHeight + _controlsHeight,
          alignment: _anchorAlignment,
        ),
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
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // Half of the width goes to the panel, so the masonry gets
                  // narrower and the anchored masonry re-seeds its lanes.
                  final double panelWidth = _sidePanel
                      ? constraints.maxWidth * 0.5
                      : 0.0;
                  // The row keeps both slots even when the panel is closed: a
                  // SliverAnchorController may only be attached to one render
                  // object, so the sliver subtree must not be recreated in the
                  // same frame that a new sliver mounts.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: _content(context)),
                      SizedBox(
                        width: panelWidth,
                        child: _sidePanel ? const _SidePanel() : null,
                      ),
                    ],
                  );
                },
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

/// A stand-in for a real reader sidebar: fixed content, no scrolling, so the
/// demo keeps a single scroll view.
class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.article_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text('Side panel', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This panel takes 50% of the width, so the masonry has half as '
                  'much room and lays out fewer lanes. The anchored masonry keeps '
                  'the item under the anchor line where it was.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                const _PanelTile(
                  icon: Icons.compress,
                  label: 'Lane count follows',
                ),
                const _PanelTile(
                  icon: Icons.push_pin_outlined,
                  label: 'Anchor holds',
                ),
                const _PanelTile(
                  icon: Icons.zoom_out_map,
                  label: 'No layout gap',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelTile extends StatelessWidget {
  const _PanelTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
