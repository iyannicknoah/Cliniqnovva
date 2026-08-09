import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../providers/notifications_provider.dart';

/// Task 2: "Notification bell icon with unread count badge, accessible
/// from the Home screen top bar." Unread count is derived from the same
/// list the Notification Center itself reads (no dedicated count
/// endpoint exists — see `notifications_provider.dart`'s doc comment).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationsListProvider).valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/notifications'),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppIcon(AppIcons.notification, size: 24, color: context.appText),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
