import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Central access point for Firebase services + org/branch-scoped
/// collection references. Screens/providers should go through this class
/// rather than calling `FirebaseFirestore.instance` directly, so scoping
/// conventions stay consistent everywhere (spec section 10/11: every query
/// must be scoped to organizationId, branch-level roles also to branchId).
abstract final class FirebaseService {
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
  static String? get currentUserId => auth.currentUser?.uid;

  /// Decoded custom claims (role, organizationId, branchId) for the signed-in
  /// user. Returns null if nobody is signed in.
  static Future<Map<String, dynamic>?> getCurrentUserClaims() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final result = await user.getIdTokenResult(true);
    return result.claims;
  }

  static CollectionReference<Map<String, dynamic>> organizationsRef() =>
      db.collection('organizations');

  static Query<Map<String, dynamic>> branchesRef(String organizationId) => db
      .collection('branches')
      .where('organizationId', isEqualTo: organizationId);

  static CollectionReference<Map<String, dynamic>> usersRef() =>
      db.collection('users');

  static CollectionReference<Map<String, dynamic>> patientsRef() =>
      db.collection('patients');

  static Query<Map<String, dynamic>> appointmentsRef(String branchId) =>
      db.collection('appointments').where('branchId', isEqualTo: branchId);

  static Query<Map<String, dynamic>> invoicesRef(String branchId) =>
      db.collection('invoices').where('branchId', isEqualTo: branchId);

  static CollectionReference<Map<String, dynamic>> medicalRecordsRef() =>
      db.collection('medicalRecords');

  static Query<Map<String, dynamic>> chatsRef(String branchId) =>
      db.collection('chats').where('branchId', isEqualTo: branchId);

  static Query<Map<String, dynamic>> reviewsRef(String branchId) =>
      db.collection('reviews').where('branchId', isEqualTo: branchId);

  static CollectionReference<Map<String, dynamic>> auditLogsRef() =>
      db.collection('auditLogs');
}
