import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../organizations/providers/organizations_provider.dart';

const _planBranchLimitLabels = {
  AppConstants.planBasic: '1 branch',
  AppConstants.planPro: '5 branches',
  AppConstants.planEnterprise: 'Unlimited branches',
};

/// Part 3 Task 2 — 480px slide-out panel from the right.
Future<void> showAddOrganizationPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add Organization',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => const Align(
      alignment: Alignment.centerRight,
      child: _AddOrganizationPanel(),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return SlideTransition(position: offset, child: child);
    },
  );
}

class _AddOrganizationPanel extends ConsumerStatefulWidget {
  const _AddOrganizationPanel();

  @override
  ConsumerState<_AddOrganizationPanel> createState() => _AddOrganizationPanelState();
}

class _AddOrganizationPanelState extends ConsumerState<_AddOrganizationPanel> {
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();
  String _plan = AppConstants.planBasic;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _adminEmailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final adminEmail = _adminEmailController.text.trim();
    if (name.isEmpty || adminEmail.isEmpty) {
      setState(() => _error = 'Organization name and Organization Admin email are required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(organizationsNotifierProvider.notifier)
          .create(
            name: name,
            subscriptionPlan: _plan,
            adminEmail: adminEmail,
            ownerContactName: _ownerNameController.text.trim().isEmpty ? null : _ownerNameController.text.trim(),
            ownerContactPhone: _ownerPhoneController.text.trim().isEmpty ? null : _ownerPhoneController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Organization created'),
          content: Text('$name was created and an invite was sent to $adminEmail.'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCard,
      child: SafeArea(
        child: SizedBox(
          width: 480,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add Organization',
                          style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const AppIcon(AppIcons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  CliniqnovvaTextField(
                    label: 'Organization name',
                    controller: _nameController,
                    hint: 'e.g. Kigali Family Clinic',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Subscription plan',
                    style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _plan,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: context.appCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                    ),
                    items: AppConstants.subscriptionPlans
                        .map(
                          (plan) => DropdownMenuItem(
                            value: plan,
                            child: Text('${plan[0].toUpperCase()}${plan.substring(1)} — ${_planBranchLimitLabels[plan]}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _plan = value ?? _plan),
                  ),
                  const SizedBox(height: 16),
                  CliniqnovvaTextField(label: 'Owner contact name', controller: _ownerNameController, hint: 'Optional'),
                  const SizedBox(height: 16),
                  CliniqnovvaTextField(
                    label: 'Owner contact phone',
                    controller: _ownerPhoneController,
                    hint: '+250 7XX XXX XXX',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  CliniqnovvaTextField(
                    label: 'Organization Admin email',
                    controller: _adminEmailController,
                    hint: 'admin@clinic.rw',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A temporary password is not set here — an invite email is sent instead.',
                    style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pillRedBg,
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.pillRedText, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  CliniqnovvaButton(label: 'Save', isLoading: _saving, onPressed: _saving ? null : _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
