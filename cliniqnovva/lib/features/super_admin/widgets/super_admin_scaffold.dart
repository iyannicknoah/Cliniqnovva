import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_sidebar.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared by every Super Admin screen so the sidebar/topbar aren't
/// duplicated per screen.
const superAdminNavItems = [
  SidebarNavItem(
    label: 'nav_overview',
    icon: AppIcons.overview,
    route: '/super-admin/overview',
    allowedRoles: [AppConstants.roleSuperAdmin],
  ),
  SidebarNavItem(
    label: 'nav_clinics',
    icon: AppIcons.clinics,
    route: '/super-admin/clinics',
    allowedRoles: [AppConstants.roleSuperAdmin],
  ),
  SidebarNavItem(
    label: 'nav_billing',
    icon: AppIcons.billing,
    route: '/super-admin/billing',
    allowedRoles: [AppConstants.roleSuperAdmin],
  ),
];

/// Dark sidebar + top bar ("Super Admin" badge, sign out) shell for every
/// Super Admin screen — screens only supply their own scrollable [body].
class SuperAdminScaffold extends ConsumerWidget {
  const SuperAdminScaffold({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.body,
  });

  final String currentRoute;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final userName = user?.displayName ?? user?.email ?? 'Super Admin';

    return Scaffold(
      backgroundColor: context.appBg,
      body: Row(
        children: [
          CliniqnovvaSidebar(
            items: superAdminNavItems,
            currentRoute: currentRoute,
            currentRole: AppConstants.roleSuperAdmin,
            userName: userName,
            userRoleLabel: roleLabel(AppConstants.roleSuperAdmin),
            onNavTap: (route) => context.go(route),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: AppTheme.topbarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/chat'),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: AppIcon(
                            AppIcons.chat,
                            size: 22,
                            color: context.appText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const NotificationBell(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: body,
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
