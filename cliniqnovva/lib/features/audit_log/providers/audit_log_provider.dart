import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/audit_log_model.dart';

/// View-only (docs/technical-spec.md §6.12, restored 2026-07-29). clinicId
/// is resolved server-side for Clinic Admin from their own scope; a Super
/// Admin gets a platform-wide list across every clinic. No family param —
/// filtering is a v1-minimal client-side action-text search, matching the
/// original 5-field spec rather than adding a filter panel this restoration
/// doesn't need yet.
final auditLogListProvider = FutureProvider.autoDispose<List<AuditLogModel>>((
  ref,
) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/auditLogs',
  );
  final data = response.data!['logs'] as List<dynamic>;
  return data
      .map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
