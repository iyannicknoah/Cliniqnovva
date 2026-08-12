import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/patient_profile_provider.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../auth/providers/auth_provider.dart';
import 'widgets/notification_preferences_section.dart';
import 'widgets/profile_section.dart';

/// Bottom-nav tab (Task 6). The one screen in this part that's fully wired
/// rather than a placeholder — it's the concrete consumer of
/// [themeNotifierProvider]/[localeNotifierProvider] (Task 5) and the only
/// way to sign out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings_logout_confirm_title'.tr()),
        content: Text('settings_logout_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('action_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('settings_logout'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }
  }

  /// Reuses the same `sendPasswordResetEmail` flow the login screen's
  /// "Forgot password?" link already relies on (Firebase Auth's own
  /// `sendPasswordResetEmail`) instead of a raw old/new-password form —
  /// that alternative would need Firebase Auth reauthentication
  /// (`updatePassword()` requires a recent sign-in), which this sidesteps
  /// entirely. The identifier is the signed-in patient's own phone/email
  /// (whichever exists), not typed in again.
  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(patientProfileProvider).valueOrNull;
    final identifier = (profile?['email'] as String?) ?? (profile?['phone'] as String?);
    if (identifier == null || identifier.isEmpty) return;

    try {
      await ref.read(authNotifierProvider.notifier).sendPasswordResetEmail(identifier);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('info_password_reset_sent'.tr())));
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeNotifierProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'settings_title'.tr(),
              style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            const ProfileSection(),
            const SizedBox(height: 14),
            const NotificationPreferencesSection(),
            const SizedBox(height: 14),
            CliniqnovvaCard(
              title: 'settings_appearance'.tr(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('settings_theme'.tr(), style: TextStyle(color: context.appText, fontSize: 14)),
                  Row(
                    children: [
                      Text(
                        isDark ? 'settings_theme_dark'.tr() : 'settings_theme_light'.tr(),
                        style: TextStyle(color: context.appSubtext, fontSize: 13),
                      ),
                      Switch(
                        value: isDark,
                        onChanged: (value) => ref
                            .read(themeNotifierProvider.notifier)
                            .setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            CliniqnovvaCard(
              title: 'settings_language'.tr(),
              child: RadioGroup<Locale>(
                groupValue: context.locale,
                onChanged: (value) async {
                  if (value == null) return;
                  await context.setLocale(value);
                  await ref.read(localeNotifierProvider.notifier).setLocale(value);
                },
                child: Column(
                  children: [
                    for (final locale in const [Locale('en'), Locale('fr')])
                      RadioListTile<Locale>(
                        contentPadding: EdgeInsets.zero,
                        value: locale,
                        title: Text(
                          _languageLabel(locale),
                          style: TextStyle(color: context.appText, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CliniqnovvaCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LinkRow(icon: AppIcons.document, label: 'settings_records'.tr(), onTap: () => context.push('/records')),
                  _Divider(),
                  _LinkRow(icon: AppIcons.receipt, label: 'settings_receipts'.tr(), onTap: () => context.push('/receipts')),
                  _Divider(),
                  _LinkRow(icon: AppIcons.star, label: 'settings_reviews'.tr(), onTap: () => context.push('/my-reviews')),
                  _Divider(),
                  _LinkRow(icon: AppIcons.notification, label: 'settings_notifications'.tr(), onTap: () => context.push('/notifications')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CliniqnovvaButton.text(
              label: 'settings_change_password'.tr(),
              isFullWidth: true,
              onPressed: () => _changePassword(context, ref),
            ),
            const SizedBox(height: 12),
            CliniqnovvaButton(
              label: 'settings_logout'.tr(),
              onPressed: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  String _languageLabel(Locale locale) => switch (locale.languageCode) {
    'fr' => 'Français',
    _ => 'English',
  };
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  final IconRef icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            AppIcon(icon, color: context.appSubtext, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: TextStyle(color: context.appText, fontSize: 14))),
            AppIcon(AppIcons.chevronRight, color: context.appSubtext, size: 16),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(height: 1, color: context.appBorder);
}
