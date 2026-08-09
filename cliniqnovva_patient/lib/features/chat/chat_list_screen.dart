import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/avatar_widget.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/loading_widget.dart';
import '../browse/providers/browse_provider.dart';
import 'models/chat_model.dart';
import 'providers/chats_provider.dart';

/// Bottom-nav tab (Task 6 of Part 19; real content Part 25 Task 1): every
/// chat thread this patient has, across every clinic, sorted by
/// lastMessageAt (real-time — [myChatsStreamProvider] is a live Firestore
/// listener, not a one-shot fetch). "Message a Clinic" opens Browse to
/// pick ANY branch — the actual thread-creation call lives on Clinic
/// Detail's "Message this Clinic" button (Part 20's screen), since that's
/// where a specific branch is actually chosen.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myChatsStreamProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'nav_chat'.tr(),
                      style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  CliniqnovvaButton(
                    label: 'chat_message_a_clinic'.tr(),
                    isFullWidth: false,
                    onPressed: () => context.go('/browse'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const LoadingWidget(),
                error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
                data: (chats) {
                  if (chats.isEmpty) {
                    return EmptyState(icon: AppIcons.navChat, message: 'chat_list_empty'.tr());
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: chats.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _ChatRow(chat: chats[index]),
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

class _ChatRow extends ConsumerWidget {
  const _ChatRow({required this.chat});

  final ChatModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchDetailProvider(chat.branchId));
    final unread = ref.watch(chatUnreadCountProvider(chat.id)).valueOrNull ?? 0;
    final branchName = branchAsync.valueOrNull?.branch.name ?? '…';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/chat/${chat.id}'),
      child: CliniqnovvaCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AvatarWidget(firstName: branchName, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branchName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 14,
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (chat.lastMessage != null)
                    Text(
                      chat.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread > 0 ? context.appText : context.appSubtext,
                        fontSize: 13,
                        fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (chat.lastMessageAt != null)
                  Text(DateFormat.MMMd().format(chat.lastMessageAt!), style: TextStyle(color: context.appSubtext, fontSize: 11)),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: context.appPrimary, shape: BoxShape.circle),
                  ),
                ] else
                  AppIcon(AppIcons.chevronRight, size: 14, color: context.appSubtext),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
