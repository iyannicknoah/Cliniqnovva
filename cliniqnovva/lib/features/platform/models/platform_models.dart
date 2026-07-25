/// Part 5 Task 2 — platform-wide metrics, for Cliniqnovva's own business
/// visibility only, never shown to any clinic.
class PlatformMetrics {
  const PlatformMetrics({
    required this.totalClinics,
    required this.totalBranches,
    required this.totalActiveStaff,
    required this.totalPatients,
    required this.totalAppointmentsThisMonth,
  });

  final int totalClinics;
  final int totalBranches;
  final int totalActiveStaff;
  final int totalPatients;
  final int totalAppointmentsThisMonth;

  factory PlatformMetrics.fromJson(Map<String, dynamic> json) {
    return PlatformMetrics(
      totalClinics: json['totalClinics'] as int? ?? 0,
      totalBranches: json['totalBranches'] as int? ?? 0,
      totalActiveStaff: json['totalActiveStaff'] as int? ?? 0,
      totalPatients: json['totalPatients'] as int? ?? 0,
      totalAppointmentsThisMonth:
          json['totalAppointmentsThisMonth'] as int? ?? 0,
    );
  }
}

/// One month's worth of real recorded revenue (sum of every clinic's
/// cash payments that month) — backs the Overview page's revenue chart.
/// `month` is `"YYYY-MM"`.
class RevenueTrendPoint {
  const RevenueTrendPoint({required this.month, required this.revenueRwf});

  final String month;
  final int revenueRwf;

  factory RevenueTrendPoint.fromJson(Map<String, dynamic> json) =>
      RevenueTrendPoint(
        month: json['month'] as String? ?? '',
        revenueRwf: json['revenueRwf'] as int? ?? 0,
      );

  /// Short label for a chart axis, e.g. "2026-07" -> "Jul".
  String get monthLabel {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final index = int.tryParse(parts[1]);
    if (index == null || index < 1 || index > 12) return month;
    return names[index - 1];
  }
}
