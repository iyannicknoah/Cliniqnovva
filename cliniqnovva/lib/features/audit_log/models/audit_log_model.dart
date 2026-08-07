/// Mirrors the backend's `auditLogs` document (docs/technical-spec.md §6.12,
/// restored 2026-07-29 — see auditLog.service.js for the removal/restoration
/// history). View-only: there is no create/update path from the Flutter side.
class AuditLogModel {
  const AuditLogModel({
    required this.id,
    this.actorId,
    this.actorRole,
    this.clinicId,
    required this.action,
    required this.targetCollection,
    this.targetId,
    this.timestamp,
  });

  final String id;
  final String? actorId;
  final String? actorRole;
  final String? clinicId;

  /// e.g. 'clinic.suspended', 'staff.created', 'invoice.voided' — see
  /// auditLog.service.js call sites for the full list of action strings.
  final String action;
  final String targetCollection;
  final String? targetId;
  final DateTime? timestamp;

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      actorId: json['actorId'] as String?,
      actorRole: json['actorRole'] as String?,
      clinicId: json['clinicId'] as String?,
      action: json['action'] as String? ?? '',
      targetCollection: json['targetCollection'] as String? ?? '',
      targetId: json['targetId'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}
