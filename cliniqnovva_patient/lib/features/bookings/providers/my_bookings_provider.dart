import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/linked_patient_ids_provider.dart';
import '../../../core/services/api_service.dart';
import '../../booking/models/appointment_model.dart';

/// Every appointment across every clinic this patient has ever booked with
/// — one GET /api/v1/patients/:patientId/appointments call per linked
/// record (Part 22 Task 4's endpoint is deliberately single-clinic, see its
/// own doc comment), merged client-side. My Bookings' Upcoming/Past split
/// happens in the screen, not here, so both tabs share one fetch.
final myBookingsProvider = FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
  final linkedIds = await ref.watch(linkedPatientIdsProvider.future);
  if (linkedIds.isEmpty) return [];

  final results = await Future.wait(
    linkedIds.map((id) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/patients/$id/appointments');
      return (response.data!['appointments'] as List)
          .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }),
  );
  return results.expand((list) => list).toList();
});

/// Kigali is UTC+2 fixed (no DST) — same convention as the backend's
/// kigaliDateString(), just computed client-side so Upcoming/Past bucketing
/// matches appointments.service.js#list()'s own 'upcoming'/'history' tab
/// logic exactly (a same-day, not-yet-completed/cancelled appointment
/// still counts as upcoming).
DateTime todayInKigali() {
  final kigaliNow = DateTime.now().toUtc().add(const Duration(hours: 2));
  return DateTime.utc(kigaliNow.year, kigaliNow.month, kigaliNow.day);
}

bool isUpcoming(AppointmentModel appointment, DateTime today) {
  final apptDate = DateTime.parse(appointment.date);
  if (apptDate.isAfter(today)) return true;
  if (apptDate.isAtSameMomentAs(today)) {
    return appointment.status != 'completed' && appointment.status != 'cancelled';
  }
  return false;
}

/// GET /api/v1/reviews?clinicId=&appointmentId= — "has this completed
/// appointment already been reviewed?" (Task 1: tap a completed booking →
/// prompt to review only if not already done).
final appointmentReviewExistsProvider =
    FutureProvider.autoDispose.family<bool, ({String clinicId, String appointmentId})>((ref, args) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/reviews',
    queryParameters: {'clinicId': args.clinicId, 'appointmentId': args.appointmentId},
  );
  return (response.data!['reviews'] as List).isNotEmpty;
});
