import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../providers/auth_provider.dart';

/// Task 4: phone/email + password, friendly error messages, forgot-password.
///
/// 2026-08-19, explicit user instruction — rebuilt to match a FlutterFlow
/// reference's `SigninWidget` source EXACTLY (widths/heights/paddings/radii
/// copied 1:1, not approximated), with the SINGLE deliberate deviation the
/// user called out: the sign-in button is `AppColors.primary`, not the
/// reference's black. Concretely copied from the reference: 10px outer
/// horizontal padding (not 20), 70px top padding, no logo/subtitle on this
/// screen, a top-left back button, 19px/w800 "Welcome back" with NO
/// subtitle, raw `TextFormField`s with 20-radius/barely-visible borders and
/// (18,20,18,20) content padding, a plain (non-blue) "Forgot password?", a
/// 50px/18-radius sign-in button, `Or sign in with` between two
/// screen-width-percentage dividers, and Google/Facebook/Apple rows at
/// their exact per-provider icon sizes/gaps (35/0, 25/5, 35/0 — the
/// reference itself is inconsistent between providers; copied faithfully
/// rather than normalized). Hint text and the "Create account" link are
/// this app's own content/navigation, not present in the demo reference —
/// see inline notes at each deviation.
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

  /// Google/Facebook/Apple sign-in have no backend wired up yet — this is a
  /// visual-only rebuild (2026-08-19, explicit user instruction). A silent
  /// no-op button would be misleading, so tapping one says plainly that
  /// it isn't available yet rather than pretending to attempt a sign-in.
  void _showSocialComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in isn\'t available yet.')),
    );
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

    // Reference's own `.divide(SizedBox(height: 15))` pattern — every
    // top-level child in the form column is spaced by exactly 15px.
    final children = <Widget>[
      Text(
        'login_welcome_back'.tr(),
        style: TextStyle(color: context.appText, fontSize: 19, fontWeight: FontWeight.w800),
      ),
      _AuthField(
        controller: _identifierController,
        hint: 'field_phone_or_email'.tr(), // this app's own field, not the demo's "Enter Email"
      ),
      _AuthField(
        controller: _passwordController,
        hint: 'field_enter_password'.tr(),
        obscureText: _obscurePassword,
        onFieldSubmitted: (_) => _handleSignIn(),
        suffixIcon: InkWell(
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: AppIcon(
            _obscurePassword ? AppIcons.view : AppIcons.eyeSlash,
            color: context.appSubtext,
            size: 20,
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _handleForgotPassword,
          child: Text(
            'action_forgot_password'.tr(),
            style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      if (_errorMessage != null)
        _InlineBanner(text: _errorMessage!, bg: AppColors.pillRedBg, fg: AppColors.pillRedText),
      if (_infoMessage != null)
        _InlineBanner(text: _infoMessage!, bg: AppColors.pillGreenBg, fg: AppColors.pillGreenText),
      CliniqnovvaButton(
        label: 'action_sign_in'.tr(),
        isLoading: isLoading,
        onPressed: isLoading ? null : _handleSignIn,
      ),
      const _OrDivider(),
      _SocialRow(
        mark: const _GoogleMark(size: _googleIconSize),
        markSize: _googleIconSize,
        label: 'Google',
        onPressed: () => _showSocialComingSoon('Google'),
      ),
      _SocialRow(
        mark: const _FacebookMark(size: _facebookIconSize),
        markSize: _facebookIconSize,
        label: 'Facebook',
        onPressed: () => _showSocialComingSoon('Facebook'),
      ),
      // Not in the reference (a static demo with no registration flow) —
      // this app needs a real path to account creation, so it stays.
      Center(
        child: CliniqnovvaButton.text(
          label: 'action_create_account'.tr(),
          onPressed: () => context.go('/register'),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            Align(
              // Explicit user instruction (2026-08-19) — content anchors to
              // the top (matching the reference), never vertically centered.
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 70, 10, 0),
                child: ConstrainedBox(
                  // Not in the reference (a fixed-width mobile demo) — kept
                  // so this doesn't stretch absurdly wide on a desktop
                  // browser window; a no-op at real phone widths.
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0) const SizedBox(height: 15),
                          children[i],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
              child: _BackButton(onTap: () {
                if (context.canPop()) context.pop();
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-left back button (2026-08-19) — present in the reference, absent
/// from the previous version of this screen.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: AppIcon(AppIcons.back, size: 20, color: context.appText),
      ),
    );
  }
}

/// Raw `TextFormField`, decoration copied 1:1 from the reference: 20-radius
/// rounded border that's barely visible (`context.appSecondaryBg`, same
/// role as the reference's `secondaryBackground`), transparent focused
/// border, (18,20,18,20) content padding, filled with `context.appBg`.
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        onFieldSubmitted: onFieldSubmitted,
        style: TextStyle(color: context.appText, fontSize: 14),
        cursorColor: context.appText,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: TextStyle(color: context.appSubtext, fontSize: 14),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: context.appSecondaryBg, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.transparent, width: 1),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.errorRed, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.errorRed, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          filled: true,
          fillColor: context.appBg,
          contentPadding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          suffixIcon: suffixIcon == null
              ? null
              : Padding(padding: const EdgeInsets.only(right: 14), child: suffixIcon),
        ),
      ),
    );
  }
}

/// "Or sign in with" divider. The reference sized each rule at a literal
/// 30% of the DEVICE screen width (`MediaQuery.sizeOf(context).width *
/// 0.3`) — correct on a real, full-width phone screen, but on a tablet/wide
/// browser window this form sits in a centered, width-capped column
/// (`ConstrainedBox(maxWidth: 420)` above) while the divider kept sizing
/// off the FULL screen width, so the rules blew way past the form's own
/// edges (2026-08-19, explicit user instruction — reported with a
/// screenshot on a wide viewport). Fixed with `Expanded`, which sizes each
/// rule to the row's actual available width — i.e. the form column's —
/// keeping the divider centered and contained at any viewport width.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1.5, color: context.appBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'action_or_sign_in_with'.tr(),
            style: TextStyle(color: context.appSubtext, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Container(height: 1.5, color: context.appBorder)),
      ],
    );
  }
}

/// One social-provider row — 45px height, 20-radius, `context.appSecondaryBg`
/// fill, 5px internal padding (all copied from the reference).
///
/// Icon sizes are deliberately NOT equal pixel dimensions (2026-08-19,
/// explicit user instruction: "look equal ... not having the same height
/// and width"). The Facebook mark is a solid disc that fills its square
/// edge-to-edge with zero internal padding, while the Google mark has
/// visible negative space inside its own bounding box — at identical pixel
/// sizes the Facebook mark reads as visually heavier/larger, so it's sized
/// down slightly to match perceived weight instead.
const _googleIconSize = 26.0;
const _facebookIconSize = 21.0;

class _SocialRow extends StatelessWidget {
  const _SocialRow({
    required this.mark,
    required this.markSize,
    required this.label,
    required this.onPressed,
  });

  final Widget mark;
  final double markSize;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSecondaryBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: 45,
          padding: const EdgeInsets.all(5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: markSize, height: markSize, child: mark),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Google's real mark (2026-08-19) — `assets/images/google_icon.png`, the
/// user's own file (found in their Downloads folder as "Google icon.png"
/// after the chat-attached copy couldn't be saved directly). Replaces the
/// earlier hand-drawn `CustomPainter` approximation.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/google_icon.png', width: size, height: size, fit: BoxFit.contain);
  }
}

/// Facebook's real mark (2026-08-19) — `assets/images/facebook_icon.png`,
/// same provenance as [_GoogleMark].
class _FacebookMark extends StatelessWidget {
  const _FacebookMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/facebook_icon.png', width: size, height: size, fit: BoxFit.contain);
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
