import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../providers/auth_provider.dart';

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
            _errorMessage = "We couldn't tell what kind of account this is. Please contact support.";
          });
        }
      });
    }
  }

  Future<void> _handleSignIn() async {
    setState(() => _errorMessage = null);
    await ref.read(authNotifierProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    final state = ref.read(authNotifierProvider);
    if (state.hasError && mounted) {
      final error = state.error;
      setState(() {
        _errorMessage = error is AuthException ? error.message : 'Something went wrong signing you in. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _maybeShowRedirectError(context);

    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final isWeb = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.deepNavy),
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x0D2A9D8F), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: isWeb ? 420 : double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 12)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Cliniqnovva',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      AppConstants.appTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    CliniqnovvaTextField(
                      label: 'Email',
                      controller: _emailController,
                      hint: 'you@clinic.rw',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    CliniqnovvaTextField(
                      label: 'Password',
                      controller: _passwordController,
                      hint: '••••••••',
                      obscureText: _obscurePassword,
                      onFieldSubmitted: (_) => _handleSignIn(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.pillRedBg,
                          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.pillRedText, fontSize: 13.5, height: 1.4),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    CliniqnovvaButton(
                      label: 'Sign In',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _handleSignIn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
