import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import 'auth_provider.dart';

/// Custom claims (role/clinicId/branchId) for the signed-in user.
/// Re-fetches whenever the signed-in user changes; null while signed out.
///
/// Watches both auth providers: on Flutter web the authStateChanges()
/// stream can miss an interactive sign-in (flutterfire #4348), while
/// authNotifierProvider is updated deterministically by signIn/signOut.
/// The actual user is read from FirebaseAuth.currentUser inside
/// getCurrentUserClaims(), which is always current.
final userClaimsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(authNotifierProvider);
  return FirebaseService.getCurrentUserClaims();
});

/// Whether the given clinic is active (spec section 4/10 — a
/// suspended clinic must lose access immediately). Defaults to true
/// if the field is missing, so incomplete test/dev docs aren't treated as
/// suspended by accident.
final clinicStatusProvider = FutureProvider.family<bool, String>((
  ref,
  clinicId,
) async {
  final doc = await FirebaseService.clinicsRef()
      .doc(clinicId)
      .get();
  final data = doc.data();
  if (data == null) return true;
  return (data['isActive'] as bool?) ?? true;
});

/// Whether the given clinic has at least one branch yet — drives the
/// clinic_admin onboarding redirect (spec Task 5 / section 6.2).
final hasBranchesProvider = FutureProvider.family<bool, String>((
  ref,
  clinicId,
) async {
  final snapshot = await FirebaseService.branchesRef(
    clinicId,
  ).limit(1).get();
  return snapshot.docs.isNotEmpty;
});
