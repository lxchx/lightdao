import 'dart:ui';

import 'package:breakpoint/breakpoint.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lightdao/utils/bench_flags.dart';

/// 一级页面顶栏的形态。
///
/// 三种形态的外观都由这里（以及本文件的其它常量）决定，页面里只按 [topBarModeOf]
/// 的返回值挑容器，不再各写一份颜色和透明度。
enum TopBarMode {
  /// 手机竖屏（底部导航，宽度 < `WindowSize.small`）：完全保持引入侧栏顶栏
  /// 规则之前的样子——纯色、不模糊、M3 的滑动后变色（scrolledUnder）也保留，
  /// 顶栏是否跟手收起沿用各页原来的规则。
  phone,

  /// 侧栏导航 + 矮屏 + 没打开设置里的「固定底栏&顶栏」：顶栏随滑动隐藏，
  /// 纯色、不模糊、不做 scrolledUnder 变色。
  hideOnScroll,

  /// 侧栏导航的其余情况（高度够，或打开了「固定底栏&顶栏」）：顶栏固定，
  /// 半透明 + 背景模糊，不做 scrolledUnder 变色。
  pinnedGlass,
}

/// Material 3 的高度分档门槛：窗口高度低于 480dp 算「矮屏」，手机横屏
/// （例如 914×411dp）会落进来。
const double kCompactWindowHeight = 480;

/// 固定顶栏（毛玻璃）的一组外观参数，亮色、暗色各一套。
///
/// 同一套数值在两种主题下观感并不一样：亮色下卡片底色接近白，内容透上来更显眼；
/// 暗色下卡片和页面底色只差一档，透上来的多是浅色文字，柔光也更容易糊成一片灰雾。
class TopBarGlassStyle {
  const TopBarGlassStyle({
    required this.sigma,
    required this.opacity,
    required this.glowBlurRadius,
    required this.glowLayers,
    required this.glowOpacity,
  });

  /// 背景模糊半径（dp）。
  final double sigma;

  /// 底色的不透明度。底色是页面与侧栏共用的颜色，所以静止时透出来的仍是同一种
  /// 颜色、看不出接缝；这个值只决定卡片滑过时能透出多少。
  final double opacity;

  /// 文字、图标柔光最外层的模糊半径（dp），往里的层按比例收紧。
  final double glowBlurRadius;

  /// 柔光层数：1 层最紧，层数越多过渡越柔。
  final int glowLayers;

  /// 柔光的透明度（柔光颜色永远是侧栏底色本身）。
  final double glowOpacity;

  /// 这一套参数下的柔光，从最散到最紧。
  List<Shadow> glow(Color base) {
    final Color color = base.withValues(alpha: glowOpacity);
    return <Shadow>[
      for (int layer = glowLayers; layer >= 1; layer--)
        Shadow(
          color: color,
          offset: Offset.zero,
          blurRadius: glowBlurRadius * layer / glowLayers,
        ),
    ];
  }
}

/// 亮色主题的毛玻璃参数：卡片底色接近白、透上来对比强，所以模糊散一点（透出的
/// 只是一层雾，而不是能认出内容的残影）、底色透明度也高一点；柔光用满不透明度，
/// 白色内容滑过时字边依然干净。
const TopBarGlassStyle kGlassStyleLight = TopBarGlassStyle(
  sigma: 15,
  opacity: 0.82,
  glowBlurRadius: 12,
  glowLayers: 2,
  glowOpacity: 1,
);

/// 暗色主题的毛玻璃参数：卡片底色和页面底色只差一档，透出来的多是浅色文字，所以
/// 底色更不透明、模糊收紧，避免暗处飘出一片灰雾；柔光也收紧一点、略半透明，免得
/// 白字周围糊出一圈发灰的光边。
const TopBarGlassStyle kGlassStyleDark = TopBarGlassStyle(
  sigma: 12,
  opacity: 0.86,
  glowBlurRadius: 10,
  glowLayers: 2,
  glowOpacity: 0.9,
);

/// 当前主题该用哪一套毛玻璃参数。
TopBarGlassStyle topBarGlassStyle(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? kGlassStyleDark
    : kGlassStyleLight;

/// 固定顶栏左边缘把磨砂融回侧栏底色的渐变宽度（dp）。
///
/// 顶栏紧贴侧栏，模糊后的内容若一直糊到侧栏边上，交界处会出现一条硬切；
/// 这里让底色在靠近侧栏的 [kTopBarEdgeFade] 内渐变到完全不透明（也就是侧栏
/// 底色本身），模糊内容于是淡出，交界看不出切线。
const double kTopBarEdgeFade = 24;

/// 顶栏该用哪种形态。所有一级页面的顶栏都只问这一个函数。
///
/// - 宽度 < `WindowSize.small`（底部导航）：[TopBarMode.phone]，各页保持原样。
/// - 侧栏导航（宽度 >= `WindowSize.small`）：只有「矮屏 + 没开固定底栏」才
///   跟手隐藏（[TopBarMode.hideOnScroll]），其余一律固定
///   （[TopBarMode.pinnedGlass]）。
///
/// 高度按 Material 3 的高度分档算：`MediaQuery` 的窗口高度（含系统栏）低于
/// [kCompactWindowHeight] 就是「矮屏」。矮屏时侧栏占了横向空间，纵向再被顶栏
/// 固定占住一条就太挤了，所以这时才让顶栏随滑动隐藏。
TopBarMode topBarModeOf(BuildContext context, {required bool fixedBottomBar}) {
  if (Breakpoint.fromMediaQuery(context).window < WindowSize.small) {
    return TopBarMode.phone;
  }
  if (fixedBottomBar) {
    return TopBarMode.pinnedGlass;
  }
  return MediaQuery.sizeOf(context).height < kCompactWindowHeight
      ? TopBarMode.hideOnScroll
      : TopBarMode.pinnedGlass;
}

/// 顶栏的底色：页面背景（也就是侧栏透出来的那层）的颜色。
///
/// 走 [ThemeData.scaffoldBackgroundColor] 而不是 `colorScheme.surface`，
/// 是为了让设置里的「纯黑」也一并生效（暗色主题下它改的就是这个值）。
Color topBarBaseColor(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;

/// 固定模糊顶栏里文字和图标要垫的一圈底色柔光（半径、层数、透明度随亮色/暗色
/// 分开，见 [topBarGlassStyle]）。
///
/// 卡片从顶栏下面滑过时，文字和卡片之间隔着一层与侧栏同色的过渡，字依然清楚；
/// 顶栏下面没有内容时，这圈光晕和背景同色，看不出加过东西。只给固定 + 模糊
/// 这一种形态用：纯色顶栏（跟手隐藏）和手机竖屏都不加。
///
/// 颜色一律在 `build` 里从 [Theme] 现取（见 [GlassTopBar]），页面不要把某个
/// 主题下的颜色烘进图标或文字的样式里。
List<Shadow> topBarGlow(BuildContext context) =>
    topBarGlassStyle(context).glow(topBarBaseColor(context));

/// 顶栏自己的状态栏样式。
///
/// 模糊顶栏不再是 `AppBar`（它的 `Material` 会把背景模糊层的底衬隔开，见
/// [GlassTopBar]），因此状态栏图标要显式跟主题明暗走。
SystemUiOverlayStyle topBarOverlayStyle(BuildContext context) {
  final Brightness iconBrightness =
      Theme.of(context).brightness == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
  );
}

/// 固定顶栏（半透明底色 + 背景模糊）的顶栏本体。
///
/// 刻意不用 `AppBar`：`AppBar` 外层的 `Material` 会画进自己的 `PhysicalShape`
/// 图层，`BackdropFilter` 于是只能看到这一层里的空背景，模糊等于没做（实测
/// Skia 与 Impeller 都一样）。这里用普通控件搭一个顶栏，模糊层就落在滚动视图
/// 的图层里，能真的糊到从下面滑过去的卡片。
///
/// 标题、图标画在模糊层上面（不在 `BackdropFilter` 的子树里），完全不透明；
/// 它们的柔光在这里按当前 [Theme] 现算——页面只传标题和 actions，不要把某个
/// 主题下的颜色烘进 `Icon.shadows` / `TextStyle.shadows`。
///
/// 另外给这一段的文字排布留了一个随亮度变化的极小扰动（见 [_relayoutNudge]）：
/// 只改 `TextStyle.shadows` 时，Flutter 把样式变化判成纯 paint 级，会复用已经
/// 排版好的 `ui.Paragraph`，阴影颜色就停在切换主题之前（切后台再回来才恢复，
/// 因为那时会重新布局）。让字号差 0.01% 就能逼出一次重新排版，肉眼看不出差别。
class GlassTopBar extends StatelessWidget {
  const GlassTopBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.toolbarHeight = kToolbarHeight,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final double toolbarHeight;

  /// 随亮度变化的字号扰动系数（0.01%）：见类注释。
  double get _relayoutNudge => 1.0001;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TopBarGlassStyle style = topBarGlassStyle(context);
    final Color base = topBarBaseColor(context);
    // 亮暗各一个缩放值，逼出一次重新排版（见类注释）。
    final TextScaler textScaler = TextScaler.linear(
      theme.brightness == Brightness.dark ? _relayoutNudge : 1.0,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: topBarOverlayStyle(context),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(child: _glassBackground(context, base, style)),
            MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: toolbarHeight,
                  child: Row(
                    children: [
                      if (leading != null)
                        SizedBox(
                          width: kToolbarHeight,
                          child: Center(
                            child: leading ?? const SizedBox.shrink(),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: leading == null ? 16 : 0,
                          ),
                          // 标题按内容高度垂直居中：Align 用宽松约束把子组件的高度
                          // 收到内容高度再居中（不用 IntrinsicHeight 那种固有高度
                          // 测量）。页面的标题块只要不撑满，就会和右边的图标按钮
                          // 对齐；以后再往顶栏里放别的标题也自动居中。
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            // 与 M3 AppBar 一致：标题在 DefaultTextStyle 里，嵌套的
                            // Text 会 merge，柔光因此传得下去。
                            child: DefaultTextStyle(
                              style:
                                  theme.textTheme.titleLarge?.copyWith(
                                    shadows: topBarGlow(context),
                                  ) ??
                                  const TextStyle(),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              child: title ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      if (actions != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final Widget action in actions!)
                              _withGlow(context, action),
                          ],
                        ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 给顶栏上的图标/文字加柔光——但只给那些**直接画在毛玻璃上**的图标。
  ///
  /// 自带底色的按钮（`FloatingActionButton`、`ElevatedButton` 这类实心按钮，
  /// 比如板块页的「发串」）不应该有柔光：柔光是一圈和侧栏同色的阴影，画在有底色
  /// 的按钮里会变成图标周围一圈发亮的光斑。这里统一按控件类型判断，页面不用各自
  /// 记得清掉。
  Widget _withGlow(BuildContext context, Widget action) {
    final bool hasOwnBackground =
        action is FloatingActionButton ||
        action is ElevatedButton ||
        action is FilledButton;
    return IconTheme.merge(
      data: IconThemeData(
        shadows: hasOwnBackground ? const <Shadow>[] : topBarGlow(context),
      ),
      child: action,
    );
  }

  /// 底色 + 背景模糊（只有这一层，标题和图标不在这里）。
  Widget _glassBackground(
    BuildContext context,
    Color base,
    TopBarGlassStyle style,
  ) {
    final Widget tint = Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: base.withValues(alpha: style.opacity)),
        ),
        // 左边缘把磨砂融回侧栏底色：模糊内容靠近侧栏时淡出，交界没有硬切线。
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: kTopBarEdgeFade,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [base, base.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    // `--dart-define=LD_BENCH_OFF=blur` 得到「只半透明、不模糊」的对照版本，
    // 用来单独量 [BackdropFilter] 的代价。
    if (BenchFlags.off('blur')) {
      return tint;
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: style.sigma, sigmaY: style.sigma),
      child: tint,
    );
  }
}

/// 固定模糊顶栏的 sliver：只按 [extent] 占位并固定在顶部，内容由
/// [GlassTopBar] 画（自己就是滚动视图的第一个 sliver，内容从它下面滑过）。
SliverPersistentHeader glassTopBarHeader({
  required double extent,
  required Widget child,
}) {
  return SliverPersistentHeader(
    pinned: true,
    delegate: _FixedExtentHeaderDelegate(extent: extent, child: child),
  );
}

class _FixedExtentHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _FixedExtentHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_FixedExtentHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}

/// 纯色顶栏的 AppBar：侧栏模式下顶栏跟手隐藏时用它。
///
/// 底色与侧栏同色，不做 scrolledUnder 变色，也没有阴影和分割线。
AppBar solidTopBar({
  required BuildContext context,
  Widget? title,
  Widget? leading,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    backgroundColor: topBarBaseColor(context),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    title: title,
    leading: leading,
    actions: actions,
    automaticallyImplyLeading: automaticallyImplyLeading,
  );
}

/// 纯色顶栏的 sliver：`pinned: false` 时跟手隐藏，`pinned: true` 时固定。
SliverAppBar solidTopBarSliver({
  required BuildContext context,
  bool pinned = false,
  Widget? title,
  Widget? leading,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
  double toolbarHeight = kToolbarHeight,
}) {
  return SliverAppBar(
    pinned: pinned,
    floating: true,
    snap: false,
    toolbarHeight: toolbarHeight,
    backgroundColor: topBarBaseColor(context),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    title: title,
    leading: leading,
    actions: actions,
    automaticallyImplyLeading: automaticallyImplyLeading,
  );
}
