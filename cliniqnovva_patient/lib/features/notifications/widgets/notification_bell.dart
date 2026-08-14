import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/top_bar_icon_button.dart';
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

    return TopBarIconButton(
      icon: AppIcons.notification,
      badgeCount: unreadCount,
      onTap: () => context.push('/notifications'),
    );
  }
}
