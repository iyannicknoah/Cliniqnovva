import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/appointments/providers/appointments_provider.dart';
import '../../features/patients/models/medical_record_model.dart';
import '../../features/patients/models/patient_model.dart';
import '../../features/patients/providers/patients_provider.dart';
import '../../shared/providers/connectivity_provider.dart';
import '../services/api_service.dart';
import 'offline_queue.dart';

/// Listens for reconnect and replays the queue in order, oldest first —
/// FIFO matters because a vitals entry for a patient registered in the same
/// offline session must not replay before that patient's own registration
/// has landed. Each mutation replays through the SAME notifier method that
/// enqueued it — [PatientsNotifier.register]/[addMedicalRecord],
/// [AppointmentsNotifier.setStatus] — and by the time this runs,
/// `isOfflineProvider` reports false again, so those methods naturally
/// take their normal online path. There's no separate "replay" code path
/// to keep in sync with the real one.
///
/// Kept alive for the whole app session by [OfflineBanner] watching
/// [offlineSyncProvider] once at the app root — this class's `build()`
/// never runs (and its listener never gets registered) unless something
/// watches it, same as any other Riverpod provider.
class OfflineSyncNotifier extends AsyncNotifier<void> {
  bool _wasOffline = false;
  bool _syncing = false;

  @override
  Future<void> build() async {
    ref.listen<AsyncValue<bool>>(isOfflineProvider, (previous, next) {
      final isOffline = next.valueOrNull ?? false;
      if (_wasOffline && !isOffline) {
        _sync();
      }
      _wasOffline = isOffline;
    });
  }

  Future<void> _sync() async {
    // Re-entrancy guard — a flappy connection firing the offline->online
    // transition twice in quick succession must not run two overlapping
    // sweeps over the same queue.
    if (_syncing) return;
    _syncing = true;
    try {
      final queue = ref.read(offlineQueueProvider).valueOrNull ?? const [];
      // Never touch an already-tagged entry — that one needs a human, not
      // another automatic retry — and replay strictly oldest-first.
      final toReplay = queue.where((m) => m.lastError == null).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final mutation in toReplay) {
        try {
          await _replay(mutation);
          await ref.read(offlineQueueProvider.notifier).remove(mutation.id);
        } on ApiException catch (e) {
          if (e.statusCode != null) {
            // A real rejection from the server (validation error, the
            // appointment was already handled by someone else, etc.) —
            // tag it for manual resolution instead of retrying forever.
            await ref
                .read(offlineQueueProvider.notifier)
                .markFailed(mutation.id, e.message);
          }
          // statusCode null means a connection-error-shaped failure (still
          // offline after all) — leave it queued for the next reconnect.
        } catch (_) {
          // Unexpected — leave it queued rather than lose it silently.
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _replay(PendingMutation mutation) async {
    switch (mutation.kind) {
      case OfflineMutationKind.registerPatient:
        final p = mutation.payload;
        final result = await ref
            .read(patientsNotifierProvider.notifier)
            .register(
              branchId: p['branchId'] as String,
              name: p['name'] as String,
              phone: p['phone'] as String,
              dateOfBirth: p['dateOfBirth'] != null
                  ? DateTime.tryParse(p['dateOfBirth'] as String)
                  : null,
              gender: p['gender'] as String?,
              nationalId: p['nationalId'] as String?,
              emergencyContact: p['emergencyContact'] != null
                  ? EmergencyContact.fromMap(
                      Map<String, dynamic>.from(p['emergencyContact'] as Map),
                    )
                  : null,
              location: p['location'] != null
                  ? PatientLocation.fromMap(
                      Map<String, dynamic>.from(p['location'] as Map),
                    )
                  : null,
              // Always true on replay — a background sync has no UI to ask
              // "is this the same person?" the way the live registration
              // screen does. Any real duplicate this creates is exactly
              // what the existing checkDuplicate/mergePatients tooling
              // already exists to clean up (see offline_queue.dart's doc),
              // which is a far better outcome than silently dropping a
              // patient a receptionist actually registered.
              confirmedDuplicate: true,
            );
        if (result is! PatientCreated) {
          // Shouldn't happen with confirmedDuplicate: true (the server
          // skips its duplicate check entirely down that path) — defensive
          // only. Leaves the mutation queued rather than losing it.
          throw StateError(
            'Unexpected register() result during offline sync: $result',
          );
        }

      case OfflineMutationKind.recordVitals:
        final p = mutation.payload;
        await ref
            .read(patientsNotifierProvider.notifier)
            .addMedicalRecord(
              p['patientId'] as String,
              appointmentId: p['appointmentId'] as String?,
              diagnosis: p['diagnosis'] as String?,
              prescriptions: (p['prescriptions'] as List<dynamic>?)
                  ?.map(
                    (e) => Prescription.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList(),
              notes: p['notes'] as String?,
              vitals: (p['vitals'] as Map?)?.map(
                (k, v) => MapEntry(k as String, v as String),
              ),
            );

      case OfflineMutationKind.checkInAppointment:
        final p = mutation.payload;
        await ref
            .read(appointmentsNotifierProvider.notifier)
            .setStatus(p['appointmentId'] as String, 'checkedIn');
    }
  }
}

final offlineSyncProvider = AsyncNotifierProvider<OfflineSyncNotifier, void>(
  OfflineSyncNotifier.new,
);
