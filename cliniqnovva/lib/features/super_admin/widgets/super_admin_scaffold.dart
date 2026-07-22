import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_sidebar.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared by every Super Admin screen (Organizations now; Billing/Oversight
/// once Parts 4-5 build them) so the sidebar/topbar aren't duplicated per screen.
const superAdminNavItems = [
  SidebarNavItem(
    label: 'Organizations',
    icon: Icons.apartment_outlined,
    route: '/super-admin/organizations',
    allowedRoles: [AppConstants.roleSuperAdmin],
  ),
  SidebarNavItem(
    label: 'Billing',
    icon: Icons.receipt_long_outlined,
    route: '/super-admin/billing',
    allowedRoles: [AppConstants.roleSuperAdmin],
  ),
  SidebarNavItem(
    label: 'Oversight',
    icon: Icons.shield_outlined,
    route: '/super-admin/oversight',
    allowedRoles: [AppConstants.roleSuperAdmin],
  ),
];

/// Dark sidebar + top bar ("Super Admin" badge, sign out) shell for every
/// Super Admin screen — screens only supply their own scrollable [body].
class SuperAdminScaffold extends ConsumerWidget {
  const SuperAdminScaffold({super.key, required this.currentRoute, required this.title, required this.body});

  final String currentRoute;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final userName = user?.displayName ?? user?.email ?? 'Super Admin';

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Row(
        children: [
          CliniqnovvaSidebar(
            items: superAdminNavItems,
            currentRoute: currentRoute,
            currentRole: AppConstants.roleSuperAdmin,
            userName: userName,
            userRoleLabel: 'Super Admin',
            onNavTap: (route) => context.go(route),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: AppTheme.topbarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.pillTealBg,
                          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                        ),
                        child: const Text(
                          'Super Admin',
                          style: TextStyle(color: AppColors.pillTealText, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      CliniqnovvaButton.text(
                        label: 'Sign out',
                        onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
                      ),
                    ],
                  ),
                ),
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: body)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
