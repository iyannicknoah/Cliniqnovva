/// Mirrors the backend's `notifications` document — same shape the web
/// dashboard's `NotificationModel` already parses (`type`/`title`/`body`/
/// `data`/`isRead`/`createdAt`), generic across every `type` string this
/// or any future trigger uses.
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
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
    id: json['id'] as String,
    type: json['type'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    isRead: json['isRead'] as bool? ?? false,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
  );
}
