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
                            if (state.setting.currentCookie == index) {
                              state.setting.currentCookie = 0;
                            }
                            state.setting.cookies.remove(c);
                            if (state.setting.cookies.isEmpty) {
                              state.setting.currentCookie = -1;
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
            }
            final Map<String, dynamic> jsonMap = jsonDecode(result ?? '');
            if (jsonMap.containsKey('cookie') && jsonMap.containsKey('name')) {
              navigator.pop((jsonMap['name'], jsonMap['cookie']));
            } else {
              navigator.pop();
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text("无效的二维码格式")),
              );
            }
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
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: cookieController,
                  decoration: InputDecoration(labelText: 'Cookie'),
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
  try {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      return null;
    }
    final result = await FlutterQrReader.imgScan(pickedFile.path);
    return result;
  } catch (e) {
    return null;
  }
}

Future<String?> scanQRCodeWithCamera() async {
  try {
    final ImagePicker picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      return null;
    }
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
