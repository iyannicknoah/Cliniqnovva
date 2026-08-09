/// Maps a notification's `type` + `data` to an in-app route (Task 2:
/// "deep-link to the relevant screen"; Task 3: same mapping for a tapped
/// OS-tray push). Shared by the Notification Center screen's tap handler
/// and the FCM background/terminated tap handler, so the two never drift.
/// Mirrors the web dashboard's `_NotificationMenu`'s type switch — same
/// convention, patient-side routes.
abstract final class NotificationDeepLink {
  static String? routeFor(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'appointmentReminder':
      case 'appointmentCancelled':
      case 'appointmentRescheduled':
      case 'newBooking':
        final id = data['appointmentId'] as String?;
        return id != null ? '/my-bookings/$id' : null;
      case 'newChatMessage':
        final id = data['chatId'] as String?;
        return id != null ? '/chat/$id' : null;
      case 'reviewReply':
        // No per-review detail screen exists (Part 24's My Reviews is a
        // flat list, no /my-reviews/:id view route) — the list itself is
        // the most specific place to land.
        return '/my-reviews';
      default:
        return null;
    }
  }
}
