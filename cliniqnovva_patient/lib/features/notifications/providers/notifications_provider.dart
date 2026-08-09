import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/notification_model.dart';

/// GET /api/v1/notifications — every notification for this patient, newest
/// first (already scoped server-side to `req.user.uid`). No dedicated
/// unread-count endpoint exists (confirmed against the web dashboard's own
/// bell, which derives it the same way) — count is filtered from this list
/// wherever it's needed, not fetched separately.
final notificationsListProvider = FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/notifications');
  return (response.data!['notifications'] as List).map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
});

class NotificationsNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  void build() {}

  Future<void> markRead(String id) async {
    try {
      await ApiService.instance.patch<Map<String, dynamic>>('/api/v1/notifications/$id/read');
    } finally {
      ref.invalidate(notificationsListProvider);
    }
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.instance.patch<Map<String, dynamic>>('/api/v1/notifications/read-all');
    } finally {
      ref.invalidate(notificationsListProvider);
    }
  }
}

final notificationsNotifierProvider = AsyncNotifierProvider.autoDispose<NotificationsNotifier, void>(
  NotificationsNotifier.new,
);
