import 'dart:io';
import 'dart:ui';
import 'package:breakpoint/breakpoint.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lightdao/data/global_storage.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/ui/widget/conditional_hero.dart';
import 'package:lightdao/ui/widget/drag_dismissible.dart';
import 'package:lightdao/ui/widget/sharp_stretch.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 把外部传入的初始下标夹到合法范围。
///
/// 调用方可能给出越界值（例如 `allImageNames.indexOf(...)` 未命中时的 -1），
/// 直接拿去索引图片列表会抛 RangeError。
int clampImageIndex(int index, int length) {
  if (length <= 0) return 0;
  return index.clamp(0, length - 1).toInt();
}

class XdaoImageViewer extends StatefulWidget {
  final String? heroTag;
  final List<String> imageNames;
  final int initIndex;
  final Function(File imageFile, Object? heroTag)? onEdit;

  XdaoImageViewer({
    super.key,
    this.heroTag,
    required this.imageNames,
    required this.initIndex,
    this.onEdit,
  });

  @override
  State<XdaoImageViewer> createState() => _XdaoImageViewerState();
}

class _XdaoImageViewerState extends State<XdaoImageViewer> {
  bool _scaleOnly = false;
  bool _showBottomBar = true;
  late int _currentIndex;
  late PageController _pageViewController;
  final ExitSignal _exitSignal = ExitSignal();
  int _pointerCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.imageNames.isEmpty) {
      // 没有图片可看：此时 build 里 `widget.imageNames[_currentIndex]` 必然
      // 越界，先把这一页关掉（build 里还会再兜一层空占位）。
      _currentIndex = 0;
      _pageViewController = PageController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
      return;
    }
    _currentIndex = clampImageIndex(widget.initIndex, widget.imageNames.length);
    _pageViewController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageNames.isEmpty) {
      // 交给 initState 里安排的 pop 收尾，这里不做任何下标访问
      return const SizedBox.shrink();
    }
    final appState = Provider.of<MyAppState>(context);
    final breakpoint = Breakpoint.fromMediaQuery(context);
    final imageName = widget.imageNames[_currentIndex];
    final imageProvider = CachedNetworkImageProvider(
      'https://image.nmb.best/image/$imageName',
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      // 用不带 FilterQuality 重采样层的拉伸指示器（见 sharp_stretch.dart）：
      // 形变量与观感和 Material 3 默认完全一致（实测逐帧 dx 相同），
      // 但拉伸期间不再每帧创建改变尺寸的离屏重采样层。
      body: ScrollConfiguration(
        behavior: const SharpStretchScrollBehavior(),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) {
              return;
            }
            setState(() {
              _showBottomBar = false;
            });
            Navigator.pop(context);
          },
          child: Listener(
            onPointerDown: (event) {
              setState(() {
                _pointerCount++;
                if (_pointerCount > 1) {
                  _scaleOnly = true;
                }
              });
            },
            onPointerUp: (event) {
              setState(() {
                _pointerCount = _pointerCount > 0 ? _pointerCount - 1 : 0;
                if (_pointerCount <= 1 && !_scaleOnly) {
                  _scaleOnly = false;
                }
              });
            },
            onPointerCancel: (event) {
              setState(() {
                _pointerCount = _pointerCount > 0 ? _pointerCount - 1 : 0;
                if (_pointerCount <= 1 && !_scaleOnly) {
                  _scaleOnly = false;
                }
              });
            },
            child: GestureDetector(
              onTap: () => setState(() {
                _showBottomBar = !_showBottomBar;
              }),
              child: Stack(
                children: [
                  PageView.builder(
                    physics: _scaleOnly
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    onPageChanged: (page) => setState(() {
                      _currentIndex = page;
                    }),
                    itemCount: widget.imageNames.length,
                    controller: _pageViewController,
                    itemBuilder: (context, index) {
                      final imageName = widget.imageNames[index];
                      final imageProvider = CachedNetworkImageProvider(
                        'https://image.nmb.best/image/$imageName',
                      );
                      return DragDismissible(
                        backgroundColor: Theme.of(context).canvasColor,
                        onDismissed: () => Navigator.of(context).pop(),
                        exitSignal: _exitSignal,
                        enabled:
                            appState.setting.dragToDissmissImage && !_scaleOnly,
                        child: PhotoView(
                          imageProvider: imageProvider,
                          scaleStateChangedCallback:
                              (PhotoViewScaleState state) {
                                setState(() {
                                  _scaleOnly =
                                      state != PhotoViewScaleState.initial;
                                });
                              },
                          loadingBuilder: (context, imageChunkEvent) {
                            return ConditionalHero(
                              tag: index == widget.initIndex
                                  ? widget.heroTag
                                  : "Image $imageName",
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox.expand(
                                    child: CachedNetworkImage(
                                      cacheManager: MyImageCacheManager(),
                                      imageUrl:
                                          'https://image.nmb.best/thumb/$imageName',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  if (imageChunkEvent != null &&
                                      imageChunkEvent.expectedTotalBytes !=
                                          null)
                                    CircularProgressIndicator(
                                      value:
                                          imageChunkEvent
                                              .cumulativeBytesLoaded /
                                          imageChunkEvent.expectedTotalBytes!,
                                    )
                                  else
                                    CircularProgressIndicator(),
                                ],
                              ),
                            );
                          },
                          minScale: PhotoViewComputedScale.contained * 1,
                          //maxScale: PhotoViewComputedScale.covered * 2,
                          heroAttributes: widget.heroTag == null
                              ? null
                              : PhotoViewHeroAttributes(
                                  tag: index == widget.initIndex
                                      ? widget.heroTag!
                                      : "Image $imageName",
                                ),
                          backgroundDecoration: BoxDecoration(
                            color: Colors.transparent,
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedSwitcher(
                    duration: Durations.medium1,
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInExpo,
                    child: _showBottomBar
                        ? SafeArea(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: EdgeInsets.all(breakpoint.gutters),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (widget.imageNames.length > 1)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(50),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                            sigmaX: 10.0,
                                            sigmaY: 10.0,
                                          ),
                                          child: Container(
                                            color: Theme.of(context).canvasColor
                                                .withAlpha((255 * 0.4).round()),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              '${_currentIndex + 1} / ${widget.imageNames.length}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    fontSize: 24,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      SizedBox(),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(50),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 10.0,
                                          sigmaY: 10.0,
                                        ),
                                        child: Container(
                                          color: Theme.of(context).canvasColor
                                              .withAlpha((255 * 0.4).round()),
                                          child: Row(
                                            children: [
                                              if (widget.onEdit != null)
                                                IconButton(
                                                  icon: Icon(Icons.draw),
                                                  onPressed: () async {
                                                    final String url =
                                                        (imageProvider).url;
                                                    final file =
                                                        await MyImageCacheManager()
                                                            .getSingleFile(url);
                                                    widget.onEdit!(
                                                      file,
                                                      _currentIndex ==
                                                              widget.initIndex
                                                          ? widget.heroTag
                                                          : "Image $imageName",
                                                    );
                                                  },
                                                ),
                                              IconButton(
                                                icon: Icon(Icons.close),
                                                onPressed: () {
                                                  setState(() {
                                                    _exitSignal.trigger();
                                                  });
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.share),
                                                onPressed: () =>
                                                    _shareImage(imageProvider),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.save),
                                                onPressed: () => _saveImage(
                                                  context,
                                                  imageProvider,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareImage(ImageProvider imageProvider) async {
    final showSnackBar = ScaffoldMessenger.of(context).showSnackBar;
    if (imageProvider is CachedNetworkImageProvider) {
      final String url = (imageProvider).url;
      final file = await MyImageCacheManager().getSingleFile(url);
      final bytes = await file.readAsBytes();

      final tempDir = await getTemporaryDirectory();
      final tempfile = await File('${tempDir.path}/${file.basename}').create();
      await tempfile.writeAsBytes(bytes);

      final xfile = XFile(tempfile.path);
      await Share.shareXFiles([xfile]);
    } else {
      showSnackBar(SnackBar(content: Text("无法分享该类型的图片")));
    }
  }

  Future<void> _saveImage(
    BuildContext context,
    ImageProvider imageProvider,
  ) async {
    final showSnackBar = ScaffoldMessenger.of(context).showSnackBar;
    try {
      // 请求权限
      if (Platform.isAndroid) {
        if (await Permission.storage.isGranted) {
          await Permission.storage.request();
        } else if (await Permission.manageExternalStorage.isGranted) {
          await Permission.manageExternalStorage.request();
        } else if (await Permission.photos.isGranted) {
          await Permission.photos.request();
        } else {
          await [
            Permission.storage,
            Permission.manageExternalStorage,
            Permission.photos,
          ].request();
        }
      }

      if (await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted ||
          await Permission.photos.isGranted) {
        if (imageProvider is CachedNetworkImageProvider) {
          final String url = (imageProvider).url;
          final file = await MyImageCacheManager().getSingleFile(url);
          final bytes = await file.readAsBytes();

          final directory = await getTemporaryDirectory();
          final imgFile = File('${directory.path}/${file.basename}');
          await imgFile.writeAsBytes(bytes);

          await Gal.putImage(imgFile.path);

          showSnackBar(SnackBar(content: Text("图片已保存到相册")));
        } else {
          showSnackBar(SnackBar(content: Text("无法保存该类型的图片")));
        }
      } else {
        showSnackBar(SnackBar(content: Text("请授予存储权限")));
      }
    } catch (e) {
      showSnackBar(SnackBar(content: Text("发生错误: $e")));
    }
  }
}
