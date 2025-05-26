import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:flutter_drawing_board/paint_extension.dart';
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ImageContent extends PaintContent {
  ImageContent(this.image, {this.imageUrl = ''});

  ImageContent.data({
    required this.startPoint,
    required this.size,
    required this.image,
    required this.imageUrl,
    required Paint paint,
  }) : super.paint(paint);

  factory ImageContent.fromJson(Map<String, dynamic> data) {
    return ImageContent.data(
      startPoint: jsonToOffset(data['startPoint'] as Map<String, dynamic>),
      size: jsonToOffset(data['size'] as Map<String, dynamic>),
      imageUrl: data['imageUrl'] as String,
      image: data['image'] as ui.Image,
      paint: jsonToPaint(data['paint'] as Map<String, dynamic>),
    );
  }

  Offset startPoint = Offset.zero;
  Offset size = Offset.zero;
  final String imageUrl;
  final ui.Image image;

  String get contentType => 'ImageContent';

  @override
  void startDraw(Offset startPoint) => this.startPoint = startPoint;

  @override
  void drawing(Offset nowPoint) => size = nowPoint - startPoint;

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    final Rect rect = Rect.fromPoints(startPoint, startPoint + this.size);
    paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.fill);
  }

  @override
  ImageContent copy() => ImageContent(image);

  @override
  Map<String, dynamic> toContentJson() {
    return <String, dynamic>{
      'startPoint': startPoint.toJson(),
      'size': size.toJson(),
      'imageUrl': imageUrl,
      'paint': paint.toJson(),
    };
  }
}

class DrawingBoardPage extends StatefulWidget {
  final image_picker.XFile? initialImage;

  const DrawingBoardPage({
    super.key,
    this.initialImage,
  });

  @override
  State<DrawingBoardPage> createState() => _DrawingBoardPageState();
}

class _DrawingBoardPageState extends State<DrawingBoardPage> {
  final DrawingController _drawingController = DrawingController();
  bool _hasDrawn = false;

  @override
  void initState() {
    super.initState();
    _drawingController.addListener(_onDrawingChanged);
  }

  @override
  void dispose() {
    _drawingController.removeListener(_onDrawingChanged);
    _drawingController.dispose();
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

  Future<void> _saveDrawing() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('保存画板'),
        content: Text(widget.initialImage != null ? '是否要替换已有图片？' : '是否要保存画板内容？'),
        actions: [
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
  
    // 1: 保存/替换，2: 直接退出
    if (result == 2 || result == null) {
      if (mounted) Navigator.pop(context, null);
      return;
    }
  
    // 用户确认后继续保存操作
    final ByteData? imageData = await _drawingController.getImageData();
    if (imageData == null) return;
    // 画板的数据没有背景颜色，需要手动添加背景
    final Uint8List bytes = imageData.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image originalImage = frameInfo.image;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    // 绘制白色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, originalImage.width.toDouble(), originalImage.height.toDouble()),
      Paint()..color = Colors.white,
    );
    // 绘制原图内容
    canvas.drawImage(originalImage, Offset.zero, Paint());
    final ui.Image finalImage = await recorder
        .endRecording()
        .toImage(originalImage.width, originalImage.height);
    final ByteData? pngBytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) return;
    final Uint8List finalBytes = pngBytes.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final String fileName = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
    final String filePath = '${tempDir.path}/$fileName';
    final File tempFile = File(filePath);
    await tempFile.writeAsBytes(finalBytes);
    final xFile = image_picker.XFile(filePath, name: fileName, mimeType: 'image/png');
  
    if (mounted) {
      Navigator.pop(context, xFile);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasDrawn) return true;

    await _saveDrawing();
    return false; // 总是返回false，因为_saveDrawing会处理导航
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final Size screenSize = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('画板'),
          actions: [
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _hasDrawn ? _saveDrawing : null,
            ),
          ],
        ),
        body: SafeArea(
          child: DrawingBoard(
            controller: _drawingController,
            boardPanEnabled: false,
            boardScaleEnabled: false,
            background: Container(
              // 使用屏幕剩余尺寸
              width: screenSize.width,
              height: screenSize.height -
                  kToolbarHeight -
                  MediaQuery.of(context).padding.top,
              color: Colors.white,
            ),
            showDefaultActions: true,
            showDefaultTools: true,
            defaultToolsBuilder: (Type t, _) {
              return DrawingBoard.defaultTools(t, _drawingController)
                ..insert(
                  2,
                  DefToolItem(
                    icon: Icons.image_rounded,
                    isActive: t == ImageContent,
                    onTap: () async {
                      final picker = ImagePicker();
                      final XFile? pickedFile =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        final codec = await ui.instantiateImageCodec(bytes);
                        final frame = await codec.getNextFrame();
                        final ui.Image image = frame.image;
                        _drawingController.setPaintContent(ImageContent(image));
                      }
                    },
                  ),
                );
            },
          ),
        ),
      ),
    );
  }
}
