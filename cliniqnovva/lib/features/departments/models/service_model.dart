/// Part 7 Task 2 — mirrors the backend's `services` document shape (spec
/// section 6.4). [defaultDurationMins]/[defaultPriceRwf] are exactly the
/// two fields the Part 11 booking flow reads to auto-fill expected
/// duration/price when a service is selected ("still editable by staff at
/// billing time" — the booking screen copies these as a starting point,
/// it doesn't reference this model at booking time).
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.clinicId,
    required this.branchId,
    required this.departmentId,
    required this.name,
    required this.defaultDurationMins,
    required this.defaultPriceRwf,
    this.isActive = true,
    this.createdAt,
    this.hasHistory = false,
  });

  final String id;
  final String clinicId;
  final String branchId;
  final String departmentId;
  final String name;
  final int defaultDurationMins;
  final int defaultPriceRwf;
  final bool isActive;
  final DateTime? createdAt;

  /// Server-computed on list endpoints only (never stored) — true if any
  /// appointment references this service. Drives Delete vs Deactivate-only.
  final bool hasHistory;

  bool get canDelete => !hasHistory;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      defaultDurationMins: (json['defaultDurationMins'] as num?)?.toInt() ?? 0,
      defaultPriceRwf: (json['defaultPriceRwf'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      hasHistory: json['hasHistory'] as bool? ?? false,
    );
  }
}
