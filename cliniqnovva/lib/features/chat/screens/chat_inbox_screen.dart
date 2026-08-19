import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../patients/providers/patients_provider.dart';
import '../models/chat_model.dart';
import '../providers/chats_provider.dart';
import '../widgets/new_chat_panel.dart';

String _relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// Part 15 Task 2 — /chat. Live thread list for the staff's own branch
/// (`chatsInboxStreamProvider`, a Firestore listener — updates the moment
/// anyone at the branch sends a message, no manual refresh). Task 1's rule
/// "any staff at matching branchId can read/write" means this isn't
/// restricted to whoever started a given thread.
class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.appSubtext)),
        ),
        data: (data) {
          final branchId = data?['branchId'] as String?;
          final clinicId = data?['clinicId'] as String?;

          if (branchId == null || clinicId == null) {
            return const NoBranchSelectedState();
          }

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Chat',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    CliniqnovvaButton(
                      label: '+ New Chat',
                      onPressed: () => showNewChatPanel(
                        context,
                        branchId: branchId,
                        clinicId: clinicId,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const TopBarActions(),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(child: _ThreadList(branchId: branchId)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsInboxStreamProvider(branchId));

    return chatsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
      data: (chats) => chats.isEmpty
          ? Center(
              child: Text(
                'No conversations yet — start one with "+ New Chat".',
                style: TextStyle(color: context.appSubtext),
              ),
            )
          : ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: context.appBorder),
              itemBuilder: (context, i) => _ThreadRow(chat: chats[i]),
            ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow({required this.chat});

  final ChatModel chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(chat.patientId));
    final unreadAsync = ref.watch(chatUnreadCountProvider(chat.id));
    final unread = unreadAsync.valueOrNull ?? 0;

    return InkWell(
      onTap: () => context.go('/chat/${chat.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            AvatarWidget(
              firstName: patientAsync.valueOrNull?.name ?? '?',
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientAsync.valueOrNull?.name ?? 'Loading…',
                    style: TextStyle(
                      color: context.appText,
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat.lastMessage ?? 'No messages yet.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.appSubtext, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeTime(chat.lastMessageAt ?? chat.createdAt),
                  style: TextStyle(color: context.appSubtext, fontSize: 11.5),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.brightRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
