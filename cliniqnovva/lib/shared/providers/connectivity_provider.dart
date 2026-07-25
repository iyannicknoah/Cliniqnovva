import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Part 17 Task 8 — "offline banner with retry". A live stream, not a
/// one-shot check — [OfflineBanner] appears/disappears the instant the
/// browser's own online/offline state changes (`navigator.onLine` on web),
/// no manual refresh needed.
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
