import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/appointment_model.dart';
import '../models/department_model.dart';
import '../models/service_model.dart';
import '../models/slot_model.dart';

/// GET /api/v1/departments — Booking's department picker (Task 1).
final departmentsProvider =
    FutureProvider.autoDispose.family<List<DepartmentModel>, ({String clinicId, String branchId})>((ref, args) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/departments',
    queryParameters: {'clinicId': args.clinicId, 'branchId': args.branchId},
  );
  return (response.data!['departments'] as List)
      .map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>))
      .where((d) => d.isActive)
      .toList();
});

/// GET /api/v1/services — fetched once per branch, filtered by department
/// client-side (same "fetch broad, filter in JS/Dart" convention the web
/// dashboard's own booking_screen.dart already uses, not a per-department
/// server query).
final servicesProvider =
    FutureProvider.autoDispose.family<List<ServiceModel>, ({String clinicId, String branchId})>((ref, args) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/services',
    queryParameters: {'clinicId': args.clinicId, 'branchId': args.branchId},
  );
  return (response.data!['services'] as List)
      .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
      .where((s) => s.isActive)
      .toList();
});

/// GET /api/v1/services/:id — resolves a single service's name for display
/// (Booking Detail screen, Task 2/3) without re-fetching the whole branch
/// catalog.
final serviceDetailProvider = FutureProvider.autoDispose.family<ServiceModel, String>((ref, id) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/services/$id');
  return ServiceModel.fromJson(response.data!['service'] as Map<String, dynamic>);
});

/// GET /api/v1/appointments/available-slots — the SAME endpoint the web
/// dashboard's Receptionist booking screen calls; no separate slot logic.
final availableSlotsProvider = FutureProvider.autoDispose
    .family<List<SlotModel>, ({String doctorId, String branchId, String serviceId, String date})>((ref, args) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/appointments/available-slots',
    queryParameters: {'doctorId': args.doctorId, 'branchId': args.branchId, 'serviceId': args.serviceId, 'date': args.date},
  );
  return (response.data!['slots'] as List).map((e) => SlotModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// POST /api/v1/appointments/book — the SAME endpoint + Firestore-
/// transaction double-booking protection the web dashboard's Receptionist
/// booking already uses; this notifier only shapes the request, never
/// reimplements any of that. No `patientId` is ever sent — the backend
/// resolves/creates the caller's own /patients record for this clinic
/// server-side (Part 21), so nothing client-side can book under someone
/// else's record.
class BookingNotifier extends AutoDisposeAsyncNotifier<AppointmentModel?> {
  @override
  AppointmentModel? build() => null;

  Future<AppointmentModel> submit({
    required String clinicId,
    required String branchId,
    required String doctorId,
    required String serviceId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiService.instance.post<Map<String, dynamic>>(
        '/api/v1/appointments/book',
        data: {
          'clinicId': clinicId,
          'branchId': branchId,
          'doctorId': doctorId,
          'serviceId': serviceId,
          'date': date,
          'startTime': startTime,
          'endTime': endTime,
        },
      );
      final appointment = AppointmentModel.fromJson(response.data!['appointment'] as Map<String, dynamic>);
      state = AsyncValue.data(appointment);
      return appointment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final bookingNotifierProvider = AsyncNotifierProvider.autoDispose<BookingNotifier, AppointmentModel?>(
  BookingNotifier.new,
);

/// GET /api/v1/appointments/:id — Booking Detail screen (Task 2/3).
final appointmentDetailProvider = FutureProvider.autoDispose.family<AppointmentModel, String>((ref, id) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/appointments/$id');
  return AppointmentModel.fromJson(response.data!['appointment'] as Map<String, dynamic>);
});

/// PUT /:id/reschedule and PUT /:id/status — the SAME endpoints staff use,
/// re-validating current availability / re-checking the state machine
/// server-side exactly as they already do (Task 2/3). Invalidates
/// [appointmentDetailProvider] after either write so the detail screen
/// reflects the fresh state, same "invalidate after write" convention the
/// web dashboard's ReviewsNotifier already uses.
class AppointmentActionsNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  void build() {}

  Future<AppointmentModel> reschedule(
    String id, {
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiService.instance.put<Map<String, dynamic>>(
        '/api/v1/appointments/$id/reschedule',
        data: {'date': date, 'startTime': startTime, 'endTime': endTime},
      );
      final appointment = AppointmentModel.fromJson(response.data!['appointment'] as Map<String, dynamic>);
      state = const AsyncValue.data(null);
      ref.invalidate(appointmentDetailProvider(id));
      return appointment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> cancel(String id) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.instance.put<Map<String, dynamic>>(
        '/api/v1/appointments/$id/status',
        data: {'status': 'cancelled'},
      );
      state = const AsyncValue.data(null);
      ref.invalidate(appointmentDetailProvider(id));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final appointmentActionsProvider = AsyncNotifierProvider.autoDispose<AppointmentActionsNotifier, void>(
  AppointmentActionsNotifier.new,
);
