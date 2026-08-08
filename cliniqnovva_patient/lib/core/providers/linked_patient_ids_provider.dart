import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_service.dart';

/// A patient may have one linked /patients walk-in record PER CLINIC (see
/// appointments.controller.js's Part 21/22 comments) — read directly from
/// /users/{uid} via Firestore (rules already allow `request.auth.uid ==
/// userId`, same pattern home_screen.dart's profile stream uses; no
/// backend round-trip needed just to read your own linked-record list).
/// Shared by every screen that fans a per-clinic backend call out across
/// every clinic this patient has ever interacted with (My Bookings, Part
/// 22; Medical Records/Receipts, Part 23).
final linkedPatientIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final uid = FirebaseService.currentUserId;
  if (uid == null) return [];
  final doc = await FirebaseService.userDoc(uid).get();
  final ids = doc.data()?['linkedPatientIds'] as List?;
  return ids?.map((e) => e.toString()).toList() ?? [];
});
