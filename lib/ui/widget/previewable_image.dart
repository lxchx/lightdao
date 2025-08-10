import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lightdao/ui/page/xdao_image_viewer.dart';
import 'package:lightdao/ui/widget/conditional_hero.dart';

import '../../data/global_storage.dart';

class LongPressPreviewImage extends StatefulWidget {
  final String img;
  final String ext;
  final String? imageHeroTag;
  final bool isRawPicMode;
  final List<String>? imageNames;
  final int? initIndex;
  final bool cacheImageSize;
  final Function(File imageFile, Object? heroTag)? onEdit;

  LongPressPreviewImage({
    required this.img,
    required this.ext,
    this.imageHeroTag,
    this.isRawPicMode = false,
    this.imageNames,
    this.initIndex,
    this.cacheImageSize = false,
    this.onEdit,
  });

  @override
  State<LongPressPreviewImage> createState() => _LongPressPreviewImageState();
}

class _LongPressPreviewImageState extends State<LongPressPreviewImage>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  OverlayEntry? _blurOverlayEntry;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isPreview = false;
  double? cacheWidth;
  double? cacheHeight;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    final size = memoryImageInfoCache.get('${widget.img}${widget.ext}');
    cacheWidth = size?.width;
    cacheHeight = size?.height;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showPreview(BuildContext context) {
    HapticFeedback.lightImpact();
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    Size size = renderBox.size;
    _blurOverlayEntry = _createBlurOverlayEntry(context);
    Overlay.of(context).insert(_blurOverlayEntry!);
    _overlayEntry = _createOverlayEntry(context, offset, size);
    Overlay.of(context).insert(_overlayEntry!);
    Future.delayed(Durations.short1, () {
      setState(() {
        _isPreview = true;
        _overlayEntry?.markNeedsBuild();
      });
    });
    _animationController.forward();
  }

  void _hidePreview() {
    setState(() {
      _isPreview = false;
      _overlayEntry?.markNeedsBuild();
    });

    _animationController.reverse().then((_) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _blurOverlayEntry?.remove();
      _blurOverlayEntry = null;
    });
  }

  OverlayEntry _createBlurOverlayEntry(BuildContext context) {
    return OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _animation,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  OverlayEntry _createOverlayEntry(
    BuildContext context,
    Offset initOffset,
    Size initSize,
  ) {
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            AnimatedPositioned(
              curve: Curves.easeOutExpo,
              duration: Durations.medium1,
              top: !_isPreview ? initOffset.dy : 0,
              left: !_isPreview ? initOffset.dx : 0,
              width: !_isPreview
                  ? initSize.width
                  : MediaQuery.of(context).size.width,
              height: !_isPreview
                  ? initSize.height
                  : MediaQuery.of(context).size.height,
              child: Material(
                color: Colors.transparent,
                child: FadeTransition(
                  opacity: _animation,
                  child: AnimatedPadding(
                    duration: Durations.medium1,
                    curve: Curves.easeOutExpo,
                    padding: _isPreview
                        ? EdgeInsets.all(50)
                        : EdgeInsets.all(0),
                    child: CachedNetworkImage(
                      cacheManager: MyImageCacheManager(),
                      imageUrl:
                          'https://image.nmb.best/image/${widget.img}${widget.ext}',
                      progressIndicatorBuilder:
                          (context, url, downloadProgress) => Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CachedNetworkImage(
                                  cacheManager: MyImageCacheManager(),
                                  imageUrl:
                                      'https://image.nmb.best/thumb/${widget.img}${widget.ext}',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              CircularProgressIndicator(
                                value: downloadProgress.progress,
                              ),
                            ],
                          ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showPreview(context),
      onLongPressUp: _hidePreview,
      onTap: () {
        if (widget.imageNames != null && widget.initIndex != null) {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  XdaoImageViewer(
                    initIndex: widget.initIndex!,
                    imageNames: widget.imageNames!,
                    heroTag: widget.imageHeroTag,
                    onEdit: widget.onEdit,
                  ),
            ),
          );
        } else {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  XdaoImageViewer(
                    initIndex: 0,
                    imageNames: ['${widget.img}${widget.ext}'],
                    heroTag: widget.imageHeroTag,
                    onEdit: widget.onEdit,
                  ),
            ),
          );
        }
      },
      child: ConditionalHero(
        tag: widget.imageHeroTag,
        child: CachedNetworkImage(
          cacheManager: MyImageCacheManager(),
          onImageLoaded: widget.cacheImageSize
              ? (imageInfo, synchronousCall) {
                  memoryImageInfoCache.put(
                    '${widget.img}${widget.ext}',
                    Size(
                      imageInfo.image.width.toDouble(),
                      imageInfo.image.height.toDouble(),
                    ),
                  );
                }
              : null,
          imageUrl: widget.isRawPicMode
              ? 'https://image.nmb.best/image/${widget.img}${widget.ext}'
              : 'https://image.nmb.best/thumb/${widget.img}${widget.ext}',
          progressIndicatorBuilder: (context, url, downloadProgress) =>
              SizedBox(
                width: cacheWidth,
                height: cacheHeight,
                child: cacheWidth == null
                    ? CircularProgressIndicator(
                        value: downloadProgress.progress,
                      )
                    : Center(
                        child: CircularProgressIndicator(
                          value: downloadProgress.progress,
                        ),
                      ),
              ),
        ),
      ),
    );
  }
}
