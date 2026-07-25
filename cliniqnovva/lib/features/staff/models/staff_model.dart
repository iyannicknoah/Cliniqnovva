/// Part 8 — mirrors the backend's `users` document, joined with `doctors`
/// fields (specialty, departmentIds, schedule, blockedSlots, ratings) when
/// [role] is doctor. The join happens server-side (staff.service.js); this
/// model just reads the merged shape.
class StaffModel {
  const StaffModel({
    required this.id,
    required this.clinicId,
    required this.branchId,
    required this.name,
    required this.role,
    this.phone,
    this.email,
    this.isActive = true,
    this.createdAt,
    this.specialty,
    this.departmentIds = const [],
    this.schedule = const [],
    this.blockedSlots = const [],
    this.averageRating = 0,
    this.reviewCount = 0,
  });

  final String id;
  final String clinicId;
  final String branchId;
  final String name;
  final String role;
  final String? phone;
  final String? email;
  final bool isActive;
  final DateTime? createdAt;

  /// Doctor-only fields — empty/null for every other role.
  final String? specialty;
  final List<String> departmentIds;
  final List<DoctorScheduleEntry> schedule;
  final List<BlockedSlot> blockedSlots;

  /// Part 16 Task 2 — cached, server-recalculated on every review write;
  /// never live-computed here.
  final double averageRating;
  final int reviewCount;

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      specialty: json['specialty'] as String?,
      departmentIds:
          (json['departmentIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      schedule:
          (json['schedule'] as List<dynamic>?)
              ?.map(
                (e) => DoctorScheduleEntry.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      blockedSlots:
          (json['blockedSlots'] as List<dynamic>?)
              ?.map((e) => BlockedSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One recurring weekly availability block for a doctor (spec 6.5, Part 8
/// Task 2).
class DoctorScheduleEntry {
  const DoctorScheduleEntry({
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.slotDurationMins,
  });

  /// Lowercase day name — 'monday'..'sunday'.
  final String day;
  final String startTime;
  final String endTime;
  final int slotDurationMins;

  factory DoctorScheduleEntry.fromJson(Map<String, dynamic> json) =>
      DoctorScheduleEntry(
        day: json['day'] as String? ?? '',
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        slotDurationMins: (json['slotDurationMins'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
    'slotDurationMins': slotDurationMins,
  };
}

/// A blocked date/time range for a doctor (leave, emergency, etc — spec
/// 6.5, Part 8 Task 2).
class BlockedSlot {
  const BlockedSlot({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  /// ISO date string, 'YYYY-MM-DD'.
  final String date;
  final String startTime;
  final String endTime;
  final String? reason;

  factory BlockedSlot.fromJson(Map<String, dynamic> json) => BlockedSlot(
    date: json['date'] as String? ?? '',
    startTime: json['startTime'] as String? ?? '',
    endTime: json['endTime'] as String? ?? '',
    reason: json['reason'] as String?,
  );
}

/// One appointment flagged as conflicting with a just-added blocked slot
/// (Part 8 Task 2: "never silently drop them" — returned by the
/// blocked-slots endpoint for staff to review). Only the fields the warning
/// banner needs; the full appointment model lands with Part 9's booking engine.
class ConflictingAppointment {
  const ConflictingAppointment({
    required this.id,
    this.patientId,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String? patientId;
  final String? startTime;
  final String? endTime;

  factory ConflictingAppointment.fromJson(Map<String, dynamic> json) =>
      ConflictingAppointment(
        id: json['id'] as String,
        patientId: json['patientId'] as String?,
        startTime: json['startTime'] as String?,
        endTime: json['endTime'] as String?,
      );
}
