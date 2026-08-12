import 'package:flutter/material.dart';

import '../../../core/theme/theme_ext.dart';
import '../home_screen.dart';
import 'sample_home_data.dart';

/// `/dev/home-preview` (see app_router.dart) — renders Home's real layout
/// ([HomeTopBar]/[ServicesRow]/[ClinicCarousel], same widgets the real
/// [HomeScreen] uses) fed [sampleHomeBrowseData] directly, with no
/// Riverpod provider involved at all — deliberately NOT a
/// `homeBrowseProvider` override (a nested `ProviderScope` override is
/// easy to get subtly wrong/silently no-op; passing plain data straight
/// into the same presentational widgets can't fail to render). The ONLY
/// way to see Home's design without a real login, since live login is
/// still blocked by the known Firebase project mismatch
/// (docs/known-issues.md). Not linked from anywhere in the real app UI.
class HomePreviewScreen extends StatelessWidget {
  const HomePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeTopBar(),
              const SizedBox(height: 28),
              ServicesRow(services: sampleHomeBrowseData.services),
              const SizedBox(height: 24),
              ClinicCarousel(title: 'Popular Clinics', branches: sampleHomeBrowseData.popular),
              const SizedBox(height: 24),
              ClinicCarousel(title: 'New on Cliniqnovva', branches: sampleHomeBrowseData.newOnes, isNew: true),
            ],
          ),
        ),
      ),
    );
  }
}
