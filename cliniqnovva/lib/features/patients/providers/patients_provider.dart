import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/offline/offline_queue.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/providers/connectivity_provider.dart';
import '../models/medical_record_model.dart';
import '../models/patient_document_model.dart';
import '../models/patient_model.dart';

/// Search params for [patientsSearchProvider] — a Dart record so the
/// family key is structurally equal across rebuilds with the same values
/// (Riverpod caches/dedupes on that), same convention as any other
/// multi-argument family in this app.
typedef PatientSearchParams = ({String? branchId, String query});

/// Search by name/phone/National ID, one box (Part 9 Task 1). [branchId]
/// null lets the server infer scope for a branch-scoped caller.
final patientsSearchProvider = FutureProvider.autoDispose
    .family<List<PatientModel>, PatientSearchParams>((ref, params) async {
      // The path segment is the Part 9 Task 4 route shape
      // (GET /api/patients/:clinicId); the server ignores it for
      // every scoped caller (branch/org-level) and derives clinicId
      // from their own token instead — real filtering is query params.
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/patients/search',
        queryParameters: {
          if (params.branchId != null) 'branchId': params.branchId,
          if (params.query.isNotEmpty) 'q': params.query,
        },
      );
      final data = response.data!['patients'] as List<dynamic>;
      return data
          .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// One patient by id — role-gated server-side (Part 9 Task 3): a
/// receptionist's response simply has no `medicalRecords`/`documents` keys,
/// so [PatientModel.medicalRecords]/[documents] come back null for them.
final patientDetailProvider = FutureProvider.autoDispose
    .family<PatientModel, String>((ref, patientId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/patients/detail/$patientId',
      );
      return PatientModel.fromJson(
        response.data!['patient'] as Map<String, dynamic>,
      );
    });

/// Owns every patient write action (Part 9) — screens call these instead of
/// hitting ApiService directly.
class PatientsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Part 10 Task 3 — POST (a reusable pre-flight; POST /api/patients also
  /// runs this same check itself before creating, see [register]).
  Future<List<DuplicateMatch>> checkDuplicate({
    String? phone,
    String? nationalId,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/patients/check-duplicate',
      data: {
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (nationalId != null && nationalId.isNotEmpty)
          'nationalId': nationalId,
      },
    );
    final data = response.data!['matches'] as List<dynamic>;
    return data
        .map((e) => DuplicateMatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Part 10 Task 1 — the server itself checks for a duplicate before
  /// creating and responds 409 `{possibleDuplicate: true, matches}` instead
  /// of a created patient. This calls the Dio client directly (bypassing
  /// ApiService's generic error-to-string wrapping, same reason
  /// [uploadDocument] does) so that 409 response body survives intact for
  /// the caller to branch on. Pass [confirmedDuplicate] true to skip the
  /// server's check (the user already saw the prompt and chose to proceed).
  Future<PatientCreateResult> register({
    required String branchId,
    required String name,
    required String phone,
    DateTime? dateOfBirth,
    String? gender,
    String? nationalId,
    EmergencyContact? emergencyContact,
    PatientLocation? location,
    bool confirmedDuplicate = false,
  }) async {
    // Offline-first (2026-07-30) — patient registration is a pure create,
    // so there's no conflict to check for here; the duplicate-check itself
    // needs the network too, so it's skipped rather than blocking the
    // whole registration on a call that would just fail. Any real
    // duplicate this creates is caught the normal way once synced, via the
    // existing checkDuplicate/mergePatients tooling.
    if (ref.read(isOfflineProvider).valueOrNull ?? false) {
      await ref
          .read(offlineQueueProvider.notifier)
          .enqueue(OfflineMutationKind.registerPatient, {
            'branchId': branchId,
            'name': name,
            'phone': phone,
            'dateOfBirth': dateOfBirth?.toIso8601String(),
            'gender': gender,
            'nationalId': nationalId,
            'emergencyContact': emergencyContact?.toMap(),
            'location': location?.toMap(),
          });
      return const PatientQueuedOffline();
    }

    try {
      final response = await ApiService.instance.client.post<Map<String, dynamic>>(
        '/api/v1/patients',
        data: {
          'branchId': branchId,
          'name': name,
          'phone': phone,
          'dateOfBirth': dateOfBirth?.toIso8601String(),
          'gender': gender,
          'nationalId': nationalId,
          'emergencyContact': emergencyContact?.toMap(),
          'location': location?.toMap(),
          'confirmedDuplicate': confirmedDuplicate,
        },
      );
      ref.invalidate(patientsSearchProvider);
      return PatientCreated(
        PatientModel.fromJson(response.data!['patient'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 409 &&
          data is Map<String, dynamic> &&
          data['possibleDuplicate'] == true) {
        final matches = (data['matches'] as List<dynamic>)
            .map((m) => DuplicateMatch.fromJson(m as Map<String, dynamic>))
            .toList();
        return PatientPossibleDuplicate(matches);
      }
      final message = data is Map<String, dynamic> ? data['error'] as String? : null;
      throw ApiException(
        message ?? 'Something went wrong. Please try again.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<void> updateProfile(String patientId, Map<String, dynamic> fields) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/patients/$patientId',
      data: fields,
    );
    ref.invalidate(patientDetailProvider(patientId));
    ref.invalidate(patientsSearchProvider);
  }

  /// Offline-first (2026-07-30) — vitals/visit recording is a pure append
  /// (a new medical-record entry, never an edit of an existing one), so
  /// there's nothing to conflict with once synced. Callers that want to
  /// show a different message for the queued-offline case should check
  /// `isOfflineProvider` themselves before calling, same pattern
  /// `_AddRecordFormState._save()` in patient_profile_screen.dart uses —
  /// this method's return type stays `void` either way since the caller
  /// already knows going in whether it's about to queue or send.
  Future<void> addMedicalRecord(
    String patientId, {
    String? appointmentId,
    String? diagnosis,
    List<Prescription>? prescriptions,
    String? notes,
    Map<String, String>? vitals,
  }) async {
    final data = {
      'appointmentId': appointmentId,
      'diagnosis': diagnosis,
      'prescriptions': prescriptions?.map((p) => p.toJson()).toList(),
      'notes': notes,
      'vitals': vitals,
    };

    if (ref.read(isOfflineProvider).valueOrNull ?? false) {
      await ref
          .read(offlineQueueProvider.notifier)
          .enqueue(OfflineMutationKind.recordVitals, {
            'patientId': patientId,
            ...data,
          });
      return;
    }

    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/patients/$patientId/medical-records',
      data: data,
    );
    ref.invalidate(patientDetailProvider(patientId));
  }

  Future<PatientDocumentModel> uploadDocument(
    String patientId, {
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final parts = contentType.split('/');
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: parts.length == 2
            ? MediaType(parts[0], parts[1])
            : MediaType('application', 'octet-stream'),
      ),
    });
    final response = await ApiService.instance.client.post<Map<String, dynamic>>(
      '/api/v1/patients/$patientId/documents',
      data: formData,
    );
    ref.invalidate(patientDetailProvider(patientId));
    return PatientDocumentModel.fromJson(
      response.data!['document'] as Map<String, dynamic>,
    );
  }

  /// A fresh 15-minute signed URL for one document — never cached, since it
  /// expires (Part 9 Task 4: "role-gated" — the server refuses this for a
  /// receptionist even with a valid key).
  Future<String> getDocumentSignedUrl(String patientId, String key) async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/api/v1/patients/$patientId/documents/${Uri.encodeComponent(key)}/signed-url',
    );
    return response.data!['url'] as String;
  }

  /// Part 10 Task 2 — merges [mergedPatientId] into [survivingPatientId]:
  /// every appointment/medicalRecord/invoice is reassigned server-side,
  /// nothing lost, logged to /patientMergeLogs. Branch Admin/Clinic
  /// Admin only (enforced server-side too).
  Future<PatientModel> mergePatients({
    required String survivingPatientId,
    required String mergedPatientId,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/patients/merge',
      data: {
        'survivingPatientId': survivingPatientId,
        'mergedPatientId': mergedPatientId,
      },
    );
    ref.invalidate(patientsSearchProvider);
    ref.invalidate(patientDetailProvider(survivingPatientId));
    ref.invalidate(patientDetailProvider(mergedPatientId));
    return PatientModel.fromJson(
      response.data!['survivingPatient'] as Map<String, dynamic>,
    );
  }
}

final patientsNotifierProvider = AsyncNotifierProvider<PatientsNotifier, void>(
  PatientsNotifier.new,
);
