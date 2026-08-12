import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/services/api_service.dart';
import '../../auth/providers/access_control_provider.dart';
import '../models/branch_model.dart';

/// List response for the caller's clinic: the branches plus the plan's
/// branch limit (null = unlimited), so the UI can disable "+ Add Branch"
/// with the limit message without a second request (Part 6 Task 3).
class BranchesResult {
  const BranchesResult({required this.branches, this.branchLimit});

  final List<BranchModel> branches;
  final int? branchLimit;

  bool get limitReached =>
      branchLimit != null && branches.length >= branchLimit!;
}

/// All branches of the signed-in user's clinic (server-scoped — an
/// Clinic Admin never has to pass their own clinicId).
final branchesProvider = FutureProvider.autoDispose<BranchesResult>((
  ref,
) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/branches',
  );
  final data = response.data!;
  return BranchesResult(
    branches: (data['branches'] as List<dynamic>)
        .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    branchLimit: (data['branchLimit'] as num?)?.toInt(),
  );
});

/// One branch by id — the Branch Admin's own-branch view (Part 6 Task 3).
final branchDetailProvider = FutureProvider.autoDispose
    .family<BranchModel, String>((ref, branchId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/branches/detail/$branchId',
      );
      return BranchModel.fromJson(
        response.data!['branch'] as Map<String, dynamic>,
      );
    });

/// The branch the dashboard is currently filtered to (Part 6 Task 3:
/// "Click a branch → filter dashboard data to that branch"). Null before
/// the Clinic Admin has picked anything, which [activeBranchIdProvider]
/// defaults to the org's first branch — [showAllBranchesProvider] is the
/// explicit "All branches" choice, kept separate so the two "null" cases
/// (not chosen yet vs. deliberately viewing everything) aren't conflated.
final selectedBranchProvider = StateProvider<BranchModel?>((ref) => null);

/// True once a Clinic Admin explicitly picks "All branches" from
/// [BranchSelector], as opposed to [selectedBranchProvider] simply being
/// unset. Reset to false whenever a specific branch is chosen instead.
final showAllBranchesProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Owns every branch/department write action (Part 6) — screens call these
/// instead of hitting ApiService directly.
class BranchesNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Creates a branch for the caller's own clinic and returns it.
  /// Invalidates [hasBranchesProvider] so the router's onboarding gate sees
  /// the new branch immediately (it would otherwise keep bouncing a fresh
  /// Clinic Admin back to /onboarding off a stale `false`).
  Future<BranchModel> createBranch(Map<String, dynamic> body) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/branches',
      data: body,
    );
    ref.invalidate(branchesProvider);
    ref.invalidate(hasBranchesProvider);
    return BranchModel.fromJson(
      response.data!['branch'] as Map<String, dynamic>,
    );
  }

  Future<void> updateBranch(String branchId, Map<String, dynamic> fields) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/branches/$branchId',
      data: fields,
    );
    ref.invalidate(branchesProvider);
    ref.invalidate(branchDetailProvider(branchId));
  }

  Future<void> setBranchStatus(String branchId, bool isActive) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/branches/$branchId/status',
      data: {'isActive': isActive},
    );
    ref.invalidate(branchesProvider);
    ref.invalidate(branchDetailProvider(branchId));
  }

  /// Onboarding Step 4 ("public visibility") — uploads/replaces the
  /// branch's public profile image and returns the updated branch (with
  /// `publicImageKey` set). Mirrors patients_provider.dart's
  /// `uploadDocument()` multipart pattern.
  Future<BranchModel> uploadBranchPublicImage(
    String branchId, {
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
      '/api/v1/branches/$branchId/image',
      data: formData,
    );
    ref.invalidate(branchesProvider);
    ref.invalidate(branchDetailProvider(branchId));
    return BranchModel.fromJson(response.data!['branch'] as Map<String, dynamic>);
  }

  /// Part 6 Task 1 Step 2 — the onboarding wizard's department creation.
  Future<void> createDepartment({
    required String branchId,
    required String name,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/departments',
      data: {'branchId': branchId, 'name': name},
    );
  }
}

final branchesNotifierProvider = AsyncNotifierProvider<BranchesNotifier, void>(
  BranchesNotifier.new,
);
