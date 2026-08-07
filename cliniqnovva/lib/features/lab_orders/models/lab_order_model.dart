/// Mirrors the backend's `labOrders` document (2026-07-29). Lifecycle:
/// ordered -> collected -> resulted -> reviewed. Doctor orders/reviews;
/// Nurse or Laboratorian collects/results — see labOrders.service.js for
/// the full role-gating per transition.
class LabOrderModel {
  const LabOrderModel({
    required this.id,
    required this.clinicId,
    required this.branchId,
    required this.patientId,
    this.appointmentId,
    this.medicalRecordId,
    required this.testName,
    this.testCategory,
    this.priceRwf = 0,
    required this.status,
    this.orderedBy,
    this.orderedAt,
    this.collectedBy,
    this.collectedAt,
    this.resultValue,
    this.resultUnit,
    this.resultNotes,
    this.resultedBy,
    this.resultedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.invoiceLineItemAdded = false,
    this.createdAt,
  });

  final String id;
  final String clinicId;
  final String branchId;
  final String patientId;
  final String? appointmentId;
  final String? medicalRecordId;
  final String testName;
  final String? testCategory;
  final int priceRwf;

  /// 'ordered' | 'collected' | 'resulted' | 'reviewed'.
  final String status;
  final String? orderedBy;
  final DateTime? orderedAt;
  final String? collectedBy;
  final DateTime? collectedAt;
  final String? resultValue;
  final String? resultUnit;
  final String? resultNotes;
  final String? resultedBy;
  final DateTime? resultedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final bool invoiceLineItemAdded;
  final DateTime? createdAt;

  factory LabOrderModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? v) => v != null ? DateTime.tryParse(v) : null;
    return LabOrderModel(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      appointmentId: json['appointmentId'] as String?,
      medicalRecordId: json['medicalRecordId'] as String?,
      testName: json['testName'] as String? ?? '',
      testCategory: json['testCategory'] as String?,
      priceRwf: json['priceRwf'] as int? ?? 0,
      status: json['status'] as String? ?? 'ordered',
      orderedBy: json['orderedBy'] as String?,
      orderedAt: parse(json['orderedAt'] as String?),
      collectedBy: json['collectedBy'] as String?,
      collectedAt: parse(json['collectedAt'] as String?),
      resultValue: json['resultValue']?.toString(),
      resultUnit: json['resultUnit'] as String?,
      resultNotes: json['resultNotes'] as String?,
      resultedBy: json['resultedBy'] as String?,
      resultedAt: parse(json['resultedAt'] as String?),
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: parse(json['reviewedAt'] as String?),
      invoiceLineItemAdded: json['invoiceLineItemAdded'] as bool? ?? false,
      createdAt: parse(json['createdAt'] as String?),
    );
  }
}
