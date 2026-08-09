import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/patient_profile_provider.dart';
import '../../../core/services/api_service.dart';

/// PUT /api/auth/patient/profile — Part 26 Task 1's profile form and
/// notification preference toggles. Both write to the SAME endpoint (see
/// auth.service.js#updatePatientProfile's doc comment for why this is
/// /users/{uid}, not PUT /api/patients/:patientId) — omit whichever
/// argument isn't changing. [patientProfileProvider] is a live Firestore
/// stream, so a successful write reflects on screen immediately with no
/// manual refetch/invalidate needed.
class SettingsNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  void build() {}

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? email,
    String? dateOfBirth,
    String? nationalId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.instance.put<Map<String, dynamic>>(
        '/api/auth/patient/profile',
        data: {
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
          if (nationalId != null) 'nationalId': nationalId,
        },
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> setNotificationPreference(String key, bool value) async {
    state = const AsyncValue.loading();
    try {
      await ApiService.instance.put<Map<String, dynamic>>(
        '/api/auth/patient/profile',
        data: {
          'notificationPreferences': {key: value},
        },
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final settingsNotifierProvider = AsyncNotifierProvider.autoDispose<SettingsNotifier, void>(SettingsNotifier.new);
