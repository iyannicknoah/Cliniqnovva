/// A clinical document (lab result, X-ray, scan…) uploaded to R2 (Part 9
/// Task 3/4). [key] is the R2 object key — never a URL; viewing it means
/// asking the backend for a short-lived signed URL first (role-gated).
class PatientDocumentModel {
  const PatientDocumentModel({
    required this.id,
    required this.key,
    required this.originalName,
    required this.contentType,
    this.uploadedAt,
    this.uploadedBy,
  });

  final String id;
  final String key;
  final String originalName;
  final String contentType;
  final DateTime? uploadedAt;
  final String? uploadedBy;

  factory PatientDocumentModel.fromJson(Map<String, dynamic> json) {
    return PatientDocumentModel(
      id: json['id'] as String,
      key: json['key'] as String? ?? '',
      originalName: json['originalName'] as String? ?? 'document',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.tryParse(json['uploadedAt'] as String)
          : null,
      uploadedBy: json['uploadedBy'] as String?,
    );
  }
}
