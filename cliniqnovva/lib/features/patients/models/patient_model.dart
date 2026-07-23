import 'medical_record_model.dart';
import 'patient_document_model.dart';

/// Rwanda emergency contact — name + phone (spec 6.5A).
class EmergencyContact {
  const EmergencyContact({this.name, this.phone});

  final String? name;
  final String? phone;

  factory EmergencyContact.fromMap(Map<String, dynamic> map) =>
      EmergencyContact(
        name: map['name'] as String?,
        phone: map['phone'] as String?,
      );

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone};
}

/// Rwanda address: Province/District required, Sector/Cell/Village optional
/// (spec section 1, Part 9 Task 2). Reuses the same shape as
/// BranchLocation but kept separate — patients and branches are unrelated
/// entities that happen to share Rwanda's admin-division structure.
class PatientLocation {
  const PatientLocation({
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

  factory PatientLocation.fromMap(Map<String, dynamic> map) =>
      PatientLocation(
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

  String get label => [
    district,
    province,
  ].where((part) => part != null && part.isNotEmpty).join(', ');
}

/// Part 9 — mirrors the backend's `patients` document. [medicalRecords] and
/// [documents] are only ever populated when the API actually returned them
/// — for a receptionist-role request those KEYS are absent from the JSON
/// entirely (server-enforced), so they simply stay null/empty here rather
/// than being hidden by client-side logic.
class PatientModel {
  const PatientModel({
    required this.id,
    required this.organizationId,
    required this.branchId,
    required this.name,
    required this.phone,
    this.dateOfBirth,
    this.gender,
    this.nationalId,
    this.emergencyContact,
    this.location,
    this.registeredVia = 'walkIn',
    this.createdAt,
    this.lastVisitDate,
    this.medicalRecords,
    this.documents,
  });

  final String id;
  final String organizationId;
  final String branchId;
  final String name;
  final String phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? nationalId;
  final EmergencyContact? emergencyContact;
  final PatientLocation? location;
  final String registeredVia;
  final DateTime? createdAt;

  /// Server-computed on search results only (most recent medical record).
  final DateTime? lastVisitDate;

  /// Null when the API omitted the field (receptionist request) — not the
  /// same as an empty list, which means "clinical staff, no records yet".
  final List<MedicalRecordModel>? medicalRecords;
  final List<PatientDocumentModel>? documents;

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] as String?,
      nationalId: json['nationalId'] as String?,
      emergencyContact: json['emergencyContact'] is Map<String, dynamic>
          ? EmergencyContact.fromMap(
              json['emergencyContact'] as Map<String, dynamic>,
            )
          : null,
      location: json['location'] is Map<String, dynamic>
          ? PatientLocation.fromMap(json['location'] as Map<String, dynamic>)
          : null,
      registeredVia: json['registeredVia'] as String? ?? 'walkIn',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastVisitDate: json['lastVisitDate'] != null
          ? DateTime.tryParse(json['lastVisitDate'] as String)
          : null,
      medicalRecords: json.containsKey('medicalRecords')
          ? (json['medicalRecords'] as List<dynamic>)
                .map(
                  (e) => MedicalRecordModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
      documents: json.containsKey('documents')
          ? (json['documents'] as List<dynamic>)
                .map(
                  (e) =>
                      PatientDocumentModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
    );
  }

  int? get ageInYears {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age -= 1;
    }
    return age;
  }
}

/// A lightweight duplicate-check match (Part 9 Task 2 — the precursor to
/// Part 10's full merge flow).
class DuplicateMatch {
  const DuplicateMatch({
    required this.id,
    required this.name,
    required this.phone,
    this.nationalId,
  });

  final String id;
  final String name;
  final String phone;
  final String? nationalId;

  factory DuplicateMatch.fromJson(Map<String, dynamic> json) =>
      DuplicateMatch(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        nationalId: json['nationalId'] as String?,
      );
}
