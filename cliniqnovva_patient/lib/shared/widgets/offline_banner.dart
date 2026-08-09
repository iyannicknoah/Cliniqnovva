import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/connectivity_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import 'app_icon.dart';

/// Part 27 Task 3 — a persistent strip pinned above the whole app (wired
/// into `MaterialApp.router`'s `builder:`, see `main.dart`) whenever the
/// device reports no connectivity. Same "standing notice, not a dismissible
/// toast" pattern as the chat disclaimer banner and, on the web dashboard,
/// `cliniqnovva/lib/shared/widgets/offline_banner.dart` — this is
/// deliberately a smaller version of that one: the web app also tracks a
/// local offline-write queue (walk-in registration/vitals/check-in typed
/// while offline, synced later) that has no equivalent here — the Patient
/// App has no offline-queued writes, so only the connectivity strip itself
/// is mirrored.
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

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider).valueOrNull ?? false;

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
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
