import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
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
import '../models/report_models.dart';
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 420,
                      child: SegmentedTabs(
                        labels: const ['Revenue', 'Patient Volume', 'No-Show'],
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DateFilterButton(
                          label: _isoDate(_dateFrom),
                          onTap: () => _pickDate(isFrom: true),
                        ),
                        Text(
                          'to',
                          style: TextStyle(color: context.appSubtext),
                        ),
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
                                  AppSelectOption(
                                    value: e.key,
                                    label: e.value,
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _groupBy = v ?? 'day'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
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

/// One named block of a multi-section export — e.g. "Summary", "By Branch
/// (RWF)" — each with its own column headers, independent of every other
/// section's shape (2 columns for a metric/value or trend list, 4 for
/// No-Show's completed/no-shows/rate breakdown).
class _ExportSection {
  const _ExportSection({
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String title;
  final List<String> columns;
  final List<List<String>> rows;
}

/// Resolves an id to its display name via [names], falling back to the
/// same "Other / Manual" label the on-screen breakdown tables use for the
/// synthetic 'manual'/'unknown' keys, or the raw id otherwise.
String _displayName(Map<String, String> names, String key) =>
    names[key] ??
    (key == 'manual' || key == 'unknown' ? 'Other / Manual' : key);

String _formatDateTime(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Export buttons shared by every tab — 2026-08-15, explicit user
/// instruction: replaced the old flat "Metric,Value" dump (which discarded
/// every breakdown — By Branch/Doctor/Service never made it into a CSV or
/// PDF at all) with a real multi-section report: each [_ExportSection]
/// (Summary, the trend, By Branch, By Doctor, By Service/...) keeps its own
/// column headers and renders as its own table, in both formats, with a
/// title and a generated-at timestamp up top.
class _ExportRow extends StatelessWidget {
  const _ExportRow({required this.title, required this.sections});

  final String title;
  final List<_ExportSection> sections;

  Future<void> _exportCsv() async {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('Generated,${_formatDateTime(DateTime.now())}');
    for (final section in sections) {
      if (section.rows.isEmpty) continue;
      buffer
        ..writeln()
        ..writeln(section.title)
        ..write(buildCsv(section.columns, section.rows))
        ..writeln();
    }
    await downloadCsv(buffer.toString());
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        header: (context) => context.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Generated ${_formatDateTime(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 14),
                ],
              )
            : pw.SizedBox(),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          for (final section in sections)
            if (section.rows.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      section.title,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(
                        width: 0.4,
                        color: PdfColors.grey400,
                      ),
                      columnWidths: section.columns.length == 2
                          ? const {
                              0: pw.FlexColumnWidth(3),
                              1: pw.FlexColumnWidth(1),
                            }
                          : null,
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            for (final c in section.columns)
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 5,
                                ),
                                child: pw.Text(
                                  c,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        for (final row in section.rows)
                          pw.TableRow(
                            children: [
                              for (var i = 0; i < row.length; i++)
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: pw.Text(
                                    row[i],
                                    style: const pw.TextStyle(fontSize: 10),
                                    textAlign: i == 0
                                        ? pw.TextAlign.left
                                        : pw.TextAlign.right,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    // 2026-08-15, explicit user instruction — real buttons (not the plain
    // text links this used to be), right-aligned. `CliniqnovvaButton
    // .outlined`'s defaults are exactly the requested look: text/icon in
    // `context.appPrimary`, border in `context.appSecondaryBg`, background
    // in `context.appBg`.
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 140,
          child: CliniqnovvaButton.outlined(
            label: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: CliniqnovvaButton.outlined(
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
              // 2026-08-15, explicit user instruction — "add enough
              // spacing between these rows" (was 10, cramped next to the
              // 16px-tall bars).
              padding: const EdgeInsets.only(bottom: 18),
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

/// One row inside [_BreakdownDataTable] — a single entity
/// (branch/doctor/service), totaled over the whole selected date range.
class _BreakdownRow {
  const _BreakdownRow(this.date, this.name, this.value);
  final String date;
  final String name;
  final int value;
}

/// 2026-08-15, explicit user instruction — the Revenue tab's By branch/By
/// doctor/By service breakdowns should read as a proper table (header row +
/// ruled rows) instead of a plain label/value list. "Daily collected" stays
/// the bar chart — this only replaces the three breakdown sections below it.
///
/// 2026-08-16, explicit user instruction (reverted a same-day-earlier
/// change): a brief detour split each entity into one row PER DATE, but
/// that produced duplicate branch/doctor/service names stacked in the
/// table — reverted back to one row per entity, totaled across [entries]
/// (`report.byBranch` etc., the whole-period flat totals), with every row
/// showing the same [dateRangeLabel] ("dateFrom to dateTo") since these
/// totals have no per-row date of their own. The equal-width column look
/// from that same session is kept (name column itself is left-aligned).
///
/// 2026-08-16, explicit user instruction — also adopted by the Patient
/// Volume tab's By branch/By doctor cards (previously the older
/// `_BreakdownTable`, a plain label/value list with no header row — deleted,
/// this was its only remaining caller).
class _BreakdownDataTable extends StatelessWidget {
  const _BreakdownDataTable({
    required this.title,
    required this.columnLabel,
    required this.valueLabel,
    required this.entries,
    required this.names,
    required this.dateRangeLabel,
  });

  final String title;
  final String columnLabel;
  final String valueLabel;
  final Map<String, int> entries;
  final Map<String, String> names;
  final String dateRangeLabel;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final sortedEntities = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final rows = <_BreakdownRow>[
      for (final entity in sortedEntities.take(10))
        _BreakdownRow(
          dateRangeLabel,
          names[entity.key] ??
              (entity.key == 'manual' || entity.key == 'unknown'
                  ? 'Other / Manual'
                  : entity.key),
          entity.value,
        ),
    ];

    final headerStyle = TextStyle(
      color: context.appSubtext,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );

    Widget columns({
      required Widget date,
      required Widget name,
      required Widget value,
    }) => Row(
      children: [
        Expanded(child: date),
        Expanded(child: name),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 100),
            child: value,
          ),
        ),
      ],
    );

    return CliniqnovvaCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // 20px vertical — matches CliniqnovvaTableHeader's own header
            // row padding elsewhere in the app.
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: columns(
              date: Text('Date', style: headerStyle),
              name: Text(columnLabel, style: headerStyle),
              value: Text(
                valueLabel,
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.appBorder),
          ...rows.map(
            (r) => Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.appBorder),
                ),
              ),
              // 32px vertical — matches CliniqnovvaTableRow's row height
              // elsewhere in the app (was 10, noticeably shorter).
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: columns(
                date: Text(
                  r.date,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appSubtext,
                    fontSize: 12.5,
                  ),
                ),
                name: Text(
                  r.name,
                  style: TextStyle(color: context.appText),
                  overflow: TextOverflow.ellipsis,
                ),
                value: Text(
                  '${r.value}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.appText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No-Show's By branch table, same visual shape as [_BreakdownDataTable]
/// (header row + ruled rows, equal-width columns, last column gets 100px
/// right padding) but with 3 value columns (Completed/No-Shows/No-Show
/// Rate) instead of 1, since [NoShowBranchStat] carries all three per
/// branch. 2026-08-16, explicit user instruction ("both patient volume and
/// no-show make sure data are displayed in table like the revenue tab") —
/// replaces the old plain `Column` of label/value `Row`s that squeezed the
/// rate into one formatted string ("86% (3/18)").
class _NoShowBreakdownTable extends StatelessWidget {
  const _NoShowBreakdownTable({
    required this.title,
    required this.byBranch,
    required this.names,
    required this.dateRangeLabel,
  });

  final String title;
  final Map<String, NoShowBranchStat> byBranch;
  final Map<String, String> names;
  final String dateRangeLabel;

  @override
  Widget build(BuildContext context) {
    if (byBranch.isEmpty) return const SizedBox.shrink();

    final headerStyle = TextStyle(
      color: context.appSubtext,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    final cellStyle = TextStyle(
      color: context.appText,
      fontWeight: FontWeight.w500,
    );

    Widget columns({
      required Widget date,
      required Widget branch,
      required Widget completed,
      required Widget noShows,
      required Widget rate,
    }) => Row(
      children: [
        Expanded(child: date),
        Expanded(child: branch),
        Expanded(child: completed),
        Expanded(child: noShows),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 100),
            child: rate,
          ),
        ),
      ],
    );

    return CliniqnovvaCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: columns(
              date: Text('Date', style: headerStyle),
              branch: Text('Branch', style: headerStyle),
              completed: Text(
                'Completed',
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
              noShows: Text(
                'No-Shows',
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
              rate: Text(
                'No-Show Rate',
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.appBorder),
          ...byBranch.entries.map(
            (e) => Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.appBorder)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: columns(
                date: Text(
                  dateRangeLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appSubtext,
                    fontSize: 12.5,
                  ),
                ),
                branch: Text(
                  names[e.key] ?? e.key,
                  style: TextStyle(color: context.appText),
                  overflow: TextOverflow.ellipsis,
                ),
                completed: Text(
                  '${e.value.completedCount}',
                  textAlign: TextAlign.right,
                  style: cellStyle,
                ),
                noShows: Text(
                  '${e.value.noShowCount}',
                  textAlign: TextAlign.right,
                  style: cellStyle,
                ),
                rate: Text(
                  '${(e.value.noShowRate * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: cellStyle,
                ),
              ),
            ),
          ),
        ],
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
              // 2026-08-15, explicit user instruction — "between every
              // section increase the spacing" (was 16/20 throughout this
              // tab; bumped to 28/32).
              const SizedBox(height: 28),
              _ExportRow(
                title: 'Revenue Report ($dateFrom to $dateTo)',
                sections: [
                  _ExportSection(
                    title: 'Summary',
                    columns: const ['Metric', 'Value'],
                    rows: [
                      ['Total Collected (RWF)', '${report.totalCollectedRwf}'],
                      ['Total Billed (RWF)', '${report.totalBilledRwf}'],
                      ['Invoices', '${report.invoiceCount}'],
                    ],
                  ),
                  _ExportSection(
                    title: '${_groupByLabels[report.groupBy]} Collected (RWF)',
                    columns: const ['Date', 'Collected (RWF)'],
                    rows:
                        (report.trend.entries.toList()
                              ..sort((a, b) => a.key.compareTo(b.key)))
                            .map((e) => [e.key, '${e.value}'])
                            .toList(),
                  ),
                  _ExportSection(
                    title: 'By Branch (RWF)',
                    columns: const ['Branch', 'Collected (RWF)'],
                    rows:
                        (report.byBranch.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .map(
                              (e) => [
                                _displayName(branchNames, e.key),
                                '${e.value}',
                              ],
                            )
                            .toList(),
                  ),
                  _ExportSection(
                    title: 'By Doctor (RWF)',
                    columns: const ['Doctor', 'Collected (RWF)'],
                    rows:
                        (report.byDoctor.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .map(
                              (e) => [
                                _displayName(doctorNames, e.key),
                                '${e.value}',
                              ],
                            )
                            .toList(),
                  ),
                  _ExportSection(
                    title: 'By Service (RWF)',
                    columns: const ['Service', 'Collected (RWF)'],
                    rows:
                        (report.byService.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .map(
                              (e) => [
                                _displayName(serviceNames, e.key),
                                '${e.value}',
                              ],
                            )
                            .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              CliniqnovvaCard(
                title: '${_groupByLabels[report.groupBy]} collected (RWF)',
                child: _TrendBars(trend: report.trend, valueSuffix: ''),
              ),
              // "By branch" only makes sense with multiple branches in the
              // data — a single branch selected means every row would
              // repeat that same branch, so it's hidden then.
              if (branchId == null) ...[
                const SizedBox(height: 28),
                _BreakdownDataTable(
                  title: 'By branch (RWF)',
                  columnLabel: 'Branch',
                  valueLabel: 'Collected (RWF)',
                  entries: report.byBranch,
                  names: branchNames,
                  dateRangeLabel: '$dateFrom to $dateTo',
                ),
              ],
              const SizedBox(height: 28),
              _BreakdownDataTable(
                title: 'By doctor (RWF)',
                columnLabel: 'Doctor',
                valueLabel: 'Collected (RWF)',
                entries: report.byDoctor,
                names: doctorNames,
                dateRangeLabel: '$dateFrom to $dateTo',
              ),
              const SizedBox(height: 28),
              _BreakdownDataTable(
                title: 'By service (RWF)',
                columnLabel: 'Service',
                valueLabel: 'Collected (RWF)',
                entries: report.byService,
                names: serviceNames,
                dateRangeLabel: '$dateFrom to $dateTo',
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
              const SizedBox(height: 28),
              _ExportRow(
                title: 'Patient Volume Report ($dateFrom to $dateTo)',
                sections: [
                  _ExportSection(
                    title: 'Summary',
                    columns: const ['Metric', 'Value'],
                    rows: [
                      ['Total Visits', '${report.totalVisits}'],
                      ['Unique Patients', '${report.uniquePatients}'],
                    ],
                  ),
                  _ExportSection(
                    title: '${_groupByLabels[report.groupBy]} Visits',
                    columns: const ['Date', 'Visits'],
                    rows:
                        (report.trend.entries.toList()
                              ..sort((a, b) => a.key.compareTo(b.key)))
                            .map((e) => [e.key, '${e.value}'])
                            .toList(),
                  ),
                  _ExportSection(
                    title: 'By Branch',
                    columns: const ['Branch', 'Visits'],
                    rows:
                        (report.byBranch.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .map(
                              (e) => [
                                _displayName(branchNames, e.key),
                                '${e.value}',
                              ],
                            )
                            .toList(),
                  ),
                  _ExportSection(
                    title: 'By Doctor',
                    columns: const ['Doctor', 'Visits'],
                    rows:
                        (report.byDoctor.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .map(
                              (e) => [
                                _displayName(doctorNames, e.key),
                                '${e.value}',
                              ],
                            )
                            .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              CliniqnovvaCard(
                title: '${_groupByLabels[report.groupBy]} visits',
                child: _TrendBars(trend: report.trend, valueSuffix: ''),
              ),
              // "By branch" only makes sense with multiple branches in the
              // data — a single branch selected means every row would
              // repeat that same branch, so it's hidden then.
              if (branchId == null) ...[
                const SizedBox(height: 28),
                _BreakdownDataTable(
                  title: 'By branch',
                  columnLabel: 'Branch',
                  valueLabel: 'Visits',
                  entries: report.byBranch,
                  names: branchNames,
                  dateRangeLabel: '$dateFrom to $dateTo',
                ),
              ],
              const SizedBox(height: 28),
              _BreakdownDataTable(
                title: 'By doctor',
                columnLabel: 'Doctor',
                valueLabel: 'Visits',
                entries: report.byDoctor,
                names: doctorNames,
                dateRangeLabel: '$dateFrom to $dateTo',
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
              const SizedBox(height: 28),
              _ExportRow(
                title: 'No-Show Report ($dateFrom to $dateTo)',
                sections: [
                  _ExportSection(
                    title: 'Summary',
                    columns: const ['Metric', 'Value'],
                    rows: [
                      ['No-Show Rate', ratePct],
                      ['Completed', '${report.completedCount}'],
                      ['No-Shows', '${report.noShowCount}'],
                    ],
                  ),
                  _ExportSection(
                    title: 'By Branch',
                    columns: const [
                      'Branch',
                      'Completed',
                      'No-Shows',
                      'No-Show Rate',
                    ],
                    rows: report.byBranch.entries
                        .map(
                          (e) => [
                            _displayName(branchNames, e.key),
                            '${e.value.completedCount}',
                            '${e.value.noShowCount}',
                            '${(e.value.noShowRate * 100).toStringAsFixed(1)}%',
                          ],
                        )
                        .toList(),
                  ),
                ],
              ),
              // "By branch" only makes sense with multiple branches in the
              // data — a single branch selected means every row would
              // repeat that same branch, so it's hidden then.
              if (branchId == null) ...[
                const SizedBox(height: 28),
                _NoShowBreakdownTable(
                  title: 'By branch',
                  byBranch: report.byBranch,
                  names: branchNames,
                  dateRangeLabel: '$dateFrom to $dateTo',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
