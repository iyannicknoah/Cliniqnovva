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
import 'package:cliniqnovva/features/organizations/models/organization.dart';
import 'package:cliniqnovva/shared/widgets/avatar_widget.dart';
import 'package:cliniqnovva/shared/widgets/cliniqnovva_button.dart';
import 'package:cliniqnovva/shared/widgets/cliniqnovva_sidebar.dart';
import 'package:cliniqnovva/shared/widgets/cliniqnovva_table.dart';
import 'package:cliniqnovva/shared/widgets/metric_card.dart';
import 'package:cliniqnovva/shared/widgets/status_badge.dart';

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

  testWidgets('CliniqnovvaButton inverts with the theme: black/white in light, white/black in dark', (tester) async {
    await tester.pumpWidget(_wrap(CliniqnovvaButton(label: 'Save', onPressed: () {})));
    final lightButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(lightButton.style?.backgroundColor?.resolve({}), Colors.black);
    expect(lightButton.style?.foregroundColor?.resolve({}), Colors.white);

    await tester.pumpWidget(_wrap(
      CliniqnovvaButton(label: 'Save', onPressed: () {}),
      theme: AppTheme.darkTheme(),
    ));
    // MaterialApp animates between themes; settle so Theme.of is fully dark.
    await tester.pumpAndSettle();
    final darkButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(darkButton.style?.backgroundColor?.resolve({}), Colors.white);
    expect(darkButton.style?.foregroundColor?.resolve({}), Colors.black);
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

  testWidgets('MetricCard renders its label and value', (tester) async {
    await tester.pumpWidget(_wrap(
      const MetricCard(value: '128', label: 'Patients Today'),
    ));

    final valueText = tester.widget<Text>(find.text('128'));
    expect(valueText.style?.fontSize, 18);
    expect(valueText.style?.fontWeight, FontWeight.w600);
    expect(find.text('Patients Today'), findsOneWidget);
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

  testWidgets('LoginScreen renders the pageBackground scaffold, logo, and both fields', (tester) async {
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
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.textContaining('Powered by'), findsNothing);
    expect(find.textContaining('agree to our'), findsNothing);

    // Wordmark must be strictly bolder than the "Welcome back" heading.
    final wordmark = tester.widget<Text>(find.text('Cliniqnovva'));
    final welcome = tester.widget<Text>(find.text('Welcome back'));
    expect(wordmark.style?.fontWeight!.value, greaterThan(welcome.style?.fontWeight!.value ?? 0));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.pageBackground);
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

  testWidgets('CliniqnovvaButton.text renders underlined when requested and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      CliniqnovvaButton.text(label: 'Forgot password?', underline: true, onPressed: () => tapped = true),
    ));

    final text = tester.widget<Text>(find.text('Forgot password?'));
    expect(text.style?.decoration, TextDecoration.underline);
    await tester.tap(find.byType(CliniqnovvaButton));
    expect(tapped, isTrue);
  });

  testWidgets('CliniqnovvaTableHeader renders one column label per cell with dividers', (tester) async {
    await tester.pumpWidget(_wrap(
      const CliniqnovvaTableHeader(columns: ['Client', 'Status', 'Revenue', 'Since']),
    ));

    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Since'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('CliniqnovvaTableRow lays out one cell per Expanded and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      CliniqnovvaTableRow(
        onTap: () => tapped = true,
        cells: const [Text('Jane Uwase'), Text('Active'), Text('\$420'), Text('Jan 2026')],
      ),
    ));

    expect(find.byType(Expanded), findsNWidgets(4));
    await tester.tap(find.byType(CliniqnovvaTableRow));
    expect(tapped, isTrue);
  });

  test('Organization.fromJson parses a finite-plan org and computes branchLimitLabel', () {
    final org = Organization.fromJson({
      'id': 'org1',
      'name': 'Kigali Family Clinic',
      'subscriptionPlan': 'pro',
      'branchLimit': 5,
      'branchCount': 2,
      'isActive': true,
      'createdAt': '2026-07-20T10:00:00.000Z',
      'ownerContactName': 'Jean Uwase',
      'ownerContactPhone': '+250788123456',
      'branches': [
        {'id': 'b1', 'name': 'Downtown', 'isActive': true},
      ],
    });

    expect(org.name, 'Kigali Family Clinic');
    expect(org.subscriptionPlan, 'pro');
    expect(org.branchLimitLabel, '2 / 5');
    expect(org.branches, hasLength(1));
    expect(org.branches.first.name, 'Downtown');
  });

  test('Organization.fromJson reports "Unlimited" for a null (enterprise) branchLimit', () {
    final org = Organization.fromJson({
      'id': 'org2',
      'name': 'Rwanda Health Group',
      'subscriptionPlan': 'enterprise',
      'branchLimit': null,
      'branchCount': 12,
      'isActive': false,
      'createdAt': null,
    });

    expect(org.isActive, isFalse);
    expect(org.branchLimitLabel, 'Unlimited');
    expect(org.createdAt, isNull);
  });

  testWidgets('StatusBadge renders Active/Suspended with the right tone', (tester) async {
    await tester.pumpWidget(_wrap(const StatusBadge(text: 'Active', type: BadgeType.success)));
    expect(find.text('Active'), findsOneWidget);

    await tester.pumpWidget(_wrap(const StatusBadge(text: 'Suspended', type: BadgeType.error)));
    expect(find.text('Suspended'), findsOneWidget);
  });

  testWidgets('No italic text style is used anywhere in the login screen', (tester) async {
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

    final allText = tester.widgetList<Text>(find.byType(Text));
    for (final t in allText) {
      expect(t.style?.fontStyle, isNot(FontStyle.italic), reason: 'Found italic text: "${t.data}"');
    }
  });
}
