import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import 'auth_provider.dart';

/// Custom claims (role/organizationId/branchId) for whoever authStateProvider
/// currently reports signed in. Re-fetches whenever the signed-in user
/// changes; null while signed out.
final userClaimsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return FirebaseService.getCurrentUserClaims();
});

/// Whether the given organization is active (spec section 4/10 — a
/// suspended organization must lose access immediately). Defaults to true
/// if the field is missing, so incomplete test/dev docs aren't treated as
/// suspended by accident.
final organizationStatusProvider = FutureProvider.family<bool, String>((ref, organizationId) async {
  final doc = await FirebaseService.organizationsRef().doc(organizationId).get();
  final data = doc.data();
  if (data == null) return true;
  return (data['isActive'] as bool?) ?? true;
});

/// Whether the given organization has at least one branch yet — drives the
/// organization_admin onboarding redirect (spec Task 5 / section 6.2).
final hasBranchesProvider = FutureProvider.family<bool, String>((ref, organizationId) async {
  final snapshot = await FirebaseService.branchesRef(organizationId).limit(1).get();
  return snapshot.docs.isNotEmpty;
});
