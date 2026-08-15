import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../providers/sidebar_provider.dart';
import 'app_icon.dart';
import 'avatar_widget.dart';
import 'cliniqnovva_logo.dart';

/// Collapsed-state rail width (2026-08-14) — icon-only, centered, no
/// wordmark/labels. Expanded width stays `AppTheme.sidebarWidth`.
const _collapsedSidebarWidth = 76.0;

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
class CliniqnovvaSidebar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleItems = items
        .where((item) => item.allowedRoles.contains(currentRole))
        .toList();
    // 2026-08-14, explicit user instruction — "navbar that expands and
    // de-expands". Lives in `sidebarCollapsedProvider`, not local state,
    // since this whole widget is rebuilt fresh by the caller's shell on
    // every route change (see the provider's own doc comment).
    final collapsed = ref.watch(sidebarCollapsedProvider);

    // 2026-08-14 — collapse toggle color/style shared by both the row
    // (expanded) and column (collapsed) layouts below.
    final toggle = InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () =>
          ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          // "our secondary background color" / "our primary text color"
          // (explicit user instruction) — `context.appSecondaryBg`/`appText`,
          // not the brand blue this used before. Both theme-aware, so this
          // also fixes the toggle staying visible in dark mode.
          color: context.appSecondaryBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: AppIcon(
          collapsed ? AppIcons.chevronRight : AppIcons.chevronLeft,
          size: 17,
          color: context.appText,
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: collapsed ? _collapsedSidebarWidth : AppTheme.sidebarWidth,
      // Theme-aware background (2026-08-14 — fixes dark mode: a hardcoded
      // `Colors.white` never switched with the rest of the app). White in
      // light mode / black in dark mode, same as the page itself
      // (`context.appBg`) — a right-edge border marks the seam between them.
      decoration: BoxDecoration(
        color: context.appBg,
        border: Border(right: BorderSide(color: context.appBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 18 : 20),
            // Collapsed: logo above toggle, stacked (a Row didn't fit both
            // side by side in the 76px rail — the toggle button was
            // rendering off past the sidebar's own bounds, which is why
            // tapping it to re-expand never worked). Expanded: logo +
            // wordmark + toggle in one row, toggle pinned right via the
            // wordmark's `Expanded`.
            child: collapsed
                ? Column(
                    children: [
                      const CliniqnovvaLogo(size: 28, radius: 14),
                      const SizedBox(height: 10),
                      toggle,
                    ],
                  )
                : Row(
                    children: [
                      // 2026-08-14, explicit user instruction: back down to
                      // 28px (was briefly 35 earlier the same day), radius
                      // kept at exactly half. `background: true` (a synthetic
                      // white mat behind the mark) stays off — the logo
                      // source is natively transparent with no backing shape
                      // of its own.
                      const CliniqnovvaLogo(size: 28, radius: 14),
                      // 5px gap (explicit user instruction — was 0, briefly
                      // removed entirely earlier the same day).
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Cliniqnovva',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      toggle,
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          // 2026-08-14, explicit user instruction — 1px divider between the
          // logo/toggle header and the nav list.
          Divider(height: 1, thickness: 1, color: context.appBorder),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 10),
              children: visibleItems.map((item) {
                final active = item.route == currentRoute;
                return _SidebarNavTile(
                  item: item,
                  active: active,
                  collapsed: collapsed,
                  onTap: () => onNavTap(item.route),
                );
              }).toList(),
            ),
          ),
          _ProfileChip(
            userName: userName,
            userRoleLabel: userRoleLabel,
            userPhotoUrl: userPhotoUrl,
            collapsed: collapsed,
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
    required this.collapsed,
    required this.onTap,
  });

  final SidebarNavItem item;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 2026-08-14 — active stays the fixed brand blue in both themes;
    // inactive/hover use theme-aware tokens (was hardcoded light-mode-only
    // `AppColors.textSecondary`, invisible-ish against a dark-mode sidebar
    // now that the background itself is theme-aware too).
    final activeColor = AppColors.primary;
    final inactiveColor = context.appSubtext;
    final hoverColor = AppColors.primary.withValues(alpha: 0.06);
    final badgeCount = item.badgeCount ?? 0;
    final icon = AppIcon(
      item.icon,
      size: 19,
      color: active ? activeColor : inactiveColor,
      style: HeroIconStyle.outline,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        // Collapsed rail has no visible label — a hover tooltip keeps the
        // item identifiable (2026-08-14). Empty/no-op in expanded mode.
        message: collapsed ? item.label.tr() : '',
        waitDuration: const Duration(milliseconds: 400),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            hoverColor: hoverColor,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: collapsed
                  ? const EdgeInsets.symmetric(vertical: 11)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                // Active state: light blue tint pill (2026-08-14, follows
                // the white-sidebar flip — was a translucent-white pill
                // when the sidebar itself was solid blue).
                color: active ? AppColors.primaryTint : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: collapsed
                  ? Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          icon,
                          // Collapsed rail has no label row to hang the full
                          // pill badge off of (see the expanded branch below)
                          // — a small corner dot on the icon itself instead,
                          // same red/white styling as the notification
                          // bell's unread-count dot.
                          if (badgeCount > 0)
                            Positioned(
                              right: -7,
                              top: -5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 15,
                                  minHeight: 15,
                                ),
                                decoration: const BoxDecoration(
                                  color: AppColors.brightRed,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  badgeCount > 9 ? '9+' : '$badgeCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        icon,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label.tr(),
                            style: TextStyle(
                              color: active ? activeColor : inactiveColor,
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
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
    required this.collapsed,
  });

  final String userName;
  final String userRoleLabel;
  final String? userPhotoUrl;
  final bool collapsed;

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
      // 2026-08-13 — no boxed/bordered chip, just a top border separating
      // it from the nav list. 2026-08-14: theme-aware tokens throughout
      // (was hardcoded light-mode-only `AppColors.cardBorder`/`textPrimary`/
      // `textSecondary`, invisible-ish in dark mode now the sidebar itself
      // switches with the theme).
      // `AvatarWidget`'s own colorful gradient-initials look is left
      // untouched here — that's a distinct shared component used
      // consistently across the whole app, not a sidebar-specific style.
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        padding: EdgeInsets.all(widget.collapsed ? 8 : 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.appBorder)),
        ),
        // Collapsed rail (2026-08-14): just the avatar, centered, tapping it
        // opens the SAME theme/language/logout menu the "more" button opens
        // when expanded — the menu itself isn't collapsed-specific.
        child: widget.collapsed
            ? Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _toggleMenu,
                  child: AvatarWidget(
                    firstName: widget.userName,
                    photoUrl: widget.userPhotoUrl,
                    size: 36,
                  ),
                ),
              )
            : Row(
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
                          style: TextStyle(
                            color: context.appSubtext,
                            fontSize: 12,
                          ),
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
            // Floating popover shadow (2026-08-13) — ported from the
            // reference's Select `.panel` (`0 12px 28px rgba(20,24,27,0.16)`);
            // flat page cards stay shadow-free, only portaled/floating
            // surfaces like this menu get one.
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, 12)),
            ],
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
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 28, offset: const Offset(0, 12)),
          ],
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
