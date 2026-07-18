import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/firebase_service.dart';

/// Streams the current Firebase Auth user (null when signed out). This is
/// the single source of truth [AppRouter]/[RouterNotifier] use to decide
/// whether to redirect to /login.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth.authStateChanges();
});

/// Thin wrapper so a human-readable message reaches the login screen
/// instead of a raw FirebaseAuthException.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Owns sign-in/sign-out and reads back the signed-in user's custom claims
/// (role/organizationId/branchId) — the single place other code should go
/// through for auth actions, rather than calling FirebaseAuth directly.
class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    return FirebaseService.auth.currentUser;
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final credential = await FirebaseService.auth.signInWithEmailAndPassword(
          email: email.trim(),
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

  /// Sends a Firebase password-reset email. Throws [AuthException] with a
  /// friendly message on failure — callers should catch it, not
  /// FirebaseAuthException directly.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseService.auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyMessage(e.code));
    }
  }

  Future<String?> getUserRole() async {
    final claims = await FirebaseService.getCurrentUserClaims();
    return claims?['role'] as String?;
  }

  Future<String?> getOrganizationId() async {
    final claims = await FirebaseService.getCurrentUserClaims();
    return claims?['organizationId'] as String?;
  }

  Future<String?> getBranchId() async {
    final claims = await FirebaseService.getCurrentUserClaims();
    return claims?['branchId'] as String?;
  }

  Future<Map<String, dynamic>?> getUserClaims() => FirebaseService.getCurrentUserClaims();

  String _friendlyMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return "That email or password doesn't match our records — try again.";
      case 'invalid-email':
        return "That doesn't look like a valid email address.";
      case 'user-disabled':
        return 'This account has been disabled. Contact your clinic admin for help.';
      case 'too-many-requests':
        return "Too many attempts — please wait a moment before trying again.";
      case 'network-request-failed':
        return "We couldn't reach the server. Check your connection and try again.";
      default:
        return "Something went wrong signing you in. Please try again.";
    }
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

/// Task 7 scaffold — 2FA is only offered to super_admin/organization_admin
/// (enforced by whatever screen surfaces this toggle, not here). Full
/// enrollment needs a profile/settings screen to collect a phone number and
/// the OTP code, which doesn't exist yet — that's later, real UI work.
/// Un-enrolling doesn't need new UI, so it's implemented for real.
extension AuthNotifierMfa on AuthNotifier {
  Future<bool> isMfaEnrolled() async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return false;
    final factors = await user.multiFactor.getEnrolledFactors();
    return factors.isNotEmpty;
  }

  /// TODO: wire up for real once a profile/settings screen exists to host
  /// the toggle + phone number + OTP entry. Intended flow, using Firebase
  /// Auth's built-in multi-factor support (spec Task 7):
  ///   1. `user.multiFactor.getSession()`
  ///   2. `PhoneAuthProvider.verifyPhoneNumber(...)` with that session
  ///   3. `PhoneMultiFactorGenerator.getAssertion(...)` with the SMS code
  ///   4. `user.multiFactor.enroll(assertion)`
  Future<void> enrollMfa() async {
    throw UnimplementedError(
      'MFA enrollment is scaffolded but not wired up — needs a profile/settings screen '
      'to collect the phone number and OTP code.',
    );
  }

  Future<void> unenrollMfa() async {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;
    final factors = await user.multiFactor.getEnrolledFactors();
    if (factors.isEmpty) return;
    await user.multiFactor.unenroll(factorUid: factors.first.uid);
  }
}

/// Persisted light/dark theme preference (shared_preferences-backed).
class ThemeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'cliniqnovva.themeMode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      state = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
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

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
