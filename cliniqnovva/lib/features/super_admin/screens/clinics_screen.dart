import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/row_actions_menu.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../clinics/models/clinic.dart';
import '../../clinics/providers/clinics_provider.dart';
import '../widgets/add_clinic_panel.dart';
import '../widgets/confirm_status_dialog.dart';
import '../widgets/super_admin_scaffold.dart';

/// Part 3 Task 1 — Super Admin's clinic list: summary MetricCards,
/// search, "+ Add Clinic", and the clinics table.
class ClinicsScreen extends ConsumerStatefulWidget {
  const ClinicsScreen({super.key});

  @override
  ConsumerState<ClinicsScreen> createState() =>
      _ClinicsScreenState();
}

class _ClinicsScreenState extends ConsumerState<ClinicsScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// "Delete clinic" (2026-07-25) — archives, doesn't hard-delete. Works
  /// regardless of what's linked to the clinic (branches, staff, patients,
  /// etc. — everything), unlike the old branch-count-gated hard delete.
  Future<void> _confirmArchive(Clinic org) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete clinic?'),
        content: Text(
          '"${org.name}" and everything linked to it (branches, staff, '
          'patients, appointments, invoices) will be archived immediately '
          'and permanently deleted in 14 days unless you restore it before '
          'then.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await runWithFeedback(
        context,
        () => ref.read(clinicsNotifierProvider.notifier).archive(org.id),
        loadingMessage: 'Archiving clinic…',
        successMessage: 'Clinic archived — permanently deleted in 14 days.',
      );
    } catch (_) {
      // runWithFeedback already surfaced the server's reason.
    }
  }

  Future<void> _unarchive(Clinic org) async {
    await runWithFeedback(
      context,
      () => ref.read(clinicsNotifierProvider.notifier).unarchive(org.id),
      loadingMessage: 'Restoring clinic…',
      successMessage: 'Clinic restored.',
    );
  }

  Future<void> _confirmSetStatus(Clinic org, bool activate) async {
    final confirmed = await confirmClinicStatusChange(
      context,
      clinicName: org.name,
      activate: activate,
    );
    if (!confirmed || !mounted) return;
    await runWithFeedback(
      context,
      () => ref
          .read(clinicsNotifierProvider.notifier)
          .setStatus(org.id, activate),
      loadingMessage: activate ? 'Activating clinic…' : 'Suspending clinic…',
      successMessage: activate ? 'Clinic activated.' : 'Clinic suspended.',
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final clinicsAsync = ref.watch(clinicsListProvider);

    return SuperAdminScaffold(
      currentRoute: '/super-admin/clinics',
      title: 'Clinics',
      body: clinicsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Text('Failed to load clinics: $err'),
        data: (clinics) {
          final live = clinics.where((o) => !o.isArchived).toList();
          final archived = clinics.where((o) => o.isArchived).toList();
          final total = live.length;
          final active = live.where((o) => o.isActive).length;
          final suspended = total - active;

          final base = _showArchived ? archived : live;
          final filtered = _search.isEmpty
              ? base
              : base
                    .where(
                      (o) =>
                          o.name.toLowerCase().contains(_search.toLowerCase()),
                    )
                    .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(value: '$total', label: 'Total clinics'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(value: '$active', label: 'Active'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(value: '$suspended', label: 'Suspended'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      value: '${archived.length}',
                      label: 'Archived',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CliniqnovvaTextField(
                      label: 'Search',
                      controller: _searchController,
                      hint: 'Search by name',
                      onChanged: (value) => setState(() => _search = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (archived.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 12),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _showArchived = !_showArchived),
                        child: Text(
                          _showArchived
                              ? 'Show active clinics'
                              : 'Show archived (${archived.length})',
                          style: TextStyle(
                            color: context.appText,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  CliniqnovvaButton(
                    label: '+ Add Clinic',
                    isFullWidth: false,
                    onPressed: () => showAddClinicPanel(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CliniqnovvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CliniqnovvaTableHeader(
                      columns: [
                        'Name',
                        'Plan',
                        'Branches',
                        'Status',
                        'Created',
                        'Actions',
                      ],
                    ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _showArchived
                              ? 'No archived clinics.'
                              : 'No clinics yet.',
                          style: TextStyle(color: context.appSubtext),
                        ),
                      )
                    else
                      for (final org in filtered)
                        CliniqnovvaTableRow(
                          onTap: () => context.push(
                            '/super-admin/clinics/${org.id}',
                          ),
                          cells: [
                            Text(
                              org.name,
                              style: TextStyle(
                                color: context.appText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${org.subscriptionPlan[0].toUpperCase()}${org.subscriptionPlan.substring(1)}',
                            ),
                            Text(org.branchLimitLabel),
                            org.isArchived
                                ? StatusBadge(
                                    text:
                                        'Archived — ${org.daysUntilPurge}d left',
                                    type: BadgeType.error,
                                  )
                                : StatusBadge(
                                    text: org.isActive ? 'Active' : 'Suspended',
                                    type: org.isActive
                                        ? BadgeType.success
                                        : BadgeType.error,
                                  ),
                            Text(_formatDate(org.createdAt)),
                            org.isArchived
                                ? RowActionsMenu(
                                    actions: [
                                      RowAction(
                                        label: 'Unarchive',
                                        onTap: () => _unarchive(org),
                                      ),
                                    ],
                                  )
                                : RowActionsMenu(
                                    actions: [
                                      RowAction(
                                        label: 'View',
                                        onTap: () => context.push(
                                          '/super-admin/clinics/${org.id}',
                                        ),
                                      ),
                                      RowAction(
                                        label: org.isActive
                                            ? 'Suspend'
                                            : 'Activate',
                                        onTap: () => _confirmSetStatus(
                                          org,
                                          !org.isActive,
                                        ),
                                      ),
                                      RowAction(
                                        label: 'Delete',
                                        isDestructive: true,
                                        onTap: () => _confirmArchive(org),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
