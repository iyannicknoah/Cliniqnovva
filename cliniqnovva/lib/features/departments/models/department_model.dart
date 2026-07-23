/// Part 7 Task 1 — mirrors the backend's `departments` document shape.
/// [serviceCount] is server-computed on list endpoints only (never stored)
/// — the client uses it to decide between offering Delete (0 services) and
/// Deactivate (services attached).
class DepartmentModel {
  const DepartmentModel({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.name,
    this.isActive = true,
    this.createdAt,
    this.serviceCount = 0,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String name;
  final bool isActive;
  final DateTime? createdAt;
  final int serviceCount;

  bool get canDelete => serviceCount == 0;

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      serviceCount: (json['serviceCount'] as num?)?.toInt() ?? 0,
    );
  }
}
