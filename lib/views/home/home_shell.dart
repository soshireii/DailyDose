import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../history/history_screen.dart';
import '../medicines/medicine_list_screen.dart';
import '../today/today_screen.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Adaptive navigation: bottom bar on phones, navigation rail on tablets,
/// desktop and landscape.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _tabs = [
    _Tab('Today', Icons.today_outlined, Icons.today),
    _Tab('Medicines', Icons.medication_outlined, Icons.medication),
    _Tab('History', Icons.history_outlined, Icons.history),
  ];

  static const _pages = <Widget>[
    TodayScreen(),
    MedicineListScreen(),
    HistoryScreen(),
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(index: _index, children: _pages);
    final width = MediaQuery.sizeOf(context).width;

    if (context.isWide) {
      final extended = width >= Breakpoints.extraWide;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (final t in _tabs)
                    NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: Text(t.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
