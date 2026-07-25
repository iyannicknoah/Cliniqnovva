/// One prescribed medicine (spec section 6.6). [dispensed]/[dispensedItemId]
/// etc. are stamped server-side by Part 13's dispense flow — never sent by
/// the client, so [toJson] (used when a doctor writes a new prescription)
/// omits them entirely.
class Prescription {
  const Prescription({
    required this.medicineName,
    this.dosage,
    this.duration,
    this.dispensed = false,
    this.dispensedItemId,
    this.dispensedQuantity,
  });

  final String medicineName;
  final String? dosage;
  final String? duration;
  final bool dispensed;
  final String? dispensedItemId;
  final int? dispensedQuantity;

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
    medicineName: json['medicineName'] as String? ?? '',
    dosage: json['dosage'] as String?,
    duration: json['duration'] as String?,
    dispensed: json['dispensed'] as bool? ?? false,
    dispensedItemId: json['dispensedItemId'] as String?,
    dispensedQuantity: json['dispensedQuantity'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'medicineName': medicineName,
    'dosage': dosage,
    'duration': duration,
  };
}

/// Free-form vitals a nurse records — kept as a flexible map (blood
/// pressure, temperature, pulse, weight… whatever the visit calls for)
/// rather than a fixed schema, since clinics vary in what they track.
class Vitals {
  const Vitals(this.values);

  final Map<String, String> values;

  factory Vitals.fromMap(Map<String, dynamic> map) =>
      Vitals(map.map((k, v) => MapEntry(k, v.toString())));

  Map<String, dynamic> toMap() => values;
}

/// Mirrors the backend's `medicalRecords` document — but the SET of fields
/// actually present depends on the requester's role (Part 9 Task 3): a
/// Doctor's response has diagnosis/prescriptions/notes; a Nurse's has only
/// vitals + basic metadata, with those clinical keys omitted server-side.
/// Every field here is nullable/defaulted for exactly that reason — a null
/// [diagnosis] can mean either "not set" or "the API didn't send it to
/// this role", which is the correct ambiguity: the UI never needs to tell
/// the two apart, it just renders whatever came back.
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
    this.authorId,
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
  final String? authorId;

  factory MedicalRecordModel.fromJson(Map<String, dynamic> json) {
    return MedicalRecordModel(
      id: json['id'] as String,
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String?,
      appointmentId: json['appointmentId'] as String?,
      diagnosis: json['diagnosis'] as String?,
      prescriptions:
          (json['prescriptions'] as List<dynamic>?)
              ?.map((e) => Prescription.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      notes: json['notes'] as String?,
      vitals: json['vitals'] is Map<String, dynamic>
          ? Vitals.fromMap(json['vitals'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      authorId: json['authorId'] as String?,
    );
  }
}
