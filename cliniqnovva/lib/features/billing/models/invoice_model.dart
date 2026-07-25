/// One line item on an invoice — free-text description + a whole-RWF
/// amount (spec section 6.8: "all amounts in RWF, whole numbers").
class LineItem {
  const LineItem({required this.description, required this.amountRwf});

  final String description;
  final int amountRwf;

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    description: json['description'] as String? ?? '',
    amountRwf: (json['amountRwf'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'description': description,
    'amountRwf': amountRwf,
  };
}

/// Mirrors the backend's `invoices` document (Part 12). [totalAmountRwf] is
/// always server-recalculated from [lineItems] — this model never sends it
/// back on a write, only reads it.
class InvoiceModel {
  const InvoiceModel({
    required this.id,
    required this.clinicId,
    required this.branchId,
    required this.patientId,
    this.appointmentId,
    required this.lineItems,
    required this.totalAmountRwf,
    required this.cashPaidAmountRwf,
    required this.insuranceCoveredAmountRwf,
    required this.insuranceScheme,
    required this.status,
    this.recordedBy,
    this.createdAt,
    this.voidReason,
  });

  final String id;
  final String clinicId;
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
  final String? recordedBy;
  final DateTime? createdAt;
  final String? voidReason;

  int get balanceDueRwf =>
      totalAmountRwf - cashPaidAmountRwf - insuranceCoveredAmountRwf;

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      appointmentId: json['appointmentId'] as String?,
      lineItems:
          (json['lineItems'] as List<dynamic>?)
              ?.map((e) => LineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalAmountRwf: (json['totalAmountRwf'] as num?)?.toInt() ?? 0,
      cashPaidAmountRwf: (json['cashPaidAmountRwf'] as num?)?.toInt() ?? 0,
      insuranceCoveredAmountRwf:
          (json['insuranceCoveredAmountRwf'] as num?)?.toInt() ?? 0,
      insuranceScheme: json['insuranceScheme'] as String? ?? 'none',
      status: json['status'] as String? ?? 'unpaid',
      recordedBy: json['recordedBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      voidReason: json['voidReason'] as String?,
    );
  }
}
