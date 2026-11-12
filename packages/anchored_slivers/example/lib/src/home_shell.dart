import 'package:flutter/material.dart';

import 'demo_images.dart';
import 'demo_keys.dart';
import 'list_page.dart';
import 'masonry_page.dart';

/// Below this width the pages are switched with a bottom [NavigationBar];
/// at or above it a [NavigationRail] sits next to them.
const double kRailBreakpoint = 840;

/// Holds the two demo pages and the navigation that switches between them.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.images});

  final DemoImageStore images;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;

  void _select(int index) {
    if (index == _selected) return;
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= kRailBreakpoint;

    // An IndexedStack keeps both pages alive, so switching tabs keeps each
    // page's scroll offset and toggles.
    final Widget pages = IndexedStack(
      index: _selected,
      children: <Widget>[
        AnchoredListPage(key: DemoKeys.listPage, images: widget.images),
        AnchoredMasonryPage(key: DemoKeys.masonryPage, images: widget.images),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _selected,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.anchor),
              ),
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.view_agenda_outlined, key: DemoKeys.navList),
                  selectedIcon: Icon(Icons.view_agenda),
                  label: Text('List'),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.grid_view_outlined,
                    key: DemoKeys.navMasonry,
                  ),
                  selectedIcon: Icon(Icons.grid_view),
                  label: Text('Masonry'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: _select,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            key: DemoKeys.navList,
            icon: Icon(Icons.view_agenda_outlined),
            selectedIcon: Icon(Icons.view_agenda),
            label: 'List',
          ),
          NavigationDestination(
            key: DemoKeys.navMasonry,
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Masonry',
          ),
        ],
      ),
    );
  }
}
