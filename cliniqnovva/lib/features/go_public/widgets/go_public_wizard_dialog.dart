import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../../../shared/widgets/success_dialog.dart';
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
    // 2026-08-18, explicit user instruction — "MoMo" is the default
    // selected method the first time this step is opened, not a blank
    // segmented control; an already-saved method still wins over that
    // default once one exists.
    _payoutMethod = branch.payoutMethod ?? 'momo';
    final details = branch.payoutDetails ?? const {};
    _payoutPhoneCtrl.text = details['phone'] ?? '';
    _payoutAccountNameCtrl.text = details['accountName'] ?? '';
    _bankNameCtrl.text = details['bankName'] ?? '';
    _bankAccountCtrl.text = details['accountNumber'] ?? '';
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    final file = result?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;
    setState(() {
      _pickedImageBytes = file!.bytes;
      _pickedImageName = file.name;
      _pickedImageContentType = 'image/${file.extension ?? 'jpeg'}';
    });
  }

  Future<void> _runSave(
    Future<void> Function() action, {
    int? advanceTo,
  }) async {
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
    if (_pickedImageBytes == null &&
        ref
                .read(branchDetailProvider(widget.branchId))
                .valueOrNull
                ?.publicImageKey ==
            null) {
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
      () => ref.read(branchesNotifierProvider.notifier).updateBranch(
        widget.branchId,
        {'publicServiceIds': _selectedServiceIds.toList()},
      ),
      advanceTo: 2,
    );
  }

  Future<void> _saveDoctors() async {
    await _runSave(
      () => ref.read(branchesNotifierProvider.notifier).updateBranch(
        widget.branchId,
        {'publicDoctorIds': _selectedDoctorIds.toList()},
      ),
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
      setState(
        () => _error =
            'Confirm you\'ve double-checked these details before saving.',
      );
      return;
    }

    await _runSave(
      () => ref.read(branchesNotifierProvider.notifier).updateBranch(
        widget.branchId,
        {'payoutMethod': _payoutMethod, 'payoutDetails': details},
      ),
      advanceTo: 4,
    );
  }

  /// Explicit user instruction (2026-08-19) — going live closes the wizard
  /// immediately and shows the standard success popup on the screen behind
  /// it, instead of sitting on the "You're public!" step with the phone
  /// mockup. [Navigator.of] is captured BEFORE `pop()` — the dialog's own
  /// `context` is unmounted the instant the route closes, but the captured
  /// [NavigatorState]'s `.context` (the underlying [GoPublicScreen]) stays
  /// valid, which is what [showSuccessDialog] needs to open on top of it.
  Future<void> _goLive() async {
    await _runSave(
      () => ref.read(branchesNotifierProvider.notifier).updateBranch(
        widget.branchId,
        {'isPublic': true},
      ),
    );
    if (!mounted || _error != null) return;
    final navigator = Navigator.of(context);
    navigator.pop();
    showSuccessDialog(
      navigator.context,
      title: 'You\'re public!',
      message: 'This branch is now listed on the Cliniqnovva Patient App.',
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
          loading: () => const SizedBox(
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 200,
            child: Center(
              child: Text('$e', style: TextStyle(color: context.appSubtext)),
            ),
          ),
          data: (branch) {
            _seedFromBranch(branch);
            final steps = GoPublicSteps(branch);
            final done = [
              steps.infoDone,
              steps.servicesDone,
              steps.doctorsDone,
              steps.payoutDone,
              steps.isLive,
            ];

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
                                    accountNameController:
                                        _payoutAccountNameCtrl,
                                    bankNameController: _bankNameCtrl,
                                    bankAccountController: _bankAccountCtrl,
                                    confirmed: _payoutConfirmed,
                                    onConfirmedChanged: (v) =>
                                        setState(() => _payoutConfirmed = v),
                                  ),
                                  _ => _SuccessStep(
                                    branch: branch,
                                    allStepsDone: steps.allStepsDone,
                                    isLive: steps.isLive,
                                  ),
                                },
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 2026-08-17, explicit user instruction — "Save & Next"
                // moved out of the scrolling content column into its own
                // fixed footer bar, bottom-right, on every step tab.
                // 2026-08-18 follow-up — step 5 (Go live)'s "Go Public"
                // button joined it here too (previously inline inside
                // `_SuccessStep`, top-left) — once `isLive`, there's no
                // footer action at all (that state's content is just the
                // share/download card, no further "next" step).
                if (_activeStep < 4 || (_activeStep == 4 && !steps.isLive)) ...[
                  Divider(height: 1, color: context.appBorder),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 160,
                        child: CliniqnovvaButton(
                          label: _activeStep == 4 ? 'Go Public' : 'Save & Next',
                          isLoading: _saving,
                          onPressed: _saving
                              ? null
                              : switch (_activeStep) {
                                  0 => _saveInfo,
                                  1 => _saveServices,
                                  2 => _saveDoctors,
                                  3 => _savePayout,
                                  _ => steps.allStepsDone ? _goLive : null,
                                },
                        ),
                      ),
                    ),
                  ),
                ],
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
                      ? const AppIcon(
                          AppIcons.check,
                          size: 12,
                          color: Colors.white,
                        )
                      : Text(
                          '$number',
                          style: TextStyle(
                            color: context.appSubtext,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
          Text(
            title,
            style: TextStyle(
              color: context.appText,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: context.appSubtext, fontSize: 13),
          ),
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
          subtitle:
              'This is what patients see first — separate from your internal admin record.',
        ),
        Text(
          'Profile / banner image',
          style: TextStyle(
            color: context.appText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
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
                  ? DecorationImage(
                      image: MemoryImage(imageBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: imageBytes != null
                ? Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        imageName ?? 'Change image',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.image,
                        size: 22,
                        color: context.appSubtext,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        existingImageKey != null
                            ? 'Tap to replace image'
                            : 'Tap to choose an image',
                        style: TextStyle(
                          color: context.appSubtext,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        CliniqnovvaTextField(
          label: 'Public display name',
          controller: nameController,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CliniqnovvaTextField(
                label: 'Public phone',
                controller: phoneController,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CliniqnovvaTextField(
                label: 'Public email',
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CliniqnovvaTextField(
          label: 'Public address',
          controller: addressController,
        ),
      ],
    );
  }
}

class _ServicesStep extends ConsumerWidget {
  const _ServicesStep({
    required this.branchId,
    required this.selected,
    required this.onToggle,
  });

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
          subtitle:
              'Only the services you check here show up on your public listing.',
        ),
        servicesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              Text('$e', style: TextStyle(color: context.appSubtext)),
          data: (services) {
            if (services.isEmpty) {
              return Text(
                'No services set up yet — add some under Departments → Services first.',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final ServiceModel s in services)
                  _CheckRow(
                    label: s.name,
                    checked: selected.contains(s.id),
                    onTap: () => onToggle(s.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 2026-08-17, explicit user instruction — a grid of per-doctor cards
/// (avatar + name/specialty) replacing the plain checkbox list every other
/// step still uses. The avatar itself is a live upload target (tap to pick
/// a photo via `staffNotifierProvider.uploadDoctorPhoto`, showing
/// `assets/images/default_doctor.jpg` until one's set) — selecting a doctor
/// for the public listing still works exactly as before, just via tapping
/// anywhere on the card OTHER than the avatar (see [_DoctorCard]).
///
/// 2026-08-17 follow-up — the default photo was originally hotlinked
/// straight from Pinterest via `Image.network`, and the real uploaded photo
/// was a raw signed R2 URL, ALSO via `Image.network`. Neither ever
/// rendered: R2's bucket has no CORS policy for browser origins, and
/// Pinterest's CDN doesn't reliably allow arbitrary cross-origin embeds —
/// Flutter web's CanvasKit renderer fetches image bytes itself (unlike a
/// plain `<img>` tag), so both are subject to CORS and both silently failed
/// to `errorBuilder`. Fixed two ways: the default is now a bundled asset
/// (no network fetch, no CORS surface at all — see [_DoctorCard]), and the
/// real photo is fetched as bytes through `ApiService`'s own Dio client
/// (already CORS-permissive, already carries the auth header every other
/// authenticated request uses) and rendered via `Image.memory` instead of
/// `Image.network` — see [_AuthedImage].

class _DoctorsStep extends ConsumerStatefulWidget {
  const _DoctorsStep({
    required this.branchId,
    required this.selected,
    required this.onToggle,
  });

  final String branchId;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  ConsumerState<_DoctorsStep> createState() => _DoctorsStepState();
}

class _DoctorsStepState extends ConsumerState<_DoctorsStep> {
  final _uploadingIds = <String>{};

  Future<void> _uploadPhoto(String doctorId) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.image,
    );
    final file = result?.files.singleOrNull;
    if (file?.bytes == null || !mounted) return;

    setState(() => _uploadingIds.add(doctorId));
    try {
      await ref
          .read(staffNotifierProvider.notifier)
          .uploadDoctorPhoto(
            doctorId,
            bytes: file!.bytes!,
            filename: file.name,
            contentType: 'image/${file.extension ?? 'jpeg'}',
          );
    } catch (_) {
      // No per-card error slot in this wizard — the avatar simply keeps
      // showing whatever it showed before a failed upload.
    } finally {
      if (mounted) setState(() => _uploadingIds.remove(doctorId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider(widget.branchId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeading(
          title: 'Choose doctors',
          subtitle:
              'Only the doctors you check here show up on your public listing.',
        ),
        staffAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              Text('$e', style: TextStyle(color: context.appSubtext)),
          data: (staff) {
            final doctors = staff
                .where((s) => s.role == AppConstants.roleDoctor)
                .toList();
            if (doctors.isEmpty) {
              return Text(
                'No doctors on this branch yet — add some under Staff first.',
                style: TextStyle(color: context.appSubtext, fontSize: 13),
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final StaffModel d in doctors)
                  _DoctorCard(
                    doctor: d,
                    checked: widget.selected.contains(d.id),
                    uploading: _uploadingIds.contains(d.id),
                    onToggle: () => widget.onToggle(d.id),
                    onTapAvatar: () => _uploadPhoto(d.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.checked,
    required this.uploading,
    required this.onToggle,
    required this.onTapAvatar,
  });

  final StaffModel doctor;
  final bool checked;
  final bool uploading;
  final VoidCallback onToggle;
  final VoidCallback onTapAvatar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Container(
          width: 190,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // Explicit user instruction (2026-08-17 follow-up) — selection
            // shows via the border ONLY, background stays transparent
            // either way (previously a faint primary tint when checked).
            color: Colors.transparent,
            border: Border.all(
              color: checked ? context.appPrimary : context.appBorder,
              width: checked ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // 2026-08-17 follow-up — a same-size, fully circular
                  // `appSecondaryBg` container behind the image itself
                  // (explicit user instruction), not just `ClipOval` around
                  // it: gives the avatar a visible colored backdrop instead
                  // of empty space if the photo is slow to load or fails.
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.appSecondaryBg,
                    ),
                    child: ClipOval(
                      child: GestureDetector(
                        onTap: uploading ? null : onTapAvatar,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            doctor.photoUrl != null
                                ? _AuthedImage(
                                    path: doctor.photoUrl!,
                                    fallback: Image.asset(
                                      'assets/images/default_doctor.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/default_doctor.jpg',
                                    fit: BoxFit.cover,
                                  ),
                            if (uploading)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: uploading ? null : onTapAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.appPrimary,
                          border: Border.all(color: context.appCard, width: 2),
                        ),
                        child: const AppIcon(
                          AppIcons.camera,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                doctor.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.appText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (doctor.specialty != null) ...[
                const SizedBox(height: 3),
                Text(
                  doctor.specialty!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fetches an authenticated-only image as bytes through [ApiService]'s Dio
/// client (2026-08-17, generalized 2026-08-19 — see the doc comment above
/// [_DoctorsStep] for why: a plain `Image.network` against a signed R2 url
/// never rendered, blocked by the bucket's missing CORS policy under
/// Flutter web's CanvasKit renderer). [path] is a relative backend
/// "…-view"/"…-photo-view" route (e.g. `/api/v1/staff/:id/photo-view`,
/// `/api/v1/branches/:branchId/image-view`) that streams the bytes through
/// our own already-authenticated server instead of R2 directly —
/// `ApiService` already carries the base URL and auth header for it, same
/// as every other authenticated request in the app. [fallback] renders
/// while there's nothing to show (404 — no photo uploaded yet — or any
/// other fetch error), so this never renders a broken-image icon. While
/// fetching, shows a [ShimmerBox] shaped via [shimmerShape] to match
/// whatever the image itself is clipped to (2026-08-19, explicit user
/// instruction — no spinners on any image, app-wide).
class _AuthedImage extends StatefulWidget {
  const _AuthedImage({
    required this.path,
    required this.fallback,
    this.shimmerShape = BoxShape.rectangle,
  });

  final String path;
  final Widget fallback;
  final BoxShape shimmerShape;

  @override
  State<_AuthedImage> createState() => _AuthedImageState();
}

class _AuthedImageState extends State<_AuthedImage> {
  late Future<Uint8List> _bytes = _fetch();

  Future<Uint8List> _fetch() async {
    final response = await ApiService.instance.client.get<List<int>>(
      widget.path,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  @override
  void didUpdateWidget(covariant _AuthedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _bytes = _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        if (snapshot.hasError) {
          return widget.fallback;
        }
        return ShimmerBox(shape: widget.shimmerShape);
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

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
              child: Text(
                label,
                style: TextStyle(color: context.appText, fontSize: 13.5),
              ),
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
          subtitle:
              'Where patient payments collected through the app should be sent.',
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
              // 2026-08-18, explicit user instruction — no fill, just a
              // border in the app's secondary background color; icon/text
              // keep their amber color as the warning cue.
              borderRadius: BorderRadius.circular(AppTheme.inputRadius),
              border: Border.all(color: context.appSecondaryBg),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  AppIcons.warning,
                  size: 18,
                  color: AppColors.pillAmberText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // 2026-08-18, explicit user instruction — trimmed down
                    // to just this line.
                    'Double check account number and account holder names and make sure they match. If they don\'t match, you won\'t receive your money.',
                    style: TextStyle(
                      // 2026-08-18, explicit user instruction — text in the
                      // app's secondary text color; the icon above keeps
                      // its amber warning color unchanged.
                      color: context.appSubtext,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isBank) ...[
            CliniqnovvaTextField(
              label: 'Bank name',
              controller: bankNameController,
              hint: 'e.g. Bank of Kigali',
            ),
            const SizedBox(height: 16),
            CliniqnovvaTextField(
              label: 'Account number',
              controller: bankAccountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            CliniqnovvaTextField(
              label: 'Account holder name',
              controller: accountNameController,
            ),
          ] else ...[
            CliniqnovvaTextField(
              label:
                  '${method == 'momo' ? 'MoMo' : 'Airtel Money'} phone number',
              controller: phoneController,
              hint: '+250 7XX XXX XXX',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            CliniqnovvaTextField(
              label: 'Account holder name',
              controller: accountNameController,
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onConfirmedChanged(!confirmed),
            child: Row(
              children: [
                Checkbox(
                  value: confirmed,
                  onChanged: (v) => onConfirmedChanged(v ?? false),
                  activeColor: context.appPrimary,
                ),
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

class _SuccessStep extends ConsumerStatefulWidget {
  const _SuccessStep({
    required this.branch,
    required this.allStepsDone,
    required this.isLive,
  });

  final BranchModel branch;
  final bool allStepsDone;
  final bool isLive;

  @override
  ConsumerState<_SuccessStep> createState() => _SuccessStepState();
}

class _SuccessStepState extends ConsumerState<_SuccessStep> {
  final _shareCardKey = GlobalKey();
  bool _downloading = false;

  Future<void> _download(GlobalKey key) async {
    setState(() => _downloading = true);
    try {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
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
    final doctors =
        (ref.watch(staffListProvider(widget.branch.id)).valueOrNull ??
                const <StaffModel>[])
            .where((s) => s.role == AppConstants.roleDoctor)
            .toList();
    final publicServiceIds = widget.branch.publicServiceIds ?? const [];
    final services =
        (ref.watch(servicesProvider(widget.branch.id)).valueOrNull ??
                const <ServiceModel>[])
            .where((s) => publicServiceIds.contains(s.id))
            .toList();

    if (!widget.isLive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                style: TextStyle(
                  color: AppColors.pillAmberText,
                  fontSize: 12.5,
                ),
              ),
            )
          else
            Center(
              child: _PublicProfileCard(
                branch: widget.branch,
                doctors: doctors,
                services: services,
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
          subtitle: 'This branch is now listed on the Cliniqnovva Patient App.',
        ),
        const SizedBox(height: 20),
        Center(
          child: RepaintBoundary(
            key: _shareCardKey,
            child: _PublicProfileCard(
              branch: widget.branch,
              doctors: doctors,
              services: services,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 200,
            child: CliniqnovvaButton.outlined(
              label: 'Download',
              isLoading: _downloading,
              onPressed: _downloading ? null : () => _download(_shareCardKey),
            ),
          ),
        ),
      ],
    );
  }
}

/// Deterministic "random" rating/review-count generator (2026-08-19,
/// explicit user instruction — real per-branch/per-doctor rating aggregates
/// exist elsewhere in this app, but a brand-new clinic going live for the
/// first time has none yet, so this wizard's share card deliberately shows
/// plausible placeholder numbers instead). Seeded by an id so the same
/// clinic/doctor always gets the same number across rebuilds — never a
/// fresh random draw on every frame, which would visibly flicker.
double _seededRating(String seed) =>
    4.5 + Random(seed.hashCode).nextDouble() * 0.5;

int _seededReviewCount(String seed) => 24 + Random(seed.hashCode).nextInt(180);

/// The phone-framed downloadable "we're public" share card (2026-08-19,
/// explicit user instruction — replaces the earlier static `_ShareBadge`
/// and the flat `_ClinicShareCard` with an iPhone-mockup-styled screen):
/// the clinic's own uploaded public photo (streamed through our own server
/// via [_AuthedImage] — see `branches.service.js#getPublicImageBytes`'s doc
/// comment for why a signed R2 url can't be used directly with
/// `Image.network` here — [_ShareCardPhotoFallback] renders instead of a
/// broken image whenever there's no photo yet or the fetch fails), public
/// display name, public address, the branch's real public services (a
/// wrapping chip row), and up to [_maxDoctors] of its real doctors (real
/// names/photos, two per line). Rating/review numbers are seeded-random
/// placeholders, see [_seededRating] doc comment — nothing in this wizard
/// tracks a real branch-level aggregate yet. Height is intrinsic to its
/// content rather than a fixed iPhone aspect ratio, so it never overflows
/// regardless of how many services/doctors a branch has. Fixed,
/// non-theme-aware colors (a downloaded image should look the same
/// regardless of the admin's own light/dark setting).
class _PublicProfileCard extends StatelessWidget {
  const _PublicProfileCard({
    required this.branch,
    required this.doctors,
    required this.services,
  });

  final BranchModel branch;
  final List<StaffModel> doctors;
  final List<ServiceModel> services;

  static const _phoneWidth = 300.0;
  static const _bezel = Color(0xFF1B1D1F);

  /// Keeps the card a predictable, well-proportioned size for a downloadable
  /// image — a branch with more doctors than this just shows its first few.
  static const _maxDoctors = 4;

  @override
  Widget build(BuildContext context) {
    final name = branch.publicDisplayName ?? branch.name;
    final address = branch.publicAddress;
    final rating = _seededRating(branch.id);
    final reviewCount = _seededReviewCount(branch.id);
    final shownDoctors = doctors.take(_maxDoctors).toList();

    return Container(
      width: _phoneWidth,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _bezel,
        borderRadius: BorderRadius.circular(46),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 9 / 19.4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Container(
            color: Colors.white,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ShareCardBanner(
                      branchId: branch.id,
                      hasPhoto: branch.publicImageKey != null,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF14181B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const AppIcon(
                                  AppIcons.oversight,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                            if ((address ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1.5),
                                    child: AppIcon(
                                      AppIcons.branchLocation,
                                      size: 11,
                                      color: Color(0xFF57636C),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      address!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.35,
                                        color: Color(0xFF57636C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const AppIcon(
                                  AppIcons.star,
                                  size: 12,
                                  color: Color(0xFFFFBF09),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF14181B),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '($reviewCount reviews)',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF57636C),
                                  ),
                                ),
                              ],
                            ),
                            if (services.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                height: 1,
                                color: const Color(0xFFE0E3E7),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'SERVICES',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF57636C),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final ServiceModel s in services)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryTint,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryHover,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (shownDoctors.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                height: 1,
                                color: const Color(0xFFE0E3E7),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'DOCTORS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF57636C),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final StaffModel d in shownDoctors)
                                    SizedBox(
                                      width: (_phoneWidth - 18 - 32 - 10) / 2,
                                      child: _ShareCardDoctorTile(doctor: d),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryHover],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Book Appointment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 9,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 92,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF050607),
                        borderRadius: BorderRadius.circular(999),
                      ),
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

/// One doctor tile inside [_PublicProfileCard]'s "Doctors" wrap — a column
/// layout (photo on top, name/specialty centered below, 2026-08-19 explicit
/// user instruction matching the wizard's own [_DoctorCard] reference) so up
/// to [_PublicProfileCard._maxDoctors] fit, two per line. Real name and
/// photo (streamed via [_AuthedImage] — see its doc comment for why, same
/// CORS reasoning as the banner photo).
class _ShareCardDoctorTile extends StatelessWidget {
  const _ShareCardDoctorTile({required this.doctor});

  final StaffModel doctor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E3E7)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 64,
              height: 64,
              child: doctor.photoUrl != null
                  ? _AuthedImage(
                      path: doctor.photoUrl!,
                      fallback: const _DoctorPhotoFallback(),
                      shimmerShape: BoxShape.circle,
                    )
                  : const _DoctorPhotoFallback(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            doctor.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF14181B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            doctor.specialty ?? 'Doctor',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF57636C)),
          ),
        ],
      ),
    );
  }
}

/// Plain placeholder for [_ShareCardDoctorTile]'s avatar, shown whenever a
/// doctor hasn't uploaded a photo yet or it fails to load.
class _DoctorPhotoFallback extends StatelessWidget {
  const _DoctorPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryTint,
      alignment: Alignment.center,
      child: const AppIcon(
        AppIcons.staff,
        size: 26,
        color: AppColors.primaryHover,
      ),
    );
  }
}

/// Full-bleed banner photo for [_PublicProfileCard] — runs under the
/// dynamic-island cutout (2026-08-19, explicit user instruction: no
/// reserved status-bar space above it). [hasPhoto] mirrors
/// `BranchModel.publicImageKey != null` — skips the network round-trip
/// entirely when the branch has no photo uploaded, instead of firing a
/// request that's guaranteed to 404.
class _ShareCardBanner extends StatelessWidget {
  const _ShareCardBanner({required this.branchId, required this.hasPhoto});

  final String branchId;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          hasPhoto
              ? _AuthedImage(
                  path: '/api/v1/branches/$branchId/image-view',
                  fallback: const _ShareCardPhotoFallback(),
                )
              : const _ShareCardPhotoFallback(),
          Positioned(
            left: 12,
            top: 34,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const AppIcon(
                AppIcons.back,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain branded placeholder for [_PublicProfileCard]'s photo header, shown
/// whenever the branch has no public photo uploaded or it fails to load.
class _ShareCardPhotoFallback extends StatelessWidget {
  const _ShareCardPhotoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.skyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const AppIcon(AppIcons.image, size: 34, color: Colors.white),
    );
  }
}
