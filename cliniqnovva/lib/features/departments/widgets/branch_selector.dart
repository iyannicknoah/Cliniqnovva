import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_select.dart';
import '../../clinics/providers/branches_provider.dart';

/// Sentinel dropdown value for "All branches" — never a real Firestore
/// branch id, so it can share the same `DropdownButtonFormField<String>`
/// as the real branch options.
const _kAllBranchesValue = '__all_branches__';

/// Branch picker for an Clinic Admin viewing per-branch data
/// (Departments/Services — Part 7 Tasks 1-2 both say "per branch"). Writes
/// through [selectedBranchProvider] (Part 6) so the choice is shared with
/// /branches' "click a branch → filter" behavior, plus [showAllBranchesProvider]
/// for the "All branches" option (2026-07-26) that lets a Clinic Admin view
/// every branch's data combined instead of picking just one. Hidden entirely
/// by the caller for branch-scoped roles, who only ever see their own branch.
class BranchSelector extends ConsumerWidget {
  const BranchSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final selected = ref.watch(selectedBranchProvider);
    final showAll = ref.watch(showAllBranchesProvider);

    return branchesAsync.when(
      loading: () => const SizedBox(
        width: 220,
        height: 44,
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
      data: (result) {
        final branches = result.branches;
        if (branches.isEmpty) return const SizedBox.shrink();
        final currentId = selected?.id ?? branches.first.id;
        final currentValue = showAll
            ? _kAllBranchesValue
            : (branches.any((b) => b.id == currentId)
                  ? currentId
                  : branches.first.id);

        return SizedBox(
          width: 240,
          child: AppSelect(
            value: currentValue,
            options: [
              const AppSelectOption(
                value: _kAllBranchesValue,
                label: 'All branches',
              ),
              ...branches.map(
                (b) => AppSelectOption(value: b.id, label: b.name),
              ),
            ],
            onChanged: (id) {
              if (id == _kAllBranchesValue) {
                ref.read(showAllBranchesProvider.notifier).state = true;
                return;
              }
              final branch = branches.firstWhere((b) => b.id == id);
              ref.read(showAllBranchesProvider.notifier).state = false;
              ref.read(selectedBranchProvider.notifier).state = branch;
            },
          ),
        );
      },
    );
  }
}
