import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/services/api_service.dart';
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
      // (GET /api/patients/:organizationId); the server ignores it for
      // every scoped caller (branch/org-level) and derives organizationId
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

  Future<List<DuplicateMatch>> checkDuplicate({
    String? phone,
    String? nationalId,
  }) async {
    final response = await ApiService.instance.get<Map<String, dynamic>>(
      '/api/v1/patients/check-duplicate',
      queryParameters: {
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

  Future<PatientModel> register({
    required String branchId,
    required String name,
    required String phone,
    DateTime? dateOfBirth,
    String? gender,
    String? nationalId,
    EmergencyContact? emergencyContact,
    PatientLocation? location,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
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
      },
    );
    return PatientModel.fromJson(
      response.data!['patient'] as Map<String, dynamic>,
    );
  }

  Future<void> updateProfile(String patientId, Map<String, dynamic> fields) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/patients/$patientId',
      data: fields,
    );
    ref.invalidate(patientDetailProvider(patientId));
    ref.invalidate(patientsSearchProvider);
  }

  Future<void> addMedicalRecord(
    String patientId, {
    String? appointmentId,
    String? diagnosis,
    List<Prescription>? prescriptions,
    String? notes,
    Map<String, String>? vitals,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/patients/$patientId/medical-records',
      data: {
        'appointmentId': appointmentId,
        'diagnosis': diagnosis,
        'prescriptions': prescriptions?.map((p) => p.toJson()).toList(),
        'notes': notes,
        'vitals': vitals,
      },
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
}

final patientsNotifierProvider = AsyncNotifierProvider<PatientsNotifier, void>(
  PatientsNotifier.new,
);
