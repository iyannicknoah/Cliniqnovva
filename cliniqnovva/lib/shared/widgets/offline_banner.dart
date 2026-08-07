import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/offline_queue.dart';
import '../../core/offline/offline_sync.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../providers/connectivity_provider.dart';
import 'app_icon.dart';

/// Part 17 Task 8 — a persistent strip pinned above the whole app (wired
/// into `MaterialApp.router`'s `builder:`, see `main.dart`) whenever the
/// browser reports no connectivity. Deliberately impossible to miss —
/// same "standing notice, not a dismissible toast" reasoning as Part 15's
/// chat disclaimer banner.
///
/// Offline-first (2026-07-30) — this is also where [offlineSyncProvider]
/// gets kept alive: that notifier's `build()` (and the reconnect listener
/// it sets up) only ever runs while something is watching it, and this
/// banner is the one widget that's always mounted for the whole app
/// session. Also now shows two more states beyond plain offline/online:
/// a pending-sync count while queued writes haven't synced yet, and a
/// distinct state for entries that failed to sync for a real reason (not
/// just "still offline") and need a human to look at them.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    await checkIsOffline();
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _showFailedEntries(List<PendingMutation> failed) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Some changes couldn\'t sync'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final m in failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _kindLabel(m.kind),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.lastError ?? 'Unknown error',
                        style: const TextStyle(color: AppColors.brightRed, fontSize: 13),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            await ref.read(offlineQueueProvider.notifier).remove(m.id);
                            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                          },
                          child: const Text('Discard'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _kindLabel(OfflineMutationKind kind) => switch (kind) {
    OfflineMutationKind.registerPatient => 'Patient registration',
    OfflineMutationKind.recordVitals => 'Recorded vitals',
    OfflineMutationKind.checkInAppointment => 'Appointment check-in',
  };

  @override
  Widget build(BuildContext context) {
    // Keeps the sync engine alive for the app's lifetime — see class doc.
    ref.watch(offlineSyncProvider);

    final isOffline = ref.watch(isOfflineProvider).valueOrNull ?? false;
    final queue = ref.watch(offlineQueueProvider).valueOrNull ?? const [];
    final failed = queue.where((m) => m.lastError != null).toList();
    final pendingCount = queue.length - failed.length;

    return Column(
      children: [
        if (isOffline)
          Material(
            color: AppColors.errorRed,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const AppIcon(AppIcons.offline, color: Colors.white, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'offline_message'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: _checking ? null : _retry,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: _checking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('offline_retry'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (pendingCount > 0)
          Material(
            color: AppColors.warningAmber,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pendingCount == 1
                            ? 'Syncing 1 change…'
                            : 'Syncing $pendingCount changes…',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (failed.isNotEmpty)
          Material(
            color: AppColors.errorRed,
            child: InkWell(
              onTap: () => _showFailedEntries(failed),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.warning, color: Colors.white, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          failed.length == 1
                              ? '1 change couldn\'t sync — tap to review'
                              : '${failed.length} changes couldn\'t sync — tap to review',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
