import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/platform_models.dart';

final platformMetricsProvider = FutureProvider.autoDispose<PlatformMetrics>((
  ref,
) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/platform/metrics',
  );
  return PlatformMetrics.fromJson(
    response.data!['metrics'] as Map<String, dynamic>,
  );
});

/// Real monthly revenue growth (sum of recorded cash payments per month,
/// across every organization) — backs the Overview page's chart.
final platformRevenueTrendProvider =
    FutureProvider.autoDispose<List<RevenueTrendPoint>>((ref) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/platform/revenue-trend',
      );
      final data = response.data!['revenueTrend'] as List<dynamic>;
      return data
          .map((e) => RevenueTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// Owns the Support View session writes (Part 5 Task 3) — both are
/// audit-log-only writes, never a write to another organization's actual
/// data.
class PlatformNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> startSupportView(String organizationId) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/platform/support-view/$organizationId',
    );
    return response.data!['sessionId'] as String;
  }

  Future<void> endSupportView(String organizationId, String sessionId) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/platform/support-view/$organizationId/end',
      data: {'sessionId': sessionId},
    );
  }
}

final platformNotifierProvider = AsyncNotifierProvider<PlatformNotifier, void>(
  PlatformNotifier.new,
);
