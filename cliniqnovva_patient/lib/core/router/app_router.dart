import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/booking/booking_screen.dart';
import '../../features/bookings/booking_detail_screen.dart';
import '../../features/bookings/my_bookings_screen.dart';
import '../../features/browse/browse_screen.dart';
import '../../features/browse/clinic_detail_screen.dart';
import '../../features/browse/doctor_detail_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_thread_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/records/medical_record_detail_screen.dart';
import '../../features/records/medical_records_screen.dart';
import '../../features/records/receipt_detail_screen.dart';
import '../../features/records/receipts_screen.dart';
import '../../features/reviews/edit_review_screen.dart';
import '../../features/reviews/leave_review_screen.dart';
import '../../features/reviews/my_reviews_screen.dart';
import '../../features/settings/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/patient_app_shell.dart';
import '../services/firebase_service.dart';

/// Converts Riverpod's auth provider into a Listenable so GoRouter
/// re-evaluates `redirect` whenever sign-in state changes — same pattern
/// (and the same flutterfire #4348 workaround, see [_redirect]) as
/// cliniqnovva/lib/core/router/app_router.dart's RouterNotifier.
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

String? _redirect(Ref ref, GoRouterState state) {
  // currentUser is updated synchronously by sign-in/sign-out/registration,
  // unlike the authStateChanges() stream snapshot, which can lag right
  // after an interactive sign-in.
  final loggedIn = FirebaseService.auth.currentUser != null;
  final onAuthScreen = state.matchedLocation == '/login' || state.matchedLocation == '/register';
  debugPrint('[router] redirect at ${state.matchedLocation} (loggedIn=$loggedIn)');

  if (!loggedIn) {
    return onAuthScreen ? null : '/login';
  }
  if (onAuthScreen) return '/home';
  return null;
}

/// The single GoRouter for the Patient App (Task 6). Every signed-in user
/// here IS a patient by definition — unlike the web dashboard's router,
/// there's no per-role landing-page branching to do.
final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = RouterNotifier(ref);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: routerNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),

      GoRoute(
        path: '/browse/:branchId/doctors/:doctorId',
        builder: (context, state) =>
            DoctorDetailScreen(doctorId: state.pathParameters['doctorId']!),
      ),
      GoRoute(
        path: '/browse/:branchId',
        builder: (context, state) =>
            ClinicDetailScreen(branchId: state.pathParameters['branchId']!),
      ),
      GoRoute(
        path: '/booking',
        builder: (context, state) => BookingScreen(
          branchId: state.uri.queryParameters['branchId'] ?? '',
          doctorId: state.uri.queryParameters['doctorId'],
        ),
      ),
      GoRoute(
        path: '/my-bookings/:id',
        builder: (context, state) =>
            BookingDetailScreen(bookingId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/records', builder: (context, state) => const MedicalRecordsScreen()),
      GoRoute(
        path: '/records/:id',
        builder: (context, state) => MedicalRecordDetailScreen(recordId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/receipts', builder: (context, state) => const ReceiptsScreen()),
      GoRoute(
        path: '/receipts/:id',
        builder: (context, state) => ReceiptDetailScreen(invoiceId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/my-reviews', builder: (context, state) => const MyReviewsScreen()),
      GoRoute(
        path: '/my-reviews/:id/edit',
        builder: (context, state) => EditReviewScreen(reviewId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/leave-review/:appointmentId',
        builder: (context, state) =>
            LeaveReviewScreen(appointmentId: state.pathParameters['appointmentId']!),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),

      // Task 6: bottom navigation shows on exactly these 5 — not on any
      // detail/booking flow above, which is why they're outside this shell.
      ShellRoute(
        builder: (context, state, child) =>
            PatientAppShell(currentRoute: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/browse', builder: (context, state) => const BrowseScreen()),
          GoRoute(path: '/my-bookings', builder: (context, state) => const MyBookingsScreen()),
          GoRoute(path: '/chat', builder: (context, state) => const ChatListScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
