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
import 'widgets/service_card.dart';

/// `/explore-services` — every distinct service offered across every
/// clinic on the app, each shown exactly once ([allServicesProvider] is
/// already deduped server-side). Reached from Home's Services grid's
/// "View all" tile. Deliberately its own screen, not the Browse tab —
/// tapping a service here goes to [ServiceClinicsScreen], not Browse.
class ExploreServicesScreen extends ConsumerWidget {
  const ExploreServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allServicesProvider);

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
          'home_services'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
        data: (services) {
          if (services.isEmpty) {
            return Center(
              child: Text('browse_no_results'.tr(), style: TextStyle(color: context.appSubtext)),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final cardWidth = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final service in services)
                      ServiceCard(
                        service: service,
                        width: cardWidth,
                        onTap: () =>
                            context.go('/service-clinics?service=${Uri.encodeQueryComponent(service.name)}'),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
