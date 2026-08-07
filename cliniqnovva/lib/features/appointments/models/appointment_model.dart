/// Mirrors the backend's `appointments` document (spec section 6.7, Part
/// 11). One shared shape for every consumer — the booking engine, the
/// Appointments screen's tabs, and (per Task 5) a future Patient App
/// reusing the same POST /api/appointments/book endpoint unchanged.
class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.clinicId,
    required this.branchId,
    required this.patientId,
    required this.doctorId,
    required this.serviceId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.queueNumber,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.invoiceId,
  });

  final String id;
  final String clinicId;
  final String branchId;
  final String patientId;
  final String doctorId;
  final String serviceId;

  /// ISO date string 'YYYY-MM-DD'.
  final String date;
  final String startTime;
  final String endTime;

  /// 'pending' | 'confirmed' | 'checkedIn' | 'completed' | 'cancelled'.
  final String status;

  /// Assigned on check-in only (Part 11 Task 4) — null before then.
  final int? queueNumber;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Only ever present in the response right after a 'completed' status
  /// write (Part 12 Task 1's auto-generated invoice) — never persisted on
  /// the appointment document itself, so it's absent everywhere else.
  final String? invoiceId;

  /// Offline-first (2026-07-30) — used to synthesize an optimistic
  /// "checked in" copy of an already-loaded appointment when the real
  /// status write is queued instead of sent (see
  /// `AppointmentsNotifier.checkInOrQueue`). Only [status] is ever
  /// overridden this way; every other field (including [queueNumber],
  /// which is really assigned server-side) stays exactly what the server
  /// last sent.
  AppointmentModel copyWith({String? status}) => AppointmentModel(
    id: id,
    clinicId: clinicId,
    branchId: branchId,
    patientId: patientId,
    doctorId: doctorId,
    serviceId: serviceId,
    date: date,
    startTime: startTime,
    endTime: endTime,
    status: status ?? this.status,
    queueNumber: queueNumber,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    invoiceId: invoiceId,
  );

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      clinicId: json['clinicId'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      doctorId: json['doctorId'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      queueNumber: json['queueNumber'] as int?,
      createdBy: json['createdBy'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      invoiceId: json['invoiceId'] as String?,
    );
  }
}

/// One open slot from GET /api/appointments/available-slots.
class AppointmentSlot {
  const AppointmentSlot({required this.startTime, required this.endTime});

  final String startTime;
  final String endTime;

  factory AppointmentSlot.fromJson(Map<String, dynamic> json) =>
      AppointmentSlot(
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
      );

  String get label => '$startTime – $endTime';
}

/// GET /api/appointments/queue — Part 11 Task 4's "Now Serving #N" display.
class QueueDisplay {
  const QueueDisplay({
    this.nowServingNumber,
    required this.waitingCount,
    this.lastCompletedNumber,
  });

  final int? nowServingNumber;
  final int waitingCount;
  final int? lastCompletedNumber;

  factory QueueDisplay.fromJson(Map<String, dynamic> json) => QueueDisplay(
    nowServingNumber: json['nowServingNumber'] as int?,
    waitingCount: json['waitingCount'] as int? ?? 0,
    lastCompletedNumber: json['lastCompletedNumber'] as int?,
  );
}
