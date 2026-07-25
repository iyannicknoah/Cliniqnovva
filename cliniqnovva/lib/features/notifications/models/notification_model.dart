/// Mirrors the backend's `notifications` document (spec section 6.11, Part
/// 14) — always scoped to the CALLING user; there is no "list someone
/// else's notifications" shape.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.isRead = false,
    this.createdAt,
  });

  final String id;

  /// 'newBooking' | 'lowStock' | 'paymentRecorded'.
  final String type;
  final String title;
  final String body;

  /// Arbitrary per-type payload (e.g. `{appointmentId: ...}`, `{itemId: ...}`).
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : const {},
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
