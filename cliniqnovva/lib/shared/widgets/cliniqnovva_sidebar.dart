import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'app_icon.dart';
import 'avatar_widget.dart';
import 'cliniqnovva_logo.dart';

/// One entry in [CliniqnovvaSidebar]'s nav list. [allowedRoles] controls
/// role-based visibility — an item is hidden entirely for a role not in
/// this list. [badgeCount] (Part 17 Task 4 — "Badge counts on Appointments
/// (today), Chat (unread), Reviews") is a small pill shown beside the
/// label when > 0; null/0 shows nothing, so items without a badge concept
/// (e.g. Billing) never render an empty pill.
///
/// [label] is an `easy_localization` TRANSLATION KEY (Part 17 Task 6, e.g.
/// `'nav_dashboard'`), not display text — rendered via `.tr()` in
/// [_SidebarNavTile]. A key missing from `assets/translations/*.json`
/// safely falls back to showing the key itself, so this never breaks even
/// for a label not yet translated.
class SidebarNavItem {
  const SidebarNavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.allowedRoles,
    this.badgeCount,
  });

  final String label;
  final IconRef icon;
  final String route;
  final List<String> allowedRoles;
  final int? badgeCount;
}

/// The single sidebar component for the Admin Web Dashboard surface —
/// SAME background as the page it sits beside (2026-07-24: pure white in
/// light mode, pure black in dark mode, via `context.appBg` — reversing
/// Part 17's "always navy" rule). The only thing separating it from the
/// content pane is the right-hand border (`context.appBorder`), the same
/// "never a different flat color than the page, differentiate with a
/// border only" rule `theme_ext.dart` already uses for cards. Fixed 220px
/// width, logo top (no divider under it), role-filtered nav items (active
/// = a soft neutral pill via `context.appSecondaryBg`), signed-in user's
/// profile chip at bottom (border-only, with a "more" menu for
/// theme/language/logout — that floating popup was already theme-reactive
/// and needed no change here).
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
    final visibleItems = items
        .where((item) => item.allowedRoles.contains(currentRole))
        .toList();

    return Container(
      width: AppTheme.sidebarWidth,
      decoration: BoxDecoration(
        color: context.appBg,
        border: Border(right: BorderSide(color: context.appBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const CliniqnovvaLogo(size: 28, radius: 8),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Cliniqnovva',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.skyBlue,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: visibleItems.map((item) {
                final active = item.route == currentRoute;
                return _SidebarNavTile(
                  item: item,
                  active: active,
                  onTap: () => onNavTap(item.route),
                );
              }).toList(),
            ),
          ),
          _ProfileChip(
            userName: userName,
            userRoleLabel: userRoleLabel,
            userPhotoUrl: userPhotoUrl,
          ),
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  const _SidebarNavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final SidebarNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.appText;
    final inactiveColor = context.appSubtext;
    final hoverColor = (context.isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.04);
    final badgeCount = item.badgeCount ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          hoverColor: hoverColor,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              // Active state: soft neutral pill, no left border (design
              // rule 2026-07-23, reaffirmed 2026-07-24 for the white/black
              // sidebar — same fill `appSecondaryBg` uses for any other
              // interactive-state highlight in the app).
              color: active ? context.appSecondaryBg : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                AppIcon(
                  item.icon,
                  size: 16,
                  color: active ? activeColor : inactiveColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label.tr(),
                    style: TextStyle(
                      color: active ? activeColor : inactiveColor,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.brightRed,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The bottom-of-sidebar user profile chip — no background, border only
/// (2026-07-24). Tapping the "more" icon opens a floating menu
/// (theme, language, logout), stacked above the whole page (not confined to
/// the sidebar) via a custom [OverlayEntry] rather than [PopupMenuButton], so
/// each row inside can have its own independent tap handling.
class _ProfileChip extends ConsumerStatefulWidget {
  const _ProfileChip({
    required this.userName,
    required this.userRoleLabel,
    this.userPhotoUrl,
  });

  final String userName;
  final String userRoleLabel;
  final String? userPhotoUrl;

  @override
  ConsumerState<_ProfileChip> createState() => _ProfileChipState();
}

class _ProfileChipState extends ConsumerState<_ProfileChip> {
  final _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _removeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _toggleMenu() {
    if (_menuEntry != null) {
      _removeMenu();
      return;
    }
    final overlay = Overlay.of(context);
    _menuEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            // Pins the menu's left edge ~50px from the window's left edge,
            // regardless of the profile chip's own position within the
            // sidebar (2026-07-24) — the sidebar is always docked flush left,
            // so this offset is effectively an absolute screen position.
            offset: const Offset(50, -8),
            child: _ProfileMenuContent(onClose: _removeMenu),
          ),
        ],
      ),
    );
    overlay.insert(_menuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appBorder, width: 1),
        ),
        child: Row(
          children: [
            AvatarWidget(
              firstName: widget.userName,
              photoUrl: widget.userPhotoUrl,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    widget.userRoleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appSubtext, fontSize: 12),
                  ),
                ],
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _toggleMenu,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AppIcon(
                  AppIcons.moreHoriz,
                  size: 18,
                  color: context.appSubtext,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local display-only strings — matches the reference design but the
/// language SUBMENU it opens is visual only for now (no `setLocale` call);
/// see [_LanguageSubmenu].
String _localeName(String code) => switch (code) {
  AppConstants.langKinyarwanda => 'Kinyarwanda',
  AppConstants.langFrench => 'Français',
  _ => 'English',
};

class _ProfileMenuContent extends ConsumerStatefulWidget {
  const _ProfileMenuContent({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_ProfileMenuContent> createState() =>
      _ProfileMenuContentState();
}

class _ProfileMenuContentState extends ConsumerState<_ProfileMenuContent> {
  final _languageLink = LayerLink();
  OverlayEntry? _languageEntry;

  @override
  void dispose() {
    _removeLanguageSubmenu();
    super.dispose();
  }

  void _removeLanguageSubmenu() {
    _languageEntry?.remove();
    _languageEntry = null;
  }

  /// Opens the language submenu stacked above (later `OverlayEntry`s paint
  /// on top) and positioned beside — to the right of — this whole menu
  /// panel, not just the "Language" row (2026-07-24).
  void _toggleLanguageSubmenu() {
    if (_languageEntry != null) {
      _removeLanguageSubmenu();
      return;
    }
    final overlay = Overlay.of(context);
    _languageEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeLanguageSubmenu,
            ),
          ),
          CompositedTransformFollower(
            link: _languageLink,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(8, 0),
            child: _LanguageSubmenu(
              // Part 17 Task 6 — real switching: easy_localization re-renders
              // every `.tr()` call in the tree the instant the locale changes,
              // no restart needed. Picking any option dismisses BOTH the
              // submenu and the parent menu.
              onPick: (code) {
                context.setLocale(Locale(code));
                _removeLanguageSubmenu();
                widget.onClose();
              },
            ),
          ),
        ],
      ),
    );
    overlay.insert(_languageEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark;

    return CompositedTransformTarget(
      link: _languageLink,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appBorder, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'menu_theme'.tr(),
                style: TextStyle(
                  color: context.appText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.appSecondaryBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ThemeOption(
                        label: 'menu_light'.tr(),
                        selected: !isDark,
                        onTap: () => ref
                            .read(themeNotifierProvider.notifier)
                            .setThemeMode(ThemeMode.light),
                      ),
                    ),
                    Expanded(
                      child: _ThemeOption(
                        label: 'menu_dark'.tr(),
                        selected: isDark,
                        onTap: () => ref
                            .read(themeNotifierProvider.notifier)
                            .setThemeMode(ThemeMode.dark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: context.appBorder),
              const SizedBox(height: 12),
              Text(
                'menu_language'.tr(),
                style: TextStyle(
                  color: context.appText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: _toggleLanguageSubmenu,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSecondaryBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _localeName(context.locale.languageCode),
                          style: TextStyle(
                            color: context.appSubtext,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      AppIcon(
                        AppIcons.chevronRight,
                        size: 14,
                        color: context.appSubtext,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: context.appBorder),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () {
                    widget.onClose();
                    ref.read(authNotifierProvider.notifier).signOut();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: context.appSecondaryBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        'menu_logout'.tr(),
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Language submenu (Part 17 Task 6) — lists the 3 supported languages
/// with the same panel styling as [_ProfileMenuContent]. Picking one calls
/// [onPick] with that language code; the caller applies it via
/// `context.setLocale()`.
class _LanguageSubmenu extends StatelessWidget {
  const _LanguageSubmenu({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: context.appBorder, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final code in AppConstants.supportedLanguages)
              InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => onPick(code),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  child: Text(
                    _localeName(code),
                    style: TextStyle(color: context.appText, fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? context.appCard : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: context.appText,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
