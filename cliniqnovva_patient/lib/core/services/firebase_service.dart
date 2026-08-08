import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Central access point for Firebase services — screens/providers go
/// through this rather than calling `FirebaseFirestore.instance` directly,
/// same convention as cliniqnovva/lib/core/services/firebase_service.dart.
/// No Firebase Storage here (files go through the backend + Cloudflare R2,
/// never Firebase Storage — same standing rule as the web app).
abstract final class FirebaseService {
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static String? get currentUserId => auth.currentUser?.uid;

  /// Decoded custom claims (role/clinicId/branchId) for the signed-in user.
  /// `forceRefresh` matters here specifically because a freshly-registered
  /// patient's claims are set by the backend AFTER the Firebase Auth user
  /// already exists — the cached ID token won't have `role: patient` on it
  /// yet, so callers that just finished registration must force a refresh.
  static Future<Map<String, dynamic>?> getCurrentUserClaims({
    bool forceRefresh = false,
  }) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims;
  }

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      db.collection('users').doc(uid);
}
