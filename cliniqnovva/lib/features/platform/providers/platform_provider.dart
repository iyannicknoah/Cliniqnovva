import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/platform_models.dart';

final platformMetricsProvider = FutureProvider.autoDispose<PlatformMetrics>((ref) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/platform/metrics');
  return PlatformMetrics.fromJson(response.data!['metrics'] as Map<String, dynamic>);
});

/// Real monthly revenue growth (sum of recorded cash payments per month,
/// across every organization) — backs the Overview page's chart.
final platformRevenueTrendProvider = FutureProvider.autoDispose<List<RevenueTrendPoint>>((ref) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/platform/revenue-trend');
  final data = response.data!['revenueTrend'] as List<dynamic>;
  return data.map((e) => RevenueTrendPoint.fromJson(e as Map<String, dynamic>)).toList();
});

final platformSearchProvider = FutureProvider.autoDispose.family<PlatformSearchResults, String>((ref, query) async {
  if (query.trim().isEmpty) return const PlatformSearchResults(branches: [], staff: []);
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/platform/search',
    queryParameters: {'query': query},
  );
  return PlatformSearchResults.fromJson(response.data!);
});

/// Immutable filter set for [platformAuditLogProvider] — needs value equality
/// since it's a `.family` provider key.
class AuditLogFilter {
  const AuditLogFilter({this.organizationId, this.actorId, this.action, this.dateFrom, this.dateTo});

  final String? organizationId;
  final String? actorId;
  final String? action;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  @override
  bool operator ==(Object other) =>
      other is AuditLogFilter &&
      other.organizationId == organizationId &&
      other.actorId == actorId &&
      other.action == action &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode => Object.hash(organizationId, actorId, action, dateFrom, dateTo);
}

final platformAuditLogProvider = FutureProvider.autoDispose.family<List<AuditLogEntry>, AuditLogFilter>((ref, filter) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/platform/audit-log',
    queryParameters: {
      if (filter.organizationId != null && filter.organizationId!.isNotEmpty) 'organizationId': filter.organizationId,
      if (filter.actorId != null && filter.actorId!.isNotEmpty) 'actorId': filter.actorId,
      if (filter.action != null && filter.action!.isNotEmpty) 'action': filter.action,
      if (filter.dateFrom != null) 'dateFrom': filter.dateFrom!.toIso8601String(),
      if (filter.dateTo != null) 'dateTo': filter.dateTo!.toIso8601String(),
    },
  );
  final data = response.data!['auditLog'] as List<dynamic>;
  return data.map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList();
});

/// Owns the two write actions this module has — both are audit-log-only
/// writes (Part 5 Task 3), never a write to another organization's actual
/// data. Cross-org record viewing also goes through here so it's easy to
/// find/audit in one place.
class PlatformNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Map<String, dynamic>?> viewRecord(String collection, String id) async {
    try {
      final response = await ApiService.instance.get<Map<String, dynamic>>('/api/v1/platform/record/$collection/$id');
      return response.data!['record'] as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> startSupportView(String organizationId) async {
    final response = await ApiService.instance.post<Map<String, dynamic>>('/api/v1/platform/support-view/$organizationId');
    return response.data!['sessionId'] as String;
  }

  Future<void> endSupportView(String organizationId, String sessionId) async {
    await ApiService.instance.post<Map<String, dynamic>>(
      '/api/v1/platform/support-view/$organizationId/end',
      data: {'sessionId': sessionId},
    );
  }
}

final platformNotifierProvider = AsyncNotifierProvider<PlatformNotifier, void>(PlatformNotifier.new);
