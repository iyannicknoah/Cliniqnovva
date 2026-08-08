/// Mirrors browse.service.js's `toPublicBranch()` allowlist exactly —
/// backend/src/services/browse.service.js. Only fields that allowlist
/// returns ever reach this model; there is nothing sensitive to worry
/// about parsing here.
class BranchSummary {
  const BranchSummary({
    required this.id,
    required this.clinicId,
    required this.name,
    this.address,
    this.phone,
    this.location,
    this.workingHours,
    this.umugandaSaturdayHours,
    required this.servicesOffered,
    required this.averageRating,
    required this.reviewCount,
    required this.popularityScore,
  });

  factory BranchSummary.fromJson(Map<String, dynamic> json) {
    return BranchSummary(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      location: json['location'] as Map<String, dynamic>?,
      workingHours: json['workingHours'] as Map<String, dynamic>?,
      umugandaSaturdayHours: json['umugandaSaturdayHours'] as Map<String, dynamic>?,
      servicesOffered: (json['servicesOffered'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      popularityScore: (json['popularityScore'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String clinicId;
  final String name;
  final String? address;
  final String? phone;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? workingHours;
  final Map<String, dynamic>? umugandaSaturdayHours;
  final List<String> servicesOffered;
  final double averageRating;
  final int reviewCount;
  final double popularityScore;

  double? get latitude => (location?['lat'] as num?)?.toDouble();
  double? get longitude => (location?['lng'] as num?)?.toDouble();

  bool get is24Hours => workingHours?['is24Hours'] == true;
  String? get workingHoursStart => workingHours?['start'] as String?;
  String? get workingHoursEnd => workingHours?['end'] as String?;
}
