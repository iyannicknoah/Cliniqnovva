import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../organizations/providers/organizations_provider.dart';
import '../../platform/models/platform_models.dart';
import '../../platform/providers/platform_provider.dart';
import '../widgets/payment_history_panel.dart';
import '../widgets/super_admin_scaffold.dart';

/// The Super Admin landing page — structured like a typical admin dashboard
/// overview (KPI row, a growth chart, two recent-activity lists), adapted to
/// Cliniqnovva's own real data rather than copying any reference content.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${_formatDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(platformMetricsProvider);
    final organizationsAsync = ref.watch(organizationsListProvider);
    final revenueTrendAsync = ref.watch(platformRevenueTrendProvider);
    final activityAsync = ref.watch(
      platformAuditLogProvider(const AuditLogFilter()),
    );

    return SuperAdminScaffold(
      currentRoute: '/super-admin/overview',
      title: 'Overview',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          organizationsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Text('Failed to load clinics: $err'),
            data: (organizations) {
              final totalOrgs = organizations.length;
              final activeOrgs = organizations.where((o) => o.isActive).length;
              final totalMonthlyRevenue = organizations
                  .where((o) => o.isActive)
                  .fold<double>(0, (sum, o) => sum + o.monthlyEquivalentRwf);

              return metricsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, _) => Text('Failed to load metrics: $err'),
                data: (metrics) => Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        value: '$totalOrgs',
                        label: 'Total clinics',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MetricCard(
                        value: '$activeOrgs',
                        label: 'Active clinics',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MetricCard(
                        value: '${metrics.totalBranches}',
                        label: 'Total branches',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MetricCard(
                        value: formatRwf(totalMonthlyRevenue),
                        label: 'Monthly revenue (RWF)',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          CliniqnovvaCard(
            title: 'Revenue growth',
            child: SizedBox(
              height: 240,
              child: revenueTrendAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text(
                    'Failed to load revenue trend: $err',
                    style: TextStyle(color: context.appSubtext),
                  ),
                ),
                data: (points) => _RevenueChart(points: points),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CliniqnovvaCard(
                  title: 'Recent clinics',
                  child: organizationsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text(
                      'Failed to load: $err',
                      style: TextStyle(color: context.appSubtext),
                    ),
                    data: (organizations) {
                      final recent = organizations.take(5).toList();
                      if (recent.isEmpty) {
                        return Text(
                          'No clinics yet.',
                          style: TextStyle(color: context.appSubtext),
                        );
                      }
                      return Column(
                        children: [
                          for (final org in recent)
                            _OverviewListRow(
                              onTap: () => context.push(
                                '/super-admin/organizations/${org.id}',
                              ),
                              title: org.name,
                              subtitle:
                                  '${org.subscriptionPlan[0].toUpperCase()}${org.subscriptionPlan.substring(1)}',
                              trailing: _formatDate(org.createdAt),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CliniqnovvaCard(
                  title: 'Recent platform activity',
                  child: activityAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text(
                      'Failed to load: $err',
                      style: TextStyle(color: context.appSubtext),
                    ),
                    data: (entries) {
                      final recent = entries.take(5).toList();
                      if (recent.isEmpty) {
                        return Text(
                          'No activity yet.',
                          style: TextStyle(color: context.appSubtext),
                        );
                      }
                      return Column(
                        children: [
                          for (final entry in recent)
                            _OverviewListRow(
                              title: entry.action,
                              subtitle:
                                  entry.organizationId ??
                                  entry.actorRole ??
                                  '—',
                              trailing: _formatDateTime(entry.timestamp),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewListRow extends StatelessWidget {
  const _OverviewListRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.appSecondaryBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appSubtext, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: TextStyle(color: context.appSubtext, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real revenue growth — second-primary sky blue (2026-07-23) for the line
/// and a more-transparent sky blue for the area fill beneath it.
class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points});

  final List<RevenueTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No revenue data yet.',
          style: TextStyle(color: context.appSubtext),
        ),
      );
    }

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].revenueRwf.toDouble()),
    ];
    final maxRevenue = points
        .map((p) => p.revenueRwf)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final chartMaxY = maxRevenue == 0 ? 10.0 : maxRevenue * 1.2;
    final lineColor = AppColors.skyBlue;
    // Only label every Nth month so labels never crowd/overlap each other —
    // caps the x-axis at ~8 visible labels regardless of how many points exist.
    final labelInterval = (points.length / 8).ceil().clamp(1, points.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: chartMaxY,
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
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                if (index % labelInterval != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    points[index].monthLabel,
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
              final point = points[spot.x.toInt()];
              return LineTooltipItem(
                '${point.monthLabel}\n${formatRwf(point.revenueRwf)} RWF',
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
