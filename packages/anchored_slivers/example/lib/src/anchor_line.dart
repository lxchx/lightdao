import 'package:flutter/material.dart';

/// A translucent line that marks where the sliver's anchor sits.
///
/// [leadingInset] is the height of the pinned app bar: the sliver's visible
/// area starts below it, so the line is placed inside that area at
/// [alignment] (0.0 leading edge, 1.0 trailing edge), matching
/// `anchorAlignment`.
class AnchorLineOverlay extends StatelessWidget {
  const AnchorLineOverlay({
    super.key,
    required this.leadingInset,
    required this.alignment,
  });

  final double leadingInset;
  final double alignment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double height = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : 0.0;
          final double visible = (height - leadingInset).clamp(
            0.0,
            double.infinity,
          );
          final double y = leadingInset + visible * alignment;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: y,
                child: Container(
                  height: 1.5,
                  color: colors.primary.withValues(alpha: 0.55),
                ),
              ),
              Positioned(
                right: 10,
                top: y - 21,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      'anchor line ${(alignment * 100).round()}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
