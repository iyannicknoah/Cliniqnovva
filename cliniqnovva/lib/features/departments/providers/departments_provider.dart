import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../organizations/providers/branches_provider.dart';
import '../models/department_model.dart';

/// Departments for one branch (Part 7 Task 1: "List departments per
/// branch"). A branch-scoped user (Branch Admin etc.) is auto-scoped
/// server-side, so [branchId] is only strictly needed for an Organization
/// Admin picking among their branches — pass null to let the server infer
/// scope (branch-level actor) or return every branch's departments
/// (org-level actor with no branch selected).
final departmentsProvider = FutureProvider.autoDispose
    .family<List<DepartmentModel>, String?>((ref, branchId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/departments',
        queryParameters: branchId != null ? {'branchId': branchId} : null,
      );
      final data = response.data!['departments'] as List<dynamic>;
      return data
          .map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Owns every department write action (Part 7) — screens call these instead
/// of hitting ApiService directly.
class DepartmentsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({required String branchId, required String name}) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/departments',
      data: {'branchId': branchId, 'name': name},
    );
    ref.invalidate(departmentsProvider);
  }

  Future<void> rename(String id, String name) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/departments/$id',
      data: {'name': name},
    );
    ref.invalidate(departmentsProvider);
  }

  Future<void> setActive(String id, bool isActive) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/departments/$id',
      data: {'isActive': isActive},
    );
    ref.invalidate(departmentsProvider);
  }

  /// Hard delete — the server rejects this with a 400 if the department
  /// still has services attached (Part 7 Task 1: deactivate instead).
  Future<void> remove(String id) async {
    await ApiService.instance.delete<void>('/api/v1/departments/$id');
    ref.invalidate(departmentsProvider);
  }
}

final departmentsNotifierProvider =
    AsyncNotifierProvider<DepartmentsNotifier, void>(DepartmentsNotifier.new);

/// The branch the Departments/Services screens are currently showing, for
/// an Organization Admin choosing among several branches. Reuses
/// [selectedBranchProvider] from Part 6 (set when a branch row is tapped on
/// /branches) so navigating in from there arrives pre-filtered; screens
/// fall back to the org's first branch when nothing is selected yet.
final activeBranchIdProvider = Provider.autoDispose<String?>((ref) {
  final selected = ref.watch(selectedBranchProvider);
  if (selected != null) return selected.id;
  final branches = ref.watch(branchesProvider).valueOrNull?.branches;
  return branches?.isNotEmpty == true ? branches!.first.id : null;
});
