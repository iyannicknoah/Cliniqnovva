import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/models/branch_model.dart';
import '../../clinics/providers/branches_provider.dart';
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../departments/widgets/branch_selector.dart';
import '../providers/reviews_provider.dart';

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
            _OtherBranchesSection(currentBranchId: branchId),
          ],
        ),
      ),
    );
  }
}

/// Watches [branchesProvider] and renders every branch other than the
/// currently selected one as a table — same visual shape as Reports'
/// `_BreakdownDataTable` (header row + ruled rows, equal-width columns,
/// 100px right padding on the last column's content). Each row fetches its
/// own [popularityRankProvider] independently, same endpoint the current
/// branch's metric cards above already use, just with a different
/// `branchId`.
class _OtherBranchesSection extends ConsumerWidget {
  const _OtherBranchesSection({required this.currentBranchId});

  final String currentBranchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return branchesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (result) {
        final others = result.branches.where((b) => b.id != currentBranchId).toList();
        if (others.isEmpty) return const SizedBox.shrink();

        final headerStyle = TextStyle(
          color: context.appSubtext,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        );

        return CliniqnovvaCard(
          title: 'Other branches',
          showBorder: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _otherBranchColumns(
                  branch: Text('Branch', style: headerStyle),
                  rank: Text('Rank', textAlign: TextAlign.right, style: headerStyle),
                  score: Text('Popularity Score', textAlign: TextAlign.right, style: headerStyle),
                  rating: Text('Average Rating', textAlign: TextAlign.right, style: headerStyle),
                  reviews: Text('Reviews', textAlign: TextAlign.right, style: headerStyle),
                ),
              ),
              Divider(height: 1, thickness: 1, color: context.appBorder),
              for (final b in others) _OtherBranchRow(branch: b),
            ],
          ),
        );
      },
    );
  }
}

Widget _otherBranchColumns({
  required Widget branch,
  required Widget rank,
  required Widget score,
  required Widget rating,
  required Widget reviews,
}) => Row(
  children: [
    Expanded(child: branch),
    Expanded(child: rank),
    Expanded(child: score),
    Expanded(child: rating),
    Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 100),
        child: reviews,
      ),
    ),
  ],
);

class _OtherBranchRow extends ConsumerWidget {
  const _OtherBranchRow({required this.branch});

  final BranchModel branch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankAsync = ref.watch(popularityRankProvider(branch.id));
    final branchText = Text(
      branch.name,
      style: TextStyle(color: context.appText),
      overflow: TextOverflow.ellipsis,
    );
    final cellStyle = TextStyle(color: context.appText, fontWeight: FontWeight.w500);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: rankAsync.when(
        loading: () => _otherBranchColumns(
          branch: branchText,
          rank: const SizedBox.shrink(),
          score: const SizedBox.shrink(),
          rating: const SizedBox.shrink(),
          reviews: const SizedBox.shrink(),
        ),
        error: (e, _) => _otherBranchColumns(
          branch: branchText,
          rank: Text('—', textAlign: TextAlign.right, style: TextStyle(color: context.appSubtext)),
          score: const SizedBox.shrink(),
          rating: const SizedBox.shrink(),
          reviews: const SizedBox.shrink(),
        ),
        data: (r) => _otherBranchColumns(
          branch: branchText,
          rank: Text(
            r.totalBranchesRanked > 0 ? '#${r.rank} of ${r.totalBranchesRanked}' : '—',
            textAlign: TextAlign.right,
            style: cellStyle,
          ),
          score: Text(r.popularityScore.toStringAsFixed(2), textAlign: TextAlign.right, style: cellStyle),
          rating: Text(r.averageRating.toStringAsFixed(1), textAlign: TextAlign.right, style: cellStyle),
          reviews: Text('${r.reviewCount}', textAlign: TextAlign.right, style: cellStyle),
        ),
      ),
    );
  }
}
