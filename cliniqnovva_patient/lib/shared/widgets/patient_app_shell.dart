import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heroicons/heroicons.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// One bottom-nav tab (Task 6: home/browse/bookings/chat/settings).
class _NavTab {
  const _NavTab({required this.label, required this.icon, required this.route, this.style = HeroIconStyle.solid});

  final String label;
  final IconRef icon;
  final String route;
  final HeroIconStyle style;
}

const _tabs = [
  _NavTab(label: 'nav_home', icon: AppIcons.navHome, route: '/home', style: HeroIconStyle.mini),
  _NavTab(label: 'nav_browse', icon: AppIcons.navBrowse, route: '/browse'),
  _NavTab(label: 'nav_bookings', icon: AppIcons.navBookings, route: '/my-bookings'),
  _NavTab(label: 'nav_chat', icon: AppIcons.navChat, route: '/chat'),
  _NavTab(label: 'nav_settings', icon: AppIcons.navSettings, route: '/settings'),
];

/// The shared shell for every top-level screen (Task 6: "Bottom navigation
/// shows on home/browse/bookings/chat/settings — not on detail/booking
/// flows"). Mobile equivalent of the web dashboard's sidebar-based
/// `AppShell`/`ShellRoute` — see DESIGN_LANGUAGE.md's Patient App section
/// for the sidebar -> bottom nav adaptation.
class PatientAppShell extends StatelessWidget {
  const PatientAppShell({super.key, required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  int get _activeIndex {
    final index = _tabs.indexWhere((t) => currentRoute.startsWith(t.route));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _activeIndex;
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appBg,
          border: Border(top: BorderSide(color: context.appBorder, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavButton(
                      tab: _tabs[i],
                      isActive: i == activeIndex,
                      onTap: () {
                        if (i != activeIndex) context.go(_tabs[i].route);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.tab, required this.isActive, required this.onTap});

  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? context.appPrimary : context.appSubtext;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(tab.icon, size: 24, color: color, style: tab.style),
          const SizedBox(height: 4),
          Text(
            tab.label.tr(),
            style: TextStyle(
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
