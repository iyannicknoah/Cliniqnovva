/// Part 6 Task 2 — the full branch document model.
///
/// Mirrors the `branches` Firestore collection exactly. Most reads/writes go
/// through the backend REST API (which serves the same shape as JSON), so
/// [BranchModel.fromJson]/[toJson] delegate to the Firestore mappers — one
/// shape, two transports.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Branch working hours (2026-07-23, supports round-the-clock and
/// overnight clinics):
///   - [is24Hours] true → open 24 hours, [start]/[end] are null;
///   - otherwise a 'HH:mm' pair where an [end] EARLIER than [start] means
///     the branch closes the NEXT day (e.g. 20:00 → 04:00).
class BranchHours {
  const BranchHours({this.start, this.end, this.is24Hours = false});

  final String? start;
  final String? end;
  final bool is24Hours;

  factory BranchHours.fromMap(Map<String, dynamic> map) => BranchHours(
    start: map['start'] as String?,
    end: map['end'] as String?,
    is24Hours: map['is24Hours'] == true,
  );

  Map<String, dynamic> toMap() => is24Hours
      ? {'is24Hours': true}
      : {'start': start, 'end': end, 'is24Hours': false};

  /// Closes past midnight, on the following day.
  bool get isOvernight =>
      !is24Hours && start != null && end != null && start!.compareTo(end!) > 0;

  String get label => is24Hours
      ? 'Open 24 hours'
      : isOvernight
      ? '$start – $end (next day)'
      : '$start – $end';
}

/// Rwanda administrative location: province/district required for a valid
/// branch (Part 6 Task 4), sector/cell/village optional detail.
class BranchLocation {
  const BranchLocation({
    this.province,
    this.district,
    this.sector,
    this.cell,
    this.village,
  });

  final String? province;
  final String? district;
  final String? sector;
  final String? cell;
  final String? village;

  factory BranchLocation.fromMap(Map<String, dynamic> map) => BranchLocation(
    province: map['province'] as String?,
    district: map['district'] as String?,
    sector: map['sector'] as String?,
    cell: map['cell'] as String?,
    village: map['village'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'province': province,
    'district': district,
    'sector': sector,
    'cell': cell,
    'village': village,
  };

  /// "District, Province" — the compact one-line form used in lists.
  String get label => [
    district,
    province,
  ].where((part) => part != null && part.isNotEmpty).join(', ');
}

class BranchModel {
  const BranchModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.location,
    this.phone,
    this.workingHours,
    this.umugandaSaturdayHours,
    this.servicesOffered = const [],
    this.holidayOverrides = const [],
    this.isActive = true,
    this.createdAt,
    this.employeeCount,
  });

  final String id;
  final String organizationId;
  final String name;
  final BranchLocation? location;
  final String? phone;
  final BranchHours? workingHours;

  /// Optional override for Umuganda Saturdays (last Saturday of the month,
  /// community work morning) — null means the branch keeps normal hours.
  final BranchHours? umugandaSaturdayHours;
  final List<String> servicesOffered;

  /// Public holiday ids this branch keeps open despite the national
  /// auto-block (Part 8 Task 2: "override — keep open" per holiday).
  final List<String> holidayOverrides;
  final bool isActive;
  final DateTime? createdAt;

  /// Server-computed on list endpoints only (active non-patient users
  /// assigned to this branch) — never stored on the document.
  final int? employeeCount;

  factory BranchModel.fromFirestore(String id, Map<String, dynamic> data) {
    return BranchModel(
      id: id,
      organizationId: data['organizationId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      location: data['location'] is Map<String, dynamic>
          ? BranchLocation.fromMap(data['location'] as Map<String, dynamic>)
          : null,
      phone: data['phone'] as String?,
      workingHours: data['workingHours'] is Map<String, dynamic>
          ? BranchHours.fromMap(data['workingHours'] as Map<String, dynamic>)
          : null,
      umugandaSaturdayHours: data['umugandaSaturdayHours'] is Map<String, dynamic>
          ? BranchHours.fromMap(
              data['umugandaSaturdayHours'] as Map<String, dynamic>,
            )
          : null,
      servicesOffered:
          (data['servicesOffered'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      holidayOverrides:
          (data['holidayOverrides'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: data['isActive'] as bool? ?? true,
      createdAt: switch (data['createdAt']) {
        final Timestamp t => t.toDate(),
        final String s => DateTime.tryParse(s),
        _ => null,
      },
      employeeCount: (data['employeeCount'] as num?)?.toInt(),
    );
  }

  /// The document body (no id — that's the document path). [employeeCount]
  /// is deliberately excluded: it's computed, not stored.
  Map<String, dynamic> toFirestore() => {
    'organizationId': organizationId,
    'name': name,
    'location': location?.toMap(),
    'phone': phone,
    'workingHours': workingHours?.toMap(),
    'umugandaSaturdayHours': umugandaSaturdayHours?.toMap(),
    'servicesOffered': servicesOffered,
    'holidayOverrides': holidayOverrides,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory BranchModel.fromJson(Map<String, dynamic> json) =>
      BranchModel.fromFirestore(json['id'] as String? ?? '', json);

  Map<String, dynamic> toJson() => {'id': id, ...toFirestore()};
}
