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
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../models/patient_model.dart';
import '../providers/patients_provider.dart';
import '../widgets/patient_form_fields.dart';
import 'patient_profile_screen.dart';

/// Part 9 Task 2's front-desk registration form. 2026-08-14, explicit user
/// instruction — switched from a full routed page (`/patients/register`) to
/// a centered modal dialog, matching Add Branch/Add Service's pattern
/// (`Material` + rounded `AppTheme.cardRadius` corners, fade+scale
/// transition). Phone is the only required identifier (spec 6.5A — no
/// smartphone/app account needed). On submit, a duplicate-check runs first
/// and WARNS on a match rather than blocking — full merge handling is Part
/// 10's scope.
///
/// Part 11 Task 1's "register new" shortcut from the Booking dialog passes
/// [returnPatientId] — on success (or "use existing record"), this pops
/// itself with the patient id as the dialog's result (`Navigator.pop(id)`)
/// instead of opening the usual Patient Profile panel, so the booking
/// dialog underneath can just `await` this call and pick up the new patient
/// directly. (2026-08-15 — replaced the old `returnTo` route-string param,
/// which navigated to `/appointments/book?patientId=…`; that route no
/// longer exists now that booking is a dialog too.)
Future<String?> showRegisterPatientPanel(
  BuildContext context, {
  bool returnPatientId = false,
}) {
  return showGeneralDialog<String?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Register Patient',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: _RegisterPatientPanel(returnPatientId: returnPatientId),
    ),
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

class _RegisterPatientPanel extends ConsumerWidget {
  const _RegisterPatientPanel({this.returnPatientId = false});

  final bool returnPatientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

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
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: claims.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(60),
            child: LoadingWidget(),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: TextStyle(color: context.appSubtext)),
          ),
          data: (data) {
            final role = data?['role'] as String?;
            final isOrgAdmin = role == AppConstants.roleClinicAdmin;
            final ownBranchId = data?['branchId'] as String?;
            return _RegisterForm(
              branchId: isOrgAdmin ? null : ownBranchId,
              showBranchSelector: isOrgAdmin,
              returnPatientId: returnPatientId,
            );
          },
        ),
      ),
    );
  }
}

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({
    required this.branchId,
    required this.showBranchSelector,
    this.returnPatientId = false,
  });

  final bool returnPatientId;

  final String? branchId;

  /// True for a Clinic Admin — shown so that if "All branches" is the
  /// active filter, they can pick the one branch this patient registers
  /// under instead of hitting the "No branch to register this patient
  /// under" error with no way to fix it from this screen.
  final bool showBranchSelector;

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

  /// Part 10 Task 1 — submits directly; the server itself checks for a
  /// duplicate and responds with a "possible duplicate" outcome instead of
  /// creating. [confirmedDuplicate] is only ever true on the resubmit after
  /// the user picked "No, create new patient" below.
  Future<void> _submit({bool confirmedDuplicate = false}) async {
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
    final branchId = widget.branchId ?? ref.read(activeBranchIdProvider);
    if (branchId == null) {
      setState(() {
        _saving = false;
        _error = 'No branch to register this patient under.';
      });
      return;
    }

    try {
      final result = await ref
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
            confirmedDuplicate: confirmedDuplicate,
          );

      if (!mounted) return;

      switch (result) {
        case PatientCreated(:final patient):
          _goToPatient(patient.id);
        case PatientPossibleDuplicate(:final matches):
          setState(() => _saving = false);
          await _handlePossibleDuplicate(matches);
        case PatientQueuedOffline():
          // No created patient id yet (see PatientQueuedOffline's doc) —
          // show what happened and close, rather than trying to deep-link
          // anywhere. Also skips returnTo/booking hand-off: booking isn't
          // one of the offline-capable flows, so there's no patient to hand
          // back to it yet either.
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Saved locally — will sync automatically once you\'re back online.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  void _goToPatient(String patientId) {
    if (widget.returnPatientId) {
      Navigator.of(context).pop(patientId);
    } else {
      Navigator.of(context).pop();
      showPatientProfilePanel(context, id: patientId);
    }
  }

  /// "Is this the same person?" — Yes navigates to the existing record
  /// without creating anything; No resubmits with confirmedDuplicate so the
  /// server skips its own check this time (Part 10 Task 1's exact wording).
  Future<void> _handlePossibleDuplicate(List<DuplicateMatch> matches) async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Is this the same person?'),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No, create new patient'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, use existing record'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (choice == true) {
      _goToPatient(matches.first.id);
    } else if (choice == false) {
      await _submit(confirmedDuplicate: true);
    }
    // choice == null (dialog dismissed): leave the form as-is, no action.
  }

  @override
  Widget build(BuildContext context) {
    // 2026-08-15, explicit user instruction — Register is disabled while
    // "All branches" is the active filter, since a patient always belongs
    // to exactly one branch and submitting in that state would otherwise
    // just fail with "No branch to register this patient under." For a
    // non-org-admin, `widget.branchId` is already a real branch, so this is
    // always false for them.
    final effectiveBranchId =
        widget.branchId ?? ref.watch(activeBranchIdProvider);
    final noBranchSelected = effectiveBranchId == null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Register Patient',
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.showBranchSelector) ...[
                  const BranchSelector(),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  icon: const AppIcon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Phone is the only required field — everything else can be filled in later.',
              style: TextStyle(color: context.appSubtext, fontSize: 13),
            ),
            const SizedBox(height: 20),
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
            if (noBranchSelected) ...[
              const SizedBox(height: 16),
              Text(
                'Select a specific branch above — "All branches" can\'t be used to register a patient.',
                style: TextStyle(color: context.appSubtext, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                CliniqnovvaButton.text(
                  label: 'Cancel',
                  color: context.appText,
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                CliniqnovvaButton(
                  label: 'Register',
                  isLoading: _saving,
                  onPressed: _saving || noBranchSelected ? null : _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
