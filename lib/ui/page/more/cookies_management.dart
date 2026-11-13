import 'dart:convert';

import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_qr_reader_plus/flutter_qr_reader.dart';

import '../../../data/setting.dart';

class CookieManagementPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    return Scaffold(
      appBar: AppBar(title: Text('饼干管理')),
      body: ListView(
        padding: EdgeInsets.all(breakpoint.gutters),
        children: [
          ...appState.setting.cookies.mapIndex(
            (index, c) => Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12.0),
                onTap: () {
                  appState.setState((state) {
                    state.setting.currentCookie = index;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(
                          index != appState.setting.currentCookie
                              ? Icons.cookie_outlined
                              : Icons.cookie_rounded,
                          color: index != appState.setting.currentCookie
                              ? null
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            c.getShowName(),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () async {
                          TextEditingController displayNameController =
                              TextEditingController(
                                text:
                                    appState.setting.cookies[index].displayName,
                              );
                          String? result = await showDialog<String>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('饼干备注'),
                                content: TextField(
                                  controller: displayNameController,
                                  decoration: InputDecoration(
                                    hintText: "请输入备注",
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(
                                        context,
                                      ).pop(displayNameController.text);
                                    },
                                    child: Text('确定'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null) {
                            appState.setState((_) {
                              appState.setting.cookies[index].displayName =
                                  displayNameController.text;
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          appState.setState((state) {
                            final current = state.setting.currentCookie;
                            if (current == index) {
                              // 删掉的正是当前账号：退回列表第一项
                              state.setting.currentCookie = 0;
                            } else if (current > index) {
                              // 删的是当前账号之前的项：后面的元素整体前移一位，
                              // 下标不减一就会指向"下一个账号"（或越界成匿名态）
                              state.setting.currentCookie = current - 1;
                            }
                            // 删的是当前账号之后的项：下标不用动

                            state.setting.cookies.remove(c);

                            if (state.setting.cookies.isEmpty) {
                              state.setting.currentCookie = -1;
                            } else {
                              // 兜底：无论怎么删，下标都必须落在列表范围内
                              state.setting.currentCookie = state
                                  .setting
                                  .currentCookie
                                  .clamp(0, state.setting.cookies.length - 1)
                                  .toInt();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16.0),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('添加饼干'),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final cookieResult = await showAddCookieDialog(context);
              if (cookieResult == null) return;
              final (name, hash) = cookieResult;
              if (!appState.setting.cookies.any((c) => c.cookieHash == hash)) {
                appState.setState((_) {
                  appState.setting.cookies.add(
                    CookieSetting(
                      cookieHash: hash,
                      name: name,
                      displayName: '',
                    ),
                  );
                  if (appState.setting.cookies.length == 1) {
                    appState.setting.currentCookie = 0;
                  }
                });
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text("添加成功，编辑添加备注")),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text("饼干已存在")),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// 解析二维码里的饼干信息，返回 (name, cookieHash)。
///
/// 二维码内容必须是 JSON 对象且带 name / cookie 两个键；解析失败或格式
/// 不对都返回 null，由调用方提示用户。原来的实现是直接 `jsonDecode`（还要
/// 先判空），非 JSON 的二维码会抛未捕获异常。
(String, String)? parseCookieQrCode(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final name = decoded['name'];
  final cookie = decoded['cookie'];
  if (name is! String || cookie is! String) return null;
  if (name.isEmpty || cookie.isEmpty) return null;
  return (name, cookie);
}

// name, cookieHash
Future<(String, String)?> showAddCookieDialog(BuildContext context) {
  return showDialog<(String, String)>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('新增饼干'),
      children: [
        SimpleDialogOption(
          child: Text('扫描二维码'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: Text('扫描二维码')),
                  body: MobileScanner(
                    controller: MobileScannerController(
                      detectionSpeed: DetectionSpeed.normal,
                      facing: CameraFacing.back,
                    ),
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final String? code = barcodes.first.rawValue;
                        if (code != null) {
                          try {
                            final Map<String, dynamic> jsonMap = jsonDecode(
                              code,
                            );
                            if (jsonMap.containsKey('cookie') &&
                                jsonMap.containsKey('name')) {
                              Navigator.of(
                                context,
                              ).pop((jsonMap['name'], jsonMap['cookie']));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("无效的二维码格式")),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text("二维码解析错误")));
                          }
                        }
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
        SimpleDialogOption(
          child: Text('选择二维码图片'),
          onPressed: () async {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final navigator = Navigator.of(context);
            final result = await pickAndDecodeQRCode();
            if (result == null) {
              navigator.pop();
              scaffoldMessenger.showSnackBar(SnackBar(content: Text("识别失败")));
              return;
            }
            final parsed = parseCookieQrCode(result);
            if (parsed == null) {
              navigator.pop();
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text("无效的二维码格式")),
              );
              return;
            }
            navigator.pop(parsed);
          },
        ),
        SimpleDialogOption(
          child: Text('手动创建'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            final TextEditingController nameController =
                TextEditingController();
            final TextEditingController cookieController =
                TextEditingController();
            await showCookieEditDialog(
              context,
              nameController,
              cookieController,
            );
            if (nameController.text.isNotEmpty &&
                cookieController.text.isNotEmpty) {
              navigator.pop((nameController.text, cookieController.text));
            }
          },
        ),
      ],
    ),
  );
}

Future<dynamic> showCookieEditDialog(
  BuildContext context,
  TextEditingController nameController,
  TextEditingController cookieController,
) {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('手动创建'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 带 controller 的 TextField 输入时只会重绘内部的
                // EditableText，外层 StatefulBuilder 不会重建，于是下面
                // 「确认」按钮的可用性会固化成初始值（永远禁用）。这里显式
                // 触发一次重建。
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: cookieController,
                  decoration: InputDecoration(labelText: 'Cookie'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: cookieController.text.isEmpty
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                    },
              child: Text('确认'),
            ),
          ],
        ),
      );
    },
  );
}

Future<String?> pickAndDecodeQRCode() async {
  final ImagePicker picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);
  if (pickedFile == null) {
    return null;
  }
  try {
    final result = await FlutterQrReader.imgScan(pickedFile.path);
    return result;
  } catch (e) {
    return null;
  }
}

extension ReplaceWhere<E> on List<E> {
  void replaceWhere(
    bool Function(E element) test,
    E Function(E element) replacement,
  ) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) {
        this[i] = replacement(this[i]);
      }
    }
  }
}

extension MapIndexExtension<E> on List<E> {
  Iterable<T> mapIndex<T>(T Function(int index, E element) toElement) {
    return asMap().entries.map((entry) {
      return toElement(entry.key, entry.value);
    });
  }
}
