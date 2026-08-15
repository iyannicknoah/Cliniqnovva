import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Runs [action], showing a loading SnackBar for as long as it's in flight
/// and replacing it with a success SnackBar when it resolves (or an error
/// one if it throws) — the standard feedback pattern for every write action
/// in the app (2026-07-23), so a slow request never looks like a silent
/// no-op and a finished one always confirms itself.
///
/// [successMessage] is optional (2026-08-15) — omit it for call sites that
/// show `showSuccessDialog`/`showStaffAddedDialog` themselves instead (major
/// create/save forms); the loading SnackBar still shows and is cleared, just
/// without a trailing success toast.
///
/// Rethrows on failure so callers can still run their own error handling
/// (inline form errors, etc.) in addition to the SnackBar.
Future<T> runWithFeedback<T>(
  BuildContext context,
  Future<T> Function() action, {
  required String loadingMessage,
  String? successMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fg = isDark ? Colors.black : Colors.white;

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(loadingMessage)),
          ],
        ),
      ),
    );

  try {
    final result = await action();
    messenger.clearSnackBars();
    if (successMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.successGreen,
          content: Text(
            successMessage,
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return result;
  } catch (e) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    rethrow;
  }
}
