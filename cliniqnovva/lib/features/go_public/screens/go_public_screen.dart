import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart';
import '../../departments/providers/departments_provider.dart'
    show activeBranchIdProvider;
import '../providers/go_public_provider.dart';
import '../widgets/go_public_wizard_dialog.dart';

const _stepTitles = [
  'Clinic info',
  'Choose services',
  'Choose doctors',
  'Payout details',
  'Go live',
];

/// 2026-08-17, explicit user instruction — a one-line reminder of what each
/// step collects, shown under its title in [_StepRow] so a returning admin
/// knows what's needed without opening the wizard.
const _stepDescriptions = [
  'Display name, address, phone, email',
  'Choose which services show on your public profile',
  'Choose which doctors show on your public profile',
  'Mobile Money, Airtel Money, or bank account details',
  'Publish your public profile so patients can find you',
];

/// 2026-08-16, explicit user instruction — the "Go Public" nav link's
/// landing page: a static preview of the 5-step wizard (number-in-circle +
/// title, ticked once done) plus the "Go Public" button that opens
/// [showGoPublicWizard]. Branch-scoped, same pattern as Reports/Popular
/// Clinics — no branch selected shows [NoBranchSelectedState] instead of
/// guessing one.
class GoPublicScreen extends ConsumerWidget {
  const GoPublicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.appSubtext)),
        ),
        data: (data) {
          final role = data?['role'] as String?;
          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final effectiveBranchId = isOrgAdmin
              ? ref.watch(activeBranchIdProvider)
              : ownBranchId;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BackButton(),
                const SizedBox(height: 16),
                Expanded(
                  child: effectiveBranchId == null
                      ? const NoBranchSelectedState()
                      : _GoPublicBody(branchId: effectiveBranchId),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 2026-08-17, explicit user instruction — "Go Public" has no sidebar (see
/// [AppShell.build]'s route check), so this replaces it as the only way
/// back to the rest of the app. Same secondary-bg/rounded-square look as
/// the sidebar's own collapse toggle, for visual consistency.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.go('/dashboard'),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.appSecondaryBg,
          borderRadius: BorderRadius.circular(10),
        ),
        // `AppIcons.back` (`HeroIcons.arrowLeft`) rendered blank here in the
        // release web build — swapped for `chevronLeft`, the exact icon+
        // style combination the sidebar's own collapse toggle already uses
        // successfully (`cliniqnovva_sidebar.dart`'s `toggle`).
        child: AppIcon(AppIcons.chevronLeft, size: 18, color: context.appText),
      ),
    );
  }
}

class _GoPublicBody extends ConsumerWidget {
  const _GoPublicBody({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchDetailProvider(branchId));

    return branchAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (branch) {
        final steps = GoPublicSteps(branch);
        final done = [
          steps.infoDone,
          steps.servicesDone,
          steps.doctorsDone,
          steps.payoutDone,
          steps.isLive,
        ];

        // 2026-08-17, explicit user instruction — "Go Public" no longer has
        // a sidebar (see `AppShell.build`'s route check), so this page now
        // owns the whole screen width and a plain `Center` is already the
        // true screen center — no sidebar-width compensation needed
        // (unlike the brief window where this page still sat next to the
        // sidebar and `Center` alone read as visibly off-center).
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (steps.isLive) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.successGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcons.check,
                            size: 18,
                            color: AppColors.successGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You\'re live — this branch is public on the Patient App.',
                              style: TextStyle(
                                color: context.appText,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  CliniqnovvaCard(
                    borderRadius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Setup steps',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.appText,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: context.appBorder,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              children: [
                                for (var i = 0; i < _stepTitles.length; i++)
                                  _StepRow(
                                    number: i + 1,
                                    title: _stepTitles[i],
                                    description: _stepDescriptions[i],
                                    done: done[i],
                                    isLast: i == _stepTitles.length - 1,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            height: 50,
                            child: CliniqnovvaButton(
                              label: steps.isLive
                                  ? 'Manage public profile'
                                  : 'Go Public',
                              onPressed: () => showGoPublicWizard(
                                context,
                                branchId: branchId,
                                initialStep: steps.firstIncompleteStepIndex,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.description,
    required this.done,
    required this.isLast,
  });

  final int number;
  final String title;
  final String description;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? context.appPrimary : context.appSecondaryBg,
            ),
            child: done
                ? const AppIcon(AppIcons.check, size: 19, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: context.appSubtext,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: context.appSubtext, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
