import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../billing/screens/invoice_detail_screen.dart';
import '../models/notification_model.dart';
import '../providers/notifications_provider.dart';

/// Part 14 Task 1 — "Notification bell in Admin Dashboard". Same custom
/// `OverlayEntry` + `CompositedTransformTarget`/`Follower` floating-menu
/// pattern as the sidebar's profile chip menu (`cliniqnovva_sidebar.dart`),
/// so it paints above the whole page rather than being confined to
/// whatever card it's placed in.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
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
    ref.invalidate(notificationsListProvider);
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
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: _NotificationMenu(onClose: _removeMenu),
          ),
        ],
      ),
    );
    overlay.insert(_menuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCount = notificationsAsync.valueOrNull
        ?.where((n) => !n.isRead)
        .length;

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggleMenu,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AppIcon(AppIcons.notification, size: 22, color: context.appText),
              if (unreadCount != null && unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: const BoxDecoration(
                      color: AppColors.brightRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
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

class _NotificationMenu extends ConsumerWidget {
  const _NotificationMenu({required this.onClose});

  final VoidCallback onClose;

  void _open(BuildContext context, WidgetRef ref, NotificationModel n) {
    if (!n.isRead) {
      ref.read(notificationsNotifierProvider.notifier).markRead(n.id);
    }
    onClose();
    final invoiceId = n.type == 'paymentRecorded'
        ? n.data['invoiceId'] as String?
        : null;
    if (invoiceId != null) {
      showInvoiceDetailPanel(context, invoiceId: invoiceId);
      return;
    }
    final route = switch (n.type) {
      'lowStock' => '/inventory',
      'newBooking' => '/appointments',
      _ => null,
    };
    if (route != null) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        constraints: const BoxConstraints(maxHeight: 420),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(notificationsNotifierProvider.notifier).markAllRead(),
                    child: const Text('Mark all read', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.appBorder),
            Flexible(
              child: notificationsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingWidget(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('$e', style: TextStyle(color: context.appSubtext)),
                ),
                data: (notifications) => notifications.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(color: context.appSubtext),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: notifications
                            .map((n) => _NotificationRow(
                                  notification: n,
                                  onTap: () => _open(context, ref, n),
                                ))
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : context.appSecondaryBg,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 8),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: notification.isRead
                      ? Colors.transparent
                      : AppColors.brightGreen,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: TextStyle(color: context.appSubtext, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
