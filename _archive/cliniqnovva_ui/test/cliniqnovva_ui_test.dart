import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cliniqnovva_ui/cliniqnovva_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('CliniqnovvaButton renders label and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      CliniqnovvaButton(label: 'Save', onPressed: () => tapped = true),
    ));

    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.byType(CliniqnovvaButton));
    expect(tapped, isTrue);
  });

  testWidgets('CliniqnovvaButton shows a spinner and ignores taps while isLoading', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      CliniqnovvaButton(label: 'Save', isLoading: true, onPressed: () => tapped = true),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(CliniqnovvaButton));
    expect(tapped, isFalse);
  });

  testWidgets('CliniqnovvaTextField renders its label and accepts input', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(_wrap(
      CliniqnovvaTextField(label: 'Full name', controller: controller),
    ));

    expect(find.text('Full name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Jean Bosco');
    expect(controller.text, 'Jean Bosco');
  });

  testWidgets('StatusPill renders its label', (tester) async {
    await tester.pumpWidget(_wrap(
      const StatusPill(label: 'Confirmed', tone: PillTone.success),
    ));

    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('EmptyState renders title, message, and action button', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      EmptyState(
        icon: AppIcons.categoryOutlined,
        title: 'No departments yet',
        message: 'Add your first department to get started.',
        actionLabel: 'Add Department',
        onAction: () => tapped = true,
      ),
    ));

    expect(find.text('No departments yet'), findsOneWidget);
    expect(find.text('Add Department'), findsOneWidget);
    await tester.tap(find.text('Add Department'));
    expect(tapped, isTrue);
  });

  testWidgets('LanguageSwitcher shows the current locale code and lists all locales', (tester) async {
    await tester.pumpWidget(_wrap(
      LanguageSwitcher(currentLocaleCode: 'en', onChanged: (_) {}),
    ));

    expect(find.text('EN'), findsOneWidget);

    await tester.tap(find.byType(LanguageSwitcher));
    await tester.pumpAndSettle();

    expect(find.text('Kinyarwanda'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
  });

  testWidgets('AppDialogShell.show displays and returns a value on pop', (tester) async {
    await tester.pumpWidget(_wrap(
      Builder(
        builder: (context) => CliniqnovvaButton(
          label: 'Open',
          onPressed: () async {
            final result = await AppDialogShell.show<String>(
              context: context,
              child: const Text('Dialog content'),
            );
            expect(result, 'ok');
          },
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog content'), findsOneWidget);

    Navigator.of(tester.element(find.text('Dialog content'))).pop('ok');
    await tester.pumpAndSettle();
  });

  test('cardDeco()/theme extension is registered on both light and dark themes', () {
    expect(AppTheme.light().extension<CliniqnovvaColors>(), isNotNull);
    expect(AppTheme.dark().extension<CliniqnovvaColors>(), isNotNull);
  });
}
