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
    Function() onReplySuccess) {
  final appState = Provider.of<MyAppState>(context, listen: false);
  var water = false;
  var selectForum = appState.forumMap[threadOrforumId];
  var selectCookie = appState.setting.cookies
      .safeElementAtOrNull(appState.setting.currentCookie);
  var pharseEditing = false;
  var showPhrasePicker = false;
  var showTitleAndAuthor =
      titleControler.text.isNotEmpty || nameControler.text.isNotEmpty
          ? true
          : false;
  var rememberThisCookie = false;
  var rememberedCookieName = '';
  if (!isPostThread &&
      appState.setting.threadUserData.containsKey(threadOrforumId)) {
    rememberThisCookie = true;
    final index = appState.setting.cookies.indexWhere((c) =>
        c.name ==
        appState.setting.threadUserData[threadOrforumId]?.replyCookieName);
    if (index != -1) {
      selectCookie = appState.setting.cookies[index];
      rememberedCookieName = selectCookie.name;
    }
  }
  final navigator = Navigator.of(context); // 事到临头再拿会拿到一个Null，暂时就先这样吧
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      final phrases = appState.setting.phrases;
      pageRoute({
        required Widget Function(BuildContext) builder,
      }) {
        final setting = Provider.of<MyAppState>(context, listen: false).setting;
        if (setting.enableSwipeBack) {
          return SwipeablePageRoute(builder: builder);
        } else {
          return MaterialPageRoute(builder: builder);
        }
      }

      return SafeArea(
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final breakpoint = Breakpoint.fromMediaQuery(context);
            return SingleChildScrollView(
              reverse: true,
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      left: breakpoint.gutters / 2),
                                  child: MenuAnchor(
                                    menuChildren: <Widget>[
                                      MenuItemButton(
                                        onPressed: () {
                                          setState(() {
                                            showTitleAndAuthor =
                                                !showTitleAndAuthor;
                                          });
                                        },
                                        trailingIcon: Checkbox(
                                          value: showTitleAndAuthor,
                                          onChanged: (value) {
                                            setState(() {
                                              showTitleAndAuthor =
                                                  value ?? false;
                                            });
                                          },
                                        ),
                                        child: Text('更多编辑项'),
                                      ),
                                      if (!isPostThread)
                                        MenuItemButton(
                                          onPressed: () {
                                            setState(() {
                                              final value = !rememberThisCookie;
                                              rememberThisCookie = value;
                                              if (value &&
                                                  selectCookie != null) {
                                                appState.setState((_) {
                                                  appState.setting.threadUserData.update(
                                                      threadOrforumId,
                                                      (data) => data.copyWith(
                                                          replyCookieName:
                                                              selectCookie!
                                                                  .name),
                                                      ifAbsent: () =>
                                                          ThreadUserData(
                                                              tid:
                                                                  threadOrforumId,
                                                              replyCookieName:
                                                                  selectCookie!
                                                                      .name));
                                                });
                                                rememberedCookieName =
                                                    selectCookie!.name;
                                              }
                                              if (!value) {
                                                appState.setState((_) {
                                                  appState
                                                      .setting.threadUserData
                                                      .remove(threadOrforumId);
                                                });
                                                rememberedCookieName = '';
                                              }
                                            });
                                          },
                                          trailingIcon: Checkbox(
                                            value: rememberThisCookie,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == null) return;
                                                rememberThisCookie = value;
                                                if (value &&
                                                    selectCookie != null) {
                                                  appState.setState((_) {
                                                    appState.setting.threadUserData.update(
                                                        threadOrforumId,
                                                        (data) => data.copyWith(
                                                            replyCookieName:
                                                                selectCookie!
                                                                    .name),
                                                        ifAbsent: () =>
                                                            ThreadUserData(
                                                                tid:
                                                                    threadOrforumId,
                                                                replyCookieName:
                                                                    selectCookie!
                                                                        .name));
                                                  });
                                                  rememberedCookieName =
                                                      selectCookie!.name;
                                                }
                                                if (!value) {
                                                  appState.setState((_) {
                                                    appState
                                                        .setting.threadUserData
                                                        .remove(
                                                            threadOrforumId);
                                                  });
                                                  rememberedCookieName = '';
                                                }
                                              });
                                            },
                                          ),
                                          child: Text('本串记住当选饼干'),
                                        ),
                                    ],
                                    builder: (_, MenuController controller,
                                        Widget? child) {
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
                            Align(
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
                            Spacer(),
                          ],
                        ),
                        AnimatedSize(
                          duration: Durations.medium1,
                          curve: Curves.linearToEaseOut,
                          child: SizedBox(
                            height: showTitleAndAuthor ? null : 0,
                            child: Padding(
                              padding:
                                  EdgeInsets.only(bottom: breakpoint.gutters),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: breakpoint.gutters),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          flex: 2,
                                          child: TextField(
                                            onTap: () =>
                                                showPhrasePicker = false,
                                            onChanged: (value) =>
                                                setState(() {}),
                                            maxLines: 1,
                                            controller: titleControler,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: '标题',
                                              suffixIcon: titleControler
                                                      .text.isNotEmpty
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
                                            onTap: () =>
                                                showPhrasePicker = false,
                                            onChanged: (value) =>
                                                setState(() {}),
                                            controller: nameControler,
                                            maxLines: 1,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: '作者',
                                              suffixIcon: nameControler
                                                      .text.isNotEmpty
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
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 200,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: breakpoint.gutters,
                                vertical: breakpoint.gutters / 3),
                            child: TextField(
                              controller: contentControler,
                              onTap: () => showPhrasePicker = false,
                              onChanged: (content) {
                                setState(() {});
                              }, // 更新发送按钮
                              minLines: showTitleAndAuthor ? null : 2,
                              maxLines: null,
                              decoration: InputDecoration(
                                labelText: isPostThread ? '正文' : '回复',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: breakpoint.gutters,
                              vertical: breakpoint.gutters / 3),
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
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHigh,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(30),
                                              bottomLeft: Radius.circular(30),
                                            )),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Align(
                                              alignment: Alignment.center,
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Text(selectForum
                                                        ?.getShowName() ??
                                                    ''),
                                              )),
                                        )),
                                    value: selectForum,
                                    alignment: AlignmentDirectional.centerEnd,
                                    iconStyleData: IconStyleData(iconSize: 0),
                                    underline: SizedBox.shrink(),
                                    buttonStyleData: ButtonStyleData(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(30)),
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
                                        .map((forum) => DropdownMenuItem<Forum>(
                                            value: forum,
                                            child: HtmlWidget(forum.name)))
                                        .toList(),
                                  ),
                                ),
                              SizedBox(
                                width: 3,
                              ),
                              Flexible(
                                flex: 3,
                                child: DropdownButton2<CookieSetting>(
                                  customButton: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHigh,
                                        borderRadius: isPostThread
                                            ? BorderRadius.only(
                                                topRight: Radius.circular(30),
                                                bottomRight:
                                                    Radius.circular(30),
                                              )
                                            : BorderRadius.all(
                                                Radius.circular(30)),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Align(
                                            alignment: Alignment.center,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Text(
                                                '${selectCookie?.getShowName() ?? '(无饼干)'}${selectCookie?.name == rememberedCookieName ? '(记忆)' : ''}',
                                              ),
                                            )),
                                      )),
                                  buttonStyleData: ButtonStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(30)),
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
                                      .map((cookie) =>
                                          DropdownMenuItem<CookieSetting>(
                                              value: cookie,
                                              child: HtmlWidget(
                                                '${cookie.getShowName()}${cookie.name == rememberedCookieName ? '(记忆)' : ''}',
                                              )))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (imageFile != null)
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: breakpoint.gutters,
                                vertical: breakpoint.gutters / 3),
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
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                          child:
                                              Image.file(File(imageFile!.path)),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            child: Icon(Icons.cancel,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.8)),
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
                                  )),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: breakpoint.gutters,
                              vertical: breakpoint.gutters / 3),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Flexible(
                                fit: FlexFit.tight,
                                child: IconButton(
                                    onPressed: () async {
                                      int? start;
                                      int? end;
                                      final startController =
                                          TextEditingController(text: '1');
                                      final endController =
                                          TextEditingController();
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
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          for (var v in [
                                                            -1,
                                                            -10,
                                                            -100
                                                          ])
                                                            IconButton(
                                                              icon: Text('$v'),
                                                              onPressed: () {
                                                                int current =
                                                                    int.tryParse(
                                                                            startController.text) ??
                                                                        0;
                                                                current += v;
                                                                startController
                                                                        .text =
                                                                    current
                                                                        .toString();
                                                                setState(() {});
                                                              },
                                                              visualDensity:
                                                                  VisualDensity
                                                                      .compact,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            startController,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText: '起',
                                                        ),
                                                        onChanged: (_) =>
                                                            setState(() {}),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 16),
                                                      child: Text(
                                                        '~',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 24,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            endController,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        decoration:
                                                            InputDecoration(
                                                          labelText: '止',
                                                        ),
                                                        onChanged: (_) =>
                                                            setState(() {}),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          for (var v in [
                                                            1,
                                                            10,
                                                            100
                                                          ])
                                                            IconButton(
                                                              icon: Text('+$v'),
                                                              onPressed: () {
                                                                int start =
                                                                    int.tryParse(
                                                                            startController.text) ??
                                                                        0;
                                                                int end = int.tryParse(
                                                                        endController
                                                                            .text) ??
                                                                    start;
                                                                end += v;
                                                                endController
                                                                        .text =
                                                                    end.toString();
                                                                setState(() {});
                                                              },
                                                              visualDensity:
                                                                  VisualDensity
                                                                      .compact,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(false),
                                                    child: Text('取消'),
                                                  ),
                                                  TextButton(
                                                    onPressed: (startController
                                                                .text
                                                                .trim()
                                                                .isNotEmpty &&
                                                            endController.text
                                                                .trim()
                                                                .isNotEmpty)
                                                        ? () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop(true);
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
                                        final startText =
                                            startController.text.trim();
                                        final endText =
                                            endController.text.trim();
                                        if (startText.isEmpty ||
                                            endText.isEmpty) return;
                                        start = int.tryParse(startText);
                                        end = int.tryParse(endText);
                                        if (start == null || end == null) {
                                          return;
                                        }
                                        String insertText;
                                        if ((start == 0 && end != 0) ||
                                            (end == 0 && start != 0)) {
                                          insertText =
                                              '[${start == 0 ? end : start}]';
                                        } else {
                                          insertText = '[$start,$end]';
                                        }
                                        contentControler.text += insertText;
                                        setState(() {});
                                      }
                                    },
                                    icon: Icon(Icons.casino)),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        showPhrasePicker = !showPhrasePicker;
                                      });
                                      SystemChannels.textInput
                                          .invokeMethod('TextInput.hide');
                                    },
                                    icon: Icon(Icons.emoji_emotions)),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: IconButton(
                                    onPressed: () async {
                                      final file = await _picker.pickImage(
                                          source:
                                              image_picker.ImageSource.gallery);
                                      setState(() {
                                        imageFile = file;
                                        onImageChanged(file);
                                      });
                                    },
                                    icon: Icon(Icons.photo)),
                              ),
                              SizedBox(
                                width: 20,
                              ),
                              Flexible(
                                fit: FlexFit.tight,
                                child: IconButton(
                                    onPressed: contentControler
                                                .text.isNotEmpty ||
                                            imageFile != null
                                        ? () async {
                                            FocusScope.of(context).unfocus();
                                            if (selectCookie == null) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text('还没有应用饼干'),
                                                action: SnackBarAction(
                                                    label: '饼干管理',
                                                    onPressed: () {
                                                      navigator.push(
                                                        pageRoute(
                                                            builder: (context) =>
                                                                CookieManagementPage()),
                                                      );
                                                    }),
                                              ));
                                              Navigator.pop(context);
                                              return;
                                            }
                                            if (!showTitleAndAuthor &&
                                                (titleControler
                                                        .text.isNotEmpty ||
                                                    nameControler
                                                        .text.isNotEmpty)) {
                                              // 当标题作者有残留时展开，中止发送
                                              setState(() {
                                                showTitleAndAuthor = true;
                                              });
                                              return;
                                            }
                                            context.loaderOverlay.show();
                                            if (isPostThread) {
                                              postThread(
                                                      title:
                                                          titleControler.text,
                                                      name: nameControler.text,
                                                      content:
                                                          contentControler.text,
                                                      fid: selectForum!.id,
                                                      water: water,
                                                      image: imageFile?.path !=
                                                              null
                                                          ? File(
                                                              imageFile!.path)
                                                          : null,
                                                      cookie: selectCookie!
                                                          .cookieHash)
                                                  .timeout(
                                                      Duration(seconds: 10))
                                                  .then((post) {
                                                Navigator.pop(context);
                                                context.loaderOverlay.hide();
                                                nameControler.clear();
                                                titleControler.clear();
                                                contentControler.clear();
                                                onImageChanged(null);
                                                imageFile = null;
                                                appState.setting.replyHistory
                                                    .insert(
                                                        0,
                                                        ReplyJsonWithPage(
                                                            1,
                                                            -1,
                                                            post.id,
                                                            ReplyJson.fromPost(
                                                                post),
                                                            ReplyJson.fromPost(
                                                                post)));
                                                onReplySuccess();
                                              }).catchError((error) {
                                                Navigator.pop(context);
                                                context.loaderOverlay.hide();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                  content:
                                                      Text(error.toString()),
                                                ));
                                              });
                                            } else {
                                              replyThread(
                                                      title:
                                                          titleControler.text,
                                                      name: nameControler.text,
                                                      content:
                                                          contentControler.text,
                                                      threadId: threadOrforumId,
                                                      water: water,
                                                      image: imageFile?.path !=
                                                              null
                                                          ? File(
                                                              imageFile!.path)
                                                          : null,
                                                      cookie: selectCookie!
                                                          .cookieHash)
                                                  .timeout(
                                                      Duration(seconds: 10))
                                                  .then((post) {
                                                Navigator.pop(context);
                                                context.loaderOverlay.hide();
                                                nameControler.clear();
                                                titleControler.clear();
                                                contentControler.clear();
                                                onImageChanged(null);
                                                imageFile = null;
                                                appState.setting.replyHistory
                                                    .insert(
                                                        0,
                                                        ReplyJsonWithPage(
                                                            maxPage,
                                                            1,
                                                            post.resto,
                                                            thread,
                                                            ReplyJson.fromPost(
                                                                post)));
                                                onReplySuccess();
                                              }).catchError((error) {
                                                Navigator.pop(context);
                                                context.loaderOverlay.hide();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                  content:
                                                      Text(error.toString()),
                                                ));
                                              });
                                            }
                                          }
                                        : null,
                                    icon: Icon(Icons.send)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: breakpoint.gutters),
                    child: AnimatedSize(
                      duration: Durations.medium1,
                      curve: Curves.linearToEaseOut,
                      child: SizedBox(
                        height: showPhrasePicker ? 250 : 0,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            double parentWidth =
                                constraints.maxWidth; // 根据宽度计算crossAxisCount
                            int crossAxisCount = parentWidth ~/ 175 + 1;
                            return CustomScrollView(
                              slivers: [
                                if (pharseEditing)
                                  SliverReorderableGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      childAspectRatio: 2,
                                      crossAxisSpacing: 10.0,
                                      mainAxisSpacing: 10.0,
                                    ),
                                    itemBuilder: (context, index) =>
                                        ReorderableGridDelayedDragStartListener(
                                      key: ValueKey(phrases[index].key),
                                      index: index,
                                      child: Center(
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            Center(
                                                child: TextButton(
                                              child: Text(phrases[index].key),
                                              onPressed: () =>
                                                  phrases[index].canEdit
                                                      ? showDialog(
                                                          context: context,
                                                          builder: (context) =>
                                                              PhraseEditDialog(
                                                            pharseKeyInit:
                                                                phrases[index]
                                                                    .key,
                                                            pharseValueInit:
                                                                phrases[index]
                                                                    .value,
                                                            onConfirm: (key,
                                                                    value) =>
                                                                appState.setState(
                                                                    (_) =>
                                                                        setState(
                                                                            () {
                                                                          phrases[index] = Phrase(
                                                                              key,
                                                                              value,
                                                                              canEdit: phrases[index].canEdit);
                                                                        })),
                                                          ),
                                                        )
                                                      : null,
                                            )),
                                            if (phrases[index].canEdit)
                                              IconButton(
                                                icon: Icon(Icons.delete),
                                                iconSize: 16,
                                                onPressed: () {
                                                  appState.setState((_) =>
                                                      setState(() {
                                                        phrases.removeAt(index);
                                                      }));
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    itemCount: phrases.length,
                                    onReorder: (oldIndex, newIndex) {
                                      appState.setState((_) => setState(() {
                                            final Phrase item =
                                                phrases.removeAt(oldIndex);
                                            phrases.insert(newIndex, item);
                                          }));
                                    },
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
                                    itemBuilder: (context, index) => TextButton(
                                        onPressed: () {
                                          if (contentControler
                                                      .selection.start !=
                                                  -1 &&
                                              contentControler
                                                      .selection.start ==
                                                  contentControler
                                                      .selection.end) {
                                            // 在光标处插入
                                            final lastPart = contentControler
                                                .text
                                                .substring(contentControler
                                                    .selection.start);
                                            contentControler.text =
                                                contentControler
                                                    .text
                                                    .replaceRange(
                                                        contentControler
                                                            .selection.start,
                                                        null,
                                                        phrases[index].value +
                                                            lastPart);
                                          } else {
                                            contentControler.text +=
                                                phrases[index].value;
                                          }
                                          setState(() {});
                                        },
                                        child: Text(phrases[index].key)),
                                    itemCount: phrases.length,
                                  ),
                                if (pharseEditing)
                                  SliverToBoxAdapter(
                                    child: Center(
                                        child: Text(
                                      '点击编辑，长按拖动',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color:
                                                  Theme.of(context).hintColor),
                                    )),
                                  ),
                                SliverToBoxAdapter(
                                    child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: breakpoint.gutters / 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            pharseEditing = !pharseEditing;
                                          });
                                        },
                                        label:
                                            Text(pharseEditing ? '结束' : '自定义'),
                                        icon: Icon(Icons.edit),
                                      ),
                                      if (pharseEditing)
                                        SizedBox(
                                          width: breakpoint.gutters,
                                        ),
                                      if (pharseEditing)
                                        FilledButton.icon(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  PhraseEditDialog(
                                                onConfirm: (key, value) {
                                                  appState.setState(
                                                      (_) => setState(() {
                                                            phrases.add(Phrase(
                                                                key, value,
                                                                canEdit: true));
                                                          }));
                                                },
                                              ),
                                            );
                                          },
                                          label: Text('添加'),
                                          icon: Icon(Icons.add),
                                        ),
                                    ],
                                  ),
                                ))
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class PhraseEditDialog extends StatefulWidget {
  final void Function(String key, String value) onConfirm;
  final String? pharseKeyInit;
  final String? pharseValueInit;
  PhraseEditDialog(
      {super.key,
      required this.onConfirm,
      this.pharseKeyInit,
      this.pharseValueInit});

  @override
  State<PhraseEditDialog> createState() => _PhraseEditDialogState();
}

class _PhraseEditDialogState extends State<PhraseEditDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    _nameController.text = widget.pharseKeyInit ?? '';
    _valueController.text = widget.pharseValueInit ?? '';
    super.initState();
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('名称和值都不能为空')),
              );
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
