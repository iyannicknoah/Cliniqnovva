import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../appointments/models/appointment_model.dart';
import '../../appointments/providers/appointments_provider.dart';
import '../../appointments/screens/appointments_screen.dart' show AppointmentsList;
import '../../auth/providers/access_control_provider.dart';
import '../../billing/models/invoice_model.dart';
import '../../billing/providers/invoices_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../departments/widgets/branch_selector.dart';
import '../../patients/models/patient_model.dart';
import '../../patients/providers/patients_provider.dart' show patientDetailProvider;
import '../../reports/models/report_models.dart';
import '../../reports/providers/reports_provider.dart';
import '../../staff/models/staff_model.dart';
import '../../staff/providers/staff_provider.dart' show staffDetailProvider;
import '../../super_admin/widgets/payment_history_panel.dart' show formatRwf;

const _monthAbbr = [
  '',
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
          // 2026-08-13, explicit user instruction — Revenue is Admin/
          // Accountant only; Receptionist (the only other role that ever
          // lands on /dashboard, see app_shell.dart's nav matrix — Accountant
          // has its own /accountant-overview and never renders this screen)
          // must not see it.
          final canSeeRevenue = [
            AppConstants.roleClinicAdmin,
            AppConstants.roleBranchAdmin,
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
                        style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isOrgAdmin) ...[const BranchSelector(), const SizedBox(width: 12)],
                    const TopBarActions(),
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
                            canSeeRevenue: canSeeRevenue,
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
  const _DashboardBody({required this.branchId, required this.canManage, required this.canSeeRevenue});

  final String? branchId;
  final bool canManage;
  final bool canSeeRevenue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = _todayIso();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricsRow(branchId: branchId, today: today),
        const SizedBox(height: 20),
        // 2026-08-13, explicit user instruction — Quick Actions removed
        // entirely; Revenue is now full width (was sharing a row with
        // Quick Actions) and a real monthly trend instead of a same-day
        // by-department breakdown. Admin/Accountant only — see
        // `canSeeRevenue` above.
        if (canSeeRevenue) ...[
          _RevenueTrendCard(branchId: branchId),
          const SizedBox(height: 16),
        ],
        _TodayAppointmentsCard(branchId: branchId, canManage: canManage),
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
      // 2026-08-14, explicit user instruction — "View all" on the same row
      // as the section title, navigating to the full Appointments page.
      trailing: CliniqnovvaButton.text(
        label: 'View all',
        onPressed: () => context.go('/appointments'),
      ),
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

/// Full-width monthly revenue trend (2026-08-13, second pass — explicit
/// user instruction to rebuild this like Stripe's "Recent earnings" widget:
/// a big total for the selected period, a period-length dropdown filter,
/// and a real bar chart with plain Y-axis value ticks + X-axis month labels
/// instead of axis title text, which was the first pass's approach and
/// rendered as illegible rotated/wrapped text — scrapped entirely rather
/// than fixed in place). Bar color is `context.appPrimary` (black light /
/// white dark) to match `reports_screen.dart`'s own revenue bar chart
/// (`_TrendBars`) — the sky-blue line style used elsewhere on this
/// dashboard was a line-chart convention that doesn't carry over to bars.
/// Admin/Accountant only — see `canSeeRevenue` in `_DashboardBody`.
const _periodOptions = [3, 6, 12];

class _RevenueTrendCard extends ConsumerStatefulWidget {
  const _RevenueTrendCard({required this.branchId});

  final String? branchId;

  @override
  ConsumerState<_RevenueTrendCard> createState() => _RevenueTrendCardState();
}

class _RevenueTrendCardState extends ConsumerState<_RevenueTrendCard> {
  int _monthsBack = 6;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rangeStart = DateTime(now.year, now.month - (_monthsBack - 1), 1);
    final months = [for (var i = 0; i < _monthsBack; i++) DateTime(rangeStart.year, rangeStart.month + i, 1)];
    String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final revenueAsync = ref.watch(
      revenueReportProvider((
        branchId: widget.branchId,
        dateFrom: isoDate(rangeStart),
        dateTo: isoDate(now),
        groupBy: 'month',
      )),
    );

    return CliniqnovvaCard(
      title: 'dashboard_revenue_trend'.tr(),
      trailing: SizedBox(
        width: 150,
        child: DropdownButtonFormField<int>(
          initialValue: _monthsBack,
          isExpanded: true,
          icon: const AppIcon(AppIcons.chevronDown, size: 16),
          style: TextStyle(color: context.appText, fontSize: 12.5),
          dropdownColor: context.appCard,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: context.appCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              borderSide: BorderSide(color: context.appBorder),
            ),
          ),
          items: [
            for (final n in _periodOptions)
              DropdownMenuItem(value: n, child: Text('dashboard_revenue_period_$n'.tr())),
          ],
          onChanged: (v) => setState(() => _monthsBack = v ?? 6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          revenueAsync.when(
            loading: () => const SizedBox(height: 32),
            error: (e, _) => const SizedBox(height: 32),
            data: (revenue) => Text(
              formatRwf(revenue.totalCollectedRwf),
              style: TextStyle(color: context.appText, fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: revenueAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
              data: (revenue) {
                final monthKeys = [for (final m in months) '${m.year}-${m.month.toString().padLeft(2, '0')}'];
                final values = [for (final k in monthKeys) (revenue.trend[k] ?? 0).toDouble()];
                // 2026-08-13, explicit user instruction — fixed 50,000 RWF
                // gridline step (was `maxY / 4`, a fraction of whatever the
                // real max happened to be, which produced a nonsense
                // 0/3/5/8/10 RWF scale whenever there's little/no revenue
                // yet). Always at least one step of headroom above the
                // tallest bar, and always at least 50,000 at the top even
                // with zero data.
                final rawMax = values.reduce((a, b) => a > b ? a : b);
                // 2026-08-14, explicit user instruction — dropped the 10k
                // marker just above zero from the previous pass's Y-axis
                // tick set (0 / 10k / 100k / 200k / 300k RWF); now a plain
                // 0 / 100k / 200k / 300k RWF set, evenly spaced. Extends
                // past 300k in further 100k steps only if real revenue
                // actually clears it, so the fixed set is always at least
                // these 4 values.
                final yTicks = <int>[0, 100000, 200000, 300000];
                while (yTicks.last < rawMax + 100000) {
                  yTicks.add(yTicks.last + 100000);
                }
                final yTickSet = yTicks.toSet();
                // 2026-08-14, explicit user instruction — the topmost
                // gridline (at the highest tick, e.g. 400,000) wasn't
                // rendering at all. Root cause: `maxY` sat exactly on that
                // tick, so its gridline landed flush on the chart's very top
                // pixel edge with zero headroom above it, and fl_chart
                // doesn't draw a line with nowhere to sit — it needs to be
                // strictly inside the plotted range, not on its boundary.
                // Extending `maxY` a bit past the last tick gives that line
                // room to actually paint.
                final maxY = yTicks.last.toDouble() + 40000;
                final barColor = context.appPrimary;

                return BarChart(
                  BarChartData(
                    minY: 0,
                    maxY: maxY,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 100000,
                      checkToShowHorizontalLine: (value) => yTickSet.contains(value.round()),
                      getDrawingHorizontalLine: (value) => FlLine(color: context.appBorder, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 76,
                          interval: 100000,
                          getTitlesWidget: (value, meta) {
                            if (!yTickSet.contains(value.round())) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                formatRwf(value),
                                style: TextStyle(color: context.appSubtext, fontSize: 10.5),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= months.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _monthAbbr[months[index].month],
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
                      for (var i = 0; i < values.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: values[i],
                              color: barColor,
                              width: 18,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dev-only sample-data preview (2026-08-14, explicit user instruction — "add
// sample data on dashboard so I get a way to see how this looks with data").
// Same pattern as the Patient App's `/dev/home-preview`: a route-scoped
// `ProviderScope` override feeds fixed sample data into the SAME widgets the
// real screen uses, so the design can be seen fully populated without
// needing a real logged-in session or writing anything to the real backend/
// Firestore. Reached only via a direct `/dev/dashboard-preview` URL — not
// linked from anywhere in the real app UI, not a production feature.
// ---------------------------------------------------------------------------

const _samplePatients = <String, PatientModel>{
  'sample-patient-1': PatientModel(
    id: 'sample-patient-1',
    clinicId: 'sample-clinic',
    branchId: 'sample-branch',
    name: 'Aline Uwase',
    phone: '+250788123456',
  ),
  'sample-patient-2': PatientModel(
    id: 'sample-patient-2',
    clinicId: 'sample-clinic',
    branchId: 'sample-branch',
    name: 'Eric Nkurunziza',
    phone: '+250788654321',
  ),
  'sample-patient-3': PatientModel(
    id: 'sample-patient-3',
    clinicId: 'sample-clinic',
    branchId: 'sample-branch',
    name: 'Chantal Mukamana',
    phone: '+250788112233',
  ),
};

const _sampleStaff = <String, StaffModel>{
  'sample-doctor-1': StaffModel(
    id: 'sample-doctor-1',
    clinicId: 'sample-clinic',
    branchId: 'sample-branch',
    name: 'Dr. Jean Mugisha',
    role: AppConstants.roleDoctor,
  ),
  'sample-doctor-2': StaffModel(
    id: 'sample-doctor-2',
    clinicId: 'sample-clinic',
    branchId: 'sample-branch',
    name: 'Dr. Grace Umutesi',
    role: AppConstants.roleDoctor,
  ),
};

List<AppointmentModel> _sampleAppointments() {
  final today = _todayIso();
  return [
    AppointmentModel(
      id: 'sample-appt-1',
      clinicId: 'sample-clinic',
      branchId: 'sample-branch',
      patientId: 'sample-patient-1',
      doctorId: 'sample-doctor-1',
      serviceId: 'sample-service-1',
      date: today,
      startTime: '09:00',
      endTime: '09:30',
      status: 'completed',
    ),
    AppointmentModel(
      id: 'sample-appt-2',
      clinicId: 'sample-clinic',
      branchId: 'sample-branch',
      patientId: 'sample-patient-2',
      doctorId: 'sample-doctor-2',
      serviceId: 'sample-service-2',
      date: today,
      startTime: '10:30',
      endTime: '11:00',
      status: 'checkedIn',
    ),
    AppointmentModel(
      id: 'sample-appt-3',
      clinicId: 'sample-clinic',
      branchId: 'sample-branch',
      patientId: 'sample-patient-3',
      doctorId: 'sample-doctor-1',
      serviceId: 'sample-service-1',
      date: today,
      startTime: '13:00',
      endTime: '13:30',
      status: 'confirmed',
    ),
    AppointmentModel(
      id: 'sample-appt-4',
      clinicId: 'sample-clinic',
      branchId: 'sample-branch',
      patientId: 'sample-patient-1',
      doctorId: 'sample-doctor-2',
      serviceId: 'sample-service-2',
      date: today,
      startTime: '15:00',
      endTime: '15:30',
      status: 'pending',
    ),
  ];
}

const _sampleInvoices = <InvoiceModel>[
  InvoiceModel(
    id: 'sample-inv-1',
    clinicId: 'sample-clinic',
    branchId: 'sample-branch',
    patientId: 'sample-patient-1',
    lineItems: [LineItem(description: 'Consultation', amountRwf: 15000)],
    totalAmountRwf: 15000,
    cashPaidAmountRwf: 0,
    insuranceCoveredAmountRwf: 0,
    insuranceScheme: 'none',
    status: 'unpaid',
  ),
  InvoiceModel(
    id: 'sample-inv-2',
    clinicId: 'sample-clinic',
    branchId: 'sample-branch',
    patientId: 'sample-patient-2',
    lineItems: [LineItem(description: 'Lab test', amountRwf: 8000)],
    totalAmountRwf: 8000,
    cashPaidAmountRwf: 4000,
    insuranceCoveredAmountRwf: 0,
    insuranceScheme: 'none',
    status: 'partial',
  ),
];

/// Fixed-looking monthly revenue, always ending at the CURRENT month so the
/// bar chart's default 6-month window is fully populated whenever this
/// preview is opened, regardless of the real date.
Map<String, int> _sampleMonthlyTrend() {
  final now = DateTime.now();
  const values = [120000, 95000, 180000, 60000, 240000, 150000];
  final map = <String, int>{};
  for (var i = 0; i < values.length; i++) {
    final m = DateTime(now.year, now.month - (values.length - 1 - i), 1);
    map['${m.year}-${m.month.toString().padLeft(2, '0')}'] = values[i];
  }
  return map;
}

class DashboardPreviewScreen extends StatelessWidget {
  const DashboardPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appointmentsListProvider.overrideWith((ref, params) async => _sampleAppointments()),
        patientDetailProvider.overrideWith(
          (ref, id) async => _samplePatients[id] ?? _samplePatients.values.first,
        ),
        staffDetailProvider.overrideWith(
          (ref, id) async => _sampleStaff[id] ?? _sampleStaff.values.first,
        ),
        invoicesListProvider.overrideWith((ref, params) async => _sampleInvoices),
        revenueReportProvider.overrideWith((ref, params) async {
          if (params.groupBy == 'month') {
            final trend = _sampleMonthlyTrend();
            return RevenueReport(
              dateFrom: params.dateFrom,
              dateTo: params.dateTo,
              groupBy: 'month',
              invoiceCount: 12,
              totalBilledRwf: 900000,
              totalCollectedRwf: trend.values.fold(0, (a, b) => a + b),
              trend: trend,
              byBranch: const {},
              byDoctor: const {},
              byService: const {},
            );
          }
          return const RevenueReport(
            dateFrom: '',
            dateTo: '',
            groupBy: 'day',
            invoiceCount: 2,
            totalBilledRwf: 45000,
            totalCollectedRwf: 45000,
            trend: {},
            byBranch: {},
            byDoctor: {},
            byService: {},
          );
        }),
      ],
      child: Scaffold(
        backgroundColor: context.appBg,
        body: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard — sample data preview',
                style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              const Expanded(
                child: SingleChildScrollView(
                  child: _DashboardBody(branchId: 'sample-branch', canManage: true, canSeeRevenue: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
