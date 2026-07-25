import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../billing/providers/invoices_provider.dart';
import '../../chat/providers/chats_provider.dart';
import '../../departments/providers/departments_provider.dart';
import '../../departments/providers/services_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../patients/providers/patients_provider.dart';
import '../../reports/providers/reports_provider.dart';
import '../../reviews/providers/reviews_provider.dart';
import '../../super_admin/widgets/payment_history_panel.dart' show formatRwf;

String _todayIso() {
  final d = DateTime.now().toUtc().add(const Duration(hours: 2)); // Africa/Kigali, UTC+2
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Part 17 Task 1 — /dashboard's final design (replaces the temporary
/// nav-index built in Parts 14-16). Every number on this screen is live,
/// pulled from providers already built in earlier parts — no new backend
/// endpoints. Clinic Admin/Branch Admin/Receptionist only (Doctor/
/// Nurse get their own `/doctor-today`/`/nurse-today` instead — see
/// `app_shell.dart`'s nav matrix).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          final role = data?['role'] as String?;
          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final branchId = isOrgAdmin ? ref.watch(activeBranchIdProvider) : ownBranchId;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dashboard',
                        style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isOrgAdmin) const BranchSelector(),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: branchId == null
                      ? EmptyState(
                          icon: AppIcons.clinics,
                          message: isOrgAdmin
                              ? 'empty_pick_branch'.tr()
                              : 'empty_no_branch'.tr(),
                        )
                      : SingleChildScrollView(
                          child: _DashboardBody(branchId: branchId),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _todayIso();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricsRow(branchId: branchId, today: today),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final left = _TodayAppointmentsCard(branchId: branchId);
            final right = _RevenueByDepartmentCard(branchId: branchId, today: today);
            return isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: right),
                      ],
                    ),
                  )
                : Column(children: [left, const SizedBox(height: 16), right]);
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final left = _RecentChatsCard(branchId: branchId);
            final right = const _QuickActionsCard();
            return isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 16),
                        Expanded(child: right),
                      ],
                    ),
                  )
                : Column(children: [left, const SizedBox(height: 16), right]);
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final left = _LowStockCard(branchId: branchId);
            final right = _ReviewsNeedingReplyCard(branchId: branchId);
            return isWide
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 16),
                        Expanded(child: right),
                      ],
                    ),
                  )
                : Column(children: [left, const SizedBox(height: 16), right]);
          },
        ),
      ],
    );
  }
}

/// Row 1 — Today's appointments, Patients seen today, Revenue today,
/// Pending invoices.
class _MetricsRow extends ConsumerWidget {
  const _MetricsRow({required this.branchId, required this.today});

  final String branchId;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayApptsAsync = ref.watch(
      appointmentsListProvider((branchId: branchId, doctorId: null, patientId: null, tab: 'today')),
    );
    final revenueAsync = ref.watch(
      revenueReportProvider((branchId: branchId, dateFrom: today, dateTo: today, groupBy: 'day')),
    );
    final invoicesAsync = ref.watch(
      invoicesListProvider((branchId: branchId, status: null, dateFrom: null, dateTo: null)),
    );

    final todayAppts = todayApptsAsync.valueOrNull;
    final patientsSeenToday = todayAppts?.where((a) => a.status == 'completed').length;
    final pendingInvoices = invoicesAsync.valueOrNull
        ?.where((inv) => inv.status == AppConstants.invoiceUnpaid || inv.status == AppConstants.invoicePartial)
        .length;

    return Row(
      children: [
        Expanded(
          child: MetricCard(label: 'dashboard_metric_appointments_today'.tr(), value: '${todayAppts?.length ?? '—'}'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MetricCard(label: 'dashboard_metric_patients_seen'.tr(), value: '${patientsSeenToday ?? '—'}'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MetricCard(
            label: 'dashboard_metric_revenue_today'.tr(),
            value: revenueAsync.valueOrNull != null ? formatRwf(revenueAsync.valueOrNull!.totalCollectedRwf) : '—',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MetricCard(label: 'dashboard_metric_pending_invoices'.tr(), value: '${pendingInvoices ?? '—'}'),
        ),
      ],
    );
  }
}

/// Row 2 left (60%) — today's appointment list with status badges.
class _TodayAppointmentsCard extends ConsumerWidget {
  const _TodayAppointmentsCard({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptsAsync = ref.watch(
      appointmentsListProvider((branchId: branchId, doctorId: null, patientId: null, tab: 'today')),
    );

    return CliniqnovvaCard(
      title: 'dashboard_metric_appointments_today'.tr(),
      child: apptsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
        data: (appts) {
          if (appts.isEmpty) {
            return Text(
              'Nothing on the books today yet.',
              style: TextStyle(color: context.appSubtext),
            );
          }
          final sorted = [...appts]..sort((a, b) => a.startTime.compareTo(b.startTime));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sorted
                .take(8)
                .map(
                  (appt) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(appt.startTime, style: TextStyle(color: context.appSubtext, fontSize: 12.5)),
                        ),
                        Expanded(child: _PatientName(patientId: appt.patientId)),
                        _StatusDot(status: appt.status),
                      ],
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _PatientName extends ConsumerWidget {
  const _PatientName({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    return Text(
      patientAsync.valueOrNull?.name ?? '…',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final String status;

  static const _labels = {
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'checkedIn': 'Checked In',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  Color _color() => switch (status) {
    'completed' => AppColors.brightGreen,
    'cancelled' => AppColors.brightRed,
    'confirmed' || 'checkedIn' => AppColors.pillTealText,
    _ => AppColors.pillAmberText,
  };

  @override
  Widget build(BuildContext context) {
    return Text(
      _labels[status] ?? status,
      style: TextStyle(color: _color(), fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}

/// Row 2 right (40%) — revenue by department, bar chart.
class _RevenueByDepartmentCard extends ConsumerWidget {
  const _RevenueByDepartmentCard({required this.branchId, required this.today});

  final String branchId;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(
      revenueReportProvider((branchId: branchId, dateFrom: today, dateTo: today, groupBy: 'day')),
    );
    final servicesAsync = ref.watch(servicesProvider(branchId));
    final departmentsAsync = ref.watch(departmentsProvider(branchId));

    return CliniqnovvaCard(
      title: 'dashboard_revenue_by_department'.tr(),
      child: SizedBox(
        height: 220,
        child: revenueAsync.when(
          loading: () => const LoadingWidget(),
          error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
          data: (revenue) {
            final services = servicesAsync.valueOrNull ?? [];
            final departments = departmentsAsync.valueOrNull ?? [];
            final departmentNames = {for (final d in departments) d.id: d.name};
            final serviceDept = {for (final s in services) s.id: s.departmentId};

            final byDepartment = <String, int>{};
            revenue.byService.forEach((serviceId, amount) {
              final deptId = serviceDept[serviceId];
              final key = deptId ?? 'other';
              byDepartment[key] = (byDepartment[key] ?? 0) + amount;
            });

            if (byDepartment.isEmpty) {
              return Center(
                child: Text('No revenue recorded yet today.', style: TextStyle(color: context.appSubtext)),
              );
            }

            final entries = byDepartment.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
            final top = entries.take(6).toList();
            final maxY = (top.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2).clamp(10, double.infinity);

            return BarChart(
              BarChartData(
                maxY: maxY.toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
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
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= top.length) return const SizedBox.shrink();
                        final key = top[index].key;
                        final label = key == 'other' ? 'Other' : (departmentNames[key] ?? '—');
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.appSubtext, fontSize: 10.5),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => context.appCard,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                      formatRwf(rod.toY),
                      TextStyle(color: context.appText, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < top.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: top[i].value.toDouble(),
                          color: AppColors.skyBlue,
                          width: 22,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Row 3 left — recent chat threads needing a reply.
class _RecentChatsCard extends ConsumerWidget {
  const _RecentChatsCard({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsInboxStreamProvider(branchId));

    return CliniqnovvaCard(
      title: 'dashboard_recent_chats'.tr(),
      child: chatsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
        data: (chats) {
          if (chats.isEmpty) {
            return Text(
              'No conversations yet — they\'ll show up here once a patient reaches out.',
              style: TextStyle(color: context.appSubtext),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...chats.take(5).map(
                (chat) => InkWell(
                  onTap: () => context.go('/chat/${chat.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: _PatientName(patientId: chat.patientId)),
                        Expanded(
                          flex: 2,
                          child: Text(
                            chat.lastMessage ?? 'No messages yet.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CliniqnovvaButton.text(label: 'Open Chat Inbox', onPressed: () => context.go('/chat')),
            ],
          );
        },
      ),
    );
  }
}

/// Row 3 right — Quick Actions.
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaCard(
      title: 'dashboard_quick_actions'.tr(),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: CliniqnovvaButton(
              label: 'dashboard_register_patient'.tr(),
              onPressed: () => context.go('/patients/register'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CliniqnovvaButton(
              label: 'dashboard_book_appointment'.tr(),
              onPressed: () => context.go('/appointments/book'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CliniqnovvaButton.text(
              label: 'dashboard_run_reports'.tr(),
              onPressed: () => context.go('/reports'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row 4 left — low-stock alerts.
class _LowStockCard extends ConsumerWidget {
  const _LowStockCard({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inventoryListProvider(branchId));

    return CliniqnovvaCard(
      title: 'dashboard_low_stock'.tr(),
      child: itemsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
        data: (items) {
          final low = items.where((i) => i.needsReorder && i.isActive).toList();
          if (low.isEmpty) {
            return Row(
              children: [
                AppIcon(AppIcons.star, size: 16, color: AppColors.brightGreen),
                const SizedBox(width: 8),
                Text('Stock levels look healthy.', style: TextStyle(color: context.appSubtext)),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...low.take(6).map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(item.name, style: TextStyle(color: context.appText)),
                      ),
                      Text(
                        '${item.quantity} ${item.unit} left',
                        style: const TextStyle(color: AppColors.pillAmberText, fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CliniqnovvaButton.text(label: 'Open Inventory', onPressed: () => context.go('/inventory')),
            ],
          );
        },
      ),
    );
  }
}

/// Row 4 right — recent reviews needing a reply.
class _ReviewsNeedingReplyCard extends ConsumerWidget {
  const _ReviewsNeedingReplyCard({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsListProvider(branchId));

    return CliniqnovvaCard(
      title: 'dashboard_reviews_needing_reply'.tr(),
      child: reviewsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
        data: (reviews) {
          final needsReply = reviews.where((r) => !r.isHidden && r.staffReply == null).toList();
          if (needsReply.isEmpty) {
            return Text('You\'re all caught up on reviews.', style: TextStyle(color: context.appSubtext));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...needsReply.take(5).map(
                (review) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AvatarWidget(firstName: '?', size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          review.branchComment ?? review.doctorComment ?? '${review.branchRating}★ rating',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.appText, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CliniqnovvaButton.text(label: 'Open Reviews', onPressed: () => context.go('/reviews')),
            ],
          );
        },
      ),
    );
  }
}
