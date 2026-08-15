import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/screens/appointments_screen.dart';
import '../../features/audit_log/screens/audit_log_screen.dart' show AuditLogScreen;
import '../../features/auth/providers/access_control_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/suspended_screen.dart';
import '../../features/billing/screens/accountant_overview_screen.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/chat/screens/chat_inbox_screen.dart';
import '../../features/chat/screens/chat_thread_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/departments/screens/departments_screen.dart';
import '../../features/departments/screens/services_screen.dart';
import '../../features/doctor/screens/doctor_reviews_screen.dart';
import '../../features/doctor/screens/doctor_today_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/pharmacist_overview_screen.dart';
import '../../features/lab_orders/screens/lab_orders_screen.dart';
import '../../features/lab_orders/screens/laboratorian_overview_screen.dart';
import '../../features/mobile_patient/screens/patient_home_screen.dart';
import '../../features/mobile_staff/screens/staff_home_screen.dart';
import '../../features/nurse/screens/nurse_today_screen.dart';
import '../../features/clinics/screens/branches_screen.dart';
import '../../features/clinics/screens/onboarding_screen.dart';
import '../../features/patients/screens/merge_patients_screen.dart';
import '../../features/patients/screens/patients_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/reviews/screens/popular_clinics_screen.dart';
import '../../features/reviews/screens/reviews_screen.dart';
import '../../features/super_admin/screens/audit_log_screen.dart' show SuperAdminAuditLogScreen;
import '../../features/staff/screens/doctor_schedule_screen.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../../features/super_admin/screens/billing_screen.dart';
import '../../features/super_admin/screens/clinic_detail_screen.dart';
import '../../features/super_admin/screens/clinics_screen.dart';
import '../../features/super_admin/screens/overview_screen.dart';
import '../../features/super_admin/screens/support_view_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../constants/app_constants.dart';
import '../services/firebase_service.dart';

/// Roles whose clinic's `isActive` status gates access (spec Task 4:
/// "any clinic-scoped role"). Patients aren't tied to one clinic's
/// subscription status, and Super Admin isn't tied to any clinic.
const _orgScopedRolesForSuspension = [
  AppConstants.roleClinicAdmin,
  AppConstants.roleBranchAdmin,
  AppConstants.roleReceptionist,
  AppConstants.roleAccountant,
  AppConstants.rolePharmacist,
  AppConstants.roleDoctor,
  AppConstants.roleNurse,
  AppConstants.roleLaboratorian,
];

/// Converts Riverpod's auth providers into a Listenable so GoRouter
/// re-evaluates `redirect` whenever sign-in state changes.
///
/// Listens to both authStateProvider (Firebase's browser stream — covers
/// sign-in restored on page load and changes from other tabs) and
/// authNotifierProvider (updated deterministically by signIn/signOut).
/// The stream alone is not enough: on Flutter web, authStateChanges() is
/// known to sometimes not emit after an interactive
/// signInWithEmailAndPassword (flutterfire #4348), which left the user
/// parked on /login until a manual refresh.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    _subscriptions = [
      ref.listen<AsyncValue<User?>>(
        authStateProvider,
        (previous, next) => notifyListeners(),
      ),
      ref.listen<AsyncValue<User?>>(
        authNotifierProvider,
        (previous, next) => notifyListeners(),
      ),
    ];
  }

  final Ref ref;
  late final List<ProviderSubscription<AsyncValue<User?>>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    super.dispose();
  }
}

Future<String?> _redirect(Ref ref, GoRouterState state) async {
  // Dev-only preview routes (2026-08-14) — allowlisted before the auth
  // check entirely, same pattern as the Patient App's `/dev/home-preview`.
  // Not linked from anywhere in the real app UI.
  if (state.matchedLocation.startsWith('/dev/')) {
    return null;
  }

  // currentUser is updated synchronously by sign-in/sign-out, unlike the
  // authStateChanges() stream snapshot, which can be stale on web right
  // after an interactive login.
  final loggedIn = FirebaseService.auth.currentUser != null;
  final loggingIn = state.matchedLocation == '/login';
  debugPrint(
    '[router] redirect at ${state.matchedLocation} (loggedIn=$loggedIn)',
  );

  if (!loggedIn) {
    return loggingIn ? null : '/login';
  }

  final claims = await ref.read(userClaimsProvider.future);
  final role = claims?['role'] as String?;
  debugPrint('[router] claims resolved: role=$role');
  final clinicId = claims?['clinicId'] as String?;

  // Spec Task 3: an authenticated user whose role isn't one we recognize
  // gets signed out rather than silently let into a random screen.
  if (role == null || !AppConstants.allRoles.contains(role)) {
    await ref.read(authNotifierProvider.notifier).signOut();
    return '/login?error=unknown_role';
  }

  if (_orgScopedRolesForSuspension.contains(role) && clinicId != null) {
    final isActive = await ref.read(clinicStatusProvider(clinicId).future);
    if (!isActive) {
      return state.matchedLocation == '/suspended' ? null : '/suspended';
    }
  }
  if (state.matchedLocation == '/suspended') {
    // Only reachable here if the org is active again, or the role isn't
    // org-scoped — either way this user shouldn't be parked on this screen.
    return homeRouteForRole(role);
  }

  if (role == AppConstants.roleClinicAdmin && clinicId != null) {
    final hasBranches = await ref.read(hasBranchesProvider(clinicId).future);
    if (!hasBranches) {
      return state.matchedLocation == '/onboarding' ? null : '/onboarding';
    }
    if (state.matchedLocation == '/onboarding') {
      return '/dashboard';
    }
  }

  if (loggingIn) {
    return homeRouteForRole(role);
  }

  return null;
}

/// The single GoRouter for the whole app (spec: "one codebase" — admin web,
/// staff mobile, and patient mobile all share this router; role-based
/// visibility is enforced within screens/nav, not by having separate apps).
/// Every route requires authentication — there are no public routes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = RouterNotifier(ref);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: routerNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dev/dashboard-preview',
        builder: (context, state) => const DashboardPreviewScreen(),
      ),
      GoRoute(
        path: '/suspended',
        builder: (context, state) => const SuspendedScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      GoRoute(
        path: '/super-admin/overview',
        builder: (context, state) => const OverviewScreen(),
      ),
      GoRoute(
        path: '/super-admin/clinics',
        builder: (context, state) => const ClinicsScreen(),
      ),
      GoRoute(
        path: '/super-admin/clinics/:id',
        builder: (context, state) =>
            ClinicDetailScreen(clinicId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/super-admin/clinics/:id/support-view',
        builder: (context, state) =>
            SupportViewScreen(clinicId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/super-admin/billing',
        builder: (context, state) => const SuperAdminBillingScreen(),
      ),
      GoRoute(
        path: '/super-admin/audit-log',
        builder: (context, state) => const SuperAdminAuditLogScreen(),
      ),

      GoRoute(
        path: '/staff-home',
        builder: (context, state) => const StaffHomeScreen(),
      ),
      GoRoute(
        path: '/patient-home',
        builder: (context, state) => const PatientHomeScreen(),
      ),

      // Part 17 Task 4 — every general admin/staff screen shares one navy
      // sidebar shell. Each screen below still renders its OWN `Scaffold`
      // unchanged (none of them needed to change) — it just becomes this
      // shell's content pane. Super Admin keeps its separate
      // `SuperAdminScaffold`-based shell above; /login, /suspended,
      // /onboarding, and the two mobile placeholders stay unwrapped.
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentRoute: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          GoRoute(
            path: '/doctor-today',
            builder: (context, state) => const DoctorTodayScreen(),
          ),
          GoRoute(
            path: '/doctor-reviews',
            builder: (context, state) => const DoctorReviewsScreen(),
          ),
          GoRoute(
            path: '/nurse-today',
            builder: (context, state) => const NurseTodayScreen(),
          ),

          GoRoute(
            path: '/branches',
            builder: (context, state) => const BranchesScreen(),
          ),

          GoRoute(
            path: '/departments',
            builder: (context, state) => const DepartmentsScreen(),
          ),
          GoRoute(
            path: '/services',
            builder: (context, state) => const ServicesScreen(),
          ),

          GoRoute(
            path: '/staff',
            builder: (context, state) => const StaffScreen(),
          ),
          GoRoute(
            path: '/doctor-schedule',
            builder: (context, state) => const DoctorScheduleScreen(),
          ),

          GoRoute(
            path: '/patients',
            builder: (context, state) => const PatientsScreen(),
          ),
          GoRoute(
            path: '/patients/merge',
            builder: (context, state) => const MergePatientsScreen(),
          ),

          GoRoute(
            path: '/appointments',
            builder: (context, state) => const AppointmentsScreen(),
          ),

          GoRoute(
            path: '/accountant-overview',
            builder: (context, state) => const AccountantOverviewScreen(),
          ),
          GoRoute(
            path: '/billing',
            builder: (context, state) => const BillingScreen(),
          ),

          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/pharmacist-overview',
            builder: (context, state) => const PharmacistOverviewScreen(),
          ),
          GoRoute(
            path: '/laboratorian-overview',
            builder: (context, state) => const LaboratorianOverviewScreen(),
          ),
          GoRoute(
            path: '/lab-orders',
            builder: (context, state) => const LabOrdersScreen(),
          ),

          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/audit-log',
            builder: (context, state) => const AuditLogScreen(),
          ),

          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatInboxScreen(),
          ),
          GoRoute(
            path: '/chat/:chatId',
            builder: (context, state) =>
                ChatThreadScreen(chatId: state.pathParameters['chatId']),
          ),

          GoRoute(
            path: '/reviews',
            builder: (context, state) => const ReviewsScreen(),
          ),
          GoRoute(
            path: '/popular-clinics',
            builder: (context, state) => const PopularClinicsScreen(),
          ),
        ],
      ),
    ],
  );
});
