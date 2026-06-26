import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.home_rounded, label: 'Home', route: '/dashboard'),
    _TabItem(icon: Icons.campaign_rounded, label: 'Announcements', route: '/announcements'),
    _TabItem(icon: Icons.check_box_rounded, label: 'Tasks', route: '/tasks'),
    _TabItem(icon: Icons.calendar_month_rounded, label: 'Events', route: '/events'),
    _TabItem(icon: Icons.grid_view_rounded, label: 'More', route: '/more'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/announcements')) return 1;
    if (location.startsWith('/tasks')) return 2;
    if (location.startsWith('/events')) return 3;
    return 4; // /more, /polls, /directory, /resources, /settings, etc.
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: selected,
          onTap: (i) => context.go(_tabs[i].route),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 9),
          elevation: 0,
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String route;
  const _TabItem({required this.icon, required this.label, required this.route});
}
