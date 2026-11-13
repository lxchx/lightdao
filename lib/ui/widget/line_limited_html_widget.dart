import 'package:flutter/material.dart';
import 'package:lightdao/utils/bench_flags.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/utils/content_widget_factory.dart';
import 'package:provider/provider.dart';

class LineLimitedHtmlWidget extends StatefulWidget {
  const LineLimitedHtmlWidget({
    super.key,
    required this.content,
    this.maxLength,
    required this.contentBuilder,
  });

  final String content;
  final int? maxLength;
  final ContentWidgetFactory Function() contentBuilder;

  @override
  State<LineLimitedHtmlWidget> createState() => _LineLimitedHtmlWidgetState();
}

class _LineLimitedHtmlWidgetState extends State<LineLimitedHtmlWidget> {
  static final threadUrlRegex = RegExp(
    r'(https?://)?www\.nmbxd1?\.com\/(m\/)?t\/(\d+)',
  );
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    String displayContent = widget.content;
    final needCollapsed =
        widget.maxLength != null && widget.content.length > widget.maxLength!;
    if (needCollapsed) {
      displayContent = _isExpanded
          ? widget.content
          : '${widget.content.substring(0, widget.maxLength!)}...';
    }

    // 只有"折叠着"的长内容才需要底部渐隐。渐隐用的 ShaderMask 会让这块内容
    // 先画到一张离屏图层再合成，滚动时每帧都要付这笔钱；原来不管折不折叠都套，
    // 一屏十几条就是十几张离屏图层。
    final fadeBottom = needCollapsed && !_isExpanded && !BenchFlags.off('fade');
    return Column(
      children: [
        _BottomFade(
          enabled: fadeBottom,
          child: LayoutBuilder(
            builder: (context, covariant) {
              return SizedBox(
                width: covariant.maxWidth,
                child: HtmlWidget(
                  displayContent,
                  onTapUrl: (url) async {
                    final threadIdMatch = threadUrlRegex.firstMatch(url);
                    if (threadIdMatch != null) {
                      final threadId = int.tryParse(
                        threadIdMatch.group(3) ?? '',
                      );
                      final appState = Provider.of<MyAppState>(
                        context,
                        listen: false,
                      );
                      if (threadId == null) return false;
                      appState.navigateThreadPage2(context, threadId, false);
                      return true;
                    }
                    return false;
                  },
                  factoryBuilder: widget.contentBuilder,
                ),
              );
            },
          ),
        ),
        if (widget.maxLength != null &&
            widget.content.length > widget.maxLength!)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: SizedBox(
              height: 30,
              child: Row(
                children: [
                  Expanded(
                    child: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 底部渐隐。[enabled] 为 false 时直接返回 [child]，不产生离屏图层。
class _BottomFade extends StatelessWidget {
  const _BottomFade({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ShaderMask(
      shaderCallback: (rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
