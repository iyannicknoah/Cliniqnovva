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

/// Matches the reference design language's Signin.txt layout: plain
/// background (no card/backdrop), small logo top, centered form in the
/// middle. Social login, public sign-up, legal text, and the "Powered by"
/// footer are all omitted per the user's explicit instructions.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _checkedQueryError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _maybeShowRedirectError(BuildContext context) {
    if (_checkedQueryError) return;
    _checkedQueryError = true;
    final error = GoRouterState.of(context).uri.queryParameters['error'];
    if (error == 'unknown_role') {
      // Deferred: can't call setState synchronously during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _errorMessage =
                "We couldn't tell what kind of account this is. Please contact support.";
          });
        }
      });
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _errorMessage = null);
    await ref
        .read(authNotifierProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    final state = ref.read(authNotifierProvider);
    if (state.hasError && mounted) {
      final error = state.error;
      setState(() {
        _errorMessage = error is AuthException
            ? error.message
            : 'Something went wrong signing you in. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _maybeShowRedirectError(context);

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 40, 0, 20),
                    child: _LogoMark(),
                  ),
                  Expanded(
                    child: Align(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Text(
                                  'Sign in to your account',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ].withGap(5),
                            ),
                            const SizedBox(height: 30),
                            Column(
                              children: [
                                Column(
                                  children: [
                                    CliniqnovvaTextField(
                                      label: 'Email',
                                      controller: _emailController,
                                      hint: 'you@clinic.rw',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    CliniqnovvaTextField(
                                      label: 'Password',
                                      controller: _passwordController,
                                      hint: '••••••••',
                                      obscureText: _obscurePassword,
                                      onFieldSubmitted: (_) => _handleSignIn(),
                                      suffixIcon: IconButton(
                                        icon: AppIcon(
                                          _obscurePassword
                                              ? AppIcons.view
                                              : AppIcons.eyeSlash,
                                          color: context.appSubtext,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                      ),
                                    ),
                                  ].withGap(10),
                                ),
                                if (_errorMessage != null)
                                  _InlineBanner(
                                    text: _errorMessage!,
                                    bg: AppColors.pillRedBg,
                                    fg: AppColors.pillRedText,
                                  ),
                                CliniqnovvaButton(
                                  label: 'Sign In',
                                  isLoading: isLoading,
                                  onPressed: isLoading ? null : _handleSignIn,
                                ),
                              ].withGap(15),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CliniqnovvaLogo(size: 30, radius: 10),
        SizedBox(width: 5),
        Text(
          AppConstants.appName,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 13.5, height: 1.4),
      ),
    );
  }
}

extension _GapList on List<Widget> {
  List<Widget> withGap(double size) {
    if (isEmpty) return this;
    final result = <Widget>[];
    for (var i = 0; i < length; i++) {
      if (i > 0) result.add(SizedBox(height: size));
      result.add(this[i]);
    }
    return result;
  }
}
