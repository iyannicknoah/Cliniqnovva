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
import '../../auth/providers/access_control_provider.dart';
import '../models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Pharmacist's own landing page (2026-07-26, explicit user instruction) —
/// same structure as [AccountantOverviewScreen] (KPI row, a trend line
/// chart, a recent-items table), stock-focused instead of billing-focused.
/// Pharmacist is always branch-scoped, never org-level (see `attachScope`),
/// so there's no branch selector here, only ever "this branch's" numbers.
/// This is now the home route for this role (see `homeRouteForRole`),
/// replacing the earlier plain redirect to `/inventory`.
class PharmacistOverviewScreen extends ConsumerWidget {
  const PharmacistOverviewScreen({super.key});

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

    final itemsAsync = ref.watch(inventoryListProvider(branchId));
    final adjustmentsAsync = ref.watch(
      inventoryAdjustmentsProvider((branchId: branchId, itemId: null)),
    );

    final items = itemsAsync.valueOrNull;
    final activeItems = items?.where((i) => i.isActive).toList();
    final totalItems = activeItems?.length;
    final lowStockItems = activeItems?.where((i) => i.needsReorder).toList();
    final expiredCount = activeItems?.where((i) => i.isExpired).length;

    // Daily units dispensed, last 30 days — quantityChange is negative for
    // a dispense, so this sums the absolute amount actually given out.
    final dispenseTrend = <String, int>{};
    final adjustments =
        adjustmentsAsync.valueOrNull ?? const <InventoryAdjustmentModel>[];
    for (final entry in adjustments) {
      if (entry.type != 'dispense' || entry.createdAt == null) continue;
      final date = _isoDate(entry.createdAt!);
      if (date.compareTo(trendFrom) < 0 || date.compareTo(today) > 0) {
        continue;
      }
      final int dispensed = entry.quantityChange.abs();
      dispenseTrend[date] = (dispenseTrend[date] ?? 0) + dispensed;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              color: context.appText,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Total Items',
                  value: totalItems != null ? '$totalItems' : '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  label: 'Low Stock',
                  value: lowStockItems != null
                      ? '${lowStockItems.length}'
                      : '—',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricCard(
                  label: 'Expired',
                  value: expiredCount != null ? '$expiredCount' : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            title: 'Dispensing trend',
            child: SizedBox(
              height: 240,
              child: adjustmentsAsync.when(
                loading: () => const LoadingWidget(),
                error: (e, _) => Center(
                  child: Text(
                    '$e',
                    style: TextStyle(color: context.appSubtext),
                  ),
                ),
                data: (_) => _DispenseTrendChart(trend: dispenseTrend),
              ),
            ),
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            title: 'Items needing reorder',
            child: itemsAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, _) =>
                  Text('$e', style: TextStyle(color: context.appSubtext)),
              data: (_) {
                final top = (lowStockItems ?? const <InventoryItemModel>[])
                    .take(5)
                    .toList();
                if (top.isEmpty) {
                  return Text(
                    'No items below their reorder level.',
                    style: TextStyle(color: context.appSubtext),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CliniqnovvaTableHeader(
                      columns: ['Item', 'Category', 'Stock', 'Status'],
                    ),
                    for (final item in top)
                      CliniqnovvaTableRow(
                        cells: [
                          Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            item.category ?? '—',
                            style: TextStyle(color: context.appText),
                          ),
                          Text(
                            '${item.quantity} ${item.unit}',
                            style: TextStyle(
                              color: AppColors.pillAmberText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const StatusBadge(
                                text: 'Low stock',
                                type: BadgeType.warning,
                              ),
                              if (item.isExpired) ...[
                                const SizedBox(width: 6),
                                const StatusBadge(
                                  text: 'Expired',
                                  type: BadgeType.error,
                                ),
                              ],
                            ],
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

/// Same visual style as the Accountant Overview / Super Admin revenue
/// charts (sky blue line + a more-transparent fill beneath it), adapted for
/// a daily units-dispensed `Map<String, int>` trend.
class _DispenseTrendChart extends StatelessWidget {
  const _DispenseTrendChart({required this.trend});

  final Map<String, int> trend;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Center(
        child: Text(
          'No dispensing activity yet.',
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
    final maxValue = entries
        .map((e) => e.value)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxValue == 0 ? 10.0 : maxValue * 1.2;
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
                '${entry.key}\n${entry.value} units',
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
