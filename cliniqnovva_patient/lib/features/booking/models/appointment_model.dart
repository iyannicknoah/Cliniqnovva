/// Mirrors `appointments.service.js#book()`'s document shape exactly —
/// GET/POST/PUT /api/v1/appointments/*. `patientId` here is the caller's
/// OWN resolved /patients record id (server-derived for a patient caller,
/// see appointments.controller.js's Part 21 changes) — never trust a
/// different value from anywhere else.
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
  });

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
      queueNumber: (json['queueNumber'] as num?)?.toInt(),
    );
  }

  final String id;
  final String clinicId;
  final String branchId;
  final String patientId;
  final String doctorId;
  final String serviceId;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final int? queueNumber;
}
