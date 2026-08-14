import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/top_bar_icon_button.dart';
import '../providers/chats_provider.dart';

/// Home top bar's chat button — the mirror image of [NotificationBell],
/// badge sourced from [totalChatUnreadCountProvider].
class ChatBell extends ConsumerWidget {
  const ChatBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(totalChatUnreadCountProvider).valueOrNull ?? 0;

    return TopBarIconButton(
      icon: AppIcons.chat,
      badgeCount: unreadCount,
      onTap: () => context.go('/chat'),
    );
  }
}
