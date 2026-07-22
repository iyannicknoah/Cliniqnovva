import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/organization.dart';

final organizationsListProvider = FutureProvider.autoDispose<List<Organization>>((ref) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/organizations');
  final data = response.data!['organizations'] as List<dynamic>;
  return data.map((e) => Organization.fromJson(e as Map<String, dynamic>)).toList();
});

final organizationDetailProvider = FutureProvider.autoDispose.family<Organization, String>((ref, id) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/organizations/$id');
  return Organization.fromJson(response.data!['organization'] as Map<String, dynamic>);
});

/// Owns every write action on organizations/branches-on-behalf-of-org (Part 3
/// Tasks 2-3) — screens call these instead of hitting ApiService directly.
class OrganizationsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String name,
    required String subscriptionPlan,
    required String adminEmail,
    String? ownerContactName,
    String? ownerContactPhone,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/organizations',
      data: {
        'name': name,
        'subscriptionPlan': subscriptionPlan,
        'adminEmail': adminEmail,
        'ownerContactName': ownerContactName,
        'ownerContactPhone': ownerContactPhone,
      },
    );
    ref.invalidate(organizationsListProvider);
  }

  Future<void> updateOrganization(String id, Map<String, dynamic> fields) async {
    await ApiService.instance.put<Map<String, dynamic>>('/api/v1/organizations/$id', data: fields);
    ref.invalidate(organizationsListProvider);
    ref.invalidate(organizationDetailProvider(id));
  }

  Future<void> setStatus(String id, bool isActive) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/organizations/$id/status',
      data: {'isActive': isActive},
    );
    ref.invalidate(organizationsListProvider);
    ref.invalidate(organizationDetailProvider(id));
  }

  /// Super Admin support-exception path (Part 3 Task 3) — backend logs this
  /// as `branch.createdOnBehalfOfOrganization`, distinct from a normal
  /// Organization Admin branch creation (Part 6).
  Future<void> createBranchOnBehalf(String organizationId, {required String name, String? address, String? phone}) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/branches',
      data: {'organizationId': organizationId, 'name': name, 'address': address, 'phone': phone},
    );
    ref.invalidate(organizationDetailProvider(organizationId));
  }
}

final organizationsNotifierProvider = AsyncNotifierProvider<OrganizationsNotifier, void>(OrganizationsNotifier.new);
