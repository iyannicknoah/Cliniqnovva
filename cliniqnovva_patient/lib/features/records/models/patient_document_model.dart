/// Mirrors a `patients/{id}/documents/{docId}` entry, as returned bundled
/// into `GET /api/v1/patients/:patientId/medical-records`'s `documents`
/// array (Part 23) — the schema has no visit/appointment linkage for a
/// document (see `patients.service.js#addDocument`), so these are a flat
/// per-patient list, not grouped per visit.
class PatientDocumentModel {
  const PatientDocumentModel({
    required this.id,
    required this.key,
    required this.originalName,
    required this.contentType,
    this.uploadedAt,
  });

  final String id;
  final String key;
  final String originalName;
  final String contentType;
  final DateTime? uploadedAt;

  /// The document's owning /patients record id — the key's own second path
  /// segment (`patients/{patientId}/documents/{docId}-{name}`, see
  /// `patients.service.js#addDocument`), not tracked separately since a
  /// merged cross-clinic document list needs to know which linked record's
  /// endpoint to call for a fresh signed URL.
  String? get patientId {
    final parts = key.split('/');
    return parts.length >= 2 && parts[0] == 'patients' ? parts[1] : null;
  }

  factory PatientDocumentModel.fromJson(Map<String, dynamic> json) {
    return PatientDocumentModel(
      id: json['id'] as String,
      key: json['key'] as String? ?? '',
      originalName: json['originalName'] as String? ?? 'Document',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      uploadedAt: json['uploadedAt'] != null ? DateTime.tryParse(json['uploadedAt'] as String) : null,
    );
  }
}
