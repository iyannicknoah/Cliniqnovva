import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_logo.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../providers/branches_provider.dart';
import '../widgets/branch_form.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Part 6 Task 1 — the full-screen 4-step onboarding wizard a brand-new
/// Clinic Admin lands on (the router redirects here while their
/// clinic has zero branches):
///   1. Create your first branch (full branch form)
///   2. Add your first department (chips, at least one)
///   3. Public visibility — public on the Patient App, or private (a
///      Switch); if public, requires a profile/banner image + display
///      name + public phone/email/address, kept separate from the
///      internal name/phone/address above.
///   4. Confirm and finish → creates the branch + department(s) [+ public
///      profile], then redirects to /dashboard.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 4;

  final _branchFormKey = GlobalKey<BranchFormState>();
  final _departmentController = TextEditingController();
  final _publicNameController = TextEditingController();
  final _publicPhoneController = TextEditingController();
  final _publicEmailController = TextEditingController();
  final _publicAddressController = TextEditingController();

  int _step = 0;
  final List<String> _departments = [];

  bool _isPublic = false;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  String? _pickedImageContentType;

  /// Step 1's validated output, kept once the user advances so the form
  /// (which is disposed when Step 1 unmounts) doesn't need to stay alive.
  Map<String, dynamic>? _branchBody;

  bool _finishing = false;
  String? _error;

  @override
  void dispose() {
    _departmentController.dispose();
    _publicNameController.dispose();
    _publicPhoneController.dispose();
    _publicEmailController.dispose();
    _publicAddressController.dispose();
    super.dispose();
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

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step -= 1;
      _error = null;
    });
  }

  void _next() {
    setState(() => _error = null);

    if (_step == 0) {
      final form = _branchFormKey.currentState!;
      final validationError = form.validate();
      if (validationError != null) {
        setState(() => _error = validationError);
        return;
      }
      _branchBody = form.buildBody();
    }

    if (_step == 1 && _departments.isEmpty) {
      setState(() => _error = 'Add at least one department to continue.');
      return;
    }

    if (_step == 2 && _isPublic) {
      if (_publicNameController.text.trim().isEmpty ||
          _publicPhoneController.text.trim().isEmpty ||
          _publicEmailController.text.trim().isEmpty ||
          _publicAddressController.text.trim().isEmpty) {
        setState(() => _error = 'Fill in every public profile field, or turn off "Public" to skip.');
        return;
      }
      if (!_emailPattern.hasMatch(_publicEmailController.text.trim())) {
        setState(() => _error = 'Enter a valid public email address.');
        return;
      }
      if (_pickedImageBytes == null) {
        setState(() => _error = 'Add a profile/banner image to go public.');
        return;
      }
    }

    setState(() => _step += 1);
  }

  void _addDepartment() {
    final name = _departmentController.text.trim();
    if (name.isEmpty) return;
    final exists = _departments.any(
      (d) => d.toLowerCase() == name.toLowerCase(),
    );
    if (!exists) setState(() => _departments.add(name));
    _departmentController.clear();
  }

  Future<void> _finish() async {
    setState(() {
      _finishing = true;
      _error = null;
    });

    try {
      final notifier = ref.read(branchesNotifierProvider.notifier);
      final branch = await notifier.createBranch(_branchBody!);
      for (final department in _departments) {
        await notifier.createDepartment(branchId: branch.id, name: department);
      }

      if (_isPublic) {
        await notifier.uploadBranchPublicImage(
          branch.id,
          bytes: _pickedImageBytes!,
          filename: _pickedImageName!,
          contentType: _pickedImageContentType!,
        );
        await notifier.updateBranch(branch.id, {
          'isPublic': true,
          'publicDisplayName': _publicNameController.text.trim(),
          'publicPhone': _publicPhoneController.text.trim(),
          'publicEmail': _publicEmailController.text.trim(),
          'publicAddress': _publicAddressController.text.trim(),
        });
      } else {
        // Persisted explicitly — a freshly created branch has no `isPublic`
        // field at all, and the Patient App's visibility filter treats that
        // as visible-by-default (see browse.service.js#isVisibleToPatients).
        // Choosing "Private" here must actually record the choice.
        await notifier.updateBranch(branch.id, {'isPublic': false});
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _error = 'Something went wrong: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CliniqnovvaLogo(size: 32, radius: 10),
                      SizedBox(width: 6),
                      Text(
                        'Cliniqnovva',
                        style: TextStyle(
                          color: AppColors.skyBlue,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Step ${_step + 1} of $_stepCount',
                    style: TextStyle(color: context.appSubtext, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / _stepCount,
                      minHeight: 6,
                      backgroundColor: context.appSecondaryBg,
                      valueColor: AlwaysStoppedAnimation(context.appPrimary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: switch (_step) {
                        0 => _StepShell(
                          title: 'Create your first branch',
                          subtitle:
                              'Where does your clinic operate? You can add more branches later.',
                          child: BranchForm(key: _branchFormKey),
                        ),
                        1 => _StepShell(
                          title: 'Add your first department',
                          subtitle:
                              'e.g. General Medicine, Pediatrics, Dental… at least one is required.',
                          child: _DepartmentsStep(
                            controller: _departmentController,
                            departments: _departments,
                            onAdd: _addDepartment,
                            onRemove: (name) =>
                                setState(() => _departments.remove(name)),
                          ),
                        ),
                        2 => _StepShell(
                          title: 'Public visibility',
                          subtitle:
                              'Show this branch to patients browsing the Cliniqnovva app? You can change this later.',
                          child: _PublicVisibilityStep(
                            isPublic: _isPublic,
                            onPublicChanged: (value) => setState(() => _isPublic = value),
                            nameController: _publicNameController,
                            phoneController: _publicPhoneController,
                            emailController: _publicEmailController,
                            addressController: _publicAddressController,
                            imageBytes: _pickedImageBytes,
                            imageName: _pickedImageName,
                            onPickImage: _pickImage,
                          ),
                        ),
                        _ => _StepShell(
                          title: 'Confirm and finish',
                          subtitle:
                              'Here\'s what we\'ll set up for your clinic.',
                          child: _SummaryStep(
                            branchBody: _branchBody ?? const {},
                            departments: _departments,
                            isPublic: _isPublic,
                            publicName: _publicNameController.text,
                          ),
                        ),
                      },
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pillRedBg,
                        borderRadius: BorderRadius.circular(
                          AppTheme.inputRadius,
                        ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_step > 0)
                        CliniqnovvaButton.text(
                          label: 'Back',
                          color: context.appText,
                          onPressed: _finishing ? null : _back,
                        ),
                      const Spacer(),
                      SizedBox(
                        width: 160,
                        child: _step == _stepCount - 1
                            ? CliniqnovvaButton(
                                label: 'Finish Setup',
                                isLoading: _finishing,
                                onPressed: _finishing ? null : _finish,
                              )
                            : CliniqnovvaButton(
                                label: 'Next',
                                onPressed: _next,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.appText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: context.appSubtext, fontSize: 13.5),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _DepartmentsStep extends StatelessWidget {
  const _DepartmentsStep({
    required this.controller,
    required this.departments,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> departments;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CliniqnovvaTextField(
                label: 'Department name',
                controller: controller,
                hint: 'e.g. General Medicine',
                onFieldSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: CliniqnovvaButton(label: 'Add', onPressed: onAdd),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (departments.isEmpty)
          Text(
            'No departments yet.',
            style: TextStyle(color: context.appSubtext, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: departments
                .map(
                  (name) => Container(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: context.appSecondaryBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: context.appText,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onRemove(name),
                          child: AppIcon(
                            AppIcons.close,
                            size: 15,
                            color: context.appSubtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _PublicVisibilityStep extends StatelessWidget {
  const _PublicVisibilityStep({
    required this.isPublic,
    required this.onPublicChanged,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.imageBytes,
    required this.imageName,
    required this.onPickImage,
  });

  final bool isPublic;
  final ValueChanged<bool> onPublicChanged;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final Uint8List? imageBytes;
  final String? imageName;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: context.cardDeco(),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: isPublic,
                    activeTrackColor: context.appPrimary,
                    onChanged: onPublicChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPublic ? 'Public' : 'Private',
                      style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isPublic
                          ? 'Patients can find this branch in the app.'
                          : 'Hidden from the app — staff can still use everything internally.',
                      style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isPublic) ...[
          const SizedBox(height: 20),
          Text(
            'Profile / banner image',
            style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500),
          ),
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
              child: imageBytes == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(AppIcons.image, size: 22, color: context.appSubtext),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to choose an image',
                          style: TextStyle(color: context.appSubtext, fontSize: 13),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          imageName ?? 'Change image',
                          style: const TextStyle(color: Colors.white, fontSize: 11.5),
                        ),
                      ),
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
      ],
    );
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({
    required this.branchBody,
    required this.departments,
    required this.isPublic,
    required this.publicName,
  });

  final Map<String, dynamic> branchBody;
  final List<String> departments;
  final bool isPublic;
  final String publicName;

  /// Mirrors BranchHours.label: 24-hour flag, or a start–end pair where an
  /// end earlier than the start means the branch closes the next day.
  static String _hoursLabel(Map<String, dynamic> hours) {
    if (hours['is24Hours'] == true) return 'Open 24 hours';
    final start = hours['start'] as String? ?? '';
    final end = hours['end'] as String? ?? '';
    final overnight = start.compareTo(end) > 0;
    return overnight ? '$start – $end (next day)' : '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final location = branchBody['location'] as Map<String, dynamic>? ?? {};
    final hours = branchBody['workingHours'] as Map<String, dynamic>?;
    final umuganda =
        branchBody['umugandaSaturdayHours'] as Map<String, dynamic>?;

    final locationLine = [
      location['village'],
      location['cell'],
      location['sector'],
      location['district'],
      location['province'],
    ].whereType<String>().join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: context.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            label: 'Branch',
            value: branchBody['name'] as String? ?? '',
          ),
          _SummaryRow(
            label: 'Location',
            value: locationLine.isEmpty ? '—' : locationLine,
          ),
          _SummaryRow(
            label: 'Phone',
            value: branchBody['phone'] as String? ?? '—',
          ),
          _SummaryRow(
            label: 'Working hours',
            value: hours == null ? '—' : _hoursLabel(hours),
          ),
          _SummaryRow(
            label: 'Umuganda Saturdays',
            value: umuganda == null ? 'Normal hours' : _hoursLabel(umuganda),
          ),
          _SummaryRow(
            label: departments.length == 1 ? 'Department' : 'Departments',
            value: departments.join(', '),
          ),
          _SummaryRow(
            label: 'Patient App',
            value: isPublic ? 'Public — as "$publicName"' : 'Private',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(color: context.appSubtext, fontSize: 13.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.appText,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
