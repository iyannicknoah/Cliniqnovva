import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/service_model.dart';

/// Every service in one branch's catalog (Part 7 Task 2). Same null-means-
/// server-scope convention as [departmentsProvider].
final servicesProvider = FutureProvider.autoDispose
    .family<List<ServiceModel>, String?>((ref, branchId) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/services',
        queryParameters: branchId != null ? {'branchId': branchId} : null,
      );
      final data = response.data!['services'] as List<dynamic>;
      return data
          .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Owns every service write action (Part 7) — screens call these instead of
/// hitting ApiService directly.
class ServicesNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> create({
    required String branchId,
    required String departmentId,
    required String name,
    required int defaultDurationMins,
    required int defaultPriceRwf,
  }) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/services',
      data: {
        'branchId': branchId,
        'departmentId': departmentId,
        'name': name,
        'defaultDurationMins': defaultDurationMins,
        'defaultPriceRwf': defaultPriceRwf,
      },
    );
    ref.invalidate(servicesProvider);
  }

  Future<void> updateService(
    String id, {
    String? name,
    String? departmentId,
    int? defaultDurationMins,
    int? defaultPriceRwf,
  }) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/services/$id',
      data: {
        'name': ?name,
        'departmentId': ?departmentId,
        'defaultDurationMins': ?defaultDurationMins,
        'defaultPriceRwf': ?defaultPriceRwf,
      },
    );
    ref.invalidate(servicesProvider);
  }

  Future<void> setActive(String id, bool isActive) async {
    await ApiService.instance.put<Map<String, dynamic>>(
      '/api/v1/services/$id',
      data: {'isActive': isActive},
    );
    ref.invalidate(servicesProvider);
  }

  /// Hard delete — the server rejects this with a 400 if the service has
  /// appointment/invoice history (Part 7 Task 2: deactivate instead).
  Future<void> remove(String id) async {
    await ApiService.instance.delete<void>('/api/v1/services/$id');
    ref.invalidate(servicesProvider);
  }
}

final servicesNotifierProvider = AsyncNotifierProvider<ServicesNotifier, void>(
  ServicesNotifier.new,
);
