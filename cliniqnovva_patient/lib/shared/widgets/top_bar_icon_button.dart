import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// A circular bordered icon button with an optional unread-count badge —
/// the Home top bar's notification/chat buttons (matches the reference
/// design's `FlutterFlowIconButton` + `badges.Badge` pairing). Shared so
/// [NotificationBell] and the chat unread button render identically.
class TopBarIconButton extends StatelessWidget {
  const TopBarIconButton({super.key, required this.icon, required this.badgeCount, required this.onTap});

  final IconRef icon;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appBg,
              shape: BoxShape.circle,
              border: Border.all(color: context.appBorder),
            ),
            child: AppIcon(icon, size: 24, color: context.appText),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(color: AppColors.skyBlue, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
