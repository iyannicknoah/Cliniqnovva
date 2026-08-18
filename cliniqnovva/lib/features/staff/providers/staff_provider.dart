import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/services/api_service.dart';
import '../models/staff_model.dart';

/// Staff (doctor/nurse/receptionist/pharmacist/accountant) for one branch —
/// Part 8 Task 1. Null [branchId] lets the server infer scope (a
/// branch-scoped caller is auto-pinned; a Doctor always gets just
/// themself, regardless of branchId).
final staffListProvider = FutureProvider.autoDispose
    .family<List<StaffModel>, String?>((ref, branchId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/staff',
        queryParameters: branchId != null ? {'branchId': branchId} : null,
      );
      final data = response.data!['staff'] as List<dynamic>;
      return data
          .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// One staff member by id — includes schedule/blockedSlots for a doctor
/// (Part 8 Task 2's schedule builder reads this).
final staffDetailProvider = FutureProvider.autoDispose
    .family<StaffModel, String>((ref, staffId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/staff/$staffId',
      );
      return StaffModel.fromJson(
        response.data!['staff'] as Map<String, dynamic>,
      );
    });

/// Result of blocking a date/time — the block is always saved; conflicting
/// appointments are surfaced for staff to review, never silently dropped
/// (Part 8 Task 2).
class BlockSlotResult {
  const BlockSlotResult({
    required this.blockedSlot,
    required this.conflictingAppointments,
  });

  final BlockedSlot blockedSlot;
  final List<ConflictingAppointment> conflictingAppointments;
}

/// Owns every staff write action (Part 8) — screens call these instead of
/// hitting ApiService directly.
class StaffNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates the account directly and active immediately via
  /// POST /api/staff (internally the same account-creation path as
  /// POST /api/auth/create-user — no invite, ever). The caller already
  /// knows the password it just typed/generated; this only returns the
  /// created record.
  Future<StaffModel> create({
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String branchId,
    String? phone,
    String? specialty,
    List<String>? departmentIds,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/staff',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
        'role': role,
        'branchId': branchId,
        'phone': phone,
        'specialty': specialty,
        'departmentIds': departmentIds,
      },
    );
    ref.invalidate(staffListProvider);
    return StaffModel.fromJson(response.data!['staff'] as Map<String, dynamic>);
  }

  Future<void> updateStaff(
    String staffId, {
    String? name,
    String? phone,
    String? email,
    String? specialty,
    List<String>? departmentIds,
  }) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/staff/$staffId',
      data: {
        'name': ?name,
        'phone': ?phone,
        'email': ?email,
        'specialty': ?specialty,
        'departmentIds': ?departmentIds,
      },
    );
    ref.invalidate(staffListProvider);
    ref.invalidate(staffDetailProvider(staffId));
  }

  Future<void> setStatus(String staffId, bool isActive) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/staff/$staffId/status',
      data: {'isActive': isActive},
    );
    ref.invalidate(staffListProvider);
    ref.invalidate(staffDetailProvider(staffId));
  }

  /// Uploads/replaces a doctor's profile photo ("Go Public" wizard's
  /// Doctors step, 2026-08-17) — same shape as
  /// `branches_provider.dart`'s `uploadBranchPublicImage`.
  Future<StaffModel> uploadDoctorPhoto(
    String doctorId, {
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
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/staff/$doctorId/photo',
      data: formData,
    );
    ref.invalidate(staffListProvider);
    ref.invalidate(staffDetailProvider(doctorId));
    return StaffModel.fromJson(response.data!['staff'] as Map<String, dynamic>);
  }

  /// Saves a doctor's full weekly recurring schedule (Part 8 Task 2) — the
  /// server rejects (400) any overlapping slots on the same day.
  ///
  /// [breakMinutes] (2026-07-26) — the buffer required between one
  /// appointment and the next for this doctor; saved alongside the schedule
  /// since both live on the same "Weekly schedule" card.
  Future<void> setSchedule(
    String doctorId,
    List<DoctorScheduleEntry> entries,
    int breakMinutes,
  ) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/staff/$doctorId/schedule',
      data: {
        'schedule': entries.map((e) => e.toJson()).toList(),
        'breakMinutes': breakMinutes,
      },
    );
    ref.invalidate(staffDetailProvider(doctorId));
  }

  /// Blocks a date/time range for a doctor. Always succeeds (saves the
  /// block); the response lists any existing appointments that now fall
  /// inside it, for the caller to show as a warning.
  Future<BlockSlotResult> addBlockedSlot(
    String doctorId, {
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/staff/$doctorId/blocked-slots',
      data: {
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'reason': reason,
      },
    );
    ref.invalidate(staffDetailProvider(doctorId));
    final data = response.data!;
    return BlockSlotResult(
      blockedSlot: BlockedSlot.fromJson(
        data['blockedSlot'] as Map<String, dynamic>,
      ),
      conflictingAppointments:
          (data['conflictingAppointments'] as List<dynamic>)
              .map(
                (e) =>
                    ConflictingAppointment.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

final staffNotifierProvider = AsyncNotifierProvider<StaffNotifier, void>(
  StaffNotifier.new,
);
