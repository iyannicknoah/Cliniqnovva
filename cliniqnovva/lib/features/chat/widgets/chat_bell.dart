import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../providers/chats_provider.dart';

/// Topbar chat icon (2026-07-25) — moved out of the sidebar nav list (which
/// used to carry a `nav_chat` item + badge) and into the topbar, next to
/// [NotificationBell], matching the layout `SuperAdminScaffold` already
/// used. Badge count reuses [chatTotalUnreadProvider], same as the old
/// sidebar badge did. [branchId] is null when a Clinic Admin hasn't picked
/// an active branch yet — the icon still navigates to `/chat`, it just has
/// no badge until a branch is selected.
class ChatBell extends ConsumerWidget {
  const ChatBell({super.key, required this.branchId});

  final String? branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = branchId == null
        ? null
        : ref.watch(chatTotalUnreadProvider(branchId!)).valueOrNull;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/chat'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppIcon(AppIcons.chat, size: 22, color: context.appText),
            if (unreadCount != null && unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: const BoxDecoration(
                    color: AppColors.brightRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
