import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../departments/widgets/branch_selector.dart';
import '../providers/reviews_provider.dart';

String _formatDateTime(DateTime? d) {
  if (d == null) return 'not yet calculated';
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// Part 16 Task 5 — /popular-clinics. INTERNAL, read-only: a branch's own
/// popularityScore and where it ranks among its clinic's branches —
/// not a public leaderboard, and nothing here is editable (the score is
/// entirely server-computed, see reviews.service.js's daily node-cron job).
class PopularClinicsScreen extends ConsumerWidget {
  const PopularClinicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (data) {
          final role = data?['role'] as String?;
          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final effectiveBranchId = isOrgAdmin ? ref.watch(activeBranchIdProvider) : ownBranchId;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Popular Clinics',
                        style: TextStyle(color: context.appText, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isOrgAdmin) ...[
                      const BranchSelector(),
                      const SizedBox(width: 12),
                    ],
                    const TopBarActions(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Internal ranking — how this branch compares to your other locations. Recalculated once a day, not live.',
                  style: TextStyle(color: context.appSubtext, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: effectiveBranchId == null
                      ? const NoBranchSelectedState()
                      : _PopularityView(branchId: effectiveBranchId),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PopularityView extends ConsumerWidget {
  const _PopularityView({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankAsync = ref.watch(popularityRankProvider(branchId));

    return rankAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
      data: (rank) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Rank among your branches',
                    value: rank.totalBranchesRanked > 0
                        ? '#${rank.rank} of ${rank.totalBranchesRanked}'
                        : '—',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(label: 'Popularity Score', value: rank.popularityScore.toStringAsFixed(2)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(label: 'Average Rating', value: rank.averageRating.toStringAsFixed(1)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: MetricCard(label: 'Reviews', value: '${rank.reviewCount}'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CliniqnovvaCard(
              child: Row(
                children: [
                  AppIcon(AppIcons.trophy, size: 22, color: context.appSubtext),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How this is calculated',
                          style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Recent reviews (last 90 days) count fully; older ones count less. Branches with '
                          'very few reviews are scored down proportionally so a single rating can\'t outrank '
                          'a branch with a long, solid track record. Hidden reviews are never counted.\n\n'
                          'Last recalculated: ${_formatDateTime(rank.popularityCalculatedAt)}',
                          style: TextStyle(color: context.appSubtext, fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
