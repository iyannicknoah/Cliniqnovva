/// App-wide constants for the Patient App. Mirrors
/// cliniqnovva/lib/core/constants/app_constants.dart where it overlaps
/// (role string, supported languages) — those values are compared as
/// literal strings against the SAME backend/Firestore, so they must stay
/// byte-for-byte identical between the two apps.
abstract final class AppConstants {
  static const String appName = 'Cliniqnovva';
  static const String appTagline = 'Run your clinic. We handle the rest.';

  // Same backend both clients talk to (spec: "no backend architecture
  // changes" — one Node/Express API, shared Firestore). Android emulators
  // reach a host machine's localhost via 10.0.2.2, not localhost itself —
  // swap this per-environment when pointed at a real device/staging server.
  static const String backendBaseUrl = 'http://localhost:3000';

  static const String rolePatient = 'patient';

  // Languages — must match cliniqnovva's AppConstants.supportedLanguages
  // exactly (same three, same order: Kinyarwanda, English, French).
  static const String langKinyarwanda = 'rw';
  static const String langEnglish = 'en';
  static const String langFrench = 'fr';
  static const List<String> supportedLanguages = [
    langKinyarwanda,
    langEnglish,
    langFrench,
  ];

  // Rwandan mobile prefixes valid for phone-number validation (matches the
  // web app's AppConstants.validPhonePrefixes).
  static const List<String> validPhonePrefixes = ['078', '079', '073', '072'];

  // Appointment statuses — matches cliniqnovva's AppConstants exactly
  // (used by future parts' booking/my-bookings screens; kept here now so
  // every part after this one has one shared source instead of re-adding it).
  static const String appointmentPending = 'pending';
  static const String appointmentConfirmed = 'confirmed';
  static const String appointmentCheckedIn = 'checkedIn';
  static const String appointmentCompleted = 'completed';
  static const String appointmentCancelled = 'cancelled';
}
