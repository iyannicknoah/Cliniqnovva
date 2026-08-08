import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cliniqnovva_patient/core/theme/app_colors.dart';
import 'package:cliniqnovva_patient/core/theme/app_theme.dart';
import 'package:cliniqnovva_patient/shared/widgets/avatar_widget.dart';
import 'package:cliniqnovva_patient/shared/widgets/cliniqnovva_button.dart';
import 'package:cliniqnovva_patient/shared/widgets/status_badge.dart';

// NOTE: widget tests exercising screens that depend on EasyLocalization
// (LoginScreen, RegisterScreen, SettingsScreen, ...) were tried here and
// dropped — wrapping them in an `EasyLocalization` ancestor made
// `tester.pumpAndSettle()` hang indefinitely (10-minute timeout) in this
// environment, most likely EasyLocalization's own asset/plugin-channel
// initialization never settling under `flutter test`'s harness. Real
// end-to-end verification for Part 19's registration/login flows instead
// lives in `backend/test/patientAuth.test.js` (mock Firestore/Auth), plus
// `flutter analyze` for the Dart/widget code itself — see
// docs/known-issues.md for the broader "no live device in this
// environment" context. These tests stick to widgets with zero
// localization/Firebase dependency, which run in ~1s total.

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.lightTheme(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
    'CliniqnovvaButton inverts with the theme: black/white in light, white/black in dark',
    (tester) async {
      await tester.pumpWidget(_wrap(CliniqnovvaButton(label: 'Save', onPressed: () {})));
      final lightButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(lightButton.style?.backgroundColor?.resolve({}), Colors.black);
      expect(lightButton.style?.foregroundColor?.resolve({}), Colors.white);

      await tester.pumpWidget(
        _wrap(CliniqnovvaButton(label: 'Save', onPressed: () {}), theme: AppTheme.darkTheme()),
      );
      await tester.pumpAndSettle();
      final darkButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(darkButton.style?.backgroundColor?.resolve({}), Colors.white);
      expect(darkButton.style?.foregroundColor?.resolve({}), Colors.black);
    },
  );

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

  testWidgets('StatusBadge renders its text with the requested tone', (tester) async {
    await tester.pumpWidget(_wrap(const StatusBadge(text: 'Confirmed', type: BadgeType.success)));
    expect(find.text('Confirmed'), findsOneWidget);

    final text = tester.widget<Text>(find.text('Confirmed'));
    expect(text.style?.color, AppColors.brightGreen);
  });
}
