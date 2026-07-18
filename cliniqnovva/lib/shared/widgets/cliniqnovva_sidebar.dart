import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'avatar_widget.dart';

/// One entry in [CliniqnovvaSidebar]'s nav list. [allowedRoles] controls
/// role-based visibility — an item is hidden entirely for a role not in
/// this list.
class SidebarNavItem {
  const SidebarNavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.allowedRoles,
  });

  final String label;
  final IconData icon;
  final String route;
  final List<String> allowedRoles;
}

/// The single sidebar component for the Admin Web Dashboard surface —
/// ALWAYS deepNavy background regardless of light/dark theme, fixed 220px
/// width, logo top, role-filtered nav items with a teal active highlight +
/// left border, and the signed-in user's avatar/name/role pinned at the
/// bottom.
class CliniqnovvaSidebar extends StatelessWidget {
  const CliniqnovvaSidebar({
    super.key,
    required this.items,
    required this.currentRoute,
    required this.currentRole,
    required this.userName,
    required this.userRoleLabel,
    this.userPhotoUrl,
    required this.onNavTap,
  });

  final List<SidebarNavItem> items;
  final String currentRoute;
  final String currentRole;
  final String userName;
  final String userRoleLabel;
  final String? userPhotoUrl;
  final ValueChanged<String> onNavTap;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.where((item) => item.allowedRoles.contains(currentRole)).toList();

    return Container(
      width: AppTheme.sidebarWidth,
      color: AppColors.deepNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Cliniqnovva',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: visibleItems.map((item) {
                final active = item.route == currentRoute;
                return _SidebarNavTile(item: item, active: active, onTap: () => onNavTap(item.route));
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1B3A5C))),
            ),
            child: Row(
              children: [
                AvatarWidget(firstName: userName, photoUrl: userPhotoUrl, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        userRoleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8FA3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  const _SidebarNavTile({required this.item, required this.active, required this.onTap});

  final SidebarNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryTeal.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: active ? AppColors.primaryTeal : Colors.transparent, width: 3),
          ),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: active ? AppColors.primaryTeal : Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
