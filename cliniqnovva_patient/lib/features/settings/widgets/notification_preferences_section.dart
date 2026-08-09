import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../providers/settings_provider.dart';

/// Part 26 Task 1's toggles — appointment reminders, chat messages, review
/// replies. Opt-out model (absent key means enabled, matching the
/// backend's `isNotificationEnabled()`), so a patient who's never opened
/// this screen sees every switch already ON. Each toggle writes
/// immediately (no separate Save button) — the live [patientProfileProvider]
/// stream reflects the confirmed server state right back, which is also
/// what re-enables the switch if the write actually failed.
class NotificationPreferencesSection extends ConsumerWidget {
  const NotificationPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = (ref.watch(patientProfileProvider).valueOrNull?['notificationPreferences'] as Map?)?.cast<String, dynamic>() ?? {};
    final isSaving = ref.watch(settingsNotifierProvider).isLoading;

    bool enabled(String key) => prefs[key] != false;

    Future<void> toggle(String key, bool value) =>
        ref.read(settingsNotifierProvider.notifier).setNotificationPreference(key, value);

    return CliniqnovvaCard(
      title: 'settings_notification_preferences'.tr(),
      child: Column(
        children: [
          _PreferenceRow(
            label: 'settings_pref_appointment_reminders'.tr(),
            value: enabled('appointmentReminders'),
            enabled: !isSaving,
            onChanged: (v) => toggle('appointmentReminders', v),
          ),
          const SizedBox(height: 12),
          _PreferenceRow(
            label: 'settings_pref_chat_messages'.tr(),
            value: enabled('chatMessages'),
            enabled: !isSaving,
            onChanged: (v) => toggle('chatMessages', v),
          ),
          const SizedBox(height: 12),
          _PreferenceRow(
            label: 'settings_pref_review_replies'.tr(),
            value: enabled('reviewReplies'),
            enabled: !isSaving,
            onChanged: (v) => toggle('reviewReplies', v),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.label, required this.value, required this.enabled, required this.onChanged});

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(color: context.appText, fontSize: 14))),
        Switch(value: value, onChanged: enabled ? onChanged : null),
      ],
    );
  }
}
