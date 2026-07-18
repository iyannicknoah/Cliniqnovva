import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/flavor_config.dart';
import 'core/config/generated_l10n/app_localizations.dart';

class CliniqnovvaApp extends StatelessWidget {
  const CliniqnovvaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cliniqnovva',
      debugShowCheckedModeBanner: !FlavorConfig.isProd,
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
/// feature work (Phase 1) starts. Confirms flavor + localization wiring works.
class _SetupPlaceholderScreen extends StatelessWidget {
  const _SetupPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final flavor = FlavorConfig.instance.flavor.name;
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.appTitle} ($flavor)')),
      body: Center(
        child: Text('Project setup complete — flavor: $flavor'),
      ),
    );
  }
}
