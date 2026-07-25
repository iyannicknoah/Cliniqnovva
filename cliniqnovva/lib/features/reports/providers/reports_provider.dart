import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/report_models.dart';

/// Shared filter shape for every report (Part 14 Task 2). Date range is
/// required — the server validates dateFrom <= dateTo (spec 6.10).
typedef ReportParams = ({
  String? branchId,
  String dateFrom,
  String dateTo,
  String groupBy,
});

final revenueReportProvider = FutureProvider.autoDispose
    .family<RevenueReport, ReportParams>((ref, params) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/reports/revenue',
        queryParameters: {
          if (params.branchId != null) 'branchId': params.branchId,
          'dateFrom': params.dateFrom,
          'dateTo': params.dateTo,
          'groupBy': params.groupBy,
        },
      );
      return RevenueReport.fromJson(
        response.data!['report'] as Map<String, dynamic>,
      );
    });

final patientVolumeReportProvider = FutureProvider.autoDispose
    .family<PatientVolumeReport, ReportParams>((ref, params) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/reports/patient-volume',
        queryParameters: {
          if (params.branchId != null) 'branchId': params.branchId,
          'dateFrom': params.dateFrom,
          'dateTo': params.dateTo,
          'groupBy': params.groupBy,
        },
      );
      return PatientVolumeReport.fromJson(
        response.data!['report'] as Map<String, dynamic>,
      );
    });

typedef DateRangeParams = ({String? branchId, String dateFrom, String dateTo});

final noShowReportProvider = FutureProvider.autoDispose
    .family<NoShowReport, DateRangeParams>((ref, params) async {
      final response = await ApiService.instance.get<Map<String, dynamic>>(
        '/api/v1/reports/no-show-rate',
        queryParameters: {
          if (params.branchId != null) 'branchId': params.branchId,
          'dateFrom': params.dateFrom,
          'dateTo': params.dateTo,
        },
      );
      return NoShowReport.fromJson(
        response.data!['report'] as Map<String, dynamic>,
      );
    });
