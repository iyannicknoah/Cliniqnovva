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

/// Task 4: phone/email + password, friendly error messages, forgot-password.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    if (_identifierController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'error_identifier_password_required'.tr());
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .signIn(identifier: _identifierController.text.trim(), password: _passwordController.text);

    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    if (state.hasError) {
      final error = state.error;
      setState(() {
        _errorMessage = error is AuthException ? error.message : 'error_generic'.tr();
      });
      return;
    }

    context.go('/home');
  }

  Future<void> _handleForgotPassword() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'error_enter_identifier_first'.tr());
      return;
    }
    try {
      await ref.read(authNotifierProvider.notifier).sendPasswordResetEmail(identifier);
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
        _infoMessage = 'info_password_reset_sent'.tr();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    const _LogoMark(),
                    const SizedBox(height: 24),
                    Text(
                      'login_welcome_back'.tr(),
                      style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    Text('login_subtitle'.tr(), style: TextStyle(color: context.appSubtext)),
                    const SizedBox(height: 30),
                    CliniqnovvaTextField(
                      label: 'field_phone_or_email'.tr(),
                      controller: _identifierController,
                      hint: '0788123456',
                    ),
                    const SizedBox(height: 10),
                    CliniqnovvaTextField(
                      label: 'field_password'.tr(),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _handleSignIn(),
                      suffixIcon: IconButton(
                        icon: AppIcon(
                          _obscurePassword ? AppIcons.view : AppIcons.eyeSlash,
                          color: context.appSubtext,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CliniqnovvaButton.text(
                        label: 'action_forgot_password'.tr(),
                        underline: true,
                        onPressed: _handleForgotPassword,
                      ),
                    ),
                    if (_errorMessage != null)
                      _InlineBanner(text: _errorMessage!, bg: AppColors.pillRedBg, fg: AppColors.pillRedText),
                    if (_infoMessage != null)
                      _InlineBanner(text: _infoMessage!, bg: AppColors.pillGreenBg, fg: AppColors.pillGreenText),
                    const SizedBox(height: 10),
                    CliniqnovvaButton(
                      label: 'action_sign_in'.tr(),
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _handleSignIn,
                    ),
                    const SizedBox(height: 16),
                    CliniqnovvaButton.text(
                      label: 'action_create_account'.tr(),
                      onPressed: () => context.go('/register'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppTheme.inputRadius)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 13.5, height: 1.4)),
      ),
    );
  }
}
