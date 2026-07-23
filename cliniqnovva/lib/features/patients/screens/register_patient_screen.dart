import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart';
import '../models/patient_model.dart';
import '../providers/patients_provider.dart';
import '../widgets/patient_form_fields.dart';

/// Part 9 Task 2 — /patients/register. Front-desk registration: phone is
/// the only required identifier (spec 6.5A — no smartphone/app account
/// needed). On submit, a duplicate-check runs first and WARNS on a match
/// rather than blocking — full merge handling is Part 10's scope.
class RegisterPatientScreen extends ConsumerWidget {
  const RegisterPatientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          final isOrgAdmin = role == AppConstants.roleOrganizationAdmin;
          final ownBranchId = data?['branchId'] as String?;
          return _RegisterForm(
            branchId: isOrgAdmin ? null : ownBranchId,
          );
        },
      ),
    );
  }
}

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({required this.branchId});

  final String? branchId;

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _addressKey = GlobalKey<PatientAddressFormState>();

  DateTime? _dob;
  String? _gender;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) return 'Full name is required.';
    if (_phoneController.text.trim().isEmpty) return 'Phone is required.';
    final nationalId = _nationalIdController.text.trim();
    if (nationalId.isNotEmpty && !RegExp(r'^\d{16}$').hasMatch(nationalId)) {
      return 'National ID must be exactly 16 digits.';
    }
    if (!_addressKey.currentState!.isValid) {
      return 'Enter both province and district, or leave the address blank.';
    }
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final phone = _phoneController.text.trim();
    final nationalId = _nationalIdController.text.trim();

    try {
      final matches = await ref
          .read(patientsNotifierProvider.notifier)
          .checkDuplicate(
            phone: phone,
            nationalId: nationalId.isEmpty ? null : nationalId,
          );

      if (matches.isNotEmpty && mounted) {
        final proceed = await _showDuplicateWarning(matches);
        if (proceed != true) {
          setState(() => _saving = false);
          return;
        }
      }

      final branchId = widget.branchId ?? ref.read(activeBranchIdProvider);
      if (branchId == null) {
        setState(() {
          _saving = false;
          _error = 'No branch to register this patient under.';
        });
        return;
      }

      final patient = await ref
          .read(patientsNotifierProvider.notifier)
          .register(
            branchId: branchId,
            name: _nameController.text.trim(),
            phone: phone,
            dateOfBirth: _dob,
            gender: _gender,
            nationalId: nationalId.isEmpty ? null : nationalId,
            emergencyContact:
                _emergencyNameController.text.trim().isEmpty &&
                    _emergencyPhoneController.text.trim().isEmpty
                ? null
                : EmergencyContact(
                    name: _emergencyNameController.text.trim().isEmpty
                        ? null
                        : _emergencyNameController.text.trim(),
                    phone: _emergencyPhoneController.text.trim().isEmpty
                        ? null
                        : _emergencyPhoneController.text.trim(),
                  ),
            location: _addressKey.currentState!.value,
          );

      if (!mounted) return;
      context.go('/patients/${patient.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<bool?> _showDuplicateWarning(List<DuplicateMatch> matches) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Possible existing patient'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A patient with this phone or National ID already exists:',
              ),
              const SizedBox(height: 12),
              for (final match in matches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${match.name} — ${match.phone}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Register anyway if this is genuinely a different person.',
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
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Register anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register Patient',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Phone is the only required field — everything else can be filled in later.',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              ),
              const SizedBox(height: 24),
              CliniqnovvaTextField(
                label: 'Full name',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              CliniqnovvaTextField(
                label: 'Phone',
                controller: _phoneController,
                hint: '+250 7XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PatientDateField(
                      label: 'Date of birth',
                      date: _dob,
                      onTap: _pickDob,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GenderDropdown(
                      value: _gender,
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CliniqnovvaTextField(
                label: 'National ID (optional)',
                controller: _nationalIdController,
                hint: '16 digits',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CliniqnovvaTextField(
                      label: 'Emergency contact name',
                      controller: _emergencyNameController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CliniqnovvaTextField(
                      label: 'Emergency contact phone',
                      controller: _emergencyPhoneController,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Address (optional)',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              PatientAddressForm(key: _addressKey),
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
              Row(
                children: [
                  CliniqnovvaButton.text(
                    label: 'Cancel',
                    color: context.appText,
                    onPressed: _saving ? null : () => context.go('/patients'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 180,
                    child: CliniqnovvaButton(
                      label: 'Register',
                      isLoading: _saving,
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
