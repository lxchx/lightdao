import 'package:flutter/material.dart';

/// A compact one-line readout of what the sliver is doing.
///
/// Every value gets its own [Text] with a stable key so tests can assert on
/// numbers (the anchor index, the lane count) instead of on pixels.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.prefix, required this.entries});

  /// Prepended to the keys of the value texts, so the list page and the
  /// masonry page can both be on screen at once.
  final String prefix;

  /// Label / value pairs, rendered in order.
  final List<(String, String)> entries;

  /// Key of the [Text] that shows [label] on the page using [prefix].
  static Key valueKey(String prefix, String label) =>
      Key('$prefix-status-$label');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final (String label, String value) in entries) ...<Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                value,
                key: valueKey(prefix, label),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ],
        ),
      ),
    );
  }
}
