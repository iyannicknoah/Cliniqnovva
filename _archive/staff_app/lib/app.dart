import 'package:cliniqnovva_ui/cliniqnovva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/flavor_config.dart';
import 'core/config/generated_l10n/app_localizations.dart';

class CliniqnovvaApp extends StatelessWidget {
  const CliniqnovvaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cliniqnovva Staff',
      debugShowCheckedModeBanner: !FlavorConfig.isProd,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _SetupPlaceholderScreen(),
    );
  }
}

/// Placeholder home screen for the project-setup phase — replaced once
/// feature work (Phase 1) starts. Confirms flavor + localization + the
/// shared cliniqnovva_ui design system all wire up correctly.
class _SetupPlaceholderScreen extends StatefulWidget {
  const _SetupPlaceholderScreen();

  @override
  State<_SetupPlaceholderScreen> createState() =>
      _SetupPlaceholderScreenState();
}

class _SetupPlaceholderScreenState extends State<_SetupPlaceholderScreen> {
  String _locale = 'en';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final flavor = FlavorConfig.instance.flavor.name;

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        title: Text('${l10n.appTitle} ($flavor)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: LanguageSwitcher(
              currentLocaleCode: _locale,
              onChanged: (code) => setState(() => _locale = code),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: context.cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project setup complete — flavor: $flavor',
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      StatusPill(label: 'On Time', tone: PillTone.success),
                      StatusPill(label: 'Late', tone: PillTone.warning),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            CliniqnovvaButton(
              label: l10n.checkIn,
              icon: AppIcons.eventAvailableRounded,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
