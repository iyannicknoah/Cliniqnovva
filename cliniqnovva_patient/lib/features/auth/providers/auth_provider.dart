import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/firebase_service.dart';

/// Streams the current Firebase Auth user (null when signed out) — the
/// single source of truth the router uses to decide /login vs /home. Same
/// pattern as cliniqnovva/lib/features/auth/providers/auth_provider.dart.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth.authStateChanges();
});

/// Thin wrapper so a human-readable message reaches the UI instead of a
/// raw FirebaseAuthException/ApiException.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A possible-duplicate walk-in patient record returned by
/// POST /api/auth/patient/check-duplicate (Task 3).
class PatientMatch {
  const PatientMatch({
    required this.id,
    required this.name,
    required this.phone,
    this.clinicName,
  });

  factory PatientMatch.fromJson(Map<String, dynamic> json) => PatientMatch(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    clinicName: json['clinicName'] as String?,
  );

  final String id;
  final String name;
  final String phone;
  final String? clinicName;
}

/// Registration is self-service and phone-first (unlike staff accounts,
/// which an Admin creates directly) — Firebase Auth's email/password
/// provider is used underneath either way, since real Phone Auth needs SMS
/// OTP delivery this environment/part doesn't wire up. A patient who
/// registers with a phone but no email gets a deterministic, never-shown
/// synthetic address so Firebase still has something to key the account on;
/// login then re-derives the same address from whichever the patient types.
String _authEmailFor({String? phone, String? email}) {
  final trimmedEmail = email?.trim() ?? '';
  if (trimmedEmail.isNotEmpty) return trimmedEmail;
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return '$digits@patients.cliniqnovva.rw';
}

/// Owns sign-in/sign-out/registration and reads back the signed-in user's
/// custom claims — the single place other code should go through for auth
/// actions rather than calling FirebaseAuth/ApiService directly.
class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return FirebaseService.auth.currentUser;
  }

  Future<void> signIn({required String identifier, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final email = _authEmailFor(
          phone: identifier.contains('@') ? null : identifier,
          email: identifier.contains('@') ? identifier : null,
        );
        final credential = await FirebaseService.auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        return credential.user;
      } on FirebaseAuthException catch (e) {
        throw AuthException(_friendlyMessage(e.code));
      }
    });
  }

  Future<void> signOut() async {
    await FirebaseService.auth.signOut();
    state = const AsyncData(null);
  }

  /// Step 1 of registration (Task 3): creates the Firebase Auth account
  /// directly from the register screen. Doesn't touch the backend or set
  /// any custom claims yet — the account has no role until
  /// [finalizeRegistration] runs, which is deliberate: the duplicate-check
  /// prompt happens in between, and the user might cancel out of it.
  Future<User> createAccount({
    String? phone,
    String? email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final credential = await FirebaseService.auth.createUserWithEmailAndPassword(
        email: _authEmailFor(phone: phone, email: email),
        password: password,
      );
      final user = credential.user!;
      state = AsyncData(user);
      return user;
    } on FirebaseAuthException catch (e) {
      state = AsyncError(AuthException(_friendlyMessage(e.code)), StackTrace.current);
      throw AuthException(_friendlyMessage(e.code));
    }
  }

  /// Step 2 (optional): searches every clinic's walk-in patient records for
  /// a phone/National ID match, so the register screen can show "we found
  /// an existing record at [Clinic] — is this you?".
  Future<List<PatientMatch>> checkDuplicate({String? phone, String? nationalId}) async {
    try {
      final response = await ApiService.instance.post(
        '/api/auth/patient/check-duplicate',
        data: {'phone': phone, 'nationalId': nationalId},
      );
      final matches = (response.data['matches'] as List? ?? [])
          .map((m) => PatientMatch.fromJson(m as Map<String, dynamic>))
          .toList();
      return matches;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Step 3: finishes registration — sets the `patient` custom claim +
  /// /users/{uid} profile, and links to [linkPatientId] if the user chose
  /// "Yes, this is me". Forces an ID token refresh afterwards so the new
  /// claims are visible immediately (the router's redirect and
  /// [getUserClaims] would otherwise see a stale, claim-less token).
  Future<void> finalizeRegistration({
    required String name,
    String? phone,
    String? email,
    String? nationalId,
    required String preferredLanguage,
    String? linkPatientId,
  }) async {
    try {
      await ApiService.instance.post(
        '/api/auth/patient/finalize-registration',
        data: {
          'name': name,
          'phone': phone,
          'email': email,
          'nationalId': nationalId,
          'preferredLanguage': preferredLanguage,
          'linkPatientId': linkPatientId,
        },
      );
      await FirebaseService.getCurrentUserClaims(forceRefresh: true);
      state = AsyncData(FirebaseService.auth.currentUser);
    } on ApiException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> sendPasswordResetEmail(String identifier) async {
    try {
      final email = _authEmailFor(
        phone: identifier.contains('@') ? null : identifier,
        email: identifier.contains('@') ? identifier : null,
      );
      await FirebaseService.auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e.code));
    }
  }

  /// The patient's own identity for booking/chat/reviews/invoices/
  /// medicalRecords (Firestore rules key every one of those collections off
  /// `request.auth.uid == resource.data.patientId` for the patient's own
  /// read access) — always the signed-in user's own uid, NOT the linked
  /// walk-in record's auto-generated document id. That linked record
  /// (`linkedPatientIds` on /users/{uid}) is a separate, clinic-side
  /// continuity concern for staff, not what booking/chat key off.
  String? getPatientId() => FirebaseService.currentUserId;

  Future<Map<String, dynamic>?> getUserClaims() => FirebaseService.getCurrentUserClaims();

  String _friendlyMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return "That phone/email or password doesn't match our records — try again.";
      case 'invalid-email':
        return "That doesn't look like a valid phone number or email address.";
      case 'email-already-in-use':
        return 'An account already exists for this phone/email — try logging in instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your clinic for help.';
      case 'too-many-requests':
        return 'Too many attempts — please wait a moment before trying again.';
      case 'network-request-failed':
        return "We couldn't reach the server. Check your connection and try again.";
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

/// Persisted light/dark theme preference — same pattern as
/// cliniqnovva's ThemeNotifier.
class ThemeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'cliniqnovva_patient.themeMode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.light,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

/// Tracks whether the patient has completed the language picker at least
/// once (Task 3: "Language picker shown first, before anything else" — on
/// first launch only, never again). `null` means not chosen yet, which the
/// router treats as "show the picker". The actual locale APPLIED to the UI
/// is easy_localization's own `context.setLocale`/`context.locale` (which
/// already persists itself) — this provider exists only to gate that
/// first-launch decision synchronously, without an async easy_localization
/// call inside the router's redirect.
class LocaleNotifier extends Notifier<Locale?> {
  static const _prefsKey = 'cliniqnovva_patient.locale';

  @override
  Locale? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) state = Locale(saved);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

final localeNotifierProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
