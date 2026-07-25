import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// "Click a branch → filter dashboard data to that branch"). Null = all
/// branches combined. The dashboard screen consumes this when it's built.
final selectedBranchProvider = StateProvider<BranchModel?>((ref) => null);

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
