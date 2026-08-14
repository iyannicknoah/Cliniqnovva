import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/loading_widget.dart';
import 'providers/browse_provider.dart';
import 'widgets/branch_card.dart';

/// `/service-clinics?service=X` — every clinic offering ONE given service.
/// Reached by tapping a service card on Home or on
/// [ExploreServicesScreen] — deliberately its OWN screen (explicit ask:
/// "must not be Explore page"), not the Browse tab with a department
/// filter pre-applied: no search bar, no sort chips, no department-chip
/// row — just the service name as the title and the matching clinics.
class ServiceClinicsScreen extends ConsumerWidget {
  const ServiceClinicsScreen({super.key, required this.service});

  final String service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchListProvider(BrowseFilters(department: service)));

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          service,
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
        data: (data) {
          if (data.branches.isEmpty) {
            return Center(
              child: Text('browse_no_results'.tr(), style: TextStyle(color: context.appSubtext)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: data.branches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 20),
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
    );
  }
}
