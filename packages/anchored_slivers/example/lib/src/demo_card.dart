import 'package:flutter/material.dart';

import 'demo_images.dart';

const List<String> _bodies = <String>[
  'A short paragraph stands in for real content, so every card has the same '
      'header and a different amount of body text.',
  'Cards resize while you scroll: the anchored sliver keeps the item under '
      'the anchor line where it is, whatever moves above it.',
  'The coloured block is a fake image. It starts short and grows once the '
      'load finishes, exactly like a network image would.',
  'Prepend, resize and jump from the app bar and watch which items move and '
      'which stay put.',
];

String _bodyFor(int id) => _bodies[demoHash(id * 13 + 5) % _bodies.length];

/// One demo card: number, short text and a fake image that changes height.
///
/// The bottom 12 dp of the card is spacing, so an item is a single box for the
/// sliver and the gap is part of its extent.
class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.id,
    required this.imageHeight,
    required this.imageLoaded,
  });

  final int id;
  final double imageHeight;
  final bool imageLoaded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color accent = demoColor(id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Narrow lanes (folded phones, many masonry columns) drop the
              // badge and the body copy so nothing can overflow.
              final bool compact = constraints.maxWidth < 150;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: compact ? 26 : 32,
                        height: compact ? 26 : 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$id',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Card #$id',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (!compact) ...<Widget>[
                        const SizedBox(width: 8),
                        _Badge(
                          text: imageLoaded
                              ? '${imageHeight.round()} dp'
                              : 'loading',
                        ),
                      ],
                    ],
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      _bodyFor(id),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _FakeImage(
                    height: imageHeight,
                    loaded: imageLoaded,
                    accent: accent,
                    compact: compact,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(text, style: theme.textTheme.labelSmall),
      ),
    );
  }
}

/// The stand-in for a network image: a flat colour block that changes height
/// when the "load" finishes.
///
/// It is deliberately not animated: the jump is the thing being demonstrated,
/// and an animation would hide it.
class _FakeImage extends StatelessWidget {
  const _FakeImage({
    required this.height,
    required this.loaded,
    required this.accent,
    required this.compact,
  });

  final double height;
  final bool loaded;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String label = loaded
        ? (compact ? '${height.round()} dp' : 'image · ${height.round()} dp')
        : (compact ? 'loading' : 'loading image…');

    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: loaded
            ? Color.alphaBlend(accent.withValues(alpha: 0.75), colors.surface)
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: loaded ? null : Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            loaded ? Icons.image_outlined : Icons.downloading_outlined,
            size: 14,
            color: colors.onSurface.withValues(alpha: 0.62),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
