/// Shared shape mirrors reports.service.js's revenue()/patientVolume()/
/// noShowRate() (spec section 6.10, Part 14) — all three are read-only,
/// computed from finalized data server-side; nothing here is editable.
Map<String, int> _intMap(dynamic json) => (json as Map<String, dynamic>? ?? {})
    .map((k, v) => MapEntry(k, (v as num).toInt()));

class RevenueReport {
  const RevenueReport({
    required this.dateFrom,
    required this.dateTo,
    required this.groupBy,
    required this.invoiceCount,
    required this.totalBilledRwf,
    required this.totalCollectedRwf,
    required this.trend,
    required this.byBranch,
    required this.byDoctor,
    required this.byService,
  });

  final String dateFrom;
  final String dateTo;
  final String groupBy;
  final int invoiceCount;
  final int totalBilledRwf;
  final int totalCollectedRwf;
  final Map<String, int> trend;
  final Map<String, int> byBranch;
  final Map<String, int> byDoctor;
  final Map<String, int> byService;

  factory RevenueReport.fromJson(Map<String, dynamic> json) => RevenueReport(
    dateFrom: json['dateFrom'] as String? ?? '',
    dateTo: json['dateTo'] as String? ?? '',
    groupBy: json['groupBy'] as String? ?? 'day',
    invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
    totalBilledRwf: (json['totalBilledRwf'] as num?)?.toInt() ?? 0,
    totalCollectedRwf: (json['totalCollectedRwf'] as num?)?.toInt() ?? 0,
    trend: _intMap(json['trend']),
    byBranch: _intMap(json['byBranch']),
    byDoctor: _intMap(json['byDoctor']),
    byService: _intMap(json['byService']),
  );
}

class PatientVolumeReport {
  const PatientVolumeReport({
    required this.dateFrom,
    required this.dateTo,
    required this.groupBy,
    required this.totalVisits,
    required this.uniquePatients,
    required this.trend,
    required this.byBranch,
    required this.byDoctor,
  });

  final String dateFrom;
  final String dateTo;
  final String groupBy;
  final int totalVisits;
  final int uniquePatients;
  final Map<String, int> trend;
  final Map<String, int> byBranch;
  final Map<String, int> byDoctor;

  factory PatientVolumeReport.fromJson(Map<String, dynamic> json) =>
      PatientVolumeReport(
        dateFrom: json['dateFrom'] as String? ?? '',
        dateTo: json['dateTo'] as String? ?? '',
        groupBy: json['groupBy'] as String? ?? 'day',
        totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
        uniquePatients: (json['uniquePatients'] as num?)?.toInt() ?? 0,
        trend: _intMap(json['trend']),
        byBranch: _intMap(json['byBranch']),
        byDoctor: _intMap(json['byDoctor']),
      );
}

class NoShowBranchStat {
  const NoShowBranchStat({
    required this.completedCount,
    required this.noShowCount,
    required this.noShowRate,
  });

  final int completedCount;
  final int noShowCount;
  final double noShowRate;

  factory NoShowBranchStat.fromJson(Map<String, dynamic> json) =>
      NoShowBranchStat(
        completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
        noShowCount: (json['noShowCount'] as num?)?.toInt() ?? 0,
        noShowRate: (json['noShowRate'] as num?)?.toDouble() ?? 0,
      );
}

class NoShowReport {
  const NoShowReport({
    required this.dateFrom,
    required this.dateTo,
    required this.completedCount,
    required this.noShowCount,
    required this.noShowRate,
    required this.byBranch,
  });

  final String dateFrom;
  final String dateTo;
  final int completedCount;
  final int noShowCount;
  final double noShowRate;
  final Map<String, NoShowBranchStat> byBranch;

  factory NoShowReport.fromJson(Map<String, dynamic> json) => NoShowReport(
    dateFrom: json['dateFrom'] as String? ?? '',
    dateTo: json['dateTo'] as String? ?? '',
    completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
    noShowCount: (json['noShowCount'] as num?)?.toInt() ?? 0,
    noShowRate: (json['noShowRate'] as num?)?.toDouble() ?? 0,
    byBranch: (json['byBranch'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, NoShowBranchStat.fromJson(v as Map<String, dynamic>)),
    ),
  );
}
