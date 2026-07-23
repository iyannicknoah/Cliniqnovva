import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../organizations/providers/organizations_provider.dart';
import '../../platform/providers/platform_provider.dart';
import '../widgets/super_admin_scaffold.dart';

/// Part 5 — Super Admin's platform-wide oversight/support tools: metrics,
/// cross-org branch/staff search, a read-only cross-org record lookup
/// (patients/appointments/invoices — logged every use), and the combined
/// platform audit log with filters. Nothing on this screen writes to any
/// organization's actual data — the only writes here are the audit-log
/// entries the lookup itself creates.
class OversightScreen extends ConsumerStatefulWidget {
  const OversightScreen({super.key});

  @override
  ConsumerState<OversightScreen> createState() => _OversightScreenState();
}

class _OversightScreenState extends ConsumerState<OversightScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  final _recordIdController = TextEditingController();
  String _recordCollection = 'patients';
  Map<String, dynamic>? _recordResult;
  bool _recordNotFound = false;
  bool _recordLoading = false;

  String? _filterOrgId;
  final _filterActorController = TextEditingController();
  final _filterActionController = TextEditingController();
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  AuditLogFilter _appliedFilter = const AuditLogFilter();

  @override
  void dispose() {
    _searchController.dispose();
    _recordIdController.dispose();
    _filterActorController.dispose();
    _filterActionController.dispose();
    super.dispose();
  }

  Future<void> _viewRecord() async {
    final id = _recordIdController.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _recordLoading = true;
      _recordResult = null;
      _recordNotFound = false;
    });
    final result = await ref
        .read(platformNotifierProvider.notifier)
        .viewRecord(_recordCollection, id);
    if (!mounted) return;
    setState(() {
      _recordLoading = false;
      _recordResult = result;
      _recordNotFound = result == null;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isFrom ? _filterDateFrom = picked : _filterDateTo = picked);
  }

  void _applyAuditFilter() {
    setState(() {
      _appliedFilter = AuditLogFilter(
        organizationId: _filterOrgId,
        actorId: _filterActorController.text.trim().isEmpty
            ? null
            : _filterActorController.text.trim(),
        action: _filterActionController.text.trim().isEmpty
            ? null
            : _filterActionController.text.trim(),
        dateFrom: _filterDateFrom,
        dateTo: _filterDateTo,
      );
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
    return '${_formatDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  InputDecoration _dropdownDecoration(BuildContext context) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: context.appCard,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      borderSide: BorderSide(color: context.appBorder),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(platformMetricsProvider);
    final searchAsync = ref.watch(platformSearchProvider(_search));
    final organizationsAsync = ref.watch(organizationsListProvider);
    final auditLogAsync = ref.watch(platformAuditLogProvider(_appliedFilter));

    return SuperAdminScaffold(
      currentRoute: '/super-admin/oversight',
      title: 'Platform Oversight',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          metricsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Text('Failed to load metrics: $err'),
            data: (metrics) => Row(
              children: [
                Expanded(
                  child: MetricCard(
                    value: '${metrics.totalOrganizations}',
                    label: 'Clinics',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    value: '${metrics.totalBranches}',
                    label: 'Branches',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    value: '${metrics.totalActiveStaff}',
                    label: 'Active staff',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    value: '${metrics.totalPatients}',
                    label: 'Patients',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    value: '${metrics.totalAppointmentsThisMonth}',
                    label: 'Appts this month',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          CliniqnovvaCard(
            title: 'Search branches & staff (all clinics)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CliniqnovvaTextField(
                  label: 'Search',
                  controller: _searchController,
                  hint: 'Branch or staff name',
                  onChanged: (value) => setState(() => _search = value),
                ),
                if (_search.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  searchAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Text(
                      'Search failed: $err',
                      style: TextStyle(color: context.appSubtext),
                    ),
                    data: (results) {
                      if (results.isEmpty) {
                        return Text(
                          'No matches.',
                          style: TextStyle(color: context.appSubtext),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (results.branches.isNotEmpty) ...[
                            Text(
                              'Branches',
                              style: TextStyle(
                                color: context.appText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const CliniqnovvaTableHeader(
                              columns: ['Name', 'Clinic', 'Address'],
                            ),
                            for (final b in results.branches)
                              CliniqnovvaTableRow(
                                cells: [
                                  Text(
                                    b.name,
                                    style: TextStyle(
                                      color: context.appText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(b.organizationName ?? '—'),
                                  Text(b.address ?? '—'),
                                ],
                              ),
                            const SizedBox(height: 16),
                          ],
                          if (results.staff.isNotEmpty) ...[
                            Text(
                              'Staff',
                              style: TextStyle(
                                color: context.appText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const CliniqnovvaTableHeader(
                              columns: ['Name', 'Role', 'Clinic', 'Email'],
                            ),
                            for (final s in results.staff)
                              CliniqnovvaTableRow(
                                cells: [
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      color: context.appText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(s.role),
                                  Text(s.organizationName ?? '—'),
                                  Text(s.email ?? '—'),
                                ],
                              ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          CliniqnovvaCard(
            title:
                'View a record (any clinic) — read-only, every view is logged',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 180,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collection',
                            style: TextStyle(
                              color: context.appText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _recordCollection,
                            decoration: _dropdownDecoration(context),
                            items: const [
                              DropdownMenuItem(
                                value: 'patients',
                                child: Text('Patients'),
                              ),
                              DropdownMenuItem(
                                value: 'appointments',
                                child: Text('Appointments'),
                              ),
                              DropdownMenuItem(
                                value: 'invoices',
                                child: Text('Invoices'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _recordCollection =
                                  value ?? _recordCollection,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CliniqnovvaTextField(
                        label: 'Record ID',
                        controller: _recordIdController,
                        hint: 'e.g. AbC123...',
                      ),
                    ),
                    const SizedBox(width: 16),
                    CliniqnovvaButton(
                      label: 'View',
                      isFullWidth: false,
                      isLoading: _recordLoading,
                      onPressed: _viewRecord,
                    ),
                  ],
                ),
                if (_recordNotFound) ...[
                  const SizedBox(height: 16),
                  Text(
                    'No record found.',
                    style: TextStyle(color: context.appSubtext),
                  ),
                ],
                if (_recordResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.appSecondaryBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in _recordResult!.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: TextStyle(
                                color: context.appText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          CliniqnovvaCard(
            title: 'Platform audit log (all clinics)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinic',
                            style: TextStyle(
                              color: context.appText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          organizationsAsync.when(
                            loading: () => const SizedBox(height: 46),
                            error: (err, _) => const SizedBox(height: 46),
                            data: (orgs) => DropdownButtonFormField<String?>(
                              initialValue: _filterOrgId,
                              decoration: _dropdownDecoration(context),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All clinics'),
                                ),
                                for (final org in orgs)
                                  DropdownMenuItem(
                                    value: org.id,
                                    child: Text(org.name),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _filterOrgId = value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: CliniqnovvaTextField(
                        label: 'Actor ID',
                        controller: _filterActorController,
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: CliniqnovvaTextField(
                        label: 'Action',
                        controller: _filterActionController,
                        hint: 'e.g. organization.suspended',
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              color: context.appText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(
                              AppTheme.inputRadius,
                            ),
                            onTap: () => _pickDate(isFrom: true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: context.appCard,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.inputRadius,
                                ),
                                border: Border.all(color: context.appBorder),
                              ),
                              child: Text(
                                _formatDate(_filterDateFrom),
                                style: TextStyle(
                                  color: context.appText,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              color: context.appText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(
                              AppTheme.inputRadius,
                            ),
                            onTap: () => _pickDate(isFrom: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: context.appCard,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.inputRadius,
                                ),
                                border: Border.all(color: context.appBorder),
                              ),
                              child: Text(
                                _formatDate(_filterDateTo),
                                style: TextStyle(
                                  color: context.appText,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: CliniqnovvaButton(
                        label: 'Apply filters',
                        isFullWidth: false,
                        onPressed: _applyAuditFilter,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const CliniqnovvaTableHeader(
                  columns: ['Time', 'Action', 'Actor', 'Clinic', 'Target'],
                ),
                auditLogAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Failed to load audit log: $err',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No matching audit log entries.',
                          style: TextStyle(color: context.appSubtext),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final entry in entries)
                          CliniqnovvaTableRow(
                            cells: [
                              Text(
                                _formatDateTime(entry.timestamp),
                                style: TextStyle(
                                  color: context.appSubtext,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                entry.action,
                                style: TextStyle(
                                  color: context.appText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                entry.actorLabel ?? entry.actorRole ?? '—',
                                style: TextStyle(
                                  color: context.appSubtext,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                entry.organizationName ?? '—',
                                style: TextStyle(
                                  color: context.appSubtext,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${entry.targetCollection ?? '—'}/${entry.targetId ?? '—'}',
                                style: TextStyle(
                                  color: context.appSubtext,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
