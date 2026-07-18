import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:cliniqnovva/core/theme/app_colors.dart';
import 'package:cliniqnovva/core/theme/app_theme.dart';
import 'package:cliniqnovva/features/auth/providers/auth_provider.dart';
import 'package:cliniqnovva/features/auth/screens/login_screen.dart';
import 'package:cliniqnovva/features/auth/screens/suspended_screen.dart';
import 'package:cliniqnovva/features/dashboard/screens/dashboard_screen.dart';
import 'package:cliniqnovva/shared/widgets/avatar_widget.dart';
import 'package:cliniqnovva/shared/widgets/cliniqnovva_button.dart';
import 'package:cliniqnovva/shared/widgets/cliniqnovva_sidebar.dart';
import 'package:cliniqnovva/shared/widgets/metric_card.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(theme: theme ?? AppTheme.lightTheme(), home: Scaffold(body: child));
}

/// Avoids ever touching real FirebaseAuth during a widget test.
class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async => null;
}

void main() {
  testWidgets('DashboardScreen placeholder renders under AppTheme', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: const DashboardScreen()));
    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('CliniqnovvaButton renders label and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(CliniqnovvaButton(label: 'Save', onPressed: () => tapped = true)));
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.byType(CliniqnovvaButton));
    expect(tapped, isTrue);
  });

  testWidgets('AvatarWidget shows gradient initials when no photo is given', (tester) async {
    await tester.pumpWidget(_wrap(const AvatarWidget(firstName: 'Alice', lastName: 'Uwase')));

    expect(find.text('AU'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    final container = tester.widget<Container>(
      find.descendant(of: find.byType(AvatarWidget), matching: find.byType(Container)).last,
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
    expect((decoration.gradient as LinearGradient).colors, AppColors.avatarGradients['A']);
  });

  testWidgets('MetricCard renders a large value and an uppercase label', (tester) async {
    await tester.pumpWidget(_wrap(
      const MetricCard(value: '128', label: 'Patients Today', icon: Icons.people),
    ));

    final valueText = tester.widget<Text>(find.text('128'));
    expect(valueText.style?.fontSize, 32);
    expect(find.text('PATIENTS TODAY'), findsOneWidget);
  });

  testWidgets('CliniqnovvaSidebar is deepNavy in both light and dark theme', (tester) async {
    const items = [
      SidebarNavItem(label: 'Dashboard', icon: Icons.dashboard, route: '/dashboard', allowedRoles: ['doctor']),
    ];

    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      await tester.pumpWidget(_wrap(
        CliniqnovvaSidebar(
          items: items,
          currentRoute: '/dashboard',
          currentRole: 'doctor',
          userName: 'Jean',
          userRoleLabel: 'Doctor',
          onNavTap: (_) {},
        ),
        theme: theme,
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, AppColors.deepNavy);
    }
  });

  testWidgets('LoginScreen renders the deepNavy background, logo, and both fields', (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [GoRoute(path: '/login', builder: (context, state) => const LoginScreen())],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        ],
        child: MaterialApp.router(theme: AppTheme.lightTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cliniqnovva'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    final navyContainer = tester.widget<Container>(find.byType(Container).first);
    expect(navyContainer.color, AppColors.deepNavy);
  });

  testWidgets('LoginScreen password field toggles obscureText via the eye icon', (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [GoRoute(path: '/login', builder: (context, state) => const LoginScreen())],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        ],
        child: MaterialApp.router(theme: AppTheme.lightTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    TextField passwordField() => tester.widget<TextField>(find.byType(TextField).last);

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('SuspendedScreen shows the suspension message and a Sign Out button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SuspendedScreen()),
      ),
    );

    expect(find.text('Account Suspended'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    final bg = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(bg.backgroundColor, AppColors.deepNavy);
  });
}
