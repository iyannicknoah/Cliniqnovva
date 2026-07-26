import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../features/appointments/providers/appointments_provider.dart';
import '../../features/auth/providers/access_control_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/widgets/chat_bell.dart';
import '../../features/departments/providers/departments_provider.dart'
    show activeBranchIdProvider;
import '../../features/reviews/providers/reviews_provider.dart';
import '../../features/notifications/widgets/notification_bell.dart';
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
/// entirely 2026-07-24 along with the rest of that feature.)
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
];

/// Roles that can use Chat (2026-07-25) — used to gate the topbar [ChatBell]
/// now that Chat no longer has its own sidebar nav item. Same set the old
/// `nav_chat` [SidebarNavItem] used for `allowedRoles`.
const _chatEnabledRoles = [
  AppConstants.roleClinicAdmin,
  AppConstants.roleBranchAdmin,
  AppConstants.roleReceptionist,
];

/// Part 17 Task 4/5 — the shared shell for every non-Super-Admin screen:
/// [CliniqnovvaSidebar] on the left (role-filtered from [appNavItems], with
/// live badge counts; same white/black page background as the content pane,
/// 2026-07-24), a slim topbar with the chat icon (2026-07-25, moved out of
/// the sidebar — see [_chatEnabledRoles]) and notification bell, and the
/// routed screen on the right. Wrapping happens
/// at the router level (a `ShellRoute` in `app_router.dart`) — none of the
/// ~20 existing screens needed to change; each still renders its own
/// `Scaffold`, which just becomes this shell's content pane.
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
          body: Row(
            children: [
              CliniqnovvaSidebar(
                items: items,
                currentRoute: currentRoute,
                currentRole: role,
                userName: userName,
                userRoleLabel: roleLabel(role),
                onNavTap: (route) => context.go(route),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_chatEnabledRoles.contains(role)) ...[
                            ChatBell(branchId: branchId),
                            const SizedBox(width: 4),
                          ],
                          const NotificationBell(),
                        ],
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
      '/reviews' =>
        ref.watch(reviewsNeedingReplyCountProvider(branchId)).valueOrNull,
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
