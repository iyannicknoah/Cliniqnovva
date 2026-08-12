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

  // Languages. Deliberately DIVERGES from cliniqnovva's (web dashboard)
  // AppConstants.supportedLanguages, which still lists Kinyarwanda — removed
  // here only, because Flutter's built-in flutter_localizations package
  // ships no Material/Widgets/Cupertino translations for 'rw' at all, which
  // crashed every screen with a TextField/OutlinedButton/IconButton whenever
  // a patient picked it. A stored `preferredLanguage: 'rw'` from before this
  // change (or written by the web dashboard) has no matching Patient App UI
  // language anymore — falls back to English via `fallbackLocale` in
  // main.dart's EasyLocalization setup.
  static const String langEnglish = 'en';
  static const String langFrench = 'fr';
  static const List<String> supportedLanguages = [
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
