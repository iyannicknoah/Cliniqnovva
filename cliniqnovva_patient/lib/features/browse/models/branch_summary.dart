/// Mirrors browse.service.js's `toPublicBranch()` allowlist exactly —
/// backend/src/services/browse.service.js. Only fields that allowlist
/// returns ever reach this model; there is nothing sensitive to worry
/// about parsing here.
class BranchSummary {
  const BranchSummary({
    required this.id,
    required this.clinicId,
    required this.name,
    this.displayName,
    this.address,
    this.publicAddress,
    this.phone,
    this.publicPhone,
    this.publicEmail,
    this.imageUrl,
    this.doctorCount = 0,
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
      displayName: json['displayName'] as String?,
      address: json['address'] as String?,
      publicAddress: json['publicAddress'] as String?,
      phone: json['phone'] as String?,
      publicPhone: json['publicPhone'] as String?,
      publicEmail: json['publicEmail'] as String?,
      imageUrl: json['imageUrl'] as String?,
      doctorCount: (json['doctorCount'] as num?)?.toInt() ?? 0,
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

  /// Falls back to [name] server-side when the branch has no public profile
  /// (see browse.service.js#toPublicBranch) — never null in practice, but
  /// typed nullable to match every other field this model mirrors 1:1.
  final String? displayName;
  final String? address;
  final String? publicAddress;
  final String? phone;
  final String? publicPhone;
  final String? publicEmail;

  /// Short-lived signed R2 URL, or null for a branch with no public profile
  /// image (most branches, until their admin opts in — see
  /// [features/browse/widgets/branch_card.dart]'s placeholder for that case).
  final String? imageUrl;
  final int doctorCount;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? workingHours;
  final Map<String, dynamic>? umugandaSaturdayHours;
  final List<String> servicesOffered;
  final double averageRating;
  final int reviewCount;
  final double popularityScore;

  /// Prefers the public-profile address (what the clinic chose to show
  /// patients) over the internal one — see the model-mirrored backend
  /// comment on why these are two separate fields.
  String? get contactAddress => publicAddress ?? address;
  String? get contactPhone => publicPhone ?? phone;

  double? get latitude => (location?['lat'] as num?)?.toDouble();
  double? get longitude => (location?['lng'] as num?)?.toDouble();

  bool get is24Hours => workingHours?['is24Hours'] == true;
  String? get workingHoursStart => workingHours?['start'] as String?;
  String? get workingHoursEnd => workingHours?['end'] as String?;
}
