/// Mirrors `departments.service.js`'s document shape (id/clinicId/branchId/
/// name/isActive) — GET /api/v1/departments.
class DepartmentModel {
  const DepartmentModel({required this.id, required this.name, this.isActive = true});

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final bool isActive;
}
