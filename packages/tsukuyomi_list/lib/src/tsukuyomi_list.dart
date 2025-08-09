import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/rendering.dart' show RenderProxySliver, SliverGeometry;
import 'package:flutter/scheduler.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:tsukuyomi_list/src/tsukuyomi/rendering/viewport.dart';
import 'package:tsukuyomi_list/src/tsukuyomi/widgets/scroll_activity.dart';
import 'package:tsukuyomi_list/src/tsukuyomi/widgets/scroll_view.dart';

typedef _OnPerformLayout = void Function(
  RenderBox box,
  Size? oldSize,
  Size newSize,
);

class TsukuyomiList extends StatefulWidget {
  const TsukuyomiList.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.physics,
    this.leadingExtent = 0.0,
    this.trailingExtent = 0.0,
    this.anchor,
    this.trailing = true,
    this.debugMask = false,
    this.ignorePointer = false,
    this.scrollDirection = Axis.vertical,
    this.initialScrollIndex,
    this.onItemsChanged,
    this.sliverLeading = const <Widget>[],
    this.sliverTrailing = const <Widget>[],
    this.cacheExtent,  // 添加这一行
  })  : assert(initialScrollIndex == null || initialScrollIndex >= 0),
        assert(initialScrollIndex == null ||
            initialScrollIndex < itemCount ||
            itemCount == 0),
        assert(anchor == null || (anchor >= 0.0 && anchor <= 1.0));

  /// 列表项数量
  final int itemCount;

  /// 列表项构建器
  final IndexedWidgetBuilder itemBuilder;

  /// 列表控制器
  final TsukuyomiListScrollController? controller;

  /// 物理滚动效果
  final ScrollPhysics? physics;

  /// 列表起始位置占位间距
  final double leadingExtent;

  /// 列表结束位置占位间距
  final double trailingExtent;

  /// 列表锚点位置
  final double? anchor;

  /// 是否填充列表末尾空白部分
  final bool trailing;

  /// 是否显示列表调试遮罩
  final bool debugMask;

  /// 是否忽略列表触摸事件
  final bool ignorePointer;

  /// 列表滚动方向
  final Axis scrollDirection;

  /// 列表初始位置索引
  final int? initialScrollIndex;

  /// 列表项更新
  final ValueChanged<List<TsukuyomiListItem>>? onItemsChanged;

  /// 列表头部自定义 Sliver 列表，注意list等item会反转，需要自己反转回去
  final List<Widget> sliverLeading;

  /// 列表尾部自定义 Sliver 列表
  final List<Widget> sliverTrailing;

  /// 预渲染区域大小
  final double? cacheExtent;

  @override
  State<TsukuyomiList> createState() => _TsukuyomiListState();
}

class _TsukuyomiListState extends State<TsukuyomiList> {
  // _centerIndex 仅会在以下两个位置被修改：
  // 1. initState() 方法中初始化时
  // 2. _jumpToIndex() 方法中跳转索引时
  late int _centerIndex, _anchorIndex;
  final _centerKey = UniqueKey();
  final _elements = <Element>{};
  final _extents = <int, _TsukuyomiListItemExtent>{};
  late TsukuyomiListScrollController _scrollController;

  /// 在列表中心之前的滚动区域范围
  double _scrollExtentBeforeCenter = 0.0;

  /// 在列表中心之前的滚动区域范围
  double _scrollExtentAfterCenter = 0.0;

  @override
  void initState() {
    super.initState();
    _centerIndex = _anchorIndex = widget.initialScrollIndex ?? 0;

    _scrollController = widget.controller ?? TsukuyomiListScrollController();
    _scrollController._attach(this);
  }

  @override
  void didUpdateWidget(TsukuyomiList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 更新列表控制器
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(this);
      _scrollController._attach(this);
    }
    // 重置列表项尺寸
    if (widget.scrollDirection != oldWidget.scrollDirection) {
      _extents.clear();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TsukuyomiScrollView(
      // 第二个_SliverLayout作为center，其上的sliver是反向排列的
      center: _centerKey,
      controller: _scrollController,
      physics: widget.physics,
      ignorePointer: widget.ignorePointer,
      scrollDirection: widget.scrollDirection,
      cacheExtent: widget.cacheExtent,
      slivers: [
        ...widget.sliverLeading,
        SliverToBoxAdapter(
          child: _TsukuyomiListItem(
            onPerformLayout: (box, oldSize, newSize) {
              if (oldSize == null) return;
              final (oldExtent, newExtent) = switch (widget.scrollDirection) {
                Axis.vertical => (oldSize.height, newSize.height),
                Axis.horizontal => (oldSize.width, newSize.width),
              };
              final delta = newExtent - oldExtent;
              final viewport =
                  RenderAbstractViewport.maybeOf(box) as RenderViewportBase?;
              // 只在尺寸变小时需要修正滚动偏移
              if (delta >= 0 || viewport == null) return;
              final offset = viewport.getOffsetToReveal(box, 0.0).offset;
              final trailing = offset - viewport.offset.pixels + newExtent;
              // 如果占位区域底部可见
              if (trailing > Tolerance.defaultTolerance.distance) {
                _scrollController.position.correctImmediate(-delta);
              }
            },
            child: Container(
              color: _purpleDebugMask,
              width: switch (widget.scrollDirection) {
                Axis.vertical => null,
                Axis.horizontal => widget.leadingExtent,
              },
              height: switch (widget.scrollDirection) {
                Axis.vertical => widget.leadingExtent,
                Axis.horizontal => null,
              },
            ),
          ),
        ),
        _SliverLayout(
          onPerformLayout: (geometry) {
            _scrollExtentBeforeCenter = geometry.scrollExtent;
          },
          sliver: SliverList.builder(
            itemCount: _centerIndex > 0 ? _centerIndex : 0,
            itemBuilder: (context, index) {
              return _buildItem(context, _centerIndex - index - 1);
            },
          ),
        ),
        _SliverLayout(
          key: _centerKey,
          onPerformLayout: (geometry) {
            _scrollExtentAfterCenter = geometry.scrollExtent;
          },
          sliver: SliverStack(
            children: [
              // 从列表中心位置开始计算和显示列表末尾空白部分，避免受到视窗或列表项尺寸变化的影响
              if (widget.trailing && trailingFraction > 0.0)
                SliverFillViewport(
                  padEnds: false,
                  viewportFraction: trailingFraction,
                  delegate: SliverChildBuilderDelegate(
                    childCount: 1,
                    (context, index) => Container(color: _purpleDebugMask),
                  ),
                ),
              SliverList.builder(
                itemCount: widget.itemCount - _centerIndex,
                itemBuilder: (context, index) {
                  return _buildItem(context, _centerIndex + index);
                },
              ),
            ],
          ),
        ),
        // 在列表主轴方向尺寸不足一个屏幕时填充剩余区域，统一列表回弹复位时的视觉效果
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final extentBefore = _scrollExtentBeforeCenter;
            final extentAfter = _scrollExtentAfterCenter;
            final extentMax = constraints.viewportMainAxisExtent;
            final extentLeft = extentMax - extentBefore - extentAfter;
            return SliverToBoxAdapter(
              child: Container(
                color: _pinkDebugMask,
                height: clampDouble(extentLeft, 0.0, extentMax),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: _TsukuyomiListItem(
            onPerformLayout: (box, oldSize, newSize) {
              if (oldSize == null) return;
              final (oldExtent, newExtent) = switch (widget.scrollDirection) {
                Axis.vertical => (oldSize.height, newSize.height),
                Axis.horizontal => (oldSize.width, newSize.width),
              };
              final delta = newExtent - oldExtent;
              final viewport =
                  RenderAbstractViewport.maybeOf(box) as RenderViewportBase?;
              // 只在尺寸变小时需要修正滚动偏移
              if (delta >= 0 || viewport == null) return;
              final offset = viewport.getOffsetToReveal(box, 0.0).offset;
              final viewportDimension =
                  _scrollController.position.viewportDimension;
              final leading =
                  offset - viewport.offset.pixels - viewportDimension;
              // 如果占位区域顶部可见
              if (-leading > Tolerance.defaultTolerance.distance) {
                _scrollController.position.correctImmediate(delta);
              }
            },
            child: Container(
              color: _purpleDebugMask,
              width: switch (widget.scrollDirection) {
                Axis.vertical => null,
                Axis.horizontal => widget.trailingExtent,
              },
              height: switch (widget.scrollDirection) {
                Axis.vertical => widget.trailingExtent,
                Axis.horizontal => null,
              },
            ),
          ),
        ),
        ...widget.sliverTrailing,
      ],
    );
  }

  /// 粉色调试遮罩
  Color? get _pinkDebugMask {
    return widget.debugMask ? Colors.pink.withAlpha((255 * 0.33).round()) : null;
  }

  /// 紫色调试遮罩
  Color? get _purpleDebugMask {
    return widget.debugMask ? Colors.purple.withAlpha((255 * 0.33).round()) : null;
  }

  /// 绿色调试遮罩
  Color? get _greenDebugMask {
    return widget.debugMask ? Colors.green.withAlpha((255 * 0.33).round()) : null;
  }

  /// 列表末尾空白部分占比
  double get trailingFraction => _trailingFraction;
  double _trailingFraction = 1.0;
  set trailingFraction(double value) {
    final trailingFraction = value.clamp(0.0, 1.0);
    // 列表末尾空白部分占比只能减少不能增加
    if (trailingFraction < _trailingFraction) {
      setState(() => _trailingFraction = trailingFraction);
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    return _TsukuyomiListItem(
      // 保证添加列表项和移除列表项的对应关系
      key: ValueKey(index),
      onMount: (element) {
        _elements.add(element);
        _scheduleUpdateItems();
      },
      onUnmount: (element) {
        _elements.remove(element);
        final extent = _extents[index];
        if (extent != null) {
          _extents[index] = extent.copyWith(mounted: false);
        }
        _scheduleUpdateItems();
      },
      onPerformLayout: (box, oldSize, newSize) {
        // 获取主轴方向尺寸
        final (oldExtent, newExtent) = switch (widget.scrollDirection) {
          Axis.vertical => (oldSize?.height, newSize.height),
          Axis.horizontal => (oldSize?.width, newSize.width),
        };
        // 保存最新的列表项尺寸
        _extents[index] = _TsukuyomiListItemExtent(extent: newExtent);
        // 更新列表项的信息
        if (oldExtent != newExtent) {
          _scheduleUpdateItems();
        }
        // 当前的锚点列表项同时又是中心列表项
        if (_anchorIndex == _centerIndex) return;
        // 首次布局时不需要处理尺寸变化
        if (oldExtent == null) return;
        // 计算主轴方向上发生的尺寸变化
        final delta = newExtent - oldExtent;
        // 主轴方向上的尺寸没有发生变化
        if (delta == 0) return;
        // 当前列表项在中心列表项和锚点列表项之间
        if (_centerIndex <= index && index < _anchorIndex) {
          return _scrollController.position.correctImmediate(delta);
        }
        // 当前列表项在锚点列表项和中心列表项之间
        if (_anchorIndex <= index && index < _centerIndex) {
          return _scrollController.position.correctImmediate(-delta);
        }
      },
      // 首帧布局优先使用最后一次显示时记录的尺寸大小，避免由于列表重新布局导致列表显示错位问题。
      // 比如列表项 A 默认尺寸为 100，渲染后在某些条件下尺寸变为了 300，此时将列表项 A 滚动至
      // 预渲染范围外，等列表项 A 被移除后再滚动回原来的位置。如果这个时候列表项 A 的默认尺寸依然
      // 还是 100，并且在列表项 A 重新渲染后有某处代码调用 setState 方法触发了与列表布局相关
      // 的 performRebuild 方法，就会导致列表项 A 之后的列表项整体向前错位 200。
      child: FutureBuilder(
        future: Future.value(const Object()),
        builder: (context, snapshot) {
          double? extent;
          final item = _extents[index];
          if (!snapshot.hasData && item != null && item.reusable) {
            extent = item.extent;
          }
          return Container(
            width: widget.scrollDirection == Axis.horizontal ? extent : null,
            height: widget.scrollDirection == Axis.vertical ? extent : null,
            foregroundDecoration: BoxDecoration(
              color: index == _anchorIndex
                  ? _pinkDebugMask
                  : index == _centerIndex
                      ? _greenDebugMask
                      : null,
            ),
            child: widget.itemBuilder(context, index),
          );
        },
      ),
    );
  }

  double _calculateAnchor() {
    if (widget.anchor != null) {
      return widget.anchor!;
    }
    final position = _scrollController.position;
    final extentBefore = position.extentBefore;
    final extentInside = position.extentInside;
    final extentAfter = position.extentAfter;
    // 顶部和底部剩余滚动区域一样时优先使用上半部分作为锚点
    if (extentBefore <= extentAfter && extentBefore < extentInside) {
      return (extentBefore / extentInside / 2).clamp(0.0, 0.5);
    }
    // 底部剩余滚动区域比顶部大时再选择使用下半部分作为锚点
    if (extentAfter < extentBefore && extentAfter < extentInside) {
      return (1.0 - extentAfter / extentInside / 2).clamp(0.5, 1.0);
    }
    return 0.5;
  }

  bool _updateScheduled = false;
  void _scheduleUpdateItems() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (!mounted) return;
      RenderViewportBase? viewport;
      TsukuyomiListItem? oldAnchorItem;
      final anchor = _calculateAnchor();
      final items = <TsukuyomiListItem>[];
      int anchorIndex = _anchorIndex;
      for (final element in _elements) {
        final box = element.findRenderObject() as RenderBox?;
        viewport ??= RenderAbstractViewport.maybeOf(box) as RenderViewportBase?;
        if (box == null || !box.hasSize || viewport == null) {
          continue;
        }

        final key = element.widget.key as ValueKey<int>;
        final offset = viewport.getOffsetToReveal(box, 0.0).offset;
        final item = TsukuyomiListItem(
          index: key.value,
          size: box.size,
          axis: widget.scrollDirection,
          offset: offset - viewport.offset.pixels,
          viewport: _scrollController.position.viewportDimension,
        );
        // 添加列表项信息
        items.add(item);
        // 获取旧的锚点列表项信息
        if (item.index == _anchorIndex) {
          oldAnchorItem ??= item;
        }
        // 根据中心列表项起始位置计算列表末尾空白部分占比
        if (widget.trailing && item.index == _centerIndex) {
          trailingFraction = 1.0 - item.leading;
        }
        // 遍历获取最后一个符合条件的列表项作为锚点列表项
        if (item.leading <= anchor && item.trailing >= anchor) {
          anchorIndex = item.index;
        }
      }
      // 当前锚点列表项发生位移时才更新锚点列表项索引，避免初始化或者跳转时发生预期外的偏移
      if (oldAnchorItem?.leading != 0.0 && _anchorIndex != anchorIndex) {
        setState(() => _anchorIndex = anchorIndex);
      }
      // 回调列表项更新
      widget.onItemsChanged?.call(
        // 根据索引大小对列表项信息进行排序
        items..sort((a, b) => a.index.compareTo(b.index)),
      );
    });
  }

  void _jumpToIndex(int index) {
    assert(index >= 0);
    assert(index < widget.itemCount || widget.itemCount == 0);
    setState(() {
      _trailingFraction = 1.0;
      _scrollController.jumpTo(0.0);
      _centerIndex = _anchorIndex = index;
      // 将所有当前未渲染的列表项的尺寸信息设置为不可复用，避免在列表位置跳转时列表项尺寸快速变化
      _extents.updateAll((_, value) => value.copyWith(reusable: value.mounted));
    });
  }

  Future<void> _slideViewport(
    double viewportFraction, {
    required Duration duration,
    required Curve curve,
  }) async {
    if (viewportFraction == 0.0) return;
    assert(viewportFraction >= -1.0 && viewportFraction <= 1.0);
    final position = _scrollController.position;
    final currentPixels = position.pixels;
    final delta = position.viewportDimension * viewportFraction;
    if (delta < 0.0 && currentPixels > position.minScrollExtent) {
      final to = math.max(currentPixels + delta, position.minScrollExtent);
      return position.animateTo(to, duration: duration, curve: curve);
    }
    if (delta > 0.0 && currentPixels < position.maxScrollExtent) {
      final to = math.min(currentPixels + delta, position.maxScrollExtent);
      return position.animateTo(to, duration: duration, curve: curve);
    }
  }
}

class TsukuyomiListItem {
  /// 列表项索引
  final int index;

  /// 列表项起点相对于视窗的位置
  late final double leading;

  /// 列表项终点相对于视窗的位置
  late final double trailing;

  TsukuyomiListItem({
    required this.index,
    required Size size,
    required Axis axis,
    required double offset,
    required double viewport,
  }) {
    final extent = axis == Axis.vertical ? size.height : size.width;
    leading = _position(offset, viewport);
    trailing = _position(offset + extent, viewport);
  }

  /// 计算相对于视窗的位置
  double _position(double offset, double viewport) {
    final value = offset / viewport;
    if (nearEqual(value, 0.0, Tolerance.defaultTolerance.distance)) {
      return 0.0;
    }
    if (nearEqual(value, 1.0, Tolerance.defaultTolerance.distance)) {
      return 1.0;
    }
    return value;
  }
}

class TsukuyomiListScrollController extends ScrollController {
  @override
  TsukuyomiListScrollPosition get position {
    return super.position as TsukuyomiListScrollPosition;
  }

  @override
  TsukuyomiListScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return TsukuyomiListScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  _TsukuyomiListState? _tsukuyomiListState;

  void _attach(_TsukuyomiListState state) {
    _tsukuyomiListState = state;
  }

  void _detach(_TsukuyomiListState state) {
    if (_tsukuyomiListState == state) {
      _tsukuyomiListState = null;
    }
  }

  /// 获取当前锚点索引
  int get anchorIndex {
    assert(_tsukuyomiListState != null,
        'Controller is not attached to TsukuyomiList');
    return _tsukuyomiListState!._anchorIndex;
  }

  /// 设置当前锚点索引
  ///
  /// [index] 新的锚点索引
  set anchorIndex(int index) {
    assert(_tsukuyomiListState != null,
        'Controller is not attached to TsukuyomiList');
    assert(index >= 0 && index < _tsukuyomiListState!.widget.itemCount,
        'Index out of range');

    if (_tsukuyomiListState!._anchorIndex != index) {
      _tsukuyomiListState!._anchorIndex = index;
    }
  }

  /// 在给定index插入item，保持滚动位置
  void onInsertItem(int index, void Function() doInsert) {
    // 修正_centerIndex和_anchorIndex
    if (index <= _tsukuyomiListState!._centerIndex) {
      _tsukuyomiListState!._centerIndex++;
    }
    if (index < _tsukuyomiListState!._anchorIndex) {
      _tsukuyomiListState!._anchorIndex--;
    }

    // 如待插入item不在上半部且会影响anchor scroll offset
    // 调整centerIndex以满足条件
    if (index > _tsukuyomiListState!._centerIndex &&
        index < _tsukuyomiListState!._anchorIndex) {
      _tsukuyomiListState!._centerIndex = index;
    }
    doInsert();
  }

  /// 批量插入items，保持滚动位置
  /// [startIndex] 开始插入的索引位置
  /// [count] 插入的数量
  /// [doInsert] 执行插入操作的回调
  void onBatchInsertItems(int startIndex, int count, void Function() doInsert) {
    assert(count > 0, 'Insert count must be greater than 0');

    // 修正_centerIndex
    if (startIndex <= _tsukuyomiListState!._centerIndex) {
      _tsukuyomiListState!._centerIndex += count;
    }

    // 修正_anchorIndex
    if (startIndex <= _tsukuyomiListState!._anchorIndex) {
      _tsukuyomiListState!._anchorIndex += count;
    }

    // 如果待插入items不在上半部且会影响anchor scroll offset
    // 调整centerIndex以满足条件
    if (startIndex + count > _tsukuyomiListState!._centerIndex &&
        startIndex + count < _tsukuyomiListState!._anchorIndex) {
      _tsukuyomiListState!._centerIndex = startIndex + count;
    }

    doInsert();
  }

  /// 在给定index移除item，保持滚动位置
  void onRemoveItem(int index, void Function() doRemove) {
    // 修正_centerIndex和_anchorIndex
    if (index <= _tsukuyomiListState!._centerIndex) {
      _tsukuyomiListState!._centerIndex--;
    }
    if (index < _tsukuyomiListState!._anchorIndex) {
      _tsukuyomiListState!._anchorIndex--;
    }

    // 如待插入item不在上半部且会影响anchor scroll offset
    // 调整centerIndex以满足条件
    if (index > _tsukuyomiListState!._centerIndex &&
        index < _tsukuyomiListState!._anchorIndex) {
      _tsukuyomiListState!._centerIndex = index;
    }
    doRemove();
  }

  /// 批量删除items，保持滚动位置
  /// [startIndex] 开始删除的索引位置
  /// [count] 删除的数量
  /// [doRemove] 执行删除操作的回调
  void onBatchRemoveItems(int startIndex, int count, void Function() doRemove) {
    assert(count > 0, 'Remove count must be greater than 0');

    final endIndex = startIndex + count - 1;

    // 修正_centerIndex
    if (startIndex <= _tsukuyomiListState!._centerIndex) {
      if (endIndex < _tsukuyomiListState!._centerIndex) {
        // 删除范围完全在_centerIndex之前
        _tsukuyomiListState!._centerIndex -= count;
      } else {
        // 删除范围包含_centerIndex
        _tsukuyomiListState!._centerIndex = startIndex;
      }
    }

    // 修正_anchorIndex
    if (startIndex <= _tsukuyomiListState!._anchorIndex) {
      if (endIndex < _tsukuyomiListState!._anchorIndex) {
        // 删除范围完全在_anchorIndex之前
        _tsukuyomiListState!._anchorIndex -= count;
      } else {
        // 删除范围包含_anchorIndex
        _tsukuyomiListState!._anchorIndex = _tsukuyomiListState!._centerIndex;
      }
    }

    // 如果待删除items不在上半部且会影响anchor scroll offset
    // 调整centerIndex以满足条件
    if (endIndex > _tsukuyomiListState!._centerIndex &&
        startIndex < _tsukuyomiListState!._anchorIndex) {
      _tsukuyomiListState!._centerIndex = startIndex;
    }

    doRemove();
  }

  void jumpToIndex(int index) {
    assert(_tsukuyomiListState != null);
    _tsukuyomiListState!._jumpToIndex(index);
  }

  Future<void> slideViewport(
    double viewportFraction, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    assert(_tsukuyomiListState != null);
    return _tsukuyomiListState!._slideViewport(
      viewportFraction,
      duration: duration,
      curve: curve,
    );
  }
}

class TsukuyomiListScrollPosition extends ScrollPositionWithSingleContext {
  TsukuyomiListScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool _corrected = false;

  /// 在下次布局时修正滚动偏移
  void correctImmediate(double correction) {
    _corrected = true;
    correctBy(correction);
  }

  @override
  @protected
  bool correctForNewDimensions(
      ScrollMetrics oldPosition, ScrollMetrics newPosition) {
    // 是否需要修正滚动偏移
    if (_corrected) {
      return _corrected = false;
    }
    return super.correctForNewDimensions(oldPosition, newPosition);
  }

  @override
  Future<void> animateTo(
    double to, {
    required Duration duration,
    required Curve curve,
  }) {
    if (nearEqual(to, pixels, physics.toleranceFor(this).distance)) {
      jumpTo(to);
      return Future<void>.value();
    }

    // 根据相对位置变化进行动画处理
    final activity = TsukuyomiDeltaScrollActivity(
      this,
      from: pixels,
      to: to,
      duration: duration,
      curve: curve,
      vsync: context.vsync,
    );
    beginActivity(activity);
    return activity.done;
  }
}

class _TsukuyomiListItemExtent {
  /// 是否可以复用
  final bool reusable;

  /// 是否正在渲染
  final bool mounted;

  /// 主轴方向尺寸
  final double extent;

  const _TsukuyomiListItemExtent({
    this.reusable = true,
    this.mounted = true,
    required this.extent,
  });

  _TsukuyomiListItemExtent copyWith({
    bool? reusable,
    bool? mounted,
    double? extent,
  }) {
    return _TsukuyomiListItemExtent(
      reusable: reusable ?? this.reusable,
      mounted: mounted ?? this.mounted,
      extent: extent ?? this.extent,
    );
  }
}

class _TsukuyomiListItem extends SingleChildRenderObjectWidget {
  const _TsukuyomiListItem({
    super.key,
    this.onMount,
    this.onUnmount,
    this.onPerformLayout,
    required super.child,
  });

  final ValueChanged<Element>? onMount;

  final ValueChanged<Element>? onUnmount;

  final _OnPerformLayout? onPerformLayout;

  @override
  SingleChildRenderObjectElement createElement() {
    return _TsukuyomiListItemElement(this);
  }

  @override
  _RenderTsukuyomiListItem createRenderObject(BuildContext context) {
    return _RenderTsukuyomiListItem(onPerformLayout: onPerformLayout);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderTsukuyomiListItem renderObject) {
    renderObject.onPerformLayout = onPerformLayout;
  }
}

class _TsukuyomiListItemElement extends SingleChildRenderObjectElement {
  _TsukuyomiListItemElement(super.widget);

  @override
  _TsukuyomiListItem get widget => super.widget as _TsukuyomiListItem;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    widget.onMount?.call(this);
  }

  @override
  void unmount() {
    widget.onUnmount?.call(this);
    super.unmount();
  }
}

class _RenderTsukuyomiListItem extends RenderProxyBox {
  _RenderTsukuyomiListItem({required this.onPerformLayout});

  _OnPerformLayout? onPerformLayout;

  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    onPerformLayout?.call(this, _oldSize, size);
    _oldSize = size;
  }
}

class _SliverLayout extends SingleChildRenderObjectWidget {
  const _SliverLayout({
    super.key,
    this.onPerformLayout,
    required Widget sliver,
  }) : super(child: sliver);

  final void Function(SliverGeometry geometry)? onPerformLayout;

  @override
  _RenderSliverLayout createRenderObject(BuildContext context) {
    return _RenderSliverLayout(onPerformLayout: onPerformLayout);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderSliverLayout renderObject) {
    renderObject.onPerformLayout = onPerformLayout;
  }
}

class _RenderSliverLayout extends RenderProxySliver {
  _RenderSliverLayout({this.onPerformLayout});

  void Function(SliverGeometry geometry)? onPerformLayout;

  @override
  void performLayout() {
    super.performLayout();
    onPerformLayout?.call(geometry!);
  }
}
