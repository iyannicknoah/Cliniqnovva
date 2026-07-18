import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/screens/appointments_screen.dart';
import '../../features/appointments/screens/booking_screen.dart';
import '../../features/auth/providers/access_control_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/suspended_screen.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/billing/screens/invoice_detail_screen.dart';
import '../../features/chat/screens/chat_inbox_screen.dart';
import '../../features/chat/screens/chat_thread_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/departments/screens/departments_screen.dart';
import '../../features/departments/screens/services_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/mobile_patient/screens/patient_home_screen.dart';
import '../../features/mobile_staff/screens/staff_home_screen.dart';
import '../../features/organizations/screens/branches_screen.dart';
import '../../features/organizations/screens/onboarding_screen.dart';
import '../../features/patients/screens/patient_profile_screen.dart';
import '../../features/patients/screens/patients_screen.dart';
import '../../features/patients/screens/walkin_register_screen.dart';
import '../../features/reports/screens/audit_log_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/reviews/screens/popular_clinics_screen.dart';
import '../../features/reviews/screens/reviews_screen.dart';
import '../../features/staff/screens/doctor_schedule_screen.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../../features/super_admin/screens/billing_screen.dart';
import '../../features/super_admin/screens/organizations_screen.dart';
import '../../features/super_admin/screens/oversight_screen.dart';
import '../constants/app_constants.dart';

/// Roles whose organization's `isActive` status gates access (spec Task 4:
/// "any organization-scoped role"). Patients aren't tied to one clinic's
/// subscription status, and Super Admin isn't tied to any organization.
const _orgScopedRolesForSuspension = [
  AppConstants.roleOrganizationAdmin,
  AppConstants.roleBranchAdmin,
  AppConstants.roleReceptionist,
  AppConstants.roleAccountant,
  AppConstants.rolePharmacist,
  AppConstants.roleDoctor,
  AppConstants.roleNurse,
];

String _homeRouteForRole(String role) {
  switch (role) {
    case AppConstants.roleSuperAdmin:
      return '/super-admin/organizations';
    case AppConstants.roleDoctor:
    case AppConstants.roleNurse:
      return '/staff-home';
    case AppConstants.rolePatient:
      return '/patient-home';
    default:
      return '/dashboard';
  }
}

/// Converts Riverpod's authStateProvider into a Listenable so GoRouter
/// re-evaluates `redirect` whenever sign-in state changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    _subscription = ref.listen<AsyncValue<User?>>(
      authStateProvider,
      (previous, next) => notifyListeners(),
    );
  }

  final Ref ref;
  late final ProviderSubscription<AsyncValue<User?>> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

Future<String?> _redirect(Ref ref, GoRouterState state) async {
  final loggedIn = ref.read(authStateProvider).valueOrNull != null;
  final loggingIn = state.matchedLocation == '/login';

  if (!loggedIn) {
    return loggingIn ? null : '/login';
  }

  final claims = await ref.read(userClaimsProvider.future);
  final role = claims?['role'] as String?;
  final organizationId = claims?['organizationId'] as String?;

  // Spec Task 3: an authenticated user whose role isn't one we recognize
  // gets signed out rather than silently let into a random screen.
  if (role == null || !AppConstants.allRoles.contains(role)) {
    await ref.read(authNotifierProvider.notifier).signOut();
    return '/login?error=unknown_role';
  }

  if (_orgScopedRolesForSuspension.contains(role) && organizationId != null) {
    final isActive = await ref.read(organizationStatusProvider(organizationId).future);
    if (!isActive) {
      return state.matchedLocation == '/suspended' ? null : '/suspended';
    }
  }
  if (state.matchedLocation == '/suspended') {
    // Only reachable here if the org is active again, or the role isn't
    // org-scoped — either way this user shouldn't be parked on this screen.
    return _homeRouteForRole(role);
  }

  if (role == AppConstants.roleOrganizationAdmin && organizationId != null) {
    final hasBranches = await ref.read(hasBranchesProvider(organizationId).future);
    if (!hasBranches) {
      return state.matchedLocation == '/onboarding' ? null : '/onboarding';
    }
    if (state.matchedLocation == '/onboarding') {
      return '/dashboard';
    }
  }

  if (loggingIn) {
    return _homeRouteForRole(role);
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
      GoRoute(path: '/suspended', builder: (context, state) => const SuspendedScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),

      GoRoute(
        path: '/super-admin/organizations',
        builder: (context, state) => const OrganizationsScreen(),
      ),
      GoRoute(
        path: '/super-admin/billing',
        builder: (context, state) => const SuperAdminBillingScreen(),
      ),
      GoRoute(
        path: '/super-admin/oversight',
        builder: (context, state) => const OversightScreen(),
      ),

      GoRoute(path: '/branches', builder: (context, state) => const BranchesScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),

      GoRoute(path: '/departments', builder: (context, state) => const DepartmentsScreen()),
      GoRoute(path: '/services', builder: (context, state) => const ServicesScreen()),

      GoRoute(path: '/staff', builder: (context, state) => const StaffScreen()),
      GoRoute(path: '/doctor-schedule', builder: (context, state) => const DoctorScheduleScreen()),

      GoRoute(path: '/patients', builder: (context, state) => const PatientsScreen()),
      GoRoute(
        path: '/patients/walk-in-register',
        builder: (context, state) => const WalkInRegisterScreen(),
      ),
      GoRoute(
        path: '/patients/:id',
        builder: (context, state) => PatientProfileScreen(id: state.pathParameters['id']),
      ),

      GoRoute(path: '/appointments', builder: (context, state) => const AppointmentsScreen()),
      GoRoute(path: '/appointments/book', builder: (context, state) => const BookingScreen()),

      GoRoute(path: '/billing', builder: (context, state) => const BillingScreen()),
      GoRoute(
        path: '/billing/:invoiceId',
        builder: (context, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['invoiceId']),
      ),

      GoRoute(path: '/inventory', builder: (context, state) => const InventoryScreen()),

      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(path: '/audit-log', builder: (context, state) => const AuditLogScreen()),

      GoRoute(path: '/chat', builder: (context, state) => const ChatInboxScreen()),
      GoRoute(
        path: '/chat/:chatId',
        builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['chatId']),
      ),

      GoRoute(path: '/reviews', builder: (context, state) => const ReviewsScreen()),
      GoRoute(path: '/popular-clinics', builder: (context, state) => const PopularClinicsScreen()),

      GoRoute(path: '/staff-home', builder: (context, state) => const StaffHomeScreen()),
      GoRoute(path: '/patient-home', builder: (context, state) => const PatientHomeScreen()),
    ],
  );
});
