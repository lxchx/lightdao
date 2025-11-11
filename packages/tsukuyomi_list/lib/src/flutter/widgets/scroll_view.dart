// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'package:tsukuyomi_list/src/tsukuyomi/widgets/scroll_view.dart';

/// A widget that combines a [Scrollable] and a [Viewport] to create an
/// interactive scrolling pane of content in one dimension.
///
/// Scrollable widgets consist of three pieces:
///
///  1. A [Scrollable] widget, which listens for various user gestures and
///     implements the interaction design for scrolling.
///  2. A viewport widget, such as [Viewport] or [ShrinkWrappingViewport], which
///     implements the visual design for scrolling by displaying only a portion
///     of the widgets inside the scroll view.
///  3. One or more slivers, which are widgets that can be composed to created
///     various scrolling effects, such as lists, grids, and expanding headers.
///
/// [ScrollView] helps orchestrate these pieces by creating the [Scrollable] and
/// the viewport and deferring to its subclass to create the slivers.
///
/// To learn more about slivers, see [CustomScrollView.slivers].
///
/// To control the initial scroll offset of the scroll view, provide a
/// [controller] with its [ScrollController.initialScrollOffset] property set.
///
/// See also:
///
///  * [ListView], which is a commonly used [ScrollView] that displays a
///    scrolling, linear list of child widgets.
///  * [PageView], which is a scrolling list of child widgets that are each the
///    size of the viewport.
///  * [GridView], which is a [ScrollView] that displays a scrolling, 2D array
///    of child widgets.
///  * [CustomScrollView], which is a [ScrollView] that creates custom scroll
///    effects using slivers.
///  * [ScrollNotification] and [NotificationListener], which can be used to watch
///    the scroll position without using a [ScrollController].
///  * [TwoDimensionalScrollView], which is a similar widget [ScrollView] that
///    scrolls in two dimensions.
abstract class ScrollView extends StatelessWidget {
  /// Creates a widget that scrolls.
  ///
  /// The [ScrollView.primary] argument defaults to true for vertical
  /// scroll views if no [controller] has been provided. The [controller] argument
  /// must be null if [primary] is explicitly set to true. If [primary] is true,
  /// the nearest [PrimaryScrollController] surrounding the widget is attached
  /// to this scroll view.
  ///
  /// If the [shrinkWrap] argument is true, the [center] argument must be null.
  ///
  /// The [scrollDirection], [reverse], and [shrinkWrap] arguments must not be null.
  ///
  /// The [anchor] argument must be non-null and in the range 0.0 to 1.0.
  const ScrollView({
    super.key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    ScrollPhysics? physics,
    this.scrollBehavior,
    this.shrinkWrap = false,
    this.center,
    this.anchor = 0.0,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  })  : assert(
          !(controller != null && (primary ?? false)),
          'Primary ScrollViews obtain their ScrollController via inheritance '
          'from a PrimaryScrollController widget. You cannot both set primary to '
          'true and pass an explicit controller.',
        ),
        assert(!shrinkWrap || center == null),
        assert(anchor >= 0.0 && anchor <= 1.0),
        assert(semanticChildCount == null || semanticChildCount >= 0),
        physics = physics ??
            ((primary ?? false) ||
                    (primary == null &&
                        controller == null &&
                        identical(scrollDirection, Axis.vertical))
                ? const AlwaysScrollableScrollPhysics()
                : null);

  /// {@template flutter.widgets.scroll_view.scrollDirection}
  /// The [Axis] along which the scroll view's offset increases.
  ///
  /// For the direction in which active scrolling may be occurring, see
  /// [ScrollDirection].
  ///
  /// Defaults to [Axis.vertical].
  /// {@endtemplate}
  final Axis scrollDirection;

  /// {@template flutter.widgets.scroll_view.reverse}
  /// Whether the scroll view scrolls in the reading direction.
  ///
  /// For example, if the reading direction is left-to-right and
  /// [scrollDirection] is [Axis.horizontal], then the scroll view scrolls from
  /// left to right when [reverse] is false and from right to left when
  /// [reverse] is true.
  ///
  /// Similarly, if [scrollDirection] is [Axis.vertical], then the scroll view
  /// scrolls from top to bottom when [reverse] is false and from bottom to top
  /// when [reverse] is true.
  ///
  /// Defaults to false.
  /// {@endtemplate}
  final bool reverse;

  /// {@template flutter.widgets.scroll_view.controller}
  /// An object that can be used to control the position to which this scroll
  /// view is scrolled.
  ///
  /// Must be null if [primary] is true.
  ///
  /// A [ScrollController] serves several purposes. It can be used to control
  /// the initial scroll position (see [ScrollController.initialScrollOffset]).
  /// It can be used to control whether the scroll view should automatically
  /// save and restore its scroll position in the [PageStorage] (see
  /// [ScrollController.keepScrollOffset]). It can be used to read the current
  /// scroll position (see [ScrollController.offset]), or change it (see
  /// [ScrollController.animateTo]).
  /// {@endtemplate}
  final ScrollController? controller;

  /// {@template flutter.widgets.scroll_view.primary}
  /// Whether this is the primary scroll view associated with the parent
  /// [PrimaryScrollController].
  ///
  /// When this is true, the scroll view is scrollable even if it does not have
  /// sufficient content to actually scroll. Otherwise, by default the user can
  /// only scroll the view if it has sufficient content. See [physics].
  ///
  /// Also when true, the scroll view is used for default [ScrollAction]s. If a
  /// ScrollAction is not handled by an otherwise focused part of the application,
  /// the ScrollAction will be evaluated using this scroll view, for example,
  /// when executing [Shortcuts] key events like page up and down.
  ///
  /// On iOS, this also identifies the scroll view that will scroll to top in
  /// response to a tap in the status bar.
  ///
  /// Cannot be true while a [ScrollController] is provided to `controller`,
  /// only one ScrollController can be associated with a ScrollView.
  ///
  /// Setting to false will explicitly prevent inheriting any
  /// [PrimaryScrollController].
  ///
  /// Defaults to null. When null, and a controller is not provided,
  /// [PrimaryScrollController.shouldInherit] is used to decide automatic
  /// inheritance.
  ///
  /// By default, the [PrimaryScrollController] that is injected by each
  /// [ModalRoute] is configured to automatically be inherited on
  /// [TargetPlatformVariant.mobile] for ScrollViews in the [Axis.vertical]
  /// scroll direction. Adding another to your app will override the
  /// PrimaryScrollController above it.
  ///
  /// The following video contains more information about scroll controllers,
  /// the PrimaryScrollController widget, and their impact on your apps:
  ///
  /// {@youtube 560 315 https://www.youtube.com/watch?v=33_0ABjFJUU}
  ///
  /// {@endtemplate}
  final bool? primary;

  /// {@template flutter.widgets.scroll_view.physics}
  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// Defaults to matching platform conventions. Furthermore, if [primary] is
  /// false, then the user cannot scroll if there is insufficient content to
  /// scroll, while if [primary] is true, they can always attempt to scroll.
  ///
  /// To force the scroll view to always be scrollable even if there is
  /// insufficient content, as if [primary] was true but without necessarily
  /// setting it to true, provide an [AlwaysScrollableScrollPhysics] physics
  /// object, as in:
  ///
  /// ```dart
  ///   physics: const AlwaysScrollableScrollPhysics(),
  /// ```
  ///
  /// To force the scroll view to use the default platform conventions and not
  /// be scrollable if there is insufficient content, regardless of the value of
  /// [primary], provide an explicit [ScrollPhysics] object, as in:
  ///
  /// ```dart
  ///   physics: const ScrollPhysics(),
  /// ```
  ///
  /// The physics can be changed dynamically (by providing a new object in a
  /// subsequent build), but new physics will only take effect if the _class_ of
  /// the provided object changes. Merely constructing a new instance with a
  /// different configuration is insufficient to cause the physics to be
  /// reapplied. (This is because the final object used is generated
  /// dynamically, which can be relatively expensive, and it would be
  /// inefficient to speculatively create this object each frame to see if the
  /// physics should be updated.)
  /// {@endtemplate}
  ///
  /// If an explicit [ScrollBehavior] is provided to [scrollBehavior], the
  /// [ScrollPhysics] provided by that behavior will take precedence after
  /// [physics].
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.shadow.scrollBehavior}
  ///
  /// [ScrollBehavior]s also provide [ScrollPhysics]. If an explicit
  /// [ScrollPhysics] is provided in [physics], it will take precedence,
  /// followed by [scrollBehavior], and then the inherited ancestor
  /// [ScrollBehavior].
  final ScrollBehavior? scrollBehavior;

  /// {@template flutter.widgets.scroll_view.shrinkWrap}
  /// Whether the extent of the scroll view in the [scrollDirection] should be
  /// determined by the contents being viewed.
  ///
  /// If the scroll view does not shrink wrap, then the scroll view will expand
  /// to the maximum allowed size in the [scrollDirection]. If the scroll view
  /// has unbounded constraints in the [scrollDirection], then [shrinkWrap] must
  /// be true.
  ///
  /// Shrink wrapping the content of the scroll view is significantly more
  /// expensive than expanding to the maximum allowed size because the content
  /// can expand and contract during scrolling, which means the size of the
  /// scroll view needs to be recomputed whenever the scroll position changes.
  ///
  /// Defaults to false.
  ///
  /// {@youtube 560 315 https://www.youtube.com/watch?v=LUqDNnv_dh0}
  /// {@endtemplate}
  final bool shrinkWrap;

  /// The first child in the [GrowthDirection.forward] growth direction.
  ///
  /// Children after [center] will be placed in the [AxisDirection] determined
  /// by [scrollDirection] and [reverse] relative to the [center]. Children
  /// before [center] will be placed in the opposite of the axis direction
  /// relative to the [center]. This makes the [center] the inflection point of
  /// the growth direction.
  ///
  /// The [center] must be the key of one of the slivers built by [buildSlivers].
  ///
  /// Of the built-in subclasses of [ScrollView], only [CustomScrollView]
  /// supports [center]; for that class, the given key must be the key of one of
  /// the slivers in the [CustomScrollView.slivers] list.
  ///
  /// Most scroll views by default are ordered [GrowthDirection.forward].
  /// Changing the default values of [ScrollView.anchor],
  /// [ScrollView.center], or both, can configure a scroll view for
  /// [GrowthDirection.reverse].
  ///
  /// {@tool dartpad}
  /// This sample shows a [CustomScrollView], with [Radio] buttons in the
  /// [AppBar.bottom] that change the [AxisDirection] to illustrate different
  /// configurations. The [CustomScrollView.anchor] and [CustomScrollView.center]
  /// properties are also set to have the 0 scroll offset positioned in the middle
  /// of the viewport, with [GrowthDirection.forward] and [GrowthDirection.reverse]
  /// illustrated on either side. The sliver that shares the
  /// [CustomScrollView.center] key is positioned at the [CustomScrollView.anchor].
  ///
  /// ** See code in examples/api/lib/rendering/growth_direction/growth_direction.0.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [anchor], which controls where the [center] as aligned in the viewport.
  final Key? center;

  /// {@template flutter.widgets.scroll_view.anchor}
  /// The relative position of the zero scroll offset.
  ///
  /// For example, if [anchor] is 0.5 and the [AxisDirection] determined by
  /// [scrollDirection] and [reverse] is [AxisDirection.down] or
  /// [AxisDirection.up], then the zero scroll offset is vertically centered
  /// within the viewport. If the [anchor] is 1.0, and the axis direction is
  /// [AxisDirection.right], then the zero scroll offset is on the left edge of
  /// the viewport.
  ///
  /// Most scroll views by default are ordered [GrowthDirection.forward].
  /// Changing the default values of [ScrollView.anchor],
  /// [ScrollView.center], or both, can configure a scroll view for
  /// [GrowthDirection.reverse].
  ///
  /// {@tool dartpad}
  /// This sample shows a [CustomScrollView], with [Radio] buttons in the
  /// [AppBar.bottom] that change the [AxisDirection] to illustrate different
  /// configurations. The [CustomScrollView.anchor] and [CustomScrollView.center]
  /// properties are also set to have the 0 scroll offset positioned in the middle
  /// of the viewport, with [GrowthDirection.forward] and [GrowthDirection.reverse]
  /// illustrated on either side. The sliver that shares the
  /// [CustomScrollView.center] key is positioned at the [CustomScrollView.anchor].
  ///
  /// ** See code in examples/api/lib/rendering/growth_direction/growth_direction.0.dart **
  /// {@end-tool}
  /// {@endtemplate}
  final double anchor;

  /// {@macro flutter.rendering.RenderViewportBase.cacheExtent}
  final double? cacheExtent;

  /// The number of children that will contribute semantic information.
  ///
  /// Some subtypes of [ScrollView] can infer this value automatically. For
  /// example [ListView] will use the number of widgets in the child list,
  /// while the [ListView.separated] constructor will use half that amount.
  ///
  /// For [CustomScrollView] and other types which do not receive a builder
  /// or list of widgets, the child count must be explicitly provided. If the
  /// number is unknown or unbounded this should be left unset or set to null.
  ///
  /// See also:
  ///
  ///  * [SemanticsConfiguration.scrollChildCount], the corresponding semantics property.
  final int? semanticChildCount;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.widgets.scroll_view.keyboardDismissBehavior}
  /// [ScrollViewKeyboardDismissBehavior] the defines how this [ScrollView] will
  /// dismiss the keyboard automatically.
  /// {@endtemplate}
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// {@macro flutter.widgets.scrollable.restorationId}
  final String? restorationId;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  /// Returns the [AxisDirection] in which the scroll view scrolls.
  ///
  /// Combines the [scrollDirection] with the [reverse] boolean to obtain the
  /// concrete [AxisDirection].
  ///
  /// If the [scrollDirection] is [Axis.horizontal], the ambient
  /// [Directionality] is also considered when selecting the concrete
  /// [AxisDirection]. For example, if the ambient [Directionality] is
  /// [TextDirection.rtl], then the non-reversed [AxisDirection] is
  /// [AxisDirection.left] and the reversed [AxisDirection] is
  /// [AxisDirection.right].
  AxisDirection getDirection(BuildContext context) {
    return getAxisDirectionFromAxisReverseAndDirectionality(
        context, scrollDirection, reverse);
  }

  /// Build the list of widgets to place inside the viewport.
  ///
  /// Subclasses should override this method to build the slivers for the inside
  /// of the viewport.
  ///
  /// To learn more about slivers, see [CustomScrollView.slivers].
  List<Widget> buildSlivers(BuildContext context);

  /// Build the viewport.
  ///
  /// Subclasses may override this method to change how the viewport is built.
  /// The default implementation uses a [ShrinkWrappingViewport] if [shrinkWrap]
  /// is true, and a regular [Viewport] otherwise.
  ///
  /// The `offset` argument is the value obtained from
  /// [Scrollable.viewportBuilder].
  ///
  /// The `axisDirection` argument is the value obtained from [getDirection],
  /// which by default uses [scrollDirection] and [reverse].
  ///
  /// The `slivers` argument is the value obtained from [buildSlivers].
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) {
    assert(() {
      switch (axisDirection) {
        case AxisDirection.up:
        case AxisDirection.down:
          return debugCheckHasDirectionality(
            context,
            why: 'to determine the cross-axis direction of the scroll view',
            hint:
                'Vertical scroll views create Viewport widgets that try to determine their cross axis direction '
                'from the ambient Directionality.',
          );
        case AxisDirection.left:
        case AxisDirection.right:
          return true;
      }
    }());
    if (shrinkWrap) {
      return ShrinkWrappingViewport(
        axisDirection: axisDirection,
        offset: offset,
        slivers: slivers,
        clipBehavior: clipBehavior,
      );
    }
    return Viewport(
      axisDirection: axisDirection,
      offset: offset,
      slivers: slivers,
      cacheExtent: cacheExtent,
      center: center,
      anchor: anchor,
      clipBehavior: clipBehavior,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> slivers = buildSlivers(context);
    final AxisDirection axisDirection = getDirection(context);

    final bool effectivePrimary = primary ??
        controller == null &&
            PrimaryScrollController.shouldInherit(context, scrollDirection);

    final ScrollController? scrollController = effectivePrimary
        ? PrimaryScrollController.maybeOf(context)
        : controller;

    final Scrollable scrollable = Scrollable(
      dragStartBehavior: dragStartBehavior,
      axisDirection: axisDirection,
      controller: scrollController,
      physics: physics,
      scrollBehavior: scrollBehavior,
      semanticChildCount: semanticChildCount,
      restorationId: restorationId,
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return buildViewport(context, offset, axisDirection, slivers);
      },
      clipBehavior: clipBehavior,
    );

    final Widget scrollableResult = effectivePrimary && scrollController != null
        // Further descendant ScrollViews will not inherit the same PrimaryScrollController
        ? PrimaryScrollController.none(child: scrollable)
        : scrollable;

    if (keyboardDismissBehavior == ScrollViewKeyboardDismissBehavior.onDrag) {
      return NotificationListener<ScrollUpdateNotification>(
        child: scrollableResult,
        onNotification: (ScrollUpdateNotification notification) {
          final FocusScopeNode focusScope = FocusScope.of(context);
          if (notification.dragDetails != null && focusScope.hasFocus) {
            focusScope.unfocus();
          }
          return false;
        },
      );
    } else {
      return scrollableResult;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('scrollDirection', scrollDirection));
    properties.add(FlagProperty('reverse',
        value: reverse, ifTrue: 'reversed', showName: true));
    properties.add(DiagnosticsProperty<ScrollController>(
        'controller', controller,
        showName: false, defaultValue: null));
    properties.add(FlagProperty('primary',
        value: primary, ifTrue: 'using primary controller', showName: true));
    properties.add(DiagnosticsProperty<ScrollPhysics>('physics', physics,
        showName: false, defaultValue: null));
    properties.add(FlagProperty('shrinkWrap',
        value: shrinkWrap, ifTrue: 'shrink-wrapping', showName: true));
  }
}

/// A [ScrollView] that creates custom scroll effects using [slivers].
///
/// A [CustomScrollView] lets you supply [slivers] directly to create various
/// scrolling effects, such as lists, grids, and expanding headers. For example,
/// to create a scroll view that contains an expanding app bar followed by a
/// list and a grid, use a list of three slivers: [SliverAppBar], [SliverList],
/// and [SliverGrid].
///
/// [Widget]s in these [slivers] must produce [RenderSliver] objects.
///
/// To control the initial scroll offset of the scroll view, provide a
/// [controller] with its [ScrollController.initialScrollOffset] property set.
///
/// {@animation 400 376 https://flutter.github.io/assets-for-api-docs/assets/widgets/custom_scroll_view.mp4}
///
/// {@tool snippet}
///
/// This sample code shows a scroll view that contains a flexible pinned app
/// bar, a grid, and an infinite list.
///
/// ```dart
/// CustomScrollView(
///   slivers: <Widget>[
///     const SliverAppBar(
///       pinned: true,
///       expandedHeight: 250.0,
///       flexibleSpace: FlexibleSpaceBar(
///         title: Text('Demo'),
///       ),
///     ),
///     SliverGrid(
///       gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
///         maxCrossAxisExtent: 200.0,
///         mainAxisSpacing: 10.0,
///         crossAxisSpacing: 10.0,
///         childAspectRatio: 4.0,
///       ),
///       delegate: SliverChildBuilderDelegate(
///         (BuildContext context, int index) {
///           return Container(
///             alignment: Alignment.center,
///             color: Colors.teal[100 * (index % 9)],
///             child: Text('Grid Item $index'),
///           );
///         },
///         childCount: 20,
///       ),
///     ),
///     SliverFixedExtentList(
///       itemExtent: 50.0,
///       delegate: SliverChildBuilderDelegate(
///         (BuildContext context, int index) {
///           return Container(
///             alignment: Alignment.center,
///             color: Colors.lightBlue[100 * (index % 9)],
///             child: Text('List Item $index'),
///           );
///         },
///       ),
///     ),
///   ],
/// )
/// ```
/// {@end-tool}
///
/// {@tool dartpad}
/// By default, if items are inserted at the "top" of a scrolling container like
/// [ListView] or [CustomScrollView], the top item and all of the items below it
/// are scrolled downwards. In some applications, it's preferable to have the
/// top of the list just grow upwards, without changing the scroll position.
/// This example demonstrates how to do that with a [CustomScrollView] with
/// two [SliverList] children, and the [CustomScrollView.center] set to the key
/// of the bottom SliverList. The top one SliverList will grow upwards, and the
/// bottom SliverList will grow downwards.
///
/// ** See code in examples/api/lib/widgets/scroll_view/custom_scroll_view.1.dart **
/// {@end-tool}
///
/// ## Accessibility
///
/// A [CustomScrollView] can allow Talkback/VoiceOver to make announcements
/// to the user when the scroll state changes. For example, on Android an
/// announcement might be read as "showing items 1 to 10 of 23". To produce
/// this announcement, the scroll view needs three pieces of information:
///
///   * The first visible child index.
///   * The total number of children.
///   * The total number of visible children.
///
/// The last value can be computed exactly by the framework, however the first
/// two must be provided. Most of the higher-level scrollable widgets provide
/// this information automatically. For example, [ListView] provides each child
/// widget with a semantic index automatically and sets the semantic child
/// count to the length of the list.
///
/// To determine visible indexes, the scroll view needs a way to associate the
/// generated semantics of each scrollable item with a semantic index. This can
/// be done by wrapping the child widgets in an [IndexedSemantics].
///
/// This semantic index is not necessarily the same as the index of the widget in
/// the scrollable, because some widgets may not contribute semantic
/// information. Consider a [ListView.separated]: every other widget is a
/// divider with no semantic information. In this case, only odd numbered
/// widgets have a semantic index (equal to the index ~/ 2). Furthermore, the
/// total number of children in this example would be half the number of
/// widgets. (The [ListView.separated] constructor handles this
/// automatically; this is only used here as an example.)
///
/// The total number of visible children can be provided by the constructor
/// parameter `semanticChildCount`. This should always be the same as the
/// number of widgets wrapped in [IndexedSemantics].
///
/// See also:
///
///  * [SliverList], which is a sliver that displays linear list of children.
///  * [SliverFixedExtentList], which is a more efficient sliver that displays
///    linear list of children that have the same extent along the scroll axis.
///  * [SliverGrid], which is a sliver that displays a 2D array of children.
///  * [SliverPadding], which is a sliver that adds blank space around another
///    sliver.
///  * [SliverAppBar], which is a sliver that displays a header that can expand
///    and float as the scroll view scrolls.
///  * [ScrollNotification] and [NotificationListener], which can be used to watch
///    the scroll position without using a [ScrollController].
///  * [IndexedSemantics], which allows annotating child lists with an index
///    for scroll announcements.
class CustomScrollView extends ScrollView {
  /// Creates a [ScrollView] that creates custom scroll effects using slivers.
  ///
  /// See the [ScrollView] constructor for more details on these arguments.
  const CustomScrollView({
    super.key,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.scrollBehavior,
    super.shrinkWrap,
    super.center,
    super.anchor,
    super.cacheExtent,
    this.slivers = const <Widget>[],
    super.semanticChildCount,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.clipBehavior,
  });

  /// The slivers to place inside the viewport.
  ///
  /// ## What is a sliver?
  ///
  /// > _**sliver** (noun): a small, thin piece of something._
  ///
  /// A _sliver_ is a widget backed by a [RenderSliver] subclass, i.e. one that
  /// implements the constraint/geometry protocol that uses [SliverConstraints]
  /// and [SliverGeometry].
  ///
  /// This is as distinct from those widgets that are backed by [RenderBox]
  /// subclasses, which use [BoxConstraints] and [Size] respectively, and are
  /// known as box widgets. (Widgets like [Container], [Row], and [SizedBox] are
  /// box widgets.)
  ///
  /// While boxes are much more straightforward (implementing a simple
  /// two-dimensional Cartesian layout system), slivers are much more powerful,
  /// and are optimized for one-axis scrolling environments.
  ///
  /// Slivers are hosted in viewports, also known as scroll views, most notably
  /// [CustomScrollView].
  ///
  /// ## Examples of slivers
  ///
  /// The Flutter framework has many built-in sliver widgets, and custom widgets
  /// can be created in the same manner. By convention, sliver widgets always
  /// start with the prefix `Sliver` and are always used in properties called
  /// `sliver` or `slivers` (as opposed to `child` and `children` which are used
  /// for box widgets).
  ///
  /// Examples of widgets unique to the sliver world include:
  ///
  /// * [SliverList], a lazily-loading list of variably-sized box widgets.
  /// * [SliverFixedExtentList], a lazily-loading list of box widgets that are
  ///   all forced to the same height.
  /// * [SliverPrototypeExtentList], a lazily-loading list of box widgets that
  ///   are all forced to the same height as a given prototype widget.
  /// * [SliverGrid], a lazily-loading grid of box widgets.
  /// * [SliverAnimatedList] and [SliverAnimatedGrid], animated variants of
  ///   [SliverList] and [SliverGrid].
  /// * [SliverFillRemaining], a widget that fills all remaining space in a
  ///   scroll view, and lays a box widget out inside that space.
  /// * [SliverFillViewport], a widget that lays a list of boxes out, each
  ///   being sized to fit the whole viewport.
  /// * [SliverPersistentHeader], a sliver that implements pinned and floating
  ///   headers, e.g. used to implement [SliverAppBar].
  /// * [SliverToBoxAdapter], a sliver that wraps a box widget.
  ///
  /// Examples of sliver variants of common box widgets include:
  ///
  /// * [SliverOpacity], [SliverAnimatedOpacity], and [SliverFadeTransition],
  ///   sliver versions of [Opacity], [AnimatedOpacity], and [FadeTransition].
  /// * [SliverIgnorePointer], a sliver version of [IgnorePointer].
  /// * [SliverLayoutBuilder], a sliver version of [LayoutBuilder].
  /// * [SliverOffstage], a sliver version of [Offstage].
  /// * [SliverPadding], a sliver version of [Padding].
  /// * [SliverReorderableList], a sliver version of [ReorderableList]
  /// * [SliverSafeArea], a sliver version of [SafeArea].
  /// * [SliverVisibility], a sliver version of [Visibility].
  ///
  /// ## Benefits of slivers over boxes
  ///
  /// The sliver protocol ([SliverConstraints] and [SliverGeometry]) enables
  /// _scroll effects_, such as floating app bars, widgets that expand and
  /// shrink during scroll, section headers that are pinned only while the
  /// section's children are visible, etc.
  ///
  /// {@youtube 560 315 https://www.youtube.com/watch?v=Mz3kHQxBjGg}
  ///
  /// ## Mixing slivers and boxes
  ///
  /// In general, slivers always wrap box widgets to actually render anything
  /// (for example, there is no sliver equivalent of [Text] or [Container]);
  /// the sliver part of the equation is mostly about how these boxes should
  /// be laid out in a viewport (i.e. when scrolling).
  ///
  /// Typically, the simplest way to combine boxes into a sliver environment is
  /// to use a [SliverList] (maybe using a [ListView, which is a convenient
  /// combination of a [CustomScrollView] and a [SliverList]). In rare cases,
  /// e.g. if a single [Divider] widget is needed between two [SliverGrid]s,
  /// a [SliverToBoxAdapter] can be used to wrap the box widgets.
  ///
  /// ## Performance considerations
  ///
  /// Because the purpose of scroll views is to, well, scroll, it is common
  /// for scroll views to contain more contents than are rendered on the screen
  /// at any particular time.
  ///
  /// To improve the performance of scroll views, the content can be rendered in
  /// _lazy_ widgets, notably [SliverList] and [SliverGrid] (and their variants,
  /// such as [SliverFixedExtentList] and [SliverAnimatedGrid]). These widgets
  /// ensure that only the portion of their child lists that are actually
  /// visible get built, laid out, and painted.
  ///
  /// The [ListView] and [GridView] widgets provide a convenient way to combine
  /// a [CustomScrollView] and a [SliverList] or [SliverGrid] (respectively).
  final List<Widget> slivers;

  @override
  List<Widget> buildSlivers(BuildContext context) => slivers;
}
