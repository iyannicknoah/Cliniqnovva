/// Mirrors doctors.service.js's `toPublicDoctor()` allowlist exactly —
/// backend/src/services/doctors.service.js. No email/phone/blockedSlots/
/// breakMinutes ever reach the client — the backend never sends them.
class DoctorSummary {
  const DoctorSummary({
    required this.id,
    this.name,
    this.branchId,
    this.clinicId,
    this.specialty,
    this.bio,
    this.departmentIds = const [],
    required this.schedule,
    required this.averageRating,
    required this.reviewCount,
  });

  factory DoctorSummary.fromJson(Map<String, dynamic> json) {
    return DoctorSummary(
      id: json['id'] as String,
      name: json['name'] as String?,
      branchId: json['branchId'] as String?,
      clinicId: json['clinicId'] as String?,
      specialty: json['specialty'] as String?,
      bio: json['bio'] as String?,
      departmentIds: (json['departmentIds'] as List? ?? const []).map((e) => e.toString()).toList(),
      schedule: (json['schedule'] as List? ?? const [])
          .map((e) => DoctorScheduleEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String? name;
  final String? branchId;
  final String? clinicId;
  final String? specialty;
  final String? bio;
  final List<String> departmentIds;
  final List<DoctorScheduleEntry> schedule;
  final double averageRating;
  final int reviewCount;
}

class DoctorScheduleEntry {
  const DoctorScheduleEntry({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.slotDurationMins,
  });

  factory DoctorScheduleEntry.fromJson(Map<String, dynamic> json) {
    return DoctorScheduleEntry(
      day: json['day'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      slotDurationMins: (json['slotDurationMins'] as num?)?.toInt(),
    );
  }

  final String day;
  final String startTime;
  final String endTime;
  final int? slotDurationMins;
}
