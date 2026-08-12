import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/notification_deep_link.dart';
import 'firebase_options.dart';
import 'shared/widgets/loading_widget.dart';
import 'shared/widgets/offline_banner.dart';

/// Part 26 Task 3's foreground banner needs a `ScaffoldMessengerState`
/// reachable from outside the widget tree (an FCM callback has no
/// `BuildContext` of its own) — the standard `GlobalKey` handoff, passed
/// to `MaterialApp.router` below.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(child: CliniqnovvaPatientApp()),
    ),
  );
}

class CliniqnovvaPatientApp extends ConsumerStatefulWidget {
  const CliniqnovvaPatientApp({super.key});

  @override
  ConsumerState<CliniqnovvaPatientApp> createState() => _CliniqnovvaPatientAppState();
}

class _CliniqnovvaPatientAppState extends ConsumerState<CliniqnovvaPatientApp> {
  @override
  void initState() {
    super.initState();
    _setUpPushHandling();
  }

  /// Task 3 — three cases, same deep-link resolution
  /// ([NotificationDeepLink], shared with the in-app Notification Center):
  ///   - Foreground: FCM does NOT show a system-tray notification while the
  ///     app is open, so `onMessage` is the only signal — shown as a
  ///     dismissible SnackBar with a "View" action.
  ///   - Background (app alive, user taps the OS tray notification):
  ///     `onMessageOpenedApp`.
  ///   - Terminated (app was fully closed, user taps the OS tray
  ///     notification to LAUNCH it): `getInitialMessage()`, checked once
  ///     after the first frame so the router already exists to navigate.
  Future<void> _setUpPushHandling() async {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${notification.title}\n${notification.body}'),
          action: SnackBarAction(label: 'notification_view'.tr(), onPressed: () => _handleTap(message.data)),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage.data);
  }

  void _handleTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;
    final route = NotificationDeepLink.routeFor(type, data);
    if (route != null) ref.read(appRouterProvider).go(route);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    // Show a loading screen while Firebase resolves the initial auth state,
    // before the router makes any redirect decision.
    if (authState.isLoading) {
      return MaterialApp(
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: const Scaffold(body: LoadingWidget()),
      );
    }

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
