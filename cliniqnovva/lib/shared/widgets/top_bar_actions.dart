import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../features/auth/providers/access_control_provider.dart';
import '../../features/chat/widgets/chat_bell.dart';
import '../../features/departments/providers/departments_provider.dart'
    show activeBranchIdProvider;
import '../../features/notifications/widgets/notification_bell.dart';

/// Roles that can use Chat — same set `app_shell.dart` used before this
/// widget existed.
const _chatEnabledRoles = [
  AppConstants.roleClinicAdmin,
  AppConstants.roleBranchAdmin,
  AppConstants.roleReceptionist,
];

/// Chat + notification icons (2026-08-14) — extracted from `AppShell`'s old
/// fixed 56px topbar so every screen's own page-title row can place them on
/// the right, next to the branch filter, instead of a separate row above the
/// page content. Self-contained (reads role/branchId itself via providers)
/// so no screen needs to thread that data down just to show these icons.
class TopBarActions extends ConsumerWidget {
  const TopBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider).valueOrNull;
    final role = claims?['role'] as String? ?? '';
    final isOrgAdmin = role == AppConstants.roleClinicAdmin;
    final ownBranchId = claims?['branchId'] as String?;
    final branchId = isOrgAdmin
        ? ref.watch(activeBranchIdProvider)
        : ownBranchId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_chatEnabledRoles.contains(role)) ...[
          ChatBell(branchId: branchId),
          const SizedBox(width: 4),
        ],
        const NotificationBell(),
      ],
    );
  }
}
