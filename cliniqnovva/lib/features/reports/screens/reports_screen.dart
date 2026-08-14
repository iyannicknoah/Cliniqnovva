import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/csv_export.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart'
    show activeBranchIdProvider;
import '../../departments/providers/services_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../../clinics/providers/branches_provider.dart';
import '../../departments/models/service_model.dart';
import '../../clinics/models/branch_model.dart';
import '../../staff/models/staff_model.dart';
import '../../staff/providers/staff_provider.dart';
import '../providers/reports_provider.dart';

const _groupByLabels = {'day': 'Daily', 'week': 'Weekly', 'month': 'Monthly'};

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Part 14 Task 2 — /reports. Revenue / Patient Volume / No-show, all
/// computed server-side from FINALIZED data only (voided invoices and
/// non-completed appointments are already excluded before this screen ever
/// sees them — see reports.service.js). CSV/PDF export cover whichever tab
/// is currently active.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _tab = 0;
  String _groupBy = 'day';
  late DateTime _dateFrom;
  late DateTime _dateTo;

  @override
  void initState() {
    super.initState();
    _dateTo = DateTime.now();
    _dateFrom = _dateTo.subtract(const Duration(days: 30));
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.appSubtext)),
        ),
        data: (data) {
          final role = data?['role'] as String?;
          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final effectiveBranchId = isOrgAdmin
              ? ref.watch(activeBranchIdProvider)
              : ownBranchId;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Reports',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isOrgAdmin) ...[
                      const BranchSelector(),
                      const SizedBox(width: 12),
                    ],
                    const TopBarActions(),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 420,
                  child: SegmentedTabs(
                    labels: const ['Revenue', 'Patient Volume', 'No-Show'],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DateFilterButton(
                      label: _isoDate(_dateFrom),
                      onTap: () => _pickDate(isFrom: true),
                    ),
                    Text('to', style: TextStyle(color: context.appSubtext)),
                    _DateFilterButton(
                      label: _isoDate(_dateTo),
                      onTap: () => _pickDate(isFrom: false),
                    ),
                    if (_tab != 2)
                      SizedBox(
                        width: 160,
                        child: AppSelect(
                          value: _groupBy,
                          options: [
                            for (final e in _groupByLabels.entries)
                              AppSelectOption(value: e.key, label: e.value),
                          ],
                          onChanged: (v) =>
                              setState(() => _groupBy = v ?? 'day'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: switch (_tab) {
                    0 => _RevenueTab(
                      branchId: effectiveBranchId,
                      dateFrom: _isoDate(_dateFrom),
                      dateTo: _isoDate(_dateTo),
                      groupBy: _groupBy,
                    ),
                    1 => _VolumeTab(
                      branchId: effectiveBranchId,
                      dateFrom: _isoDate(_dateFrom),
                      dateTo: _isoDate(_dateTo),
                      groupBy: _groupBy,
                    ),
                    _ => _NoShowTab(
                      branchId: effectiveBranchId,
                      dateFrom: _isoDate(_dateFrom),
                      dateTo: _isoDate(_dateTo),
                    ),
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
        ),
        child: Text(
          label,
          style: TextStyle(color: context.appText, fontSize: 14),
        ),
      ),
    );
  }
}

/// Export buttons shared by every tab — [rows] is (label, value) pairs
/// already formatted as display strings, ready for both CSV and a PDF table.
class _ExportRow extends StatelessWidget {
  const _ExportRow({
    required this.title,
    required this.summary,
    required this.trendRows,
  });

  final String title;
  final List<(String, String)> summary;
  final List<(String, String)> trendRows;

  Future<void> _exportCsv() async {
    final csv = buildCsv([
      'Metric',
      'Value',
    ], [...summary, ...trendRows].map((r) => [r.$1, r.$2]).toList());
    await downloadCsv(csv);
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder(bottom: const pw.BorderSide(width: 0.5)),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
              },
              children: [
                for (final row in [...summary, ...trendRows])
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(row.$1),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(row.$2, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: CliniqnovvaButton.text(
            label: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ),
        SizedBox(
          width: 130,
          child: CliniqnovvaButton.text(
            label: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ),
      ],
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.trend, required this.valueSuffix});

  final Map<String, int> trend;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return Text(
        'No data in this range.',
        style: TextStyle(color: context.appSubtext),
      );
    }
    final entries = trend.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maxValue = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: context.appSubtext,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxValue == 0 ? 0 : e.value / maxValue,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: context.appPrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: Text(
                      '${e.value}$valueSuffix',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: context.appText, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({
    required this.title,
    required this.entries,
    required this.names,
  });

  final String title;
  final Map<String, int> entries;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CliniqnovvaCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sorted
            .take(10)
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        names[e.key] ??
                            (e.key == 'manual' || e.key == 'unknown'
                                ? 'Other / Manual'
                                : e.key),
                        style: TextStyle(color: context.appText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${e.value}',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RevenueTab extends ConsumerWidget {
  const _RevenueTab({
    required this.branchId,
    required this.dateFrom,
    required this.dateTo,
    required this.groupBy,
  });

  final String? branchId;
  final String dateFrom;
  final String dateTo;
  final String groupBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(
      revenueReportProvider((
        branchId: branchId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        groupBy: groupBy,
      )),
    );
    final doctorsAsync = ref.watch(staffListProvider(branchId));
    final servicesAsync = ref.watch(servicesProvider(branchId));
    final branchesAsync = ref.watch(branchesProvider);

    return reportAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (report) {
        final doctorNames = {
          for (final StaffModel d in doctorsAsync.valueOrNull ?? [])
            d.id: d.name,
        };
        final serviceNames = {
          for (final ServiceModel s in servicesAsync.valueOrNull ?? [])
            s.id: s.name,
        };
        final branchNames = {
          for (final BranchModel b in branchesAsync.valueOrNull?.branches ?? [])
            b.id: b.name,
        };

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Total Collected (RWF)',
                      value: '${report.totalCollectedRwf}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      label: 'Total Billed (RWF)',
                      value: '${report.totalBilledRwf}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      label: 'Invoices',
                      value: '${report.invoiceCount}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ExportRow(
                title: 'Revenue Report ($dateFrom to $dateTo)',
                summary: [
                  ('Total Collected (RWF)', '${report.totalCollectedRwf}'),
                  ('Total Billed (RWF)', '${report.totalBilledRwf}'),
                  ('Invoices', '${report.invoiceCount}'),
                ],
                trendRows:
                    (report.trend.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key)))
                        .map((e) => (e.key, '${e.value}'))
                        .toList(),
              ),
              const SizedBox(height: 20),
              CliniqnovvaCard(
                title: '${_groupByLabels[report.groupBy]} collected (RWF)',
                child: _TrendBars(trend: report.trend, valueSuffix: ''),
              ),
              const SizedBox(height: 16),
              _BreakdownTable(
                title: 'By branch (RWF)',
                entries: report.byBranch,
                names: branchNames,
              ),
              const SizedBox(height: 16),
              _BreakdownTable(
                title: 'By doctor (RWF)',
                entries: report.byDoctor,
                names: doctorNames,
              ),
              const SizedBox(height: 16),
              _BreakdownTable(
                title: 'By service (RWF)',
                entries: report.byService,
                names: serviceNames,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VolumeTab extends ConsumerWidget {
  const _VolumeTab({
    required this.branchId,
    required this.dateFrom,
    required this.dateTo,
    required this.groupBy,
  });

  final String? branchId;
  final String dateFrom;
  final String dateTo;
  final String groupBy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(
      patientVolumeReportProvider((
        branchId: branchId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        groupBy: groupBy,
      )),
    );
    final doctorsAsync = ref.watch(staffListProvider(branchId));
    final branchesAsync = ref.watch(branchesProvider);

    return reportAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (report) {
        final doctorNames = {
          for (final StaffModel d in doctorsAsync.valueOrNull ?? [])
            d.id: d.name,
        };
        final branchNames = {
          for (final BranchModel b in branchesAsync.valueOrNull?.branches ?? [])
            b.id: b.name,
        };

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Total Visits',
                      value: '${report.totalVisits}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      label: 'Unique Patients',
                      value: '${report.uniquePatients}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ExportRow(
                title: 'Patient Volume Report ($dateFrom to $dateTo)',
                summary: [
                  ('Total Visits', '${report.totalVisits}'),
                  ('Unique Patients', '${report.uniquePatients}'),
                ],
                trendRows:
                    (report.trend.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key)))
                        .map((e) => (e.key, '${e.value}'))
                        .toList(),
              ),
              const SizedBox(height: 20),
              CliniqnovvaCard(
                title: '${_groupByLabels[report.groupBy]} visits',
                child: _TrendBars(trend: report.trend, valueSuffix: ''),
              ),
              const SizedBox(height: 16),
              _BreakdownTable(
                title: 'By branch',
                entries: report.byBranch,
                names: branchNames,
              ),
              const SizedBox(height: 16),
              _BreakdownTable(
                title: 'By doctor',
                entries: report.byDoctor,
                names: doctorNames,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoShowTab extends ConsumerWidget {
  const _NoShowTab({
    required this.branchId,
    required this.dateFrom,
    required this.dateTo,
  });

  final String? branchId;
  final String dateFrom;
  final String dateTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(
      noShowReportProvider((
        branchId: branchId,
        dateFrom: dateFrom,
        dateTo: dateTo,
      )),
    );
    final branchesAsync = ref.watch(branchesProvider);

    return reportAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (report) {
        final branchNames = {
          for (final BranchModel b in branchesAsync.valueOrNull?.branches ?? [])
            b.id: b.name,
        };
        final ratePct = '${(report.noShowRate * 100).toStringAsFixed(1)}%';

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(label: 'No-Show Rate', value: ratePct),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      label: 'Completed',
                      value: '${report.completedCount}',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      label: 'No-Shows',
                      value: '${report.noShowCount}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ExportRow(
                title: 'No-Show Report ($dateFrom to $dateTo)',
                summary: [
                  ('No-Show Rate', ratePct),
                  ('Completed', '${report.completedCount}'),
                  ('No-Shows', '${report.noShowCount}'),
                ],
                trendRows: const [],
              ),
              const SizedBox(height: 20),
              if (report.byBranch.isNotEmpty)
                CliniqnovvaCard(
                  title: 'By branch',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: report.byBranch.entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    branchNames[e.key] ?? e.key,
                                    style: TextStyle(color: context.appText),
                                  ),
                                ),
                                Text(
                                  '${(e.value.noShowRate * 100).toStringAsFixed(1)}% (${e.value.noShowCount}/${e.value.completedCount + e.value.noShowCount})',
                                  style: TextStyle(color: context.appSubtext),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
