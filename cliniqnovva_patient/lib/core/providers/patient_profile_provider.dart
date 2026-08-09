import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_service.dart';

/// Streams the signed-in patient's own /users/{uid} doc (Firestore rules
/// already allow `request.auth.uid == userId` reads — no backend call
/// needed just to read your own profile). Shared by Home (greeting) and
/// Settings (profile form, notification preference toggles) — both need
/// the same live document, not a fetch-once copy each.
final patientProfileProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final uid = FirebaseService.currentUserId;
  if (uid == null) return Stream.value(null);
  return FirebaseService.userDoc(uid).snapshots().map((doc) => doc.data());
});
