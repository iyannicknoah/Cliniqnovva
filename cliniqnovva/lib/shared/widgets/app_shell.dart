import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../features/appointments/providers/appointments_provider.dart';
import '../../features/auth/providers/access_control_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/clinics/providers/branches_provider.dart'
    show branchDetailProvider;
import '../../features/departments/providers/departments_provider.dart'
    show activeBranchIdProvider;
import '../../features/go_public/providers/go_public_provider.dart';
import 'cliniqnovva_sidebar.dart';
import 'loading_widget.dart';

/// Part 17 Task 4 — the single canonical nav list for the whole admin web
/// surface (everything except Super Admin, which keeps its own separate
/// `superAdminNavItems`/`SuperAdminScaffold`). Each item's [allowedRoles]
/// is the INTERSECTION of what Task 4's brief describes for that role and
/// what the backend actually permits (built across Parts 6-16) — a few
/// items in Task 4's literal per-role lists would 403 if shown as written
/// (Receptionist has no backend access to Reports, Reviews, or Inventory;
/// Task 4 says "Branch Admin/Receptionist: same" as Clinic Admin, which
/// over-grants those three for Receptionist specifically). Showing a nav
/// item that always fails is worse than omitting it, so those three are
/// narrowed to the roles that can actually open them — every other item
/// follows Task 4 literally. (A fourth item, Audit Log, was removed
/// entirely 2026-07-24 along with the rest of that feature, then restored
/// 2026-07-29 — see `auditLog.routes.js`'s `requireRole` for why it's
/// Clinic Admin only here, not Branch Admin: the backend only ever
/// permitted Super Admin/Clinic Admin, matching the same
/// don't-show-a-403-only-item principle as the three narrowed items above.)
final appNavItems = <SidebarNavItem>[
  const SidebarNavItem(
    label: 'nav_dashboard',
    icon: AppIcons.overview,
    route: '/dashboard',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleReceptionist,
    ],
  ),
  // Accountant's own landing page (2026-07-26, explicit user instruction) —
  // same "role-specific home page at the top of the nav" pattern as
  // doctor-today/nurse-today below.
  const SidebarNavItem(
    label: 'nav_overview',
    icon: AppIcons.overview,
    route: '/accountant-overview',
    allowedRoles: [AppConstants.roleAccountant],
  ),
  // Pharmacist's own landing page (2026-07-26, explicit user instruction) —
  // same pattern as the Accountant one above, stock-focused instead of
  // billing-focused.
  const SidebarNavItem(
    label: 'nav_overview',
    icon: AppIcons.overview,
    route: '/pharmacist-overview',
    allowedRoles: [AppConstants.rolePharmacist],
  ),
  // Laboratorian's own landing page (2026-07-29) — same pattern as the
  // Pharmacist/Accountant overview items above.
  const SidebarNavItem(
    label: 'nav_overview',
    icon: AppIcons.overview,
    route: '/laboratorian-overview',
    allowedRoles: [AppConstants.roleLaboratorian],
  ),
  const SidebarNavItem(
    label: 'nav_today',
    icon: AppIcons.today,
    route: '/doctor-today',
    allowedRoles: [AppConstants.roleDoctor],
  ),
  const SidebarNavItem(
    label: 'nav_today',
    icon: AppIcons.today,
    route: '/nurse-today',
    allowedRoles: [AppConstants.roleNurse],
  ),
  const SidebarNavItem(
    label: 'nav_branches',
    icon: AppIcons.branchLocation,
    route: '/branches',
    allowedRoles: [AppConstants.roleClinicAdmin, AppConstants.roleBranchAdmin],
  ),
  const SidebarNavItem(
    label: 'nav_departments',
    icon: AppIcons.department,
    route: '/departments',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleReceptionist,
    ],
  ),
  const SidebarNavItem(
    label: 'nav_services',
    icon: AppIcons.service,
    route: '/services',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleReceptionist,
    ],
  ),
  const SidebarNavItem(
    label: 'nav_staff',
    icon: AppIcons.staff,
    route: '/staff',
    allowedRoles: [AppConstants.roleClinicAdmin, AppConstants.roleBranchAdmin],
  ),
  const SidebarNavItem(
    label: 'nav_doctor_schedule',
    icon: AppIcons.today,
    route: '/doctor-schedule',
    allowedRoles: [AppConstants.roleClinicAdmin, AppConstants.roleBranchAdmin],
  ),
  const SidebarNavItem(
    label: 'nav_patients',
    icon: AppIcons.patients,
    route: '/patients',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleReceptionist,
      AppConstants.roleDoctor,
      AppConstants.roleNurse,
    ],
  ),
  const SidebarNavItem(
    label: 'nav_appointments',
    icon: AppIcons.appointments,
    route: '/appointments',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleReceptionist,
    ],
  ),
  const SidebarNavItem(
    label: 'nav_billing',
    icon: AppIcons.billing,
    route: '/billing',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleReceptionist,
      AppConstants.roleAccountant,
    ],
  ),
  const SidebarNavItem(
    label: 'nav_inventory',
    icon: AppIcons.inventory,
    route: '/inventory',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.rolePharmacist,
    ],
  ),
  // Lab orders worklist (2026-07-29) — Nurse/Laboratorian's queue of tests
  // needing collection/results, plus admin parity for oversight, same
  // pattern as every other module's nav item.
  const SidebarNavItem(
    label: 'nav_lab_orders',
    icon: AppIcons.labOrders,
    route: '/lab-orders',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleNurse,
      AppConstants.roleLaboratorian,
    ],
  ),
  const SidebarNavItem(
    label: 'nav_reports',
    icon: AppIcons.reports,
    route: '/reports',
    allowedRoles: [
      AppConstants.roleClinicAdmin,
      AppConstants.roleBranchAdmin,
      AppConstants.roleAccountant,
    ],
  ),
  const SidebarNavItem(
    label: 'nav_reviews',
    icon: AppIcons.star,
    route: '/reviews',
    allowedRoles: [AppConstants.roleClinicAdmin, AppConstants.roleBranchAdmin],
  ),
  const SidebarNavItem(
    label: 'nav_reviews',
    icon: AppIcons.star,
    route: '/doctor-reviews',
    allowedRoles: [AppConstants.roleDoctor],
  ),
  const SidebarNavItem(
    label: 'nav_popular_clinics',
    icon: AppIcons.trophy,
    route: '/popular-clinics',
    allowedRoles: [AppConstants.roleClinicAdmin, AppConstants.roleBranchAdmin],
  ),
  const SidebarNavItem(
    label: 'nav_audit_log',
    icon: AppIcons.auditLog,
    route: '/audit-log',
    allowedRoles: [AppConstants.roleClinicAdmin],
  ),
];

/// Part 17 Task 4/5 — the shared shell for every non-Super-Admin screen:
/// [CliniqnovvaSidebar] on the left (role-filtered from [appNavItems], with
/// live badge counts; same white/black page background as the content pane,
/// 2026-07-24) and the routed screen on the right. Wrapping happens
/// at the router level (a `ShellRoute` in `app_router.dart`) — none of the
/// ~20 existing screens needed to change; each still renders its own
/// `Scaffold`, which just becomes this shell's content pane.
///
/// 2026-08-14, explicit user instruction — the old fixed 56px topbar (chat
/// icon + notification bell, right-aligned, sitting above every screen's
/// own page-title row) was removed from here entirely. Those two icons now
/// live inside each screen's own title row via the self-contained
/// `TopBarActions` widget (`shared/widgets/top_bar_actions.dart`), so a
/// page's title, branch filter, and the chat/notification icons render as
/// ONE row instead of two stacked ones.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.currentRoute, required this.child});

  final String currentRoute;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(userClaimsProvider);

    return claimsAsync.when(
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (claims) {
        final role = claims?['role'] as String? ?? '';
        final isOrgAdmin = role == AppConstants.roleClinicAdmin;
        final ownBranchId = claims?['branchId'] as String?;
        final branchId = isOrgAdmin
            ? ref.watch(activeBranchIdProvider)
            : ownBranchId;

        final user = ref.watch(authNotifierProvider).valueOrNull;
        final userName = user?.displayName ?? user?.email ?? roleLabel(role);

        final items = branchId == null
            ? appNavItems
            : appNavItems
                  .map((item) => _withBadge(item, ref, branchId))
                  .toList();

        return Scaffold(
          backgroundColor: context.appBg,
          // 2026-08-17, explicit user instruction — "Go Public" is a
          // full-screen page with no sidebar (it has its own back icon
          // instead, see `GoPublicScreen`'s `_BackButton`); every other
          // route keeps the normal sidebar + content `Row`.
          body: currentRoute == '/go-public'
              ? child
              : Row(
                  children: [
                    CliniqnovvaSidebar(
                      items: items,
                      currentRoute: currentRoute,
                      currentRole: role,
                      userName: userName,
                      userRoleLabel: roleLabel(role),
                      onNavTap: (route) => context.go(route),
                      pinnedItem: _goPublicItem(ref, role, branchId),
                    ),
                    Expanded(child: child),
                  ],
                ),
        );
      },
    );
  }

  /// "Go Public" (2026-08-16, explicit user instruction) — pinned above the
  /// profile chip, not part of the scrollable [appNavItems] list (see
  /// [CliniqnovvaSidebar.pinnedItem]). Branch-scoped like the wizard itself,
  /// so it's hidden entirely when no specific branch is selected (an org
  /// admin viewing "All branches") rather than pointing at an ambiguous
  /// target — same reasoning as every other branch-scoped screen in this
  /// app declining to guess.
  SidebarNavItem? _goPublicItem(WidgetRef ref, String role, String? branchId) {
    final allowed =
        role == AppConstants.roleClinicAdmin ||
        role == AppConstants.roleBranchAdmin;
    if (!allowed || branchId == null) return null;

    final branch = ref.watch(branchDetailProvider(branchId)).valueOrNull;
    final needsAttention =
        branch != null && GoPublicSteps(branch).needsAttention;

    return SidebarNavItem(
      label: 'nav_go_public',
      icon: AppIcons.mobilePhone,
      route: '/go-public',
      allowedRoles: const [
        AppConstants.roleClinicAdmin,
        AppConstants.roleBranchAdmin,
      ],
      warning: needsAttention,
    );
  }

  SidebarNavItem _withBadge(
    SidebarNavItem item,
    WidgetRef ref,
    String branchId,
  ) {
    final count = switch (item.route) {
      '/appointments' =>
        ref
            .watch(
              appointmentsListProvider((
                branchId: branchId,
                doctorId: null,
                patientId: null,
                tab: 'today',
              )),
            )
            .valueOrNull
            ?.where((a) => a.status != 'completed' && a.status != 'cancelled')
            .length,
      _ => null,
    };
    if (count == null) return item;
    return SidebarNavItem(
      label: item.label,
      icon: item.icon,
      route: item.route,
      allowedRoles: item.allowedRoles,
      badgeCount: count,
    );
  }
}
