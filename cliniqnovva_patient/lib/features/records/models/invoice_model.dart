/// One line item on an invoice — mirrors the web dashboard's
/// `cliniqnovva/lib/features/billing/models/invoice_model.dart` exactly.
class LineItem {
  const LineItem({required this.description, required this.amountRwf});

  final String description;
  final int amountRwf;

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    description: json['description'] as String? ?? '',
    amountRwf: (json['amountRwf'] as num?)?.toInt() ?? 0,
  );
}

/// Mirrors `GET /api/v1/patients/:patientId/invoices`'s per-invoice shape
/// (Part 23) — same fields as the backend's `invoices` document (Part 12),
/// plus a server-resolved `clinicName` (a patient's scope has no clinicId
/// to piggyback the usual staff-side lookup on, so `invoicesService.
/// listForPatient` resolves it explicitly — see that function's comment).
class InvoiceModel {
  const InvoiceModel({
    required this.id,
    required this.clinicId,
    this.clinicName,
    required this.branchId,
    required this.patientId,
    this.appointmentId,
    required this.lineItems,
    required this.totalAmountRwf,
    required this.cashPaidAmountRwf,
    required this.insuranceCoveredAmountRwf,
    required this.insuranceScheme,
    required this.status,
    this.createdAt,
    this.voidReason,
  });

  final String id;
  final String clinicId;
  final String? clinicName;
  final String branchId;
  final String patientId;
  final String? appointmentId;
  final List<LineItem> lineItems;
  final int totalAmountRwf;
  final int cashPaidAmountRwf;
  final int insuranceCoveredAmountRwf;

  /// 'mutuelle' | 'rssb' | 'private' | 'none'.
  final String insuranceScheme;

  /// 'unpaid' | 'partial' | 'paid' | 'voided'.
  final String status;
  final DateTime? createdAt;
  final String? voidReason;

  int get balanceDueRwf => totalAmountRwf - cashPaidAmountRwf - insuranceCoveredAmountRwf;

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      clinicName: json['clinicName'] as String?,
      branchId: json['branchId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      appointmentId: json['appointmentId'] as String?,
      lineItems: (json['lineItems'] as List<dynamic>?)?.map((e) => LineItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      totalAmountRwf: (json['totalAmountRwf'] as num?)?.toInt() ?? 0,
      cashPaidAmountRwf: (json['cashPaidAmountRwf'] as num?)?.toInt() ?? 0,
      insuranceCoveredAmountRwf: (json['insuranceCoveredAmountRwf'] as num?)?.toInt() ?? 0,
      insuranceScheme: json['insuranceScheme'] as String? ?? 'none',
      status: json['status'] as String? ?? 'unpaid',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      voidReason: json['voidReason'] as String?,
    );
  }
}
