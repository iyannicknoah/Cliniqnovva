import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/notification_model.dart';

/// Always the CALLER's own notifications — the server derives the recipient
/// from the auth token, there is no id/filter param (Part 14 Task 1).
final notificationsListProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/notifications',
      );
      final data = response.data!['notifications'] as List<dynamic>;
      return data
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Owns every notification write action (Part 14) — the ONE exposed write
/// is toggling a recipient's own read flag, never the message content.
class NotificationsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markRead(String id) async {
    await ApiService.instance.patch<Map<String, dynamic>>(
      '/api/v1/notifications/$id/read',
    );
    ref.invalidate(notificationsListProvider);
  }

  Future<void> markAllRead() async {
    await ApiService.instance.patch<Map<String, dynamic>>(
      '/api/v1/notifications/read-all',
    );
    ref.invalidate(notificationsListProvider);
  }
}

final notificationsNotifierProvider =
    AsyncNotifierProvider<NotificationsNotifier, void>(
      NotificationsNotifier.new,
    );
