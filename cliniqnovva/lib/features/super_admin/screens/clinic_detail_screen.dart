import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../clinics/models/clinic.dart';
import '../../clinics/providers/clinics_provider.dart';
import '../widgets/confirm_status_dialog.dart';
import '../widgets/super_admin_scaffold.dart';

/// Part 3 Task 3 — full clinic info (editable), Activate/Suspend
/// toggle, its branches (read-only — branch creation itself is Part 6's
/// Clinic Admin flow), and the Super Admin "create branch on this
/// org's behalf" support-exception path.
class ClinicDetailScreen extends ConsumerStatefulWidget {
  const ClinicDetailScreen({super.key, required this.clinicId});

  final String clinicId;

  @override
  ConsumerState<ClinicDetailScreen> createState() =>
      _ClinicDetailScreenState();
}

class _ClinicDetailScreenState
    extends ConsumerState<ClinicDetailScreen> {
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _subscriptionAmountController = TextEditingController();
  String _plan = AppConstants.planBasic;
  String _billingCycle = 'monthly';
  bool _fieldsLoaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _subscriptionAmountController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _atBranchLimit(Clinic org) =>
      org.branchLimit != null && org.branchCount >= org.branchLimit!;

  void _loadFields(Clinic org) {
    if (_fieldsLoaded) return;
    _fieldsLoaded = true;
    _nameController.text = org.name;
    _ownerNameController.text = org.ownerContactName ?? '';
    _ownerPhoneController.text = org.ownerContactPhone ?? '';
    _plan = org.subscriptionPlan;
    _billingCycle = org.billingCycle;
    _subscriptionAmountController.text = org.subscriptionAmountRwf.toString();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await runWithFeedback(
        context,
        () => ref
            .read(clinicsNotifierProvider.notifier)
            .updateClinic(widget.clinicId, {
              'name': _nameController.text.trim(),
              'subscriptionPlan': _plan,
              'ownerContactName': _ownerNameController.text.trim(),
              'ownerContactPhone': _ownerPhoneController.text.trim(),
              'billingCycle': _billingCycle,
              'subscriptionAmountRwf':
                  int.tryParse(_subscriptionAmountController.text.trim()) ?? 0,
            }),
        loadingMessage: 'Saving changes…',
        successMessage: 'Clinic updated.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Delete clinic" (2026-07-25) — archives, doesn't hard-delete. Works
  /// regardless of what's linked to the clinic (branches, staff, patients,
  /// etc.), unlike the old branch-count-gated hard delete.
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

  Future<void> _toggleStatus(Clinic org) async {
    final activate = !org.isActive;
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

  Future<void> _createBranchOnBehalf() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create branch on this clinic\'s behalf'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CliniqnovvaTextField(
                label: 'Branch name',
                controller: nameController,
              ),
              const SizedBox(height: 16),
              CliniqnovvaTextField(
                label: 'Address',
                controller: addressController,
                hint: 'Optional',
              ),
              const SizedBox(height: 16),
              CliniqnovvaTextField(
                label: 'Phone',
                controller: phoneController,
                hint: '+250 7XX XXX XXX (optional)',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              nameController.text.trim().isNotEmpty,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != true || nameController.text.trim().isEmpty || !mounted) {
      return;
    }

    await runWithFeedback(
      context,
      () => ref
          .read(clinicsNotifierProvider.notifier)
          .createBranchOnBehalf(
            widget.clinicId,
            name: nameController.text.trim(),
            address: addressController.text.trim().isEmpty
                ? null
                : addressController.text.trim(),
            phone: phoneController.text.trim().isEmpty
                ? null
                : phoneController.text.trim(),
          ),
      loadingMessage: 'Creating branch…',
      successMessage: 'Branch created on this clinic\'s behalf.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      clinicDetailProvider(widget.clinicId),
    );

    return SuperAdminScaffold(
      currentRoute: '/super-admin/clinics',
      title: 'Clinic detail',
      body: detailAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Text('Failed to load clinic: $err'),
        data: (org) {
          _loadFields(org);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (org.isArchived) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pillRedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const AppIcon(
                        AppIcons.warning,
                        size: 18,
                        color: AppColors.pillRedText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Archived — permanently deleted in '
                          '${org.daysUntilPurge} day${org.daysUntilPurge == 1 ? '' : 's'} '
                          'unless restored.',
                          style: const TextStyle(
                            color: AppColors.pillRedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CliniqnovvaButton.text(
                        label: 'Unarchive',
                        color: AppColors.pillRedText,
                        onPressed: () => _unarchive(org),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      org.name,
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  StatusBadge(
                    text: org.isActive ? 'Active' : 'Suspended',
                    type: org.isActive ? BadgeType.success : BadgeType.error,
                  ),
                  if (!org.isArchived) ...[
                    const SizedBox(width: 12),
                    CliniqnovvaButton.text(
                      label: 'View as Clinic Admin',
                      onPressed: () => context.push(
                        '/super-admin/clinics/${org.id}/support-view',
                      ),
                    ),
                    const SizedBox(width: 4),
                    CliniqnovvaButton.text(
                      label: 'Delete clinic',
                      color: context.appSubtext,
                      onPressed: () => _confirmArchive(org),
                    ),
                    const SizedBox(width: 4),
                    CliniqnovvaButton(
                      label: org.isActive ? 'Suspend' : 'Activate',
                      isFullWidth: false,
                      onPressed: () => _toggleStatus(org),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              CliniqnovvaCard(
                title: 'Clinic info',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CliniqnovvaTextField(
                      label: 'Clinic name',
                      controller: _nameController,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Subscription plan',
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _plan,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: context.appCard,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.inputRadius,
                          ),
                          borderSide: BorderSide(color: context.appBorder),
                        ),
                      ),
                      items: AppConstants.subscriptionPlans
                          .map(
                            (plan) => DropdownMenuItem(
                              value: plan,
                              child: Text(
                                '${plan[0].toUpperCase()}${plan.substring(1)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _plan = value ?? _plan),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Branches used: ${org.branchLimitLabel}',
                      style: TextStyle(color: context.appSubtext),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Billing cycle',
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _billingCycle,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: context.appCard,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.inputRadius,
                          ),
                          borderSide: BorderSide(color: context.appBorder),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'quarterly',
                          child: Text('Quarterly'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _billingCycle = value ?? _billingCycle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CliniqnovvaTextField(
                      label: 'Subscription amount (RWF)',
                      controller: _subscriptionAmountController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Next due: ${_formatDate(org.nextDueDate)}',
                      style: TextStyle(color: context.appSubtext),
                    ),
                    const SizedBox(height: 16),
                    CliniqnovvaTextField(
                      label: 'Owner contact name',
                      controller: _ownerNameController,
                    ),
                    const SizedBox(height: 16),
                    CliniqnovvaTextField(
                      label: 'Owner contact phone',
                      controller: _ownerPhoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    if (!org.isArchived) ...[
                      const SizedBox(height: 20),
                      CliniqnovvaButton(
                        label: 'Save changes',
                        isFullWidth: false,
                        isLoading: _saving,
                        onPressed: _save,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CliniqnovvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Branches',
                            style: TextStyle(
                              color: context.appText,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CliniqnovvaButton.text(
                          label: '+ Create branch on this clinic\'s behalf',
                          onPressed: _atBranchLimit(org) || org.isArchived
                              ? null
                              : _createBranchOnBehalf,
                        ),
                      ],
                    ),
                    if (_atBranchLimit(org)) ...[
                      const SizedBox(height: 4),
                      Text(
                        'This clinic\'s plan allows ${org.branchLimit} branch${org.branchLimit == 1 ? '' : 'es'} — upgrade the plan to add more.',
                        style: TextStyle(
                          color: context.appSubtext,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    const CliniqnovvaTableHeader(
                      columns: ['Name', 'Address', 'Phone', 'Status'],
                    ),
                    if (org.branches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No branches yet.',
                          style: TextStyle(color: context.appSubtext),
                        ),
                      )
                    else
                      for (final branch in org.branches)
                        CliniqnovvaTableRow(
                          cells: [
                            Text(
                              branch.name,
                              style: TextStyle(
                                color: context.appText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(branch.address ?? '—'),
                            Text(branch.phone ?? '—'),
                            StatusBadge(
                              text: branch.isActive ? 'Active' : 'Inactive',
                              type: branch.isActive
                                  ? BadgeType.success
                                  : BadgeType.error,
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
