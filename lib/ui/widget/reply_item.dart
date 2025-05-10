import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/thread_filter.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/ui/widget/line_limited_html_widget.dart';
import 'package:lightdao/utils/content_widget_factory.dart';
import 'package:provider/provider.dart';

import '../../data/xdao/ref.dart';
import '../../utils/kv_store.dart';
import '../../utils/time_parse.dart';
import 'conditional_hero.dart';
import 'previewable_image.dart';

class ReplyItem extends StatelessWidget {
  static final RegExp refHtmlPattern = RegExp(
      '(<font color=\\"#789922\\">&gt;&gt;(No.)?(\\d+)<\\/font>)(<br\\s*\\/?>)?(\\\\r|\\\\n)?');

  // 匹配http url，但不能是<a href=“或者>打头的，否则会破坏原有的html跳转标签
  // 可以保证用户输入的'<'会被转义成‘&lt;’，所以没有误解析用户输入的风险
  // '&' 会被转义成 '&amp;'，需要特别处理
  static final RegExp httpUrlPattern = RegExp(
      r'(?<!<a href=")(?<!>)https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b((?:[-a-zA-Z0-9()@:%_\+.~#?//=]|&amp;)*)');

  final ReplyJson threadJson;
  final Object? contentHeroTag;
  final String? imageHeroTag;
  final String? poUserHash;
  final bool contentNeedCollapsed;
  final bool collapsedRef;
  final LRUCache<int, Future<RefHtml>>? refCache;
  final bool isThreadFirstOrForumPreview;
  final bool noMoreParse;
  final bool inCardView;
  final bool isRawPicMode;
  final List<String>? imageNames;
  final int? imageInitIndex;
  final bool cacheImageSize;

  ReplyItem({
    super.key,
    required this.threadJson,
    this.imageHeroTag,
    this.poUserHash,
    this.contentHeroTag,
    this.refCache,
    required this.contentNeedCollapsed,
    this.isThreadFirstOrForumPreview = false,
    this.collapsedRef = false,
    this.noMoreParse = false,
    this.inCardView = false,
    this.isRawPicMode = false,
    this.imageNames,
    this.imageInitIndex,
    this.cacheImageSize = false,
  }) {
    assert(
        // 如果imageInitIndex有效（非null且>=0），则imageNames必须有效（非null且非空）
        (imageInitIndex == null || (imageInitIndex != null && imageInitIndex! < 0)) ||
        (imageNames != null && imageNames!.isNotEmpty),
        'imageInitIndex有效时，imageNames必须非空');
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final bool isPo = poUserHash == threadJson.userHash;
    final contentWithOutRefNextLine = threadJson.content
        .replaceAllMapped(refHtmlPattern, (match) => match.group(1) ?? '');
    final contentWithHidableElement = contentWithOutRefNextLine
        .replaceAll('[h]', '<hidable>')
        .replaceAll('[/h]', '</hidable>')
        .replaceAllMapped(
            httpUrlPattern,
            (match) =>
                '<a href="${match.group(0)!}" target="_blank">${match.group(0)!}</a>');
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConditionalHero(
            tag: contentHeroTag,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Row(
                        children: [
                          Text(threadJson.userHash,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: threadJson.admin
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer)),
                          if (isPo) Padding(padding: EdgeInsets.all(2)),
                          if (isPo)
                            Badge(
                                padding: EdgeInsets.symmetric(horizontal: 5),
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                label: Text("po",
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer))),
                        ],
                      )),
                      Container(
                        alignment: Alignment.centerRight,
                        child: threadJson.userHash != "Tips"
                            ? Text(
                                'No.${threadJson.id.toString()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: Theme.of(context).hintColor),
                              )
                            : null,
                      )
                    ],
                  ),
                  if (threadJson.userHash != "Tips")
                    Text(
                      parseJsonTimeStr(threadJson.now,
                          displayExactTime: appState.setting.displayExactTime),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).hintColor),
                    ),
                  if (inCardView)
                    SizedBox(
                      height: 5,
                    ),
                  if (threadJson.sage)
                    Text(
                      '已SAGE',
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .fontSize! *
                              1.1,
                          color: Theme.of(context).colorScheme.error),
                    ),
                  if (threadJson.title != '无标题' &&
                      threadJson.userHash != "Tips")
                    Text(
                      threadJson.title,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          fontSize: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .fontSize! *
                              1.1,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  if (threadJson.name != '无名氏')
                    Text(
                      threadJson.name,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.secondary),
                    ),
                  if (inCardView)
                    SizedBox(
                      height: 5,
                    ),
                  if (!noMoreParse)
                    LineLimitedHtmlWidget(
                      content: contentWithHidableElement,
                      maxLength: contentNeedCollapsed
                          ? appState.setting.collapsedLen
                          : null,
                      contentBuilder: () => ContentWidgetFactory(
                          refMustCollapsed: collapsedRef,
                          inRefView: 0,
                          poUserHash: poUserHash,
                          refCache: refCache,
                          inPopView: false,
                          isThreadFirstOrForumPreview:
                              isThreadFirstOrForumPreview),
                    )
                  else
                    HtmlWidget(
                      contentNeedCollapsed
                          ? threadJson.content.length <=
                                  appState.setting.collapsedLen
                              ? threadJson.content
                              : '${threadJson.content.substring(0, appState.setting.collapsedLen)}<br>...'
                          : threadJson.content,
                    )
                ],
              ),
            ),
          ),
          if (threadJson.img != '' && !noMoreParse)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: LongPressPreviewImage(
                  img: threadJson.img,
                  ext: threadJson.ext,
                  imageHeroTag: imageHeroTag,
                  isRawPicMode: isRawPicMode,
                  initIndex: imageInitIndex,
                  imageNames: imageNames,
                  cacheImageSize: cacheImageSize,
                )),
        ],
      );
    });
  }
}

class FilterableThreadWidget extends StatefulWidget {
  final Widget child;
  final ReplyJson reply;
  final bool isTimeLineFilter;

  const FilterableThreadWidget({
    super.key,
    required this.child,
    required this.reply,
    required this.isTimeLineFilter,
  });

  @override
  State<FilterableThreadWidget> createState() => _FilterableThreadWidgetState();
}

class _FilterableThreadWidgetState extends State<FilterableThreadWidget> {
  bool _isExpanded = false; // 控制展开/收起的状态

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final filterResult = widget.isTimeLineFilter
        ? appState.filterTimeLineThread(widget.reply)
        : appState.filterCommonReply(widget.reply);
    final breakpoint = Breakpoint.fromMediaQuery(context);

    if (filterResult.$1) {
      String reason;
      var filter = filterResult.$2; // 获取到的filter实例

      // 根据不同类型的filter实例生成理由
      if (filter is ForumThreadFilter) {
        reason =
            "版面 ${appState.forumMap[widget.reply.fid]?.getShowName() ?? '(fid: ${widget.reply.fid})'}";
      } else if (filter is IdThreadFilter) {
        reason = "No.${widget.reply.id}";
      } else if (filter is UserHashFilter) {
        reason = "饼干 ${widget.reply.userHash}";
      } else {
        reason = "未知";
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() {
              _isExpanded = !_isExpanded;
            }),
            onLongPress: () {
              if (filterResult.$2 != null) {
                appState.removeFilter(filterResult.$2!);
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                AnimatedCrossFade(
                  duration: Durations.short4,
                  firstChild: Icon(
                    Icons.visibility,
                    color: Theme.of(context).hintColor,
                  ),
                  secondChild: Icon(
                    Icons.visibility_off,
                    color: Theme.of(context).hintColor,
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "因 $reason 屏蔽\n点击临时展开，长按取消屏蔽",
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
          //if (_isExpanded)
          AnimatedSwitcher(
            duration: Durations.short4,
            child: !_isExpanded
                ? null
                : Padding(
                    padding: EdgeInsets.only(top: breakpoint.gutters / 2),
                    child: widget.child,
                  ),
          ),
        ],
      );
    }

    return widget.child;
  }
}
