import 'dart:io';
import 'package:breakpoint/breakpoint.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:lightdao/data/phrase.dart';

import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/xdao/forum.dart';
import 'package:lightdao/data/xdao/reply.dart';
import 'package:lightdao/ui/page/drawing_board_page.dart';
import 'package:lightdao/ui/page/more/cookies_management.dart';
import 'package:lightdao/ui/page/thread.dart';
import 'package:lightdao/utils/xdao_api.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

final image_picker.ImagePicker _picker = image_picker.ImagePicker();

void showReplyBottomSheet(
  BuildContext context,
  bool isPostThread,
  int threadOrforumId,
  int maxPage,
  ReplyJson thread,
  image_picker.XFile? imageFile,
  Function(image_picker.XFile?) onImageChanged,
  TextEditingController titleControler,
  TextEditingController nameControler,
  TextEditingController contentControler,
  Function() onReplySuccess,
) {
  final appState = Provider.of<MyAppState>(context, listen: false);
  var water = false;
  var selectForum = appState.forumMap[threadOrforumId];
  var selectCookie = appState.setting.cookies.safeElementAtOrNull(
    appState.setting.currentCookie,
  );
  var pharseEditing = false;
  var showPhrasePicker = false;
  var showTitleAndAuthor =
      titleControler.text.isNotEmpty || nameControler.text.isNotEmpty
      ? true
      : false;
  var rememberThisCookie = false;
  var rememberedCookieName = '';
  var isFullscreen = false;
  if (!isPostThread &&
      appState.setting.threadUserData.containsKey(threadOrforumId)) {
    rememberThisCookie = true;
    final index = appState.setting.cookies.indexWhere(
      (c) =>
          c.name ==
          appState.setting.threadUserData[threadOrforumId]?.replyCookieName,
    );
    if (index != -1) {
      selectCookie = appState.setting.cookies[index];
      rememberedCookieName = selectCookie.name;
    }
  }
  final navigator = Navigator.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      final phrases = appState.setting.phrases;
      pageRoute({required Widget Function(BuildContext) builder}) {
        final setting = Provider.of<MyAppState>(context, listen: false).setting;
        if (setting.enableSwipeBack) {
          return SwipeablePageRoute(builder: builder);
        } else {
          return MaterialPageRoute(builder: builder);
        }
      }

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final breakpoint = Breakpoint.fromMediaQuery(context);
          final viewInsets = MediaQuery.of(context).viewInsets;
          final view = View.of(context);
          final systemTopPadding = MediaQueryData.fromView(view).padding.top;
          final TextEditingController nameController = TextEditingController();
          final TextEditingController valueController = TextEditingController();

          void handleRememberCookie(bool value) {
            rememberThisCookie = value;
            if (value && selectCookie != null) {
              appState.setState((_) {
                appState.setting.threadUserData.update(
                  threadOrforumId,
                  (data) => data.copyWith(replyCookieName: selectCookie!.name),
                  ifAbsent: () => ThreadUserData(
                    tid: threadOrforumId,
                    replyCookieName: selectCookie!.name,
                  ),
                );
              });
              rememberedCookieName = selectCookie!.name;
            } else {
              appState.setState((_) {
                appState.setting.threadUserData.remove(threadOrforumId);
              });
              rememberedCookieName = '';
            }
          }

          Widget buildTopBar() {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: breakpoint.gutters / 2),
                      child: MenuAnchor(
                        menuChildren: <Widget>[
                          MenuItemButton(
                            onPressed: () {
                              setState(() {
                                showTitleAndAuthor = !showTitleAndAuthor;
                              });
                            },
                            trailingIcon: Checkbox(
                              value: showTitleAndAuthor,
                              onChanged: (value) {
                                setState(() {
                                  showTitleAndAuthor = value ?? false;
                                });
                              },
                            ),
                            child: Text('更多编辑项'),
                          ),
                          if (!isPostThread)
                            MenuItemButton(
                              onPressed: () {
                                setState(() {
                                  handleRememberCookie(!rememberThisCookie);
                                });
                              },
                              trailingIcon: Checkbox(
                                value: rememberThisCookie,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == null) return;
                                    handleRememberCookie(value);
                                  });
                                },
                              ),
                              child: Text('本串记住当选饼干'),
                            ),
                        ],
                        builder: (_, MenuController controller, Widget? child) {
                          return IconButton(
                            onPressed: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                            icon: const Icon(Icons.more_vert),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        height: 3,
                        width: 50,
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).hintColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        setState(() {
                          isFullscreen = !isFullscreen;
                        });
                      },
                      icon: Icon(
                        isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          Widget buildTitleAndAuthorFields() {
            return Padding(
              padding: EdgeInsets.only(
                bottom: breakpoint.gutters,
                left: breakpoint.gutters,
                right: breakpoint.gutters,
              ),
              child: Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: TextField(
                      onTap: () => setState(() {
                        showPhrasePicker = false;
                      }),
                      onChanged: (value) => setState(() {}),
                      maxLines: 1,
                      controller: titleControler,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '标题',
                        suffixIcon: titleControler.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  titleControler.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: breakpoint.gutters),
                  Flexible(
                    flex: 1,
                    child: TextField(
                      onTap: () => setState(() {
                        showPhrasePicker = false;
                      }),
                      onChanged: (value) => setState(() {}),
                      controller: nameControler,
                      maxLines: 1,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: '作者',
                        suffixIcon: nameControler.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  nameControler.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildAnimatedTitleAndAuthorSection() {
            return AnimatedSize(
              duration: Durations.medium1,
              curve: Curves.linearToEaseOut,
              child: showTitleAndAuthor
                  ? buildTitleAndAuthorFields()
                  : const SizedBox.shrink(),
            );
          }

          Widget buildPhrasePicker() {
            return AnimatedSize(
              duration: Durations.medium1,
              curve: Curves.linearToEaseOut,
              child: SizedBox(
                height: showPhrasePicker ? 250 : 0,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: breakpoint.gutters),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double parentWidth = constraints.maxWidth;
                      final phraseWidth = appState.setting.phraseWidth;
                      int crossAxisCount = (parentWidth ~/ phraseWidth).clamp(
                        1,
                        20,
                      );
                      return CustomScrollView(
                        slivers: [
                          if (pharseEditing)
                            SliverReorderableGrid(
                              itemBuilder: (context, index) {
                                final key = phrases[index].key;
                                final value = phrases[index].value;
                                return Card(
                                  key: ValueKey(key),
                                  child: TextButton(
                                    onPressed: () {
                                      if (contentControler.selection.start !=
                                              -1 &&
                                          contentControler.selection.start ==
                                              contentControler.selection.end) {
                                        final lastPart = contentControler.text
                                            .substring(
                                              contentControler.selection.start,
                                            );
                                        final firstPart = contentControler.text
                                            .substring(
                                              0,
                                              contentControler.selection.start,
                                            );
                                        contentControler.text =
                                            '$firstPart$value$lastPart';
                                        contentControler.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset:
                                                    contentControler
                                                        .selection
                                                        .start +
                                                    value.length,
                                              ),
                                            );
                                      } else {
                                        contentControler.text += value;
                                      }
                                      setState(() {});
                                    },
                                    child: Text(
                                      key,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              },
                              itemCount: phrases.length,
                              onReorder: (oldIndex, newIndex) {
                                setState(() {
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = phrases.removeAt(oldIndex);
                                  phrases.insert(newIndex, item);
                                });
                              },
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: 2,
                                    crossAxisSpacing: 10.0,
                                    mainAxisSpacing: 10.0,
                                  ),
                            )
                          else
                            SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: 2,
                                    crossAxisSpacing: 10.0,
                                    mainAxisSpacing: 10.0,
                                  ),
                              itemCount: phrases.length,
                              itemBuilder: (context, index) => TextButton(
                                onPressed: () {
                                  if (contentControler.selection.start != -1 &&
                                      contentControler.selection.start ==
                                          contentControler.selection.end) {
                                    final lastPart = contentControler.text
                                        .substring(
                                          contentControler.selection.start,
                                        );
                                    final firstPart = contentControler.text
                                        .substring(
                                          0,
                                          contentControler.selection.start,
                                        );
                                    contentControler.text =
                                        '$firstPart${phrases[index].value}$lastPart';
                                    contentControler
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset:
                                            contentControler.selection.start +
                                            phrases[index].value.length,
                                      ),
                                    );
                                  } else {
                                    contentControler.text +=
                                        phrases[index].value;
                                  }
                                  setState(() {});
                                },
                                child: Text(
                                  phrases[index].key,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          if (pharseEditing)
                            SliverToBoxAdapter(
                              child: Center(
                                child: Text(
                                  '点击编辑，长按拖动',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context).hintColor,
                                      ),
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: breakpoint.gutters / 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        pharseEditing = !pharseEditing;
                                      });
                                    },
                                    label: Text(pharseEditing ? '结束' : '自定义'),
                                    icon: Icon(Icons.edit),
                                  ),
                                  SizedBox(width: 20),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      final result = await showDialog<String>(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text('添加短语'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                TextField(
                                                  controller: nameController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: '名称',
                                                      ),
                                                ),
                                                TextField(
                                                  controller: valueController,
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: '值',
                                                      ),
                                                  maxLines: null,
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Text('取消'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  final name =
                                                      nameController.text;
                                                  final value =
                                                      valueController.text;
                                                  if (name.isNotEmpty &&
                                                      value.isNotEmpty) {
                                                    Navigator.pop(
                                                      context,
                                                      '$name|$value',
                                                    );
                                                  }
                                                },
                                                child: Text('添加'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (result != null) {
                                        final parts = result.split('|');
                                        if (parts.length == 2) {
                                          final key = parts[0];
                                          final value = parts[1];
                                          setState(() {
                                            phrases.add(
                                              Phrase(key, value, canEdit: true),
                                            );
                                          });
                                        }
                                      }
                                    },
                                    label: Text('添加'),
                                    icon: Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          }

          Widget buildTextField() {
            return isFullscreen
                ? Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: breakpoint.gutters,
                      ),
                      child: TextField(
                        controller: contentControler,
                        onTap: () => setState(() {
                          showPhrasePicker = false;
                        }),
                        onChanged: (content) {
                          setState(() {});
                        },
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          labelText: isPostThread ? '正文' : '回复',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: breakpoint.gutters,
                      vertical: breakpoint.gutters / 3,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200),
                      child: TextField(
                        controller: contentControler,
                        onTap: () => setState(() {
                          showPhrasePicker = false;
                        }),
                        onChanged: (content) {
                          setState(() {});
                        },
                        minLines: 2,
                        maxLines: 100, // 随便填个比maxHeight多的数，不填布局会有问题
                        decoration: InputDecoration(
                          labelText: isPostThread ? '正文' : '回复',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  );
          }

          Widget buildBottomControls() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageFile != null)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: breakpoint.gutters,
                      vertical: breakpoint.gutters / 3,
                    ),
                    child: SizedBox(
                      height: 100,
                      child: Row(
                        children: [
                          Expanded(child: SizedBox()),
                          SizedBox(
                            height: 100,
                            child: Stack(
                              alignment: AlignmentDirectional.topCenter,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10.0),
                                  child: Image.file(File(imageFile!.path)),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    child: Icon(
                                      Icons.cancel,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withAlpha(200),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        imageFile = null;
                                        onImageChanged(null);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                CheckboxMenuButton(
                                  value: water,
                                  onChanged: (val) {
                                    setState(() {
                                      water = val ?? false;
                                    });
                                  },
                                  child: Text('添加水印'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    breakpoint.gutters,
                    breakpoint.gutters / 3,
                    breakpoint.gutters,
                    breakpoint.gutters / 3,
                  ),
                  child: Row(
                    children: [
                      if (isPostThread)
                        Flexible(
                          flex: 2,
                          child: DropdownButton2<Forum>(
                            isExpanded: true,
                            customButton: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  bottomLeft: Radius.circular(30),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: HtmlWidget(
                                      selectForum?.getShowName() ?? '',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            value: selectForum,
                            alignment: AlignmentDirectional.centerEnd,
                            iconStyleData: IconStyleData(iconSize: 0),
                            underline: SizedBox.shrink(),
                            buttonStyleData: ButtonStyleData(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(30),
                                ),
                              ),
                              elevation: 0,
                            ),
                            onChanged: (forum) {
                              if (forum != null) {
                                setState(() {
                                  selectForum = forum;
                                });
                              }
                            },
                            items: appState.forumMap.values
                                .map(
                                  (forum) => DropdownMenuItem<Forum>(
                                    value: forum,
                                    child: HtmlWidget(forum.name),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      if (isPostThread) SizedBox(width: 3),
                      Flexible(
                        flex: 3,
                        child: DropdownButton2<CookieSetting>(
                          customButton: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                              borderRadius: isPostThread
                                  ? BorderRadius.only(
                                      topRight: Radius.circular(30),
                                      bottomRight: Radius.circular(30),
                                    )
                                  : BorderRadius.all(Radius.circular(30)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Align(
                                alignment: Alignment.center,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    '${selectCookie?.getShowName() ?? '(无饼干)'}${selectCookie?.name == rememberedCookieName ? '(记忆)' : ''}',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          buttonStyleData: ButtonStyleData(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(
                                Radius.circular(30),
                              ),
                            ),
                            elevation: 0,
                          ),
                          value: selectCookie,
                          alignment: AlignmentDirectional.centerEnd,
                          iconStyleData: IconStyleData(iconSize: 0),
                          underline: SizedBox.shrink(),
                          onChanged: (cookie) {
                            if (cookie != null) {
                              setState(() {
                                selectCookie = cookie;
                              });
                            }
                          },
                          items: appState.setting.cookies
                              .map(
                                (cookie) => DropdownMenuItem<CookieSetting>(
                                  value: cookie,
                                  child: HtmlWidget(
                                    '${cookie.getShowName()}${cookie.name == rememberedCookieName ? '(记忆)' : ''}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: breakpoint.gutters,
                    vertical: breakpoint.gutters / 3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Flexible(
                        fit: FlexFit.tight,
                        child: IconButton(
                          onPressed: () async {
                            final startController = TextEditingController(
                              text: '1',
                            );
                            final endController = TextEditingController();
                            final result = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    return AlertDialog(
                                      title: Text('输入骰子范围'),
                                      content: Row(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (var v in [
                                                  -1,
                                                  -10,
                                                  -100,
                                                  -1000,
                                                ])
                                                  IconButton(
                                                    icon: Text('$v'),
                                                    onPressed: () {
                                                      int current =
                                                          int.tryParse(
                                                            startController
                                                                .text,
                                                          ) ??
                                                          0;
                                                      current += v;
                                                      startController.text =
                                                          current.toString();
                                                      setState(() {});
                                                    },
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: startController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: '起',
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Text(
                                              '~',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 24,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: endController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: '止',
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (var v in [
                                                  1,
                                                  10,
                                                  100,
                                                  1000,
                                                ])
                                                  IconButton(
                                                    icon: Text('+$v'),
                                                    onPressed: () {
                                                      int end =
                                                          int.tryParse(
                                                            endController.text,
                                                          ) ??
                                                          0;
                                                      end += v;
                                                      endController.text = end
                                                          .toString();
                                                      setState(() {});
                                                    },
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              (startController.text
                                                      .trim()
                                                      .isNotEmpty &&
                                                  endController.text
                                                      .trim()
                                                      .isNotEmpty)
                                              ? () {
                                                  Navigator.of(
                                                    context,
                                                  ).pop(true);
                                                }
                                              : null,
                                          child: Text('确定'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                            if (result == true) {
                              final startText = startController.text.trim();
                              final endText = endController.text.trim();
                              if (startText.isEmpty || endText.isEmpty) {
                                return;
                              }
                              final start = int.tryParse(startText);
                              final end = int.tryParse(endText);
                              if (start == null || end == null) {
                                return;
                              }
                              String insertText;
                              if ((start == 0 && end != 0) ||
                                  (end == 0 && start != 0)) {
                                insertText = '[${start == 0 ? end : start}]';
                              } else {
                                insertText = '[$start,$end]';
                              }
                              contentControler.text += insertText;
                              setState(() {});
                            }
                          },
                          icon: Icon(Icons.casino),
                        ),
                      ),
                      SizedBox(width: 20),
                      Flexible(
                        fit: FlexFit.tight,
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              showPhrasePicker = !showPhrasePicker;
                            });
                            SystemChannels.textInput.invokeMethod(
                              'TextInput.hide',
                            );
                          },
                          icon: Icon(Icons.emoji_emotions),
                        ),
                      ),
                      SizedBox(width: 20),
                      Flexible(
                        fit: FlexFit.tight,
                        child: IconButton(
                          onPressed: () async {
                            final file = await _picker.pickImage(
                              source: image_picker.ImageSource.gallery,
                            );
                            setState(() {
                              imageFile = file;
                              onImageChanged(file);
                            });
                          },
                          icon: Icon(Icons.photo),
                        ),
                      ),
                      SizedBox(width: 20),
                      Flexible(
                        fit: FlexFit.tight,
                        child: IconButton(
                          onPressed: () async {
                            final result = await navigator.push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    DrawingBoardPage(initialImage: imageFile),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                imageFile = result;
                                onImageChanged(result);
                              });
                            }
                          },
                          icon: Icon(Icons.draw),
                        ),
                      ),
                      SizedBox(width: 20),
                      Flexible(
                        fit: FlexFit.tight,
                        child: IconButton(
                          onPressed:
                              contentControler.text.isNotEmpty ||
                                  imageFile != null
                              ? () async {
                                  FocusScope.of(context).unfocus();
                                  if (selectCookie == null) {
                                    if (!navigator.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('还没有应用饼干'),
                                        action: SnackBarAction(
                                          label: '饼干管理',
                                          onPressed: () {
                                            navigator.push(
                                              pageRoute(
                                                builder: (context) =>
                                                    CookieManagementPage(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                    navigator.pop();
                                    return;
                                  }
                                  if (!showTitleAndAuthor &&
                                      (titleControler.text.isNotEmpty ||
                                          nameControler.text.isNotEmpty)) {
                                    setState(() {
                                      showTitleAndAuthor = true;
                                    });
                                    return;
                                  }
                                  context.loaderOverlay.show();
                                  try {
                                    if (isPostThread) {
                                      final post = await postThread(
                                        title: titleControler.text,
                                        name: nameControler.text,
                                        content: contentControler.text,
                                        fid: selectForum!.id,
                                        water: water,
                                        image: imageFile?.path != null
                                            ? File(imageFile!.path)
                                            : null,
                                        cookie: selectCookie!.cookieHash,
                                      ).timeout(Duration(seconds: 10));

                                      if (!navigator.mounted) return;
                                      navigator.pop();
                                      if (context.mounted) {
                                        context.loaderOverlay.hide();
                                      }
                                      nameControler.clear();
                                      titleControler.clear();
                                      contentControler.clear();
                                      onImageChanged(null);
                                      imageFile = null;
                                      appState.setting.replyHistory.insert(
                                        0,
                                        ReplyJsonWithPage(
                                          1,
                                          -1,
                                          post.id,
                                          ReplyJson.fromPost(post),
                                          ReplyJson.fromPost(post),
                                        ),
                                      );
                                      onReplySuccess();
                                    } else {
                                      final post = await replyThread(
                                        title: titleControler.text,
                                        name: nameControler.text,
                                        content: contentControler.text,
                                        threadId: threadOrforumId,
                                        water: water,
                                        image: imageFile?.path != null
                                            ? File(imageFile!.path)
                                            : null,
                                        cookie: selectCookie!.cookieHash,
                                      ).timeout(Duration(seconds: 10));

                                      if (!navigator.mounted) return;
                                      navigator.pop();
                                      if (context.mounted) {
                                        context.loaderOverlay.hide();
                                      }
                                      nameControler.clear();
                                      titleControler.clear();
                                      contentControler.clear();
                                      onImageChanged(null);
                                      imageFile = null;
                                      appState.setting.replyHistory.insert(
                                        0,
                                        ReplyJsonWithPage(
                                          maxPage,
                                          1,
                                          post.resto,
                                          thread,
                                          ReplyJson.fromPost(post),
                                        ),
                                      );
                                      onReplySuccess();
                                    }
                                  } catch (error) {
                                    if (!navigator.mounted) return;
                                    navigator.pop();
                                    if (!context.mounted) return;
                                    context.loaderOverlay.hide();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                }
                              : null,
                          icon: Icon(Icons.send),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          Widget finalLayout;
          if (isFullscreen) {
            finalLayout = Padding(
              padding: EdgeInsets.only(top: systemTopPadding),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                resizeToAvoidBottomInset: true,
                body: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: buildTopBar()),
                      SliverToBoxAdapter(
                        child: buildAnimatedTitleAndAuthorSection(),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          children: [
                            buildTextField(),
                            buildBottomControls(),
                            buildPhrasePicker(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            finalLayout = Padding(
              padding: EdgeInsets.only(
                top: systemTopPadding,
                bottom: viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    buildTopBar(),
                    buildAnimatedTitleAndAuthorSection(),
                    buildTextField(),
                    buildBottomControls(),
                    buildPhrasePicker(),
                  ],
                ),
              ),
            );
          }
          return finalLayout;
        },
      );
    },
  );
}

class PhraseEditDialog extends StatefulWidget {
  final void Function(String key, String value) onConfirm;
  final String? pharseKeyInit;
  final String? pharseValueInit;
  PhraseEditDialog({
    super.key,
    required this.onConfirm,
    this.pharseKeyInit,
    this.pharseValueInit,
  });

  @override
  State<PhraseEditDialog> createState() => _PhraseEditDialogState();
}

class _PhraseEditDialogState extends State<PhraseEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.pharseKeyInit ?? '';
    _valueController.text = widget.pharseValueInit ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑短语'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(labelText: '值'),
              maxLines: null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty &&
                _valueController.text.isNotEmpty) {
              widget.onConfirm(_nameController.text, _valueController.text);
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('名称和值都不能为空')));
            }
          },
          child: const Text('确认'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
      ],
    );
  }
}
