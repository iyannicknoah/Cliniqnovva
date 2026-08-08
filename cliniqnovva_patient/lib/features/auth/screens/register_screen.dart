import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_logo.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../providers/auth_provider.dart';

enum _Step { language, form, duplicatePrompt }

/// Task 3: language picker first (before anything else), then the
/// registration form, then — on submit — an interactive "is this you?"
/// prompt if the phone number matches an existing walk-in record.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  _Step _step = _Step.language;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<PatientMatch> _matches = const [];

  @override
  void initState() {
    super.initState();
    final alreadyPicked = ref.read(localeNotifierProvider);
    if (alreadyPicked != null) _step = _Step.form;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _pickLanguage(Locale locale) async {
    await context.setLocale(locale);
    await ref.read(localeNotifierProvider.notifier).setLocale(locale);
    if (mounted) setState(() => _step = _Step.form);
  }

  String? _validate() {
    if (_nameController.text.trim().isEmpty) return 'error_name_required'.tr();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    if (phone.isEmpty && email.isEmpty) return 'error_phone_or_email_required'.tr();
    if (phone.isNotEmpty) {
      final validPrefix = AppConstants.validPhonePrefixes.any(phone.startsWith);
      if (phone.length != 10 || !validPrefix) return 'error_phone_invalid'.tr();
    }
    if (_passwordController.text.length < 6) return 'error_password_too_short'.tr();
    if (_passwordController.text != _confirmController.text) return 'error_passwords_dont_match'.tr();
    return null;
  }

  Future<void> _submit() async {
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
    final locale = ref.read(localeNotifierProvider)?.languageCode ?? AppConstants.langEnglish;

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .createAccount(phone: phone, email: email, password: _passwordController.text);

      final matches = await ref.read(authNotifierProvider.notifier).checkDuplicate(phone: phone);

      if (!mounted) return;
      if (matches.isNotEmpty) {
        setState(() {
          _matches = matches;
          _step = _Step.duplicatePrompt;
          _isSubmitting = false;
        });
        return;
      }

      await _finalize(locale: locale, phone: phone, email: email, linkPatientId: null);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _finalize({
    required String locale,
    required String? phone,
    required String? email,
    required String? linkPatientId,
  }) async {
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .finalizeRegistration(
            name: _nameController.text.trim(),
            phone: phone,
            email: email,
            preferredLanguage: locale,
            linkPatientId: linkPatientId,
          );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
        _step = _Step.form;
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
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: switch (_step) {
                _Step.language => _LanguageStep(onPicked: _pickLanguage),
                _Step.form => _buildFormStep(),
                _Step.duplicatePrompt => _buildDuplicatePrompt(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const _LogoMark(),
          const SizedBox(height: 24),
          Text(
            'register_title'.tr(),
            style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          Text('register_subtitle'.tr(), style: TextStyle(color: context.appSubtext)),
          const SizedBox(height: 24),
          CliniqnovvaTextField(label: 'field_full_name'.tr(), controller: _nameController),
          const SizedBox(height: 14),
          CliniqnovvaTextField(
            label: 'field_phone'.tr(),
            controller: _phoneController,
            hint: '0788123456',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          CliniqnovvaTextField(
            label: 'field_email_optional'.tr(),
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          CliniqnovvaTextField(
            label: 'field_password'.tr(),
            controller: _passwordController,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: AppIcon(_obscurePassword ? AppIcons.view : AppIcons.eyeSlash, color: context.appSubtext, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 14),
          CliniqnovvaTextField(
            label: 'field_confirm_password'.tr(),
            controller: _confirmController,
            obscureText: _obscureConfirm,
            onFieldSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              icon: AppIcon(_obscureConfirm ? AppIcons.view : AppIcons.eyeSlash, color: context.appSubtext, size: 20),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _InlineBanner(text: _errorMessage!, bg: AppColors.pillRedBg, fg: AppColors.pillRedText),
          ],
          const SizedBox(height: 20),
          CliniqnovvaButton(
            label: 'action_create_account'.tr(),
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: CliniqnovvaButton.text(
              label: 'action_have_account'.tr(),
              onPressed: () => context.go('/login'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDuplicatePrompt() {
    final match = _matches.first;
    final locale = ref.read(localeNotifierProvider)?.languageCode ?? AppConstants.langEnglish;
    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'duplicate_prompt_title'.tr(namedArgs: {
            'clinic': match.clinicName ?? 'duplicate_prompt_a_clinic'.tr(),
          }),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appText, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          match.name,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appSubtext, fontSize: 14),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _InlineBanner(text: _errorMessage!, bg: AppColors.pillRedBg, fg: AppColors.pillRedText),
        ],
        const SizedBox(height: 24),
        CliniqnovvaButton(
          label: 'action_yes_link'.tr(),
          isLoading: _isSubmitting,
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  await _finalize(locale: locale, phone: phone, email: email, linkPatientId: match.id);
                },
        ),
        const SizedBox(height: 10),
        CliniqnovvaButton(
          label: 'action_no_not_me'.tr(),
          color: context.appSecondaryBg,
          isLoading: _isSubmitting,
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  await _finalize(locale: locale, phone: phone, email: email, linkPatientId: null);
                },
        ),
      ],
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.onPicked});

  final ValueChanged<Locale> onPicked;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _LogoMark(),
        const SizedBox(height: 40),
        Text(
          'choose_language'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        _LanguageOption(label: 'Kinyarwanda', onTap: () => onPicked(const Locale('rw'))),
        const SizedBox(height: 12),
        _LanguageOption(label: 'English', onTap: () => onPicked(const Locale('en'))),
        const SizedBox(height: 12),
        _LanguageOption(label: 'Français', onTap: () => onPicked(const Locale('fr'))),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: context.appBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: context.appText, fontSize: 15, fontWeight: FontWeight.w500)),
            AppIcon(AppIcons.chevronRight, size: 18, color: context.appSubtext),
          ],
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CliniqnovvaLogo(size: 32, radius: 10),
        const SizedBox(width: 5),
        Text(
          AppConstants.appName,
          style: const TextStyle(color: AppColors.skyBlue, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 13.5, height: 1.4)),
    );
  }
}
