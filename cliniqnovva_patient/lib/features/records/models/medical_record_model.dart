/// One prescribed medicine — mirrors the web dashboard's
/// `cliniqnovva/lib/features/patients/models/medical_record_model.dart`
/// exactly (field names `medicineName`/`dosage`/`duration`), read-only
/// here since the Patient App never writes a prescription.
class Prescription {
  const Prescription({required this.medicineName, this.dosage, this.duration});

  final String medicineName;
  final String? dosage;
  final String? duration;

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
    medicineName: json['medicineName'] as String? ?? '',
    dosage: json['dosage'] as String?,
    duration: json['duration'] as String?,
  );
}

/// Free-form vitals (blood pressure, temperature, pulse, weight…) — kept as
/// a flexible map, same as the web dashboard's model, since clinics vary in
/// what they track.
class Vitals {
  const Vitals(this.values);

  final Map<String, String> values;

  factory Vitals.fromMap(Map<String, dynamic> map) => Vitals(map.map((k, v) => MapEntry(k, v.toString())));
}

/// Mirrors `GET /api/v1/patients/:patientId/medical-records`'s `records`
/// shape (Part 23) — the FULL clinical detail (diagnosis/prescriptions/
/// notes/vitals), never the receptionist-tier redacted shape `getById`
/// gives other roles.
class MedicalRecordModel {
  const MedicalRecordModel({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.appointmentId,
    this.diagnosis,
    this.prescriptions = const [],
    this.notes,
    this.vitals,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String? doctorId;
  final String? appointmentId;
  final String? diagnosis;
  final List<Prescription> prescriptions;
  final String? notes;
  final Vitals? vitals;
  final DateTime? createdAt;

  factory MedicalRecordModel.fromJson(Map<String, dynamic> json) {
    return MedicalRecordModel(
      id: json['id'] as String,
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String?,
      appointmentId: json['appointmentId'] as String?,
      diagnosis: json['diagnosis'] as String?,
      prescriptions:
          (json['prescriptions'] as List<dynamic>?)?.map((e) => Prescription.fromJson(e as Map<String, dynamic>)).toList() ??
          const [],
      notes: json['notes'] as String?,
      vitals: json['vitals'] is Map<String, dynamic> ? Vitals.fromMap(json['vitals'] as Map<String, dynamic>) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}
