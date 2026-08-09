import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import 'models/notification_model.dart';
import 'notification_deep_link.dart';
import 'providers/notifications_provider.dart';

/// Pushed on top of the shell — reached from Settings' link row and the
/// Home screen's bell (Task 2). Every notification for this patient,
/// newest first; tap marks it read and deep-links to the relevant screen.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsListProvider);
    final unreadCount = async.valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          'settings_notifications'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (unreadCount > 0)
            CliniqnovvaButton.text(
              label: 'notifications_mark_all_read'.tr(),
              onPressed: () => ref.read(notificationsNotifierProvider.notifier).markAllRead(),
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(child: Text('notifications_empty'.tr(), style: TextStyle(color: context.appSubtext)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _NotificationRow(notification: notifications[index]),
          );
        },
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final NotificationModel notification;

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    if (!notification.isRead) {
      await ref.read(notificationsNotifierProvider.notifier).markRead(notification.id);
    }
    final route = NotificationDeepLink.routeFor(notification.type, notification.data);
    if (route != null && context.mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _handleTap(context, ref),
      child: CliniqnovvaCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 5, right: 10),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.skyBlue, shape: BoxShape.circle),
              )
            else
              const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(notification.body, style: TextStyle(color: context.appSubtext, fontSize: 13)),
                  if (notification.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      DateFormat.yMMMd().add_jm().format(notification.createdAt!),
                      style: TextStyle(color: context.appSubtext, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
