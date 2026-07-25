import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../clinics/providers/branches_provider.dart';

/// Branch picker for an Clinic Admin viewing per-branch data
/// (Departments/Services — Part 7 Tasks 1-2 both say "per branch"). Writes
/// through [selectedBranchProvider] (Part 6) so the choice is shared with
/// /branches' "click a branch → filter" behavior. Hidden entirely by the
/// caller for branch-scoped roles, who only ever see their own branch.
class BranchSelector extends ConsumerWidget {
  const BranchSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final selected = ref.watch(selectedBranchProvider);

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

        return SizedBox(
          width: 240,
          child: DropdownButtonFormField<String>(
            initialValue: branches.any((b) => b.id == currentId)
                ? currentId
                : branches.first.id,
            isExpanded: true,
            style: TextStyle(color: context.appText, fontSize: 14),
            dropdownColor: context.appCard,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: context.appCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: BorderSide(color: context.appBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                borderSide: BorderSide(color: context.appBorder),
              ),
            ),
            items: branches
                .map(
                  (b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) {
              final branch = branches.firstWhere((b) => b.id == id);
              ref.read(selectedBranchProvider.notifier).state = branch;
            },
          ),
        );
      },
    );
  }
}
