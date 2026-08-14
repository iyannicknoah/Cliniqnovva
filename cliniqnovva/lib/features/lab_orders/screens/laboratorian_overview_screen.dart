import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../models/lab_order_model.dart';
import '../providers/lab_orders_provider.dart';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Laboratorian's own landing page (2026-07-29) — same structure as
/// [PharmacistOverviewScreen]/[AccountantOverviewScreen] (KPI row, a trend
/// line chart, a recent-items table). Laboratorian is always branch-scoped,
/// never org-level, so there's no branch selector here, only ever "this
/// branch's" numbers. This is the home route for this role (see
/// `homeRouteForRole`).
class LaboratorianOverviewScreen extends ConsumerWidget {
  const LaboratorianOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          final branchId = data?['branchId'] as String?;
          if (branchId == null) {
            return Center(
              child: Text('empty_no_branch'.tr(), style: TextStyle(color: context.appSubtext)),
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
    final trendFrom = _isoDate(DateTime.now().subtract(const Duration(days: 30)));

    final query = (branchId: branchId, status: null, patientId: null);
    final ordersAsync = ref.watch(labOrdersListProvider(query));
    final orders = ordersAsync.valueOrNull;

    final pendingCollection = orders?.where((o) => o.status == 'ordered').length;
    final awaitingResult = orders?.where((o) => o.status == 'collected').length;
    final resultedToday = orders
        ?.where((o) => o.resultedAt != null && _isoDate(o.resultedAt!) == today)
        .length;

    final resultTrend = <String, int>{};
    for (final o in orders ?? const <LabOrderModel>[]) {
      if (o.resultedAt == null) continue;
      final date = _isoDate(o.resultedAt!);
      if (date.compareTo(trendFrom) < 0 || date.compareTo(today) > 0) continue;
      resultTrend[date] = (resultTrend[date] ?? 0) + 1;
    }

    final pending = (orders ?? const <LabOrderModel>[])
        .where((o) => o.status == 'ordered' || o.status == 'collected')
        .toList()
      ..sort((a, b) => (a.orderedAt ?? DateTime(0)).compareTo(b.orderedAt ?? DateTime(0)));

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
                  style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w800),
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
                  label: 'Pending Collection',
                  value: pendingCollection != null ? '$pendingCollection' : '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  label: 'Awaiting Result',
                  value: awaitingResult != null ? '$awaitingResult' : '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  label: 'Resulted Today',
                  value: resultedToday != null ? '$resultedToday' : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            title: 'Tests resulted, last 30 days',
            child: SizedBox(
              height: 240,
              child: ordersAsync.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
                data: (_) => _ResultTrendChart(trend: resultTrend),
              ),
            ),
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            title: 'Needs action',
            child: ordersAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
              data: (_) {
                final top = pending.take(5).toList();
                if (top.isEmpty) {
                  return Text('Nothing pending.', style: TextStyle(color: context.appSubtext));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CliniqnovvaTableHeader(columns: ['Test', 'Status']),
                    for (final o in top)
                      CliniqnovvaTableRow(
                        cells: [
                          Text(
                            o.testName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
                          ),
                          StatusBadge(
                            text: o.status == 'ordered' ? 'Awaiting collection' : 'Awaiting result',
                            type: BadgeType.warning,
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

/// Same visual style as the Pharmacist Overview dispensing-trend chart —
/// sky blue line + a more-transparent fill beneath it, adapted for a daily
/// tests-resulted `Map<String, int>` trend.
class _ResultTrendChart extends StatelessWidget {
  const _ResultTrendChart({required this.trend});

  final Map<String, int> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Center(
        child: Text('No results recorded yet.', style: TextStyle(color: context.appSubtext)),
      );
    }

    final entries = trend.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final spots = [
      for (var i = 0; i < entries.length; i++) FlSpot(i.toDouble(), entries[i].value.toDouble()),
    ];
    final maxValue = entries.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxValue == 0 ? 10.0 : maxValue * 1.2;
    final lineColor = AppColors.skyBlue;
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
          getDrawingHorizontalLine: (value) => FlLine(color: context.appBorder, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                if (index % labelInterval != 0) return const SizedBox.shrink();
                final label = entries[index].key.length >= 10
                    ? entries[index].key.substring(5)
                    : entries[index].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: TextStyle(color: context.appSubtext, fontSize: 11)),
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
                '${entry.key}\n${entry.value} resulted',
                TextStyle(color: context.appText, fontWeight: FontWeight.w600, fontSize: 12),
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
            belowBarData: BarAreaData(show: true, color: lineColor.withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}
