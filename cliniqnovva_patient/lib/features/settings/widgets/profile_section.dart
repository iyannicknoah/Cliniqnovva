import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../providers/settings_provider.dart';

/// Part 26 Task 1's editable profile form — name/phone/email/date of
/// birth/National ID, all on the account's own `/users/{uid}` doc (see
/// `settings_provider.dart`'s doc comment for why, not the walk-in
/// `/patients/{id}` record). Pre-filled from the live
/// [patientProfileProvider] stream once, then left alone — re-seeding the
/// controllers on every snapshot would clobber whatever the patient is
/// mid-typing.
class ProfileSection extends ConsumerStatefulWidget {
  const ProfileSection({super.key});

  @override
  ConsumerState<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<ProfileSection> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalIdController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _initialized = false;
  String? _error;

  void _initFrom(Map<String, dynamic> data) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = data['name'] as String? ?? '';
    _phoneController.text = data['phone'] as String? ?? '';
    _emailController.text = data['email'] as String? ?? '';
    _nationalIdController.text = data['nationalId'] as String? ?? '';
    final dob = data['dateOfBirth'] as String?;
    _dateOfBirth = dob != null ? DateTime.tryParse(dob) : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      await ref.read(settingsNotifierProvider.notifier).updateProfile(
            name: _nameController.text,
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            dateOfBirth: _dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!) : null,
            nationalId: _nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings_profile_saved'.tr())));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(patientProfileProvider).valueOrNull;
    if (profile != null) _initFrom(profile);
    final isLoading = ref.watch(settingsNotifierProvider).isLoading;

    return CliniqnovvaCard(
      title: 'settings_profile'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CliniqnovvaTextField(label: 'field_full_name'.tr(), controller: _nameController),
          const SizedBox(height: 14),
          CliniqnovvaTextField(label: 'field_phone'.tr(), controller: _phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
          CliniqnovvaTextField(label: 'field_email_optional'.tr(), controller: _emailController, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          Text('settings_date_of_birth'.tr(), style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateOfBirth,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              decoration: BoxDecoration(border: Border.all(color: context.appBorder), borderRadius: BorderRadius.circular(12)),
              child: Text(
                _dateOfBirth != null ? DateFormat.yMMMd().format(_dateOfBirth!) : 'settings_date_of_birth_hint'.tr(),
                style: TextStyle(color: _dateOfBirth != null ? context.appText : context.appSubtext, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 14),
          CliniqnovvaTextField(label: 'settings_national_id'.tr(), controller: _nationalIdController, keyboardType: TextInputType.number),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          CliniqnovvaButton(label: 'action_save'.tr(), isLoading: isLoading, onPressed: _save),
        ],
      ),
    );
  }
}
