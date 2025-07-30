import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:image_picker/image_picker.dart';
import 'package:lightdao/ui/widget/conditional_hero.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lightdao/utils/permission_helper.dart';
import 'package:lightdao/utils/permission_debug.dart';
import 'package:lightdao/utils/photo_saver.dart';
import 'dart:io';

class DrawingBoardPage extends StatefulWidget {
  final image_picker.XFile? initialImage;
  final File? backgroundImage;
  final Object? heroTag;

  const DrawingBoardPage({
    super.key,
    this.initialImage,
    this.backgroundImage,
    this.heroTag,
  });

  @override
  State<DrawingBoardPage> createState() => _DrawingBoardPageState();
}

class _DrawingBoardPageState extends State<DrawingBoardPage> {
  final DrawingController _drawingController = DrawingController();
  bool _hasDrawn = false;
  ui.Image? _bgImage;
  Size? _bgImageSize;
  double _currentBoardWidth = 0;
  double _currentBoardHeight = 0;
  File? _backgroundImageFile;

  @override
  void initState() {
    super.initState();
    _drawingController.addListener(_onDrawingChanged);
    _loadBackgroundImage();
  }

  Future<void> _loadBackgroundImage() async {
    final imageFile = _backgroundImageFile ?? widget.backgroundImage;
    if (imageFile != null) {
      final data = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frameInfo = await codec.getNextFrame();
      setState(() {
        _bgImage = frameInfo.image;
        _bgImageSize = Size(
          _bgImage!.width.toDouble(),
          _bgImage!.height.toDouble(),
        );
      });
    }
  }

  @override
  void dispose() {
    _drawingController.removeListener(_onDrawingChanged);
    _drawingController.dispose();
    _bgImage?.dispose();
    super.dispose();
  }

  void _onDrawingChanged() {
    // 检查是否有绘制内容，使用正确的API
    if (!_hasDrawn && _drawingController.getHistory.isNotEmpty) {
      setState(() {
        _hasDrawn = true;
      });
    }
  }

  /// 将画板内容保存为图片文件
  Future<XFile?> _saveImageToFile(Directory directory, String prefix) async {
    final ByteData? drawingData = await _drawingController.getImageData();
    if (drawingData == null && _bgImage == null) {
      return null;
    }
    if (_bgImage != null &&
        drawingData == null &&
        widget.initialImage == null &&
        prefix == 'drawing') {
      return null;
    }

    ui.Image? drawingImage;
    if (drawingData != null) {
      final drawingBytes = drawingData.buffer.asUint8List();
      final drawingCodec = await ui.instantiateImageCodec(drawingBytes);
      final drawingFrameInfo = await drawingCodec.getNextFrame();
      drawingImage = drawingFrameInfo.image;
    }

    double finalImageWidth, finalImageHeight;
    if (_bgImage != null) {
      finalImageWidth = _bgImage!.width.toDouble();
      finalImageHeight = _bgImage!.height.toDouble();
    } else if (drawingImage != null) {
      finalImageWidth = drawingImage.width.toDouble();
      finalImageHeight = drawingImage.height.toDouble();
    } else {
      return null;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, finalImageWidth, finalImageHeight),
    );

    if (_bgImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, finalImageWidth, finalImageHeight),
        image: _bgImage!,
        fit: BoxFit.contain,
      );
    } else if (drawingImage != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, finalImageWidth, finalImageHeight),
        Paint()..color = Colors.white,
      );
    }

    if (drawingImage != null) {
      if (_bgImage != null) {
        // 计算背景图在画板中的实际渲染尺寸和位置
        final FittedSizes fittedBgInBoard = applyBoxFit(
          BoxFit.contain,
          Size(
            _bgImage!.width.toDouble(),
            _bgImage!.height.toDouble(),
          ), // 原始背景图尺寸
          Size(_currentBoardWidth, _currentBoardHeight), // 画板组件尺寸
        );

        // drawingImage（从controller.getImageData()获取）对应整个画板区域（_currentBoardWidth x _currentBoardHeight）
        // 用户是相对于fittedBgInBoard.destination区域进行绘制的
        // 我们需要将drawingImage中覆盖fittedBgInBoard.destination的部分
        // 缩放到覆盖原始_bgImage（finalImageWidth x finalImageHeight）

        // srcRect是drawingImage中对应可见背景图的部分
        final Rect srcRect = Rect.fromLTWH(
          0,
          0,
          drawingImage.width.toDouble(),
          drawingImage.height.toDouble(),
        );
        // dstRect是最终图片的完整尺寸（原始背景图尺寸）
        final Rect dstRect = Rect.fromLTWH(
          0,
          0,
          finalImageWidth,
          finalImageHeight,
        );

        canvas.drawImageRect(drawingImage, srcRect, dstRect, Paint());
      } else {
        // 没有背景图，drawingImage是完整内容
        canvas.drawImage(drawingImage, Offset.zero, Paint());
      }
    }

    final ui.Image finalImage = await recorder.endRecording().toImage(
      finalImageWidth.toInt(),
      finalImageHeight.toInt(),
    );
    final ByteData? pngBytes = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    drawingImage?.dispose();

    if (pngBytes == null) {
      return null;
    }

    final String fileName =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final String filePath = '${directory.path}/$fileName';
    final File file = File(filePath);
    await file.writeAsBytes(pngBytes.buffer.asUint8List());
    return XFile(filePath, name: fileName, mimeType: 'image/png');
  }

  void _saveAsDrawing() async {
    try {
      final directory = await getTemporaryDirectory();
      final xFile = await _saveImageToFile(directory, 'drawing');
      if (!mounted) return;
      if (xFile == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败！')));
        return;
      }

      // 使用PhotoSaver，让它自己处理权限
      final success = await PhotoSaver.saveImageToGallery(
        xFile.path,
        context: context,
      );

      if (success && mounted) {
        PhotoSaver.showSuccessMessage(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  Future<void> _saveDrawing(bool onExit) async {
    // 只有退出而不是点击保存或者点击保存且原来有图片时才弹窗询问
    if (onExit ||
        (!onExit &&
            widget.initialImage != null &&
            widget.initialImage != null)) {
      final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(onExit ? '退出' : '保存画板'),
          content: Text(widget.initialImage != null ? '替换已有图片？' : '保存画板？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 2),
              child: Text('放弃画板内容，直接退出'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 1),
              child: Text(widget.initialImage != null ? '替换原有图片' : '保存'),
            ),
          ],
        ),
      );

      if (result == null) return; // 用户取消了操作

      // 1: 保存/替换，2: 直接退出
      if (result == 2) {
        if (mounted) Navigator.pop(context, null);
        return;
      }
    }

    // 用户确认后继续保存操作
    final tempDir = await getTemporaryDirectory();
    final xFile = await _saveImageToFile(tempDir, 'drawing');

    if (mounted) {
      Navigator.pop(context, xFile);
    }
  }

  Future<bool> _onWillPop() async {
    // 如果没有绘制内容，并且没有背景图（或者有背景图但不是来自 initialImage 的编辑场景），则直接退出
    if (!_hasDrawn) return true;

    await _saveDrawing(true);
    return false; // 总是返回false，因为_saveDrawing会处理导航
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final Size screenSize = MediaQuery.of(context).size;
    final double appBarHeight = AppBar().preferredSize.height;
    final double topPadding = MediaQuery.of(context).padding.top;

    Widget boardBackground;
    double boardWidth;
    double boardHeight;
    bool allowPanAndScale = false;

    if (_bgImage != null && _bgImageSize != null) {
      allowPanAndScale = true;
      final double screenWidth = screenSize.width;
      final double screenHeightAvailable =
          screenSize.height - appBarHeight - topPadding;

      final FittedSizes fittedSizes = applyBoxFit(
        BoxFit.contain,
        _bgImageSize!,
        Size(screenWidth, screenHeightAvailable),
      );

      boardWidth = fittedSizes.destination.width;
      boardHeight = fittedSizes.destination.height;
      _currentBoardWidth = boardWidth;
      _currentBoardHeight = boardHeight;

      final imageFile = _backgroundImageFile ?? widget.backgroundImage;
      boardBackground = ConditionalHero(
        tag: widget.heroTag,
        child: Image.file(
          imageFile!,
          fit: BoxFit.contain,
          width: boardWidth,
          height: boardHeight,
        ),
      );
    } else {
      boardWidth = screenSize.width;
      boardHeight = screenSize.height - appBarHeight - topPadding;
      _currentBoardWidth = boardWidth;
      _currentBoardHeight = boardHeight;
      boardBackground = Container(
        width: boardWidth,
        height: boardHeight,
        color: Colors.white,
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('画板'),
          actions: [
            IconButton(
              icon: Icon(Icons.camera_alt),
              tooltip: '拍照作为背景',
              onPressed: () async {
                try {
                  // 请求相机权限
                  final hasPermission =
                      await PermissionHelper.requestCameraPermission(context);
                  if (!hasPermission) {
                    return;
                  }

                  final picker = image_picker.ImagePicker();
                  final file = await picker.pickImage(
                    source: image_picker.ImageSource.camera,
                  );
                  if (file != null) {
                    setState(() {
                      _backgroundImageFile = File(file.path);
                    });
                    await _loadBackgroundImage();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.photo_library),
              tooltip: '从相册选择背景',
              onPressed: () async {
                try {
                  final picker = image_picker.ImagePicker();
                  final file = await picker.pickImage(
                    source: image_picker.ImageSource.gallery,
                  );
                  if (file != null) {
                    setState(() {
                      _backgroundImageFile = File(file.path);
                    });
                    await _loadBackgroundImage();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.save_as),
              tooltip: '保存到相册',
              onPressed: (_hasDrawn || _bgImage != null)
                  ? _saveAsDrawing
                  : null, // 如果有背景图也允许保存
            ),
            IconButton(
              icon: Icon(Icons.done),
              tooltip: '完成并退出',
              onPressed: (_hasDrawn || _bgImage != null)
                  ? () => _saveDrawing(false)
                  : null, // 如果有背景图也允许完成
            ),
            if (Platform.isIOS)
              IconButton(
                icon: Icon(Icons.bug_report),
                tooltip: '权限调试',
                onPressed: () async {
                  await PermissionDebug.debugPhotoPermission(context);
                },
              ),
          ],
        ),
        body: SafeArea(
          child: DrawingBoard(
            alignment: Alignment.center,
            controller: _drawingController,
            boardPanEnabled: allowPanAndScale,
            boardScaleEnabled: allowPanAndScale,
            background: boardBackground,
            showDefaultActions: true,
            showDefaultTools: true,
            defaultToolsBuilder: (Type t, _) =>
                DrawingBoard.defaultTools(t, _drawingController)..insert(
                  0,
                  DefToolItem(
                    icon: Icons.circle_rounded,
                    activeColor: _drawingController.getColor,
                    onTap: () async {
                      Color selectedColor = _drawingController.getColor;
                      final color = await showDialog<Color>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('选择颜色'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: _drawingController.getColor,
                              onColorChanged: (color) {
                                setState(() {
                                  selectedColor = color;
                                });
                              },
                              pickerAreaHeightPercent: 0.8,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, selectedColor);
                              },
                              child: Text('确定'),
                            ),
                          ],
                        ),
                      );
                      if (color != null) {
                        setState(() {
                          _drawingController.setStyle(color: color);
                        });
                      }
                    },
                    isActive: true,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
