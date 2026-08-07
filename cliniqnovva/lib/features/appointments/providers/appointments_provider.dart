import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_queue.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/providers/connectivity_provider.dart';
import '../models/appointment_model.dart';

/// Params for [availableSlotsProvider] — a Dart record so identical
/// selections share a cached result (same convention as every other
/// multi-argument family in this app).
typedef SlotQueryParams = ({
  String doctorId,
  String branchId,
  String serviceId,
  String date,
});

final availableSlotsProvider = FutureProvider.autoDispose
    .family<List<AppointmentSlot>, SlotQueryParams>((ref, params) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/appointments/available-slots',
        queryParameters: {
          'doctorId': params.doctorId,
          'branchId': params.branchId,
          'serviceId': params.serviceId,
          'date': params.date,
        },
      );
      final data = response.data!['slots'] as List<dynamic>;
      return data
          .map((e) => AppointmentSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Params for [appointmentsListProvider] — Part 11 Task 3's Today/
/// Upcoming/History tabs, each just a different `tab` value.
typedef AppointmentListParams = ({
  String? branchId,
  String? doctorId,
  String? patientId,
  String tab,
});

final appointmentsListProvider = FutureProvider.autoDispose
    .family<List<AppointmentModel>, AppointmentListParams>((
      ref,
      params,
    ) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/appointments',
        queryParameters: {
          if (params.branchId != null) 'branchId': params.branchId,
          if (params.doctorId != null) 'doctorId': params.doctorId,
          if (params.patientId != null) 'patientId': params.patientId,
          'tab': params.tab,
        },
      );
      final data = response.data!['appointments'] as List<dynamic>;
      return data
          .map((e) => AppointmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

typedef QueueParams = ({String branchId, String date});

/// Part 11 Task 4 — "Now Serving #N" for reception.
final queueDisplayProvider = FutureProvider.autoDispose
    .family<QueueDisplay, QueueParams>((ref, params) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/appointments/queue',
        queryParameters: {'branchId': params.branchId, 'date': params.date},
      );
      return QueueDisplay.fromJson(
        response.data!['queue'] as Map<String, dynamic>,
      );
    });

/// Owns every appointment write action (Part 11) — screens call these
/// instead of hitting ApiService directly.
class AppointmentsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  void _invalidateAll() {
    ref.invalidate(availableSlotsProvider);
    ref.invalidate(appointmentsListProvider);
    ref.invalidate(queueDisplayProvider);
  }

  /// Part 11 Task 2 — the single shared booking endpoint. A 409 here means
  /// someone else took the slot between the client fetching it and this
  /// call (the server re-checks inside a transaction); surfaced as a plain
  /// [ApiException] so the caller can show "that slot was just taken".
  /// Either way — success or a conflict — [availableSlotsProvider] is
  /// invalidated so the slot grid always reflects reality on the next
  /// build, never a stale pre-booking snapshot (Task 2: "reject clearly and
  /// refresh available slots").
  Future<AppointmentModel> book({
    required String branchId,
    required String patientId,
    required String doctorId,
    required String serviceId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await ApiService.instance.post<Map<String, dynamic>>(
        '/api/v1/appointments/book',
        data: {
          'branchId': branchId,
          'patientId': patientId,
          'doctorId': doctorId,
          'serviceId': serviceId,
          'date': date,
          'startTime': startTime,
          'endTime': endTime,
        },
      );
      return AppointmentModel.fromJson(
        response.data!['appointment'] as Map<String, dynamic>,
      );
    } finally {
      _invalidateAll();
    }
  }

  /// Confirm/Cancel/Check-In/Mark-Complete — one call, the server's state
  /// machine enforces which transitions are legal (Part 11 Task 3: Mark
  /// Complete rejected unless already Checked-In).
  Future<AppointmentModel> setStatus(String appointmentId, String status) async {
    final response = await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/appointments/$appointmentId/status',
      data: {'status': status},
    );
    _invalidateAll();
    return AppointmentModel.fromJson(
      response.data!['appointment'] as Map<String, dynamic>,
    );
  }

  /// Offline-first (2026-07-30) — check-in is the one status transition
  /// worth queuing (see offline_queue.dart's doc for why just this one:
  /// confirm/cancel/complete carry more state-machine/billing risk and are
  /// less likely to be the actual in-the-moment offline action anyway).
  /// Deliberately a separate method from [setStatus] rather than a branch
  /// inside it — [setStatus] stays untouched for confirm/cancel/complete,
  /// so nothing about their behavior changes here. When offline, returns a
  /// locally-synthesized "checked in" copy of [appointment] (see
  /// `AppointmentModel.copyWith`) so the caller's UI can update optimistically
  /// even though nothing was actually sent yet.
  Future<AppointmentModel> checkInOrQueue(AppointmentModel appointment) async {
    if (ref.read(isOfflineProvider).valueOrNull ?? false) {
      await ref
          .read(offlineQueueProvider.notifier)
          .enqueue(OfflineMutationKind.checkInAppointment, {
            'appointmentId': appointment.id,
          });
      return appointment.copyWith(status: 'checkedIn');
    }
    return setStatus(appointment.id, 'checkedIn');
  }

  /// Re-validates current availability server-side; a 409 means the new
  /// slot was taken in the meantime — [availableSlotsProvider] is
  /// invalidated either way, same reasoning as [book].
  Future<AppointmentModel> reschedule(
    String appointmentId, {
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await ApiService.instance.put<Map<String, dynamic>>(
        '/api/v1/appointments/$appointmentId/reschedule',
        data: {'date': date, 'startTime': startTime, 'endTime': endTime},
      );
      return AppointmentModel.fromJson(
        response.data!['appointment'] as Map<String, dynamic>,
      );
    } finally {
      _invalidateAll();
    }
  }
}

final appointmentsNotifierProvider =
    AsyncNotifierProvider<AppointmentsNotifier, void>(
      AppointmentsNotifier.new,
    );
