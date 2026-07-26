import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/screens/appointments_screen.dart' show AppointmentsList;
import '../../auth/providers/access_control_provider.dart';
import '../../billing/providers/invoices_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart';
import '../../departments/providers/services_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../../reports/providers/reports_provider.dart';
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
          final isAllBranches = isOrgAdmin && ref.watch(showAllBranchesProvider);
          final canManage = [
            AppConstants.roleClinicAdmin,
            AppConstants.roleBranchAdmin,
            AppConstants.roleReceptionist,
          ].contains(role);

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
                  child: branchId == null && !isAllBranches
                      ? EmptyState(
                          icon: AppIcons.clinics,
                          message: isOrgAdmin
                              ? 'empty_pick_branch'.tr()
                              : 'empty_no_branch'.tr(),
                        )
                      : SingleChildScrollView(
                          child: _DashboardBody(
                            branchId: isAllBranches ? null : branchId,
                            canManage: canManage,
                          ),
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
  const _DashboardBody({required this.branchId, required this.canManage});

  final String? branchId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _todayIso();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricsRow(branchId: branchId, today: today),
        const SizedBox(height: 20),
        _TodayAppointmentsCard(branchId: branchId, canManage: canManage),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final left = _RevenueByDepartmentCard(branchId: branchId, today: today);
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
      ],
    );
  }
}

/// Row 1 — Today's appointments, Patients seen today, Revenue today,
/// Pending invoices.
class _MetricsRow extends ConsumerWidget {
  const _MetricsRow({required this.branchId, required this.today});

  final String? branchId;
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

/// Full-width "Today's Appointments" section (2026-07-25) — reuses the same
/// Patient/Doctor/Date & time/Status/Actions table the Appointments screen's
/// Today tab renders, Confirm/Reschedule/Cancel included, instead of the old
/// compact time+name+status-dot list confined to 60% of the row.
class _TodayAppointmentsCard extends StatelessWidget {
  const _TodayAppointmentsCard({required this.branchId, required this.canManage});

  final String? branchId;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return CliniqnovvaCard(
      title: 'dashboard_metric_appointments_today'.tr(),
      child: AppointmentsList(
        branchId: branchId,
        doctorId: null,
        tab: 'today',
        canManage: canManage,
        embedded: true,
      ),
    );
  }
}

/// Pairs with Quick Actions (2026-07-25, briefly full width for one
/// revision, now back to sharing a row — Reviews Needing Reply is the one
/// that's full width now) — revenue by department, bar chart.
class _RevenueByDepartmentCard extends ConsumerWidget {
  const _RevenueByDepartmentCard({required this.branchId, required this.today});

  final String? branchId;
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

/// Quick Actions — now pairs with Revenue by Department (2026-07-25, briefly
/// paired with Reviews Needing Reply for one revision; Reviews is full width
/// on its own row now, with a "View all" link instead).
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

