import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_logo.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../clinics/models/branch_model.dart';
import '../../clinics/providers/branches_provider.dart';
import '../../departments/models/service_model.dart';
import '../../departments/providers/services_provider.dart';
import '../../staff/models/staff_model.dart';
import '../../staff/providers/staff_provider.dart';
import '../providers/go_public_provider.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

const _stepTitles = ['Clinic info', 'Services', 'Doctors', 'Payout', 'Go live'];

/// 2026-08-16, explicit user instruction — the "Go Public" wizard: tabs of
/// steps on the left (ticked once done), content on the right, "Save and
/// Next" per step. Opened from [GoPublicScreen]'s "Go Public" button, or
/// re-opened any time to review/edit an already-public profile. [initialStep]
/// lets a caller (e.g. a future "fix this step" link) jump straight to one.
Future<void> showGoPublicWizard(
  BuildContext context, {
  required String branchId,
  int initialStep = 0,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Go Public',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: _GoPublicWizard(branchId: branchId, initialStep: initialStep),
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

class _GoPublicWizard extends ConsumerStatefulWidget {
  const _GoPublicWizard({required this.branchId, required this.initialStep});

  final String branchId;
  final int initialStep;

  @override
  ConsumerState<_GoPublicWizard> createState() => _GoPublicWizardState();
}

class _GoPublicWizardState extends ConsumerState<_GoPublicWizard> {
  late int _activeStep = widget.initialStep;
  bool _seeded = false;

  // Step 1 — clinic info.
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _pickedImageContentType;

  // Step 2/3 — services/doctors selection.
  Set<String> _selectedServiceIds = {};
  Set<String> _selectedDoctorIds = {};

  // Step 4 — payout.
  String? _payoutMethod;
  final _payoutPhoneCtrl = TextEditingController();
  final _payoutAccountNameCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  bool _payoutConfirmed = false;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _payoutPhoneCtrl.dispose();
    _payoutAccountNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    super.dispose();
  }

  /// Only runs once per dialog open — the text fields are the source of
  /// truth once edited, so this must not clobber in-progress typing every
  /// time [branchDetailProvider] refetches after a save.
  void _seedFromBranch(BranchModel branch) {
    if (_seeded) return;
    _seeded = true;
    _nameCtrl.text = branch.publicDisplayName ?? '';
    _phoneCtrl.text = branch.publicPhone ?? '';
    _emailCtrl.text = branch.publicEmail ?? '';
    _addressCtrl.text = branch.publicAddress ?? '';
    _selectedServiceIds = {...(branch.publicServiceIds ?? const [])};
    _selectedDoctorIds = {...(branch.publicDoctorIds ?? const [])};
    _payoutMethod = branch.payoutMethod;
    final details = branch.payoutDetails ?? const {};
    _payoutPhoneCtrl.text = details['phone'] ?? '';
    _payoutAccountNameCtrl.text = details['accountName'] ?? '';
    _bankNameCtrl.text = details['bankName'] ?? '';
    _bankAccountCtrl.text = details['accountNumber'] ?? '';
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
    final file = result?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;
    setState(() {
      _pickedImageBytes = file!.bytes;
      _pickedImageName = file.name;
      _pickedImageContentType = 'image/${file.extension ?? 'jpeg'}';
    });
  }

  Future<void> _runSave(Future<void> Function() action, {int? advanceTo}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (advanceTo != null) _activeStep = advanceTo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  Future<void> _saveInfo() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Fill in every field to continue.');
      return;
    }
    if (!_emailPattern.hasMatch(_emailCtrl.text.trim())) {
      setState(() => _error = 'Enter a valid public email address.');
      return;
    }
    if (_pickedImageBytes == null && ref.read(branchDetailProvider(widget.branchId)).valueOrNull?.publicImageKey == null) {
      setState(() => _error = 'Add a profile/banner image to continue.');
      return;
    }

    await _runSave(() async {
      final notifier = ref.read(branchesNotifierProvider.notifier);
      if (_pickedImageBytes != null) {
        await notifier.uploadBranchPublicImage(
          widget.branchId,
          bytes: _pickedImageBytes!,
          filename: _pickedImageName!,
          contentType: _pickedImageContentType!,
        );
      }
      await notifier.updateBranch(widget.branchId, {
        'publicDisplayName': _nameCtrl.text.trim(),
        'publicPhone': _phoneCtrl.text.trim(),
        'publicEmail': _emailCtrl.text.trim(),
        'publicAddress': _addressCtrl.text.trim(),
      });
    }, advanceTo: 1);
  }

  Future<void> _saveServices() async {
    await _runSave(
      () => ref
          .read(branchesNotifierProvider.notifier)
          .updateBranch(widget.branchId, {'publicServiceIds': _selectedServiceIds.toList()}),
      advanceTo: 2,
    );
  }

  Future<void> _saveDoctors() async {
    await _runSave(
      () => ref
          .read(branchesNotifierProvider.notifier)
          .updateBranch(widget.branchId, {'publicDoctorIds': _selectedDoctorIds.toList()}),
      advanceTo: 3,
    );
  }

  Future<void> _savePayout() async {
    if (_payoutMethod == null) {
      setState(() => _error = 'Choose a payout method.');
      return;
    }
    final details = _payoutMethod == 'bank'
        ? {
            'bankName': _bankNameCtrl.text.trim(),
            'accountNumber': _bankAccountCtrl.text.trim(),
            'accountName': _payoutAccountNameCtrl.text.trim(),
          }
        : {
            'phone': _payoutPhoneCtrl.text.trim(),
            'accountName': _payoutAccountNameCtrl.text.trim(),
          };
    if (details.values.any((v) => v.isEmpty)) {
      setState(() => _error = 'Fill in every payout field.');
      return;
    }
    if (!_payoutConfirmed) {
      setState(() => _error = 'Confirm you\'ve double-checked these details before saving.');
      return;
    }

    await _runSave(
      () => ref.read(branchesNotifierProvider.notifier).updateBranch(widget.branchId, {
        'payoutMethod': _payoutMethod,
        'payoutDetails': details,
      }),
      advanceTo: 4,
    );
  }

  Future<void> _goLive() async {
    await _runSave(
      () => ref.read(branchesNotifierProvider.notifier).updateBranch(widget.branchId, {'isPublic': true}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchAsync = ref.watch(branchDetailProvider(widget.branchId));

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
          minWidth: 820,
          maxWidth: 820,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: branchAsync.when(
          loading: () => const SizedBox(height: 400, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SizedBox(
            height: 200,
            child: Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
          ),
          data: (branch) {
            _seedFromBranch(branch);
            final steps = GoPublicSteps(branch);
            final done = [steps.infoDone, steps.servicesDone, steps.doctorsDone, steps.payoutDone, steps.isLive];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Go Public',
                          style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const AppIcon(AppIcons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.appBorder),
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 210,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (var i = 0; i < _stepTitles.length; i++)
                                _TabRow(
                                  number: i + 1,
                                  title: _stepTitles[i],
                                  done: done[i],
                                  active: i == _activeStep,
                                  onTap: () => setState(() {
                                    _activeStep = i;
                                    _error = null;
                                  }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(width: 1, color: context.appBorder),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                switch (_activeStep) {
                                  0 => _ClinicInfoStep(
                                    nameController: _nameCtrl,
                                    phoneController: _phoneCtrl,
                                    emailController: _emailCtrl,
                                    addressController: _addressCtrl,
                                    imageBytes: _pickedImageBytes,
                                    imageName: _pickedImageName,
                                    existingImageKey: branch.publicImageKey,
                                    onPickImage: _pickImage,
                                  ),
                                  1 => _ServicesStep(
                                    branchId: widget.branchId,
                                    selected: _selectedServiceIds,
                                    onToggle: (id) => setState(
                                      () => _selectedServiceIds.contains(id)
                                          ? _selectedServiceIds.remove(id)
                                          : _selectedServiceIds.add(id),
                                    ),
                                  ),
                                  2 => _DoctorsStep(
                                    branchId: widget.branchId,
                                    selected: _selectedDoctorIds,
                                    onToggle: (id) => setState(
                                      () => _selectedDoctorIds.contains(id)
                                          ? _selectedDoctorIds.remove(id)
                                          : _selectedDoctorIds.add(id),
                                    ),
                                  ),
                                  3 => _PayoutStep(
                                    method: _payoutMethod,
                                    onMethodChanged: (m) => setState(() {
                                      _payoutMethod = m;
                                      _payoutConfirmed = false;
                                    }),
                                    phoneController: _payoutPhoneCtrl,
                                    accountNameController: _payoutAccountNameCtrl,
                                    bankNameController: _bankNameCtrl,
                                    bankAccountController: _bankAccountCtrl,
                                    confirmed: _payoutConfirmed,
                                    onConfirmedChanged: (v) => setState(() => _payoutConfirmed = v),
                                  ),
                                  _ => _SuccessStep(
                                    branch: branch,
                                    allStepsDone: steps.allStepsDone,
                                    isLive: steps.isLive,
                                    saving: _saving,
                                    onGoLive: _goLive,
                                  ),
                                },
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
                                      style: const TextStyle(color: AppColors.pillRedText, fontSize: 13),
                                    ),
                                  ),
                                ],
                                if (_activeStep < 4) ...[
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: 160,
                                    child: CliniqnovvaButton(
                                      label: 'Save & Next',
                                      isLoading: _saving,
                                      onPressed: _saving
                                          ? null
                                          : switch (_activeStep) {
                                              0 => _saveInfo,
                                              1 => _saveServices,
                                              2 => _saveDoctors,
                                              _ => _savePayout,
                                            },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({
    required this.number,
    required this.title,
    required this.done,
    required this.active,
    required this.onTap,
  });

  final int number;
  final String title;
  final bool done;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: active ? context.appSecondaryBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? context.appPrimary : context.appSecondaryBg,
                  ),
                  child: done
                      ? const AppIcon(AppIcons.check, size: 12, color: Colors.white)
                      : Text(
                          '$number',
                          style: TextStyle(color: context.appSubtext, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: context.appSubtext, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ClinicInfoStep extends StatelessWidget {
  const _ClinicInfoStep({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.imageBytes,
    required this.imageName,
    required this.existingImageKey,
    required this.onPickImage,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final Uint8List? imageBytes;
  final String? imageName;
  final String? existingImageKey;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Clinic info',
          subtitle: 'This is what patients see first — separate from your internal admin record.',
        ),
        Text('Profile / banner image', style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          onTap: onPickImage,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: context.appBorder),
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              image: imageBytes != null
                  ? DecorationImage(image: MemoryImage(imageBytes!), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: imageBytes != null
                ? Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(imageName ?? 'Change image', style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(AppIcons.image, size: 22, color: context.appSubtext),
                      const SizedBox(height: 6),
                      Text(
                        existingImageKey != null ? 'Tap to replace image' : 'Tap to choose an image',
                        style: TextStyle(color: context.appSubtext, fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        CliniqnovvaTextField(
          label: 'Public display name',
          controller: nameController,
          hint: 'Shown to patients — can differ from the internal branch name',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CliniqnovvaTextField(
                label: 'Public phone',
                controller: phoneController,
                hint: '+250 7XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CliniqnovvaTextField(
                label: 'Public email',
                controller: emailController,
                hint: 'clinic@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CliniqnovvaTextField(
          label: 'Public address',
          controller: addressController,
          hint: 'Street, sector — how a patient would find you',
        ),
      ],
    );
  }
}

class _ServicesStep extends ConsumerWidget {
  const _ServicesStep({required this.branchId, required this.selected, required this.onToggle});

  final String branchId;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider(branchId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Choose services',
          subtitle: 'Only the services you check here show up on your public listing.',
        ),
        servicesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
          data: (services) {
            if (services.isEmpty) {
              return Text(
                'No services set up yet — add some under Departments → Services first.',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final ServiceModel s in services) _CheckRow(label: s.name, checked: selected.contains(s.id), onTap: () => onToggle(s.id)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DoctorsStep extends ConsumerWidget {
  const _DoctorsStep({required this.branchId, required this.selected, required this.onToggle});

  final String branchId;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider(branchId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Choose doctors',
          subtitle: 'Only the doctors you check here show up on your public listing.',
        ),
        staffAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
          data: (staff) {
            final doctors = staff.where((s) => s.role == AppConstants.roleDoctor).toList();
            if (doctors.isEmpty) {
              return Text(
                'No doctors on this branch yet — add some under Staff first.',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final StaffModel d in doctors)
                  _CheckRow(
                    label: d.specialty != null ? '${d.name} — ${d.specialty}' : d.name,
                    checked: selected.contains(d.id),
                    onTap: () => onToggle(d.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.checked, required this.onTap});

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onTap(),
              activeColor: context.appPrimary,
            ),
            Expanded(
              child: Text(label, style: TextStyle(color: context.appText, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    );
  }
}

const _payoutMethods = ['momo', 'airtel', 'bank'];
const _payoutMethodLabels = ['MoMo', 'Airtel Money', 'Bank Account'];

class _PayoutStep extends StatelessWidget {
  const _PayoutStep({
    required this.method,
    required this.onMethodChanged,
    required this.phoneController,
    required this.accountNameController,
    required this.bankNameController,
    required this.bankAccountController,
    required this.confirmed,
    required this.onConfirmedChanged,
  });

  final String? method;
  final ValueChanged<String> onMethodChanged;
  final TextEditingController phoneController;
  final TextEditingController accountNameController;
  final TextEditingController bankNameController;
  final TextEditingController bankAccountController;
  final bool confirmed;
  final ValueChanged<bool> onConfirmedChanged;

  @override
  Widget build(BuildContext context) {
    final isBank = method == 'bank';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Payout details',
          subtitle: 'Where patient payments collected through the app should be sent.',
        ),
        SegmentedTabs(
          labels: _payoutMethodLabels,
          index: method == null ? -1 : _payoutMethods.indexOf(method!),
          onChanged: (i) => onMethodChanged(_payoutMethods[i]),
        ),
        if (method != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pillAmberBg,
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.warning, size: 18, color: AppColors.pillAmberText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These details aren\'t verified against your provider — a typo means a real payment goes '
                    'to the wrong place. Double-check everything before confirming.',
                    style: TextStyle(color: AppColors.pillAmberText, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isBank) ...[
            CliniqnovvaTextField(label: 'Bank name', controller: bankNameController, hint: 'e.g. Bank of Kigali'),
            const SizedBox(height: 16),
            CliniqnovvaTextField(
              label: 'Account number',
              controller: bankAccountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            CliniqnovvaTextField(label: 'Account holder name', controller: accountNameController),
          ] else ...[
            CliniqnovvaTextField(
              label: '${method == 'momo' ? 'MoMo' : 'Airtel Money'} phone number',
              controller: phoneController,
              hint: '+250 7XX XXX XXX',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            CliniqnovvaTextField(label: 'Account holder name', controller: accountNameController),
          ],
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onConfirmedChanged(!confirmed),
            child: Row(
              children: [
                Checkbox(value: confirmed, onChanged: (v) => onConfirmedChanged(v ?? false), activeColor: context.appPrimary),
                Expanded(
                  child: Text(
                    'I\'ve double-checked these payout details are correct.',
                    style: TextStyle(color: context.appText, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SuccessStep extends StatefulWidget {
  const _SuccessStep({
    required this.branch,
    required this.allStepsDone,
    required this.isLive,
    required this.saving,
    required this.onGoLive,
  });

  final BranchModel branch;
  final bool allStepsDone;
  final bool isLive;
  final bool saving;
  final VoidCallback onGoLive;

  @override
  State<_SuccessStep> createState() => _SuccessStepState();
}

class _SuccessStepState extends State<_SuccessStep> {
  final _badgeKey = GlobalKey();
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final boundary = _badgeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final uri = Uri.parse('data:image/png;base64,${base64Encode(bytes)}');
      await launchUrl(uri, webOnlyWindowName: '_blank');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            title: 'Go live',
            subtitle: 'Everything above is saved and ready — one click puts this branch on the Patient App.',
          ),
          if (!widget.allStepsDone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.pillAmberBg,
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              ),
              child: Text(
                'Finish the steps on the left first — clinic info, services, doctors and payout all need to be saved.',
                style: TextStyle(color: AppColors.pillAmberText, fontSize: 12.5),
              ),
            )
          else
            SizedBox(
              width: 200,
              child: CliniqnovvaButton(
                label: 'Go Public',
                isLoading: widget.saving,
                onPressed: widget.saving ? null : widget.onGoLive,
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'You\'re public!',
          subtitle: 'This branch is now listed on the Cliniqnovva Patient App. Share the badge below on social media.',
        ),
        Center(
          child: RepaintBoundary(
            key: _badgeKey,
            child: _ShareBadge(displayName: widget.branch.publicDisplayName ?? widget.branch.name),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 220,
            child: CliniqnovvaButton.outlined(
              label: 'Download badge',
              isLoading: _downloading,
              onPressed: _downloading ? null : _download,
            ),
          ),
        ),
      ],
    );
  }
}

/// The shareable "we're on Cliniqnovva" badge — captured to PNG by
/// [_SuccessStepState._download] via a [RepaintBoundary]. Kept as a small,
/// self-contained, fixed-size graphic (not theme-aware — a downloaded image
/// posted publicly should look the same regardless of the admin's own
/// light/dark setting when they clicked the button).
class _ShareBadge extends StatelessWidget {
  const _ShareBadge({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.skyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CliniqnovvaLogo(size: 48, radius: 14, background: true),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'is now booking on Cliniqnovva',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
