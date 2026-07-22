import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../organizations/models/organization.dart';
import '../../organizations/providers/organizations_provider.dart';
import '../widgets/confirm_status_dialog.dart';
import '../widgets/super_admin_scaffold.dart';

/// Part 3 Task 3 — full organization info (editable), Activate/Suspend
/// toggle, its branches (read-only — branch creation itself is Part 6's
/// Organization Admin flow), and the Super Admin "create branch on this
/// org's behalf" support-exception path.
class OrganizationDetailScreen extends ConsumerStatefulWidget {
  const OrganizationDetailScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<OrganizationDetailScreen> createState() => _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState extends ConsumerState<OrganizationDetailScreen> {
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  String _plan = AppConstants.planBasic;
  bool _fieldsLoaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    super.dispose();
  }

  void _loadFields(Organization org) {
    if (_fieldsLoaded) return;
    _fieldsLoaded = true;
    _nameController.text = org.name;
    _ownerNameController.text = org.ownerContactName ?? '';
    _ownerPhoneController.text = org.ownerContactPhone ?? '';
    _plan = org.subscriptionPlan;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(organizationsNotifierProvider.notifier)
          .updateOrganization(widget.organizationId, {
            'name': _nameController.text.trim(),
            'subscriptionPlan': _plan,
            'ownerContactName': _ownerNameController.text.trim(),
            'ownerContactPhone': _ownerPhoneController.text.trim(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organization updated.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus(Organization org) async {
    final activate = !org.isActive;
    final confirmed = await confirmOrganizationStatusChange(context, organizationName: org.name, activate: activate);
    if (!confirmed) return;
    await ref.read(organizationsNotifierProvider.notifier).setStatus(org.id, activate);
  }

  Future<void> _createBranchOnBehalf() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create branch on this org\'s behalf'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CliniqnovvaTextField(label: 'Branch name', controller: nameController),
              const SizedBox(height: 16),
              CliniqnovvaTextField(label: 'Address', controller: addressController, hint: 'Optional'),
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
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text.trim().isNotEmpty),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != true || nameController.text.trim().isEmpty) return;

    await ref
        .read(organizationsNotifierProvider.notifier)
        .createBranchOnBehalf(
          widget.organizationId,
          name: nameController.text.trim(),
          address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Branch created on this organization\'s behalf — logged in the audit trail.')));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(organizationDetailProvider(widget.organizationId));

    return SuperAdminScaffold(
      currentRoute: '/super-admin/organizations',
      title: 'Organization detail',
      body: detailAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (err, _) => Text('Failed to load organization: $err'),
        data: (org) {
          _loadFields(org);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      org.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  StatusBadge(
                    text: org.isActive ? 'Active' : 'Suspended',
                    type: org.isActive ? BadgeType.success : BadgeType.error,
                  ),
                  const SizedBox(width: 12),
                  CliniqnovvaButton(
                    label: org.isActive ? 'Suspend' : 'Activate',
                    isFullWidth: false,
                    onPressed: () => _toggleStatus(org),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CliniqnovvaCard(
                title: 'Organization info',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CliniqnovvaTextField(label: 'Organization name', controller: _nameController),
                    const SizedBox(height: 16),
                    const Text(
                      'Subscription plan',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _plan,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.pageBackground,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                          borderSide: const BorderSide(color: Color(0xFFD8E8E6)),
                        ),
                      ),
                      items: AppConstants.subscriptionPlans
                          .map(
                            (plan) => DropdownMenuItem(value: plan, child: Text('${plan[0].toUpperCase()}${plan.substring(1)}')),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _plan = value ?? _plan),
                    ),
                    const SizedBox(height: 4),
                    Text('Branches used: ${org.branchLimitLabel}', style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    CliniqnovvaTextField(label: 'Owner contact name', controller: _ownerNameController),
                    const SizedBox(height: 16),
                    CliniqnovvaTextField(
                      label: 'Owner contact phone',
                      controller: _ownerPhoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    CliniqnovvaButton(label: 'Save changes', isFullWidth: false, isLoading: _saving, onPressed: _save),
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
                        const Expanded(
                          child: Text(
                            'Branches',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        CliniqnovvaButton.text(
                          label: '+ Create branch on this org\'s behalf',
                          onPressed: _createBranchOnBehalf,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const CliniqnovvaTableHeader(columns: ['Name', 'Address', 'Phone', 'Status']),
                    if (org.branches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No branches yet.', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      for (final branch in org.branches)
                        CliniqnovvaTableRow(
                          cells: [
                            Text(branch.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            Text(branch.address ?? '—'),
                            Text(branch.phone ?? '—'),
                            StatusBadge(
                              text: branch.isActive ? 'Active' : 'Inactive',
                              type: branch.isActive ? BadgeType.success : BadgeType.error,
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
