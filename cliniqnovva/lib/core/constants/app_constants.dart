/// App-wide constants. Public holidays are intentionally NOT listed here —
/// they're configurable per spec section 1 and load from the Firestore
/// `/publicHolidays` collection at runtime, never hardcoded.
abstract final class AppConstants {
  static const String appName = 'Cliniqnovva';
  static const String appTagline = 'Run your clinic. We handle the rest.';

  static const String backendBaseUrl = 'http://localhost:3000';

  // Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleClinicAdmin = 'clinic_admin';
  static const String roleBranchAdmin = 'branch_admin';
  static const String roleReceptionist = 'receptionist';
  static const String roleAccountant = 'accountant';
  static const String rolePharmacist = 'pharmacist';
  static const String roleDoctor = 'doctor';
  static const String roleNurse = 'nurse';
  static const String rolePatient = 'patient';

  static const List<String> allRoles = [
    roleSuperAdmin,
    roleClinicAdmin,
    roleBranchAdmin,
    roleReceptionist,
    roleAccountant,
    rolePharmacist,
    roleDoctor,
    roleNurse,
    rolePatient,
  ];

  /// Roles manageable from the Staff screen (Part 8 Task 1) — excludes
  /// branch_admin/clinic_admin/super_admin, whose accounts are
  /// created elsewhere.
  static const List<String> staffRoles = [
    roleDoctor,
    roleNurse,
    roleReceptionist,
    rolePharmacist,
    roleAccountant,
  ];

  // Subscription plans
  static const String planBasic = 'basic';
  static const String planPro = 'pro';
  static const String planEnterprise = 'enterprise';
  static const List<String> subscriptionPlans = [
    planBasic,
    planPro,
    planEnterprise,
  ];

  // Appointment statuses
  static const String appointmentPending = 'pending';
  static const String appointmentConfirmed = 'confirmed';
  static const String appointmentCheckedIn = 'checkedIn';
  static const String appointmentCompleted = 'completed';
  static const String appointmentCancelled = 'cancelled';
  static const List<String> appointmentStatuses = [
    appointmentPending,
    appointmentConfirmed,
    appointmentCheckedIn,
    appointmentCompleted,
    appointmentCancelled,
  ];

  // Invoice statuses
  static const String invoiceUnpaid = 'unpaid';
  static const String invoicePartial = 'partial';
  static const String invoicePaid = 'paid';
  static const String invoiceVoided = 'voided';
  static const List<String> invoiceStatuses = [
    invoiceUnpaid,
    invoicePartial,
    invoicePaid,
    invoiceVoided,
  ];

  // Insurance schemes
  static const String insuranceMutuelle = 'mutuelle';
  static const String insuranceRssb = 'rssb';
  static const String insurancePrivate = 'private';
  static const String insuranceNone = 'none';
  static const List<String> insuranceSchemes = [
    insuranceMutuelle,
    insuranceRssb,
    insurancePrivate,
    insuranceNone,
  ];

  // Languages
  static const String langKinyarwanda = 'rw';
  static const String langEnglish = 'en';
  static const String langFrench = 'fr';
  static const List<String> supportedLanguages = [
    langKinyarwanda,
    langEnglish,
    langFrench,
  ];

  // Rwandan mobile prefixes valid for phone-number validation (spec section 1)
  static const List<String> validPhonePrefixes = ['078', '079', '073', '072'];
}

/// Landing route per role. Used by the router's redirect and by the login
/// screen's explicit post-sign-in navigation — keep the two in sync by
/// keeping this the single source of truth.
///
/// Part 17 Task 2/3 — Doctor/Nurse now land on their own dedicated "Today"
/// screens (there's no Staff Mobile App in this build, so these are
/// full web screens) instead of the old `/staff-home` placeholder.
String homeRouteForRole(String role) {
  switch (role) {
    case AppConstants.roleSuperAdmin:
      return '/super-admin/overview';
    case AppConstants.roleDoctor:
      return '/doctor-today';
    case AppConstants.roleNurse:
      return '/nurse-today';
    case AppConstants.rolePatient:
      return '/patient-home';
    default:
      return '/dashboard';
  }
}

/// Single canonical role -> display-label mapping (Part 17) — replaces the
/// partial, duplicated-per-screen maps that used to live in
/// `staff_screen.dart` and the hardcoded `'Super Admin'` string in
/// `SuperAdminScaffold`. Covers all 9 [AppConstants.allRoles].
String roleLabel(String role) => switch (role) {
  AppConstants.roleSuperAdmin => 'Super Admin',
  AppConstants.roleClinicAdmin => 'Clinic Admin',
  AppConstants.roleBranchAdmin => 'Branch Admin',
  AppConstants.roleReceptionist => 'Receptionist',
  AppConstants.roleAccountant => 'Accountant',
  AppConstants.rolePharmacist => 'Pharmacist',
  AppConstants.roleDoctor => 'Doctor',
  AppConstants.roleNurse => 'Nurse',
  AppConstants.rolePatient => 'Patient',
  _ => role,
};
