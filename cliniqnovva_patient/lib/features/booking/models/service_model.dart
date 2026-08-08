/// Mirrors `services.service.js`'s document shape — GET /api/v1/services.
/// Field names are `defaultDurationMins`/`defaultPriceRwf` exactly (not
/// `durationMins`/`priceRwf`) — matching the backend, not guessed names.
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.departmentId,
    required this.defaultDurationMins,
    required this.defaultPriceRwf,
    this.isActive = true,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      defaultDurationMins: (json['defaultDurationMins'] as num?)?.toInt() ?? 0,
      defaultPriceRwf: (json['defaultPriceRwf'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final String departmentId;
  final int defaultDurationMins;
  final int defaultPriceRwf;
  final bool isActive;
}
