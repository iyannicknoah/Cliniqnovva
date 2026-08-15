import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../patients/providers/patients_provider.dart';
import '../../reports/providers/reports_provider.dart';
import '../../super_admin/widgets/payment_history_panel.dart' show formatRwf;
import '../providers/invoices_provider.dart';
import 'invoice_detail_screen.dart';

const _statusLabels = {
  AppConstants.invoiceUnpaid: 'Unpaid',
  AppConstants.invoicePartial: 'Partial',
  AppConstants.invoicePaid: 'Paid',
  AppConstants.invoiceVoided: 'Voided',
};

BadgeType _badgeTypeFor(String status) => switch (status) {
  AppConstants.invoicePaid => BadgeType.success,
  AppConstants.invoiceVoided => BadgeType.error,
  AppConstants.invoicePartial => BadgeType.info,
  _ => BadgeType.warning,
};

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return _isoDate(d);
}

/// Accountant's landing page (2026-07-26, explicit user instruction) —
/// structured like Super Admin's `/super-admin/overview` (KPI row, a
/// revenue growth line chart, a recent-items table), scoped to the
/// Accountant's own branch — Accountant is always branch-scoped, never
/// org-level (see `attachScope`), so there's no branch selector here, only
/// ever "this branch's" numbers. This is now the home route for this role
/// (see `homeRouteForRole`), replacing the earlier plain redirect to
/// `/billing`.
class AccountantOverviewScreen extends ConsumerWidget {
  const AccountantOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.appSubtext)),
        ),
        data: (data) {
          final branchId = data?['branchId'] as String?;
          if (branchId == null) {
            return Center(
              child: Text(
                'empty_no_branch'.tr(),
                style: TextStyle(color: context.appSubtext),
              ),
            );
          }
          return _OverviewBody(branchId: branchId);
        },
      ),
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _isoDate(DateTime.now());
    final trendFrom = _isoDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );

    final todayRevenueAsync = ref.watch(
      revenueReportProvider((
        branchId: branchId,
        dateFrom: today,
        dateTo: today,
        groupBy: 'day',
      )),
    );
    final trendAsync = ref.watch(
      revenueReportProvider((
        branchId: branchId,
        dateFrom: trendFrom,
        dateTo: today,
        groupBy: 'day',
      )),
    );
    final invoicesAsync = ref.watch(
      invoicesListProvider((
        branchId: branchId,
        status: null,
        dateFrom: null,
        dateTo: null,
      )),
    );

    final invoices = invoicesAsync.valueOrNull;
    final pendingCount = invoices
        ?.where(
          (inv) =>
              inv.status == AppConstants.invoiceUnpaid ||
              inv.status == AppConstants.invoicePartial,
        )
        .length;
    final paidCount = invoices
        ?.where((inv) => inv.status == AppConstants.invoicePaid)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overview',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const TopBarActions(),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Total Revenue Today (RWF)',
                  value: todayRevenueAsync.valueOrNull != null
                      ? formatRwf(
                          todayRevenueAsync.valueOrNull!.totalCollectedRwf,
                        )
                      : '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  label: 'Pending Invoices',
                  value: pendingCount != null ? '$pendingCount' : '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  label: 'Paid Invoices',
                  value: paidCount != null ? '$paidCount' : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            title: 'Revenue growth',
            child: SizedBox(
              height: 240,
              child: trendAsync.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Center(
                  child: Text(
                    '$e',
                    style: TextStyle(color: context.appSubtext),
                  ),
                ),
                data: (report) => _RevenueTrendChart(trend: report.trend),
              ),
            ),
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            title: 'Recent invoices',
            child: invoicesAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, _) =>
                  Text('$e', style: TextStyle(color: context.appSubtext)),
              data: (all) {
                final recent = [...all]
                  ..sort(
                    (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                      a.createdAt ?? DateTime(0),
                    ),
                  );
                final top = recent.take(5).toList();
                if (top.isEmpty) {
                  return Text(
                    'No invoices yet.',
                    style: TextStyle(color: context.appSubtext),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CliniqnovvaTableHeader(
                      columns: ['Patient', 'Date', 'Total (RWF)', 'Status'],
                    ),
                    for (final invoice in top)
                      CliniqnovvaTableRow(
                        onTap: () => showInvoiceDetailPanel(
                          context,
                          invoiceId: invoice.id,
                        ),
                        cells: [
                          _PatientCell(patientId: invoice.patientId),
                          Text(
                            _formatDate(invoice.createdAt),
                            style: TextStyle(color: context.appText),
                          ),
                          Text(
                            formatRwf(invoice.totalAmountRwf),
                            style: TextStyle(color: context.appText),
                          ),
                          StatusBadge(
                            text:
                                _statusLabels[invoice.status] ?? invoice.status,
                            type: _badgeTypeFor(invoice.status),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientCell extends ConsumerWidget {
  const _PatientCell({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    return patientAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('—', style: TextStyle(color: context.appSubtext)),
      data: (patient) => Text(
        patient.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Same visual style as Super Admin's revenue chart (`overview_screen.dart`
/// — sky blue line + a more-transparent fill beneath it) adapted for a
/// daily `Map<String, int>` trend instead of the platform's monthly
/// `RevenueTrendPoint` list.
class _RevenueTrendChart extends StatelessWidget {
  const _RevenueTrendChart({required this.trend});

  final Map<String, int> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Center(
        child: Text(
          'No revenue data yet.',
          style: TextStyle(color: context.appSubtext),
        ),
      );
    }

    final entries = trend.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots = [
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].value.toDouble()),
    ];
    final maxRevenue = entries
        .map((e) => e.value)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxRevenue == 0 ? 10.0 : maxRevenue * 1.2;
    final lineColor = AppColors.skyBlue;
    // Only label every Nth day so labels never crowd/overlap each other —
    // caps the x-axis at ~8 visible labels regardless of the range length.
    final labelInterval = (entries.length / 8).ceil().clamp(1, entries.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: chartMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: chartMaxY / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: context.appBorder, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                if (index % labelInterval != 0) {
                  return const SizedBox.shrink();
                }
                // Trend keys are ISO dates ('YYYY-MM-DD') — trim to 'MM-DD'
                // so labels stay short at any range length.
                final label = entries[index].key.length >= 10
                    ? entries[index].key.substring(5)
                    : entries[index].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label,
                    style: TextStyle(color: context.appSubtext, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => context.appCard,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final entry = entries[spot.x.toInt()];
              return LineTooltipItem(
                '${entry.key}\n${formatRwf(entry.value)} RWF',
                TextStyle(
                  color: context.appText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
