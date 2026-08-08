import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// Shared placeholder for every feature screen Part 19 only scaffolds a
/// route for (browse/booking/records/reviews/chat detail flows — later
/// parts build the real content). Shows a back button whenever it's NOT a
/// bottom-nav tab (i.e. pushed on top of the shell), so it's always
/// navigable even with nothing else on the screen yet.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, this.showBackButton = false});

  final String title;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: context.appBg,
              elevation: 0,
              leading: IconButton(
                icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
              title: Text(title, style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600)),
            )
          : null,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!showBackButton)
              Text(title, style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w600)),
            if (!showBackButton) const SizedBox(height: 8),
            Text('coming_soon'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
