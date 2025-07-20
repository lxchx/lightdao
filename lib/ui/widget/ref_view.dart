import 'dart:io';
import 'dart:math';

import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lightdao/data/xdao/thread.dart';
import 'package:lightdao/ui/page/pop_ref_view_page.dart';
import 'package:lightdao/ui/widget/line_limited_html_widget.dart';
import 'package:lightdao/ui/widget/reply_item.dart';
import 'package:lightdao/utils/content_widget_factory.dart';
import 'package:lightdao/utils/xdao_api.dart';
import 'package:lightdao/utils/throttle.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

import '../../data/setting.dart';
import '../../data/xdao/ref.dart';
import '../../utils/kv_store.dart';
import 'previewable_image.dart';

class RefView extends StatefulWidget {
  final int refId;
  final int inRefView;
  final bool inPopView;
  final String? poUserHash;
  final LRUCache<int, Future<RefHtml>>? refCache;
  final Future<RefHtml>? replyJson;
  final bool mustCollapsed;
  final bool isThreadFirstOrForumPreview; // 在这两种情况下Content本身在Hero中了，组件就不能有Hero
  final Function(File image, Object? heroTag)? onImageEdit;
  final IntervalRunner<RefHtml>? throttle;

  RefView(
      {required this.refId,
      required this.inRefView,
      this.poUserHash,
      this.refCache,
      this.replyJson,
      required this.inPopView,
      this.isThreadFirstOrForumPreview = false,
      this.mustCollapsed = false,
      this.onImageEdit,
      this.throttle});

  @override
  State<RefView> createState() => _RefViewState();
}

class _RefViewState extends State<RefView> with SingleTickerProviderStateMixin {
  static final RegExp refHtmlPattern = RegExp(
      '(<font color=\\"#789922\\">&gt;&gt;(No.)?(\\d+)<\\/font>)(<br\\s*\\/?>)?(\\\\r|\\\\n)?');

  // 匹配http url，但不能是<a href=“或者>打头的，否则会破坏原有的html跳转标签
  // 可以保证用户输入的'<'会被转义成‘&lt;’，所以没有误解析用户输入的风险
  // '&' 会被转义成 '&amp;'，需要特别处理
  static final RegExp httpUrlPattern = RegExp(
      r'(?<!<a href=")(?<!>)https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b((?:[-a-zA-Z0-9()@:%_\+.~#?//=]|&amp;)*)');

  late Future<RefHtml> _futureReply;
  bool _isCollapsed = true;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<MyAppState>(context, listen: false);
    if (widget.inPopView && widget.inRefView == 0 ||
        widget.inRefView <= appState.setting.refCollapsing - 2) {
      _isCollapsed = false;
    }
    if (appState.setting.refPoping - 1 == 0 && !widget.inPopView ||
        widget.mustCollapsed) {
      _isCollapsed = true; // 如果不是弹窗而且rePoping设为1，第一层强制折叠，比较符合弹窗优先的逻辑
    }
    if (widget.refCache != null) {
      final ref = widget.refCache!.get(widget.refId);
      _futureReply = ref ??
          fetchRefFromHtml(widget.refId, appState.getCurrentCookie(),
              throttle: widget.throttle);
      widget.refCache!.put(widget.refId, _futureReply);
    } else {
      _futureReply = fetchRefFromHtml(
          widget.refId, appState.getCurrentCookie(),
          throttle: widget.throttle);
    }
  }

  Future<dynamic> showRefActionMenu(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        final appState = Provider.of<MyAppState>(context, listen: false);
        return SimpleDialog(
          title: Text('No.${widget.refId}'),
          children: [
            FutureBuilder(
                future: _futureReply,
                builder: (context, snapshot) {
                  pageRoute({
                    required Widget Function(BuildContext) builder,
                  }) {
                    final setting =
                        Provider.of<MyAppState>(context, listen: false).setting;
                    if (setting.enableSwipeBack) {
                      return SwipeablePageRoute(builder: builder);
                    } else {
                      return MaterialPageRoute(builder: builder);
                    }
                  }

                  if (!snapshot.hasError &&
                      snapshot.connectionState != ConnectionState.waiting) {
                    return SimpleDialogOption(
                      child: Text('复制内容'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          pageRoute(
                            builder: (BuildContext context) => Scaffold(
                              appBar: AppBar(
                                title: Text('自由复制'),
                              ),
                              body: Theme(
                                data: Theme.of(context).copyWith(
                                    textTheme: Theme.of(context)
                                        .textTheme
                                        .apply(
                                          fontSizeFactor:
                                              appState.setting.fontSizeFactor,
                                        )),
                                child: SelectionArea(
                                  child: ListView(
                                    children: [
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: ReplyItem(
                                            poUserHash: widget.poUserHash,
                                            threadJson: snapshot.data!,
                                            contentNeedCollapsed: false,
                                            noMoreParse: true,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    return Container();
                  }
                }),
            SimpleDialogOption(
              child: Text('复制引用号'),
              onPressed: () {
                Navigator.of(context).pop();
                Clipboard.setData(ClipboardData(text: '>>No.${widget.refId}'));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('>>No.${widget.refId}已复制到剪贴板中'),
                ));
              },
            ),
            SimpleDialogOption(
              child: Text('折叠引用'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isCollapsed = !_isCollapsed;
                });
              },
            ),
            SimpleDialogOption(
              child: Text('单独弹出'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return PopRefViewPage(
                        refId: widget.refId,
                        poUserHash: widget.poUserHash,
                      );
                    },
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return AnimatedSize(
        duration: widget.inPopView ? Durations.medium3 : Durations.short2,
        curve: widget.inPopView ? Curves.easeOutExpo : Curves.linear,
        child: Container(
          child: _isCollapsed
              ? InkWell(
                  onTap: () {
                    setState(() {
                      if (widget.inRefView >= appState.setting.refPoping - 1) {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder:
                                (context, animation, secondaryAnimation) {
                              return PopRefViewPage(
                                refId: widget.refId,
                                poUserHash: widget.poUserHash,
                              );
                            },
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return FadeTransition(
                                  opacity: animation, child: child);
                            },
                          ),
                        );
                      } else if (!widget.inPopView ||
                          widget.inPopView && widget.inRefView > 0) {
                        _isCollapsed = !_isCollapsed;
                      }
                    });
                  },
                  onLongPress: () {
                    showRefActionMenu(context);
                  },
                  child: Row(
                    children: [
                      Text('>>No.${widget.refId.toString()}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Color.fromARGB(255, 123, 145, 69),
                                  ))
                    ],
                  ),
                )
              : FutureBuilder<RefHtml>(
                  future: _futureReply,
                  builder: (context, snapshot) {
                    if (!snapshot.hasError) {
                      final refNotReady =
                          snapshot.connectionState == ConnectionState.waiting;
                      return Padding(
                        padding: refNotReady
                            ? EdgeInsets.all(0)
                            : EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () {
                            if (widget.inPopView) {
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                _isCollapsed = !_isCollapsed;
                              });
                            }
                          },
                          onLongPress: () {
                            showRefActionMenu(context);
                          },
                          borderRadius: BorderRadius.circular(4.0),
                          child: InputDecorator(
                            isEmpty: refNotReady,
                            decoration: InputDecoration(
                              filled: refNotReady
                                  ? null
                                  : widget.inPopView
                                      ? true
                                      : null,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withAlpha(200),
                              isDense: true,
                              contentPadding: refNotReady
                                  ? EdgeInsets.fromLTRB(
                                      0,
                                      breakpoint.gutters / 2,
                                      0,
                                      breakpoint.gutters / 2)
                                  : EdgeInsets.fromLTRB(
                                      breakpoint.gutters,
                                      breakpoint.gutters / 2,
                                      breakpoint.gutters,
                                      breakpoint.gutters / 2),
                              label: Skeletonizer(
                                enabled: refNotReady,
                                effect: ShimmerEffect(
                                    baseColor:
                                        Color.fromARGB(255, 123, 145, 69)),
                                child: Skeleton.shade(
                                    child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                      refNotReady
                                          ? '>>No.${widget.refId.toString()}'
                                          : 'No.${widget.refId.toString()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: Color.fromARGB(
                                                  255, 123, 145, 69),
                                              shadows: refNotReady
                                                  ? null
                                                  : [
                                                      Shadow(
                                                        offset: Offset(0, -1),
                                                        blurRadius: 5,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surface
                                                            .withAlpha(200),
                                                      ),
                                                    ])),
                                )),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: refNotReady
                                        ? Colors.transparent
                                        : Color.fromARGB(255, 120, 153, 34),
                                    width: 1.5),
                              ),
                            ),
                            child: refNotReady
                                ? null
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(snapshot.data!.userHash,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: snapshot.data!.admin
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .error
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onPrimaryContainer)),
                                          if (snapshot.data?.userHash ==
                                              widget.poUserHash)
                                            Padding(padding: EdgeInsets.all(2)),
                                          if (snapshot.data?.userHash ==
                                              widget.poUserHash)
                                            Badge(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 5),
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .secondaryContainer,
                                                label: Text("po",
                                                    style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSecondaryContainer))),
                                        ],
                                      ),
                                      if (snapshot.data!.sage)
                                        Text(
                                          '已SAGE',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall!
                                              .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall!
                                                          .fontSize! *
                                                      1.1,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error),
                                        ),
                                      if (snapshot.data!.title != '无标题' &&
                                          snapshot.data!.userHash != "Tips")
                                        Text(
                                          snapshot.data!.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall!
                                              .copyWith(
                                                  fontSize: Theme.of(context)
                                                          .textTheme
                                                          .titleSmall!
                                                          .fontSize! *
                                                      1.1,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                        ),
                                      if (snapshot.data!.name != '无名氏')
                                        Text(
                                          snapshot.data!.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary),
                                        ),
                                      LineLimitedHtmlWidget(
                                        content: snapshot.data!.content
                                            .replaceAllMapped(refHtmlPattern,
                                                (match) => match.group(1) ?? '')
                                            .replaceAll('[h]', '<hidable>')
                                            .replaceAll('[/h]', '</hidable>')
                                            .replaceAllMapped(
                                                httpUrlPattern,
                                                (match) =>
                                                    '<a href="${match.group(0)!}" target="_blank">${match.group(0)!}</a>'),
                                        maxLength: widget.inPopView &&
                                                widget.inRefView == 0
                                            ? null
                                            : appState.setting
                                                .collapsedLen, // 弹窗的第一层就不要折叠了
                                        contentBuilder: () => ContentWidgetFactory(
                                            inRefView: widget.inRefView + 1,
                                            poUserHash: widget.poUserHash,
                                            refCache: widget.refCache,
                                            inPopView: widget.inPopView,
                                            isThreadFirstOrForumPreview: widget
                                                .isThreadFirstOrForumPreview,
                                            onImageEdit: widget.onImageEdit),
                                      ),
                                      if (snapshot.data?.img != '')
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 5),
                                            child: LongPressPreviewImage(
                                              img: snapshot.data!.img,
                                              ext: snapshot.data!.ext,
                                              // 一个reply可能会被多次引用，只能加随机数了
                                              imageHeroTag: widget
                                                      .isThreadFirstOrForumPreview
                                                  ? null
                                                  : 'RefImage in ref ${widget.refId} ${Random().nextInt(1 << 32).toString()}',
                                              onEdit: widget.onImageEdit,
                                            )),
                                      if (snapshot.data?.threadId != -1)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            InkWell(
                                                onTap: () async {
                                                  final threadId =
                                                      snapshot.data?.threadId;
                                                  if (threadId == null) return;
                                                  appState.navigateThreadPage2(
                                                      context, threadId, false,
                                                      thread: ThreadJson
                                                          .fromRefHtml(
                                                              snapshot.data!),
                                                      fullThread: false);
                                                },
                                                child: Text('查看原串',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onPrimaryContainer)))
                                          ],
                                        )
                                    ],
                                  ),
                          ),
                        ),
                      );
                    } else {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            final appState =
                                Provider.of<MyAppState>(context, listen: false);
                            _futureReply = fetchRefFromHtml(
                                widget.refId, appState.getCurrentCookie());
                            if (widget.refCache != null) {
                              widget.refCache!.put(widget.refId, _futureReply);
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                  '>>No.${widget.refId.toString()}: ${snapshot.error}',
                                  softWrap: true,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      )),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
        ));
  }
}
