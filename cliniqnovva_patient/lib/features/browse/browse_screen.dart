import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/loading_widget.dart';
import 'providers/browse_provider.dart';
import 'widgets/branch_card.dart';

const _sortOptions = ['popular', 'rating', 'name'];

/// Bottom-nav tab (Task 6 of Part 19; real content added Part 20 Task 2):
/// search bar (clinic/branch/doctor/specialty), department + sort filter
/// chips, and the resulting branch list.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  BrowseFilters _filters = const BrowseFilters();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _filters = _filters.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(branchListProvider(_filters));

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'nav_browse'.tr(),
                    style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  _SearchField(controller: _searchController, onChanged: _onSearchChanged),
                  const SizedBox(height: 12),
                  _SortChips(
                    selected: _filters.sortBy,
                    onSelected: (value) => setState(() => _filters = _filters.copyWith(sortBy: value)),
                  ),
                  const SizedBox(height: 8),
                  async.whenOrNull(
                        data: (data) => _DepartmentChips(
                          departments: data.availableDepartments,
                          selected: _filters.department,
                          onSelected: (value) => setState(
                            () => _filters = _filters.copyWith(department: value, clearDepartment: value == null),
                          ),
                        ),
                      ) ??
                      const SizedBox.shrink(),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const LoadingWidget(),
                error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
                data: (data) {
                  if (data.branches.isEmpty) {
                    return Center(
                      child: Text('browse_no_results'.tr(), style: TextStyle(color: context.appSubtext)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: data.branches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final branch = data.branches[index];
                      return BranchCard(
                        branch: branch,
                        isNew: branch.reviewCount < data.reviewCountThreshold,
                        onTap: () => context.go('/browse/${branch.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSecondaryBg,
        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: context.appText, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'browse_search_hint'.tr(),
          hintStyle: TextStyle(color: context.appSubtext, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: AppIcon(AppIcons.search, size: 18, color: context.appSubtext),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _SortChips extends StatelessWidget {
  const _SortChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sortOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = _sortOptions[index];
          return _FilterChip(
            label: 'browse_sort_$option'.tr(),
            icon: AppIcons.filterList,
            isSelected: selected == option,
            onTap: () => onSelected(option),
          );
        },
      ),
    );
  }
}

class _DepartmentChips extends StatelessWidget {
  const _DepartmentChips({required this.departments, required this.selected, required this.onSelected});

  final List<String> departments;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: departments.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterChip(
              label: 'browse_all_departments'.tr(),
              isSelected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final department = departments[index - 1];
          return _FilterChip(
            label: department,
            isSelected: selected == department,
            onTap: () => onSelected(department),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.icon});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconRef? icon;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? context.appPrimary : context.appSecondaryBg;
    final fg = isSelected ? (context.isDark ? Colors.black : Colors.white) : context.appText;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

