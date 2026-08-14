import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../clinics/providers/clinics_provider.dart';

const _planBranchLimitLabels = {
  AppConstants.planBasic: '1 branch',
  AppConstants.planPro: '5 branches',
  AppConstants.planEnterprise: 'Unlimited branches',
};

/// Part 3 Task 2 — 480px centered modal.
Future<void> showAddClinicPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Add Clinic',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const Center(child: _AddClinicPanel()),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _AddClinicPanel extends ConsumerStatefulWidget {
  const _AddClinicPanel();

  @override
  ConsumerState<_AddClinicPanel> createState() =>
      _AddClinicPanelState();
}

class _AddClinicPanelState extends ConsumerState<_AddClinicPanel> {
  final _nameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _subscriptionAmountController = TextEditingController();
  String _plan = AppConstants.planBasic;
  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _subscriptionAmountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final adminEmail = _adminEmailController.text.trim();
    final adminPassword = _adminPasswordController.text;
    if (name.isEmpty || adminEmail.isEmpty || adminPassword.isEmpty) {
      setState(
        () => _error =
            'Clinic name, Clinic Admin email, and password are required.',
      );
      return;
    }
    if (adminPassword.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await runWithFeedback(
        context,
        () => ref
            .read(clinicsNotifierProvider.notifier)
            .create(
              name: name,
              subscriptionPlan: _plan,
              adminEmail: adminEmail,
              adminPassword: adminPassword,
              ownerContactName: _ownerNameController.text.trim().isEmpty
                  ? null
                  : _ownerNameController.text.trim(),
              ownerContactPhone: _ownerPhoneController.text.trim().isEmpty
                  ? null
                  : _ownerPhoneController.text.trim(),
              subscriptionAmountRwf: int.tryParse(
                _subscriptionAmountController.text.trim(),
              ),
            ),
        loadingMessage: 'Creating clinic…',
        successMessage: 'Clinic created.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Clinic created'),
          content: Text(
            '$name was created. The clinic admin can sign in with $adminEmail and the password you set.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
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
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: context.appBorder),
        ),
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Clinic',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
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
                  label: 'Clinic name',
                  controller: _nameController,
                  hint: 'e.g. Kigali Family Clinic',
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
                AppSelect(
                  value: _plan,
                  options: AppConstants.subscriptionPlans
                      .map(
                        (plan) => AppSelectOption(
                          value: plan,
                          label: '${plan[0].toUpperCase()}${plan.substring(1)} — ${_planBranchLimitLabels[plan]}',
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _plan = value ?? _plan),
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Subscription amount (RWF)',
                  controller: _subscriptionAmountController,
                  hint: 'Amount they\'re paying per billing cycle',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Owner contact name',
                  controller: _ownerNameController,
                  hint: 'Optional',
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Owner contact phone',
                  controller: _ownerPhoneController,
                  hint: '+250 7XX XXX XXX',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Clinic Admin email',
                  controller: _adminEmailController,
                  hint: 'admin@clinic.rw',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Clinic Admin password',
                  controller: _adminPasswordController,
                  hint: 'At least 6 characters',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: AppIcon(
                      _obscurePassword ? AppIcons.view : AppIcons.eyeSlash,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
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
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.pillRedText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                CliniqnovvaButton(
                  label: 'Save',
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
