import 'package:flutter/rendering.dart' hide RenderViewport;
import 'package:flutter/widgets.dart';
import 'package:tsukuyomi_list/src/tsukuyomi/rendering/viewport.dart';

part 'package:tsukuyomi_list/src/flutter/widgets/viewport.dart';

class TsukuyomiScrollViewViewport extends Viewport {
  TsukuyomiScrollViewViewport({
    super.key,
    super.axisDirection,
    super.crossAxisDirection,
    super.anchor,
    required super.offset,
    super.center,
    super.cacheExtent,
    super.cacheExtentStyle,
    super.clipBehavior,
    super.slivers,
  });

  @override
  RenderViewport createRenderObject(BuildContext context) {
    final renderViewport = super.createRenderObject(context);
    return RenderTsukuyomiScrollViewViewport(
      axisDirection: renderViewport.axisDirection,
      crossAxisDirection: renderViewport.crossAxisDirection,
      anchor: renderViewport.anchor,
      offset: renderViewport.offset,
      cacheExtent: renderViewport.cacheExtent,
      cacheExtentStyle: renderViewport.cacheExtentStyle,
      clipBehavior: renderViewport.clipBehavior,
    );
  }
}
