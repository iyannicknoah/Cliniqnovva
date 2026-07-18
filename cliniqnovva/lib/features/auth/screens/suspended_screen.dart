import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../providers/auth_provider.dart';

/// Shown instead of any app content when the signed-in user's organization
/// has been suspended (spec Task 4) — the only action available is signing
/// out. No dashboard, no data, nothing else is reachable from here.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cliniqnovva',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 40),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.warningAmber.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber, size: 34),
              ),
              const SizedBox(height: 24),
              const Text(
                'Account Suspended',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                "Your organization's account has been suspended. Please contact Cliniqnovva support.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8FA3B8), fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                child: CliniqnovvaButton(
                  label: 'Sign Out',
                  color: AppColors.warningAmber,
                  onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
