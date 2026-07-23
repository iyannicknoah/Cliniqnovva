/// Mirrors the backend's `publicHolidays` document (spec section 1). Read
/// -only for now — Part 8's Doctor Schedule screen displays these as
/// auto-blocked, with a per-branch "override — keep open" toggle stored on
/// the branch (see BranchModel — not on the holiday itself).
class PublicHolidayModel {
  const PublicHolidayModel({
    required this.id,
    required this.name,
    required this.date,
    this.appliesNationwide = true,
  });

  final String id;
  final String name;
  final DateTime? date;
  final bool appliesNationwide;

  factory PublicHolidayModel.fromJson(Map<String, dynamic> json) {
    return PublicHolidayModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
      appliesNationwide: json['appliesNationwide'] as bool? ?? true,
    );
  }
}
