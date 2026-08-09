import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Part 27 Task 3 — "offline banner with retry". Mirrors
/// cliniqnovva/lib/shared/providers/connectivity_provider.dart (same
/// package, same shape) — a live stream, not a one-shot check, so
/// [OfflineBanner] appears/disappears the instant the OS reports a
/// connectivity change, no manual refresh needed.
final isOfflineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.contains(ConnectivityResult.none),
  );
});

/// One-shot re-check for the banner's "Retry" button — invalidating
/// [isOfflineProvider] alone wouldn't re-query the platform, it would just
/// re-subscribe to the same stream, so the retry button explicitly calls
/// this instead.
Future<bool> checkIsOffline() async {
  final results = await Connectivity().checkConnectivity();
  return results.contains(ConnectivityResult.none);
}
