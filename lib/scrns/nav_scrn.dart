import 'package:flutter/material.dart';
import '../core/app_cfg.dart';
import '../data/app_ctrl.dart';
import 'auth_scrn.dart';
import 'explore_scrn.dart';
import 'store_scrn.dart';
import 'studio_scrn.dart';

class NavScrn extends StatefulWidget { // top-level 4-tab shell preserving stage & draft state across tabs
  final AppCtrl ctrl;

  const NavScrn({super.key, required this.ctrl});

  @override
  State<NavScrn> createState() => _NavScrnState();
}

class _NavScrnState extends State<NavScrn> {
  int _curTab = 0;

  void _goTab(int idx) => setState(() => _curTab = idx);

  @override
  Widget build(BuildContext context) {
    final ui = UiCfg.of(context);
    final pages = [
      StudioScrn(ctrl: widget.ctrl, onAuth: () => _goTab(3)),
      ExploreScrn(ctrl: widget.ctrl, onStudio: () => _goTab(0)),
      StoreScrn(ctrl: widget.ctrl, onStudio: () => _goTab(0), onAuth: () => _goTab(3)),
      AuthScrn(ctrl: widget.ctrl, onStudio: () => _goTab(0)),
    ];

    final body = IndexedStack(index: _curTab, children: pages);

    if (ui.isDesk) { // desktop/landscape rail only; portrait tablets keep bottom navigation bar
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _curTab,
              onDestinationSelected: _goTab,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.weekend_outlined), selectedIcon: Icon(Icons.weekend), label: Text('Studio')),
                NavigationRailDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: Text('Discover')),
                NavigationRailDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks), label: Text('Storage')),
                NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Account')),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _curTab,
        onDestinationSelected: _goTab,
        height: 62,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.weekend_outlined), selectedIcon: Icon(Icons.weekend), label: 'Studio'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.bookmarks_outlined), selectedIcon: Icon(Icons.bookmarks), label: 'Storage'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}