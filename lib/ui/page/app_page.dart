import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lightdao/data/setting.dart';
import 'package:lightdao/data/xdao/ref.dart';
import 'package:lightdao/ui/widget/scaffold_accessory_builder.dart';
import 'package:lightdao/utils/kv_store.dart';
import 'package:provider/provider.dart';
import 'package:breakpoint/breakpoint.dart';
import 'package:lightdao/ui/page/forum_page.dart';
import 'package:lightdao/ui/page/more_page.dart';
import 'package:lightdao/ui/page/trend_page.dart';

/// 应用的主页面外壳，负责处理顶级导航（底部、侧边）和页面布局。
class AppPage extends StatefulWidget {
  const AppPage({super.key});

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<GlobalKey?> _pageKeys = [];

  int _selectedPageIndex = 0;
  bool _isBottomBarVisible = true;
  bool _isOutSideDrawerExpanded = true;

  // 获取当前页面的 ScaffoldAccessoryBuilder
  ScaffoldAccessoryBuilder? get _currentPageScaffoldAccessoryBuilder {
    if (_selectedPageIndex < 0 || _selectedPageIndex >= _pageKeys.length) {
      return null;
    }
    final key = _pageKeys[_selectedPageIndex];
    if (key == null) return null;
    final state = key.currentState;
    return state is ScaffoldAccessoryBuilder ? state : null;
  }

  // 声明为 late，因为它们的初始化被安全地移到了 didChangeDependencies 中。
  late final ValueNotifier<ForumSelection> _forumSelectionNotifier;
  late final List<Widget> _pages;

  // 用于确保依赖 context 的初始化逻辑只执行一次的标志位。
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // initState 中不应包含任何依赖 context 的代码，以避免生命周期错误。
  }

  /// didChangeDependencies 在 initState 之后、build 之前被调用，
  /// 此时 context 已完全可用，是执行依赖 context 的初始化的最佳位置。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 使用标志位防止此逻辑在后续的重构中被重复执行。
    if (_isInitialized) {
      return;
    }

    final appState = Provider.of<MyAppState>(context, listen: false);
    // 此处创建的cache是局部的，仅传递给TrendPage，符合封装原则。
    final trendRefCache = LRUCache<int, Future<RefHtml>>(100);

    _forumSelectionNotifier = ValueNotifier(
      ForumSelection(
        id: appState.setting.initForumOrTimelineId,
        name: appState.setting.initForumOrTimelineName,
        isTimeline: appState.setting.initIsTimeline,
      ),
    );

    // 现在在这里初始化页面列表是安全的，因为 context 可用。
    final forumPageKey = GlobalKey<ScaffoldAccessoryBuilder<ForumPage>>();
    final trendPageKey = GlobalKey<ScaffoldAccessoryBuilder<TrendPage>>();
    _pages = [
      ForumPage(
        key: forumPageKey,
        forumSelectionNotifier: _forumSelectionNotifier,
        scaffoldSetState: () => setState(() {}),
      ),
      starPage(context),
      TrendPage(key: trendPageKey, refCache: trendRefCache),
      MorePage(),
    ];

    _pageKeys.addAll([forumPageKey, null, trendPageKey, null]);

    // 设置标志位，表示初始化已完成。
    _isInitialized = true;
  }

  @override
  void dispose() {
    _forumSelectionNotifier.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (_selectedPageIndex == index) {
      if (!(_currentPageScaffoldAccessoryBuilder?.onReLocated(context) ??
          false)) {
        _scaffoldKey.currentState?.openDrawer();
      }
      return;
    }
    setState(() {
      _selectedPageIndex = index;
      if (index != 0) {
        _isBottomBarVisible = true;
      }
    });
  }

  /// 为小屏幕构建一个完整的抽屉Widget。
  Widget? _buildSmallScreenDrawer() {
    if (!_isInitialized) return null;

    final content = _currentPageScaffoldAccessoryBuilder?.buildDrawerContent(
      context,
    );
    if (content == null || content.isEmpty) return null;

    return Drawer(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              child: Text(
                '氢岛',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            ...content,
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget? _buildCurrentPageFab() {
    if (!_isInitialized) return null;
    final breakpoint = Breakpoint.fromMediaQuery(context);
    final appState = Provider.of<MyAppState>(context, listen: false);
    if (breakpoint.window >= WindowSize.small ||
        (!appState.setting.fixedBottomBar && !_isBottomBarVisible)) {
      return null;
    }
    return _currentPageScaffoldAccessoryBuilder?.buildFloatingActionButton(
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 如果尚未初始化，显示一个加载指示器，防止访问 late 变量时出错。
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final appState = Provider.of<MyAppState>(context, listen: false);
    final breakpoint = Breakpoint.fromMediaQuery(context);

    const List<ExampleDestination> destinations = <ExampleDestination>[
      ExampleDestination(
        selectedIcon: Icon(Icons.home),
        icon: Icon(Icons.home_outlined),
        label: '板块',
      ),
      ExampleDestination(
        selectedIcon: Icon(Icons.favorite),
        icon: Icon(Icons.favorite_border),
        label: '收藏',
      ),
      ExampleDestination(
        selectedIcon: Icon(Icons.whatshot),
        icon: Icon(Icons.whatshot_outlined),
        label: '趋势',
      ),
      ExampleDestination(
        icon: Icon(Icons.more_horiz),
        selectedIcon: Icon(Icons.more_horiz),
        label: '更多',
      ),
    ];

    return Scaffold(
      key: _scaffoldKey,
      // 根据屏幕尺寸决定抽屉的构建方式
      drawer: breakpoint.window < WindowSize.medium
          ? _buildSmallScreenDrawer()
          : null,
      drawerEdgeDragWidth: MediaQuery.of(context).size.width / 3,
      floatingActionButton: _buildCurrentPageFab(),
      body: Row(
        children: [
          // 大屏幕的 NavigationDrawer
          if (breakpoint.window >= WindowSize.medium)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: _isOutSideDrawerExpanded ? 256 : 128,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: NavigationDrawer(
                  backgroundColor: Colors.transparent,
                  onDestinationSelected: _onDestinationSelected,
                  selectedIndex: _selectedPageIndex,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: IconButton(
                        onPressed: () => setState(() {
                          _isOutSideDrawerExpanded = !_isOutSideDrawerExpanded;
                        }),
                        icon: Icon(
                          _isOutSideDrawerExpanded
                              ? Icons.menu_open
                              : Icons.menu,
                        ),
                      ),
                    ),
                    // 渲染主导航项目
                    ...destinations.map(
                      (e) => NavigationDrawerDestination(
                        icon: e.icon,
                        selectedIcon: e.selectedIcon,
                        label: Text(e.label),
                      ),
                    ),
                    if (_isOutSideDrawerExpanded &&
                        _currentPageScaffoldAccessoryBuilder != null &&
                        _currentPageScaffoldAccessoryBuilder!
                                .buildDrawerContent(context) !=
                            null) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(28, 16, 28, 10),
                        child: Divider(), // 视觉分割线
                      ),
                      // 获取页面内容并使用扩展操作符注入
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: breakpoint.gutters / 2,
                          ),
                          child: Column(
                            children: [
                              ...(_currentPageScaffoldAccessoryBuilder
                                      ?.buildDrawerContent(context) ??
                                  []),
                              SizedBox(
                                height: MediaQuery.of(context).padding.bottom,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // 中等屏幕的 NavigationRail
          if (breakpoint.window > WindowSize.xsmall &&
              breakpoint.window < WindowSize.medium)
            NavigationRail(
              labelType: NavigationRailLabelType.all,
              selectedIndex: _selectedPageIndex,
              onDestinationSelected: _onDestinationSelected,
              leading: FloatingActionButton(
                heroTag: 'FloatingActionButton_OpenDrawer',
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                child: const Icon(Icons.menu),
              ),
              destinations: [
                ...destinations.map(
                  (e) => NavigationRailDestination(
                    icon: e.icon,
                    selectedIcon: e.selectedIcon,
                    label: Text(e.label),
                  ),
                ),
              ],
            ),
          // 主内容区
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (_selectedPageIndex == 0) {
                  final ScrollDirection direction = notification.direction;
                  if (direction == ScrollDirection.reverse &&
                      _isBottomBarVisible) {
                    setState(() => _isBottomBarVisible = false);
                  } else if (direction == ScrollDirection.forward &&
                      !_isBottomBarVisible) {
                    setState(() => _isBottomBarVisible = true);
                  }
                }
                return true;
              },
              child: IndexedStack(index: _selectedPageIndex, children: _pages),
            ),
          ),
        ],
      ),
      // 小屏幕的底部导航栏
      bottomNavigationBar: breakpoint.window >= WindowSize.small
          ? null
          : SafeArea(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutExpo,
                height: _isBottomBarVisible || appState.setting.fixedBottomBar
                    ? 67
                    : 0,
                child: ClipRRect(
                  child: NavigationBar(
                    onDestinationSelected: _onDestinationSelected,
                    selectedIndex: _selectedPageIndex,
                    destinations: destinations
                        .map(
                          (e) => NavigationDestination(
                            icon: e.icon,
                            selectedIcon: e.selectedIcon,
                            label: e.label,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
    );
  }
}

class ExampleDestination {
  const ExampleDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final Widget icon;
  final Widget selectedIcon;
}
