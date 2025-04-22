import 'package:flutter/material.dart';
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
  static final threadUrlRegex =
      RegExp(r'(https?:\/\/)?www\.nmbxd1\.com\/t\/(\d+)');
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

    return Column(
      children: [
        ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.black,
                Colors.black,
                _isExpanded || !needCollapsed
                    ? Colors.black
                    : Colors.transparent
              ],
            ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
          },
          blendMode: BlendMode.dstIn,
          child: LayoutBuilder(builder: (context, covariant) {
            return SizedBox(
              width: covariant.maxWidth,
              child: HtmlWidget(
                displayContent,
                onTapUrl: (url) async {
                  final threadIdMatch = threadUrlRegex.firstMatch(url);
                  if (threadIdMatch != null) {
                    final threadId = int.tryParse(threadIdMatch.group(2) ?? '');
                    final appState =
                        Provider.of<MyAppState>(context, listen: false);
                    if (threadId == null) return false;
                    appState.navigateThreadPage2(context, threadId, false);
                    return true;
                  }
                  return false;
                },
                factoryBuilder: widget.contentBuilder,
              ),
            );
          }),
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
