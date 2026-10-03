import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/guards/role_guard.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';

class BottomNavBar extends StatelessWidget {
  final String currentLocation;

  const BottomNavBar({super.key, required this.currentLocation});

  static const _tabs = <_NavTab>[
    _NavTab(
      label: 'Accueil',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      route: Routes.dashboard,
    ),
    _NavTab(
      label: 'Scanner',
      icon: Icons.qr_code_scanner_outlined,
      activeIcon: Icons.qr_code_scanner,
      route: Routes.scanner,
    ),
    _NavTab(
      label: 'Cycles',
      icon: Icons.autorenew_outlined,
      activeIcon: Icons.autorenew,
      route: Routes.cycles,
    ),
    _NavTab(
      label: 'Stock',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      route: Routes.stock,
    ),
    _NavTab(
      label: 'Alertes',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      route: Routes.alerts,
    ),
    _NavTab(
      label: 'Plus',
      icon: Icons.more_horiz_outlined,
      activeIcon: Icons.more_horiz,
      route: Routes.settings,
    ),
  ];

  List<_NavTab> _visibleTabs() {
    final session = getIt<SessionStore>();
    return _tabs
        .where((tab) => RoleGuard.isAllowed(
              route: tab.route,
              hasPermission: session.hasPermission,
            ))
        .toList();
  }

  int _currentIndex(List<_NavTab> tabs) {
    for (var i = 0; i < tabs.length; i++) {
      if (currentLocation.startsWith(tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs();
    final index = _currentIndex(tabs);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        border: Border(top: BorderSide(color: AppColors.hairline)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F12284B),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: tabs[i],
                    isActive: i == index,
                    onTap: () {
                      if (i == index) return;
                      context.go(tabs[i].route);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.brandPrimary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.brandPrimaryLight
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(
              isActive ? tab.activeIcon : tab.icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
