import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';

/// Registers this device's FCM token so `notifications.service.js#sendPush()`
/// (Part 14/22) has somewhere to deliver a push — Part 25 Task 4's
/// prerequisite: nothing in this app registered a token before now. Every
/// step fails soft — a denied permission, an unavailable token, or a
/// network hiccup all just mean "no push for now," never a blocking error
/// or a crash; notifications are a nice-to-have, not core app function.
abstract final class NotificationService {
  static Future<void> registerDeviceToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null) return;

      await ApiService.instance.post<Map<String, dynamic>>('/api/auth/fcm-token', data: {'token': token});
    } catch (_) {
      // Best-effort — see doc comment above.
    }
  }
}
