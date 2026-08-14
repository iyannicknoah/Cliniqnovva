import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../patients/providers/patients_provider.dart';
import '../models/chat_model.dart';
import '../providers/chats_provider.dart';

String _formatTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// Part 15 Task 3 — /chat/:chatId. Real-time via Firestore listeners
/// (`chatMessagesStreamProvider`) — no polling, no manual refresh. Any
/// staff at the chat's branch can open and continue it (DONE CONDITION);
/// there is no "assigned to me" concept anywhere in this screen.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, this.chatId});

  final String? chatId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _markReadOnce() {
    if (_markedRead || widget.chatId == null) return;
    _markedRead = true;
    ref.read(chatsNotifierProvider.notifier).markPatientMessagesRead(widget.chatId!);
  }

  Future<void> _send() async {
    final chatId = widget.chatId;
    final text = _messageController.text;
    if (chatId == null || text.trim().isEmpty) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await ref.read(chatsNotifierProvider.notifier).sendMessage(chatId, text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatId = widget.chatId;
    if (chatId == null) {
      return Scaffold(
        backgroundColor: context.appBg,
        body: Center(
          child: Text('No chat selected.', style: TextStyle(color: context.appSubtext)),
        ),
      );
    }

    final chatAsync = ref.watch(chatDetailStreamProvider(chatId));
    final messagesAsync = ref.watch(chatMessagesStreamProvider(chatId));

    messagesAsync.whenData((_) => _markReadOnce());

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          _ThreadHeader(chat: chatAsync.valueOrNull),
          const _DisclaimerBanner(),
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
              data: (messages) => messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet — say hello.',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(24),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final message = messages[messages.length - 1 - i];
                        final isPatient = message.senderRole == 'patient';
                        return Align(
                          alignment: isPatient ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isPatient ? context.appSecondaryBg : context.appCard,
                              border: Border.all(color: context.appBorder),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  message.text,
                                  style: TextStyle(color: context.appText, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${roleLabel(message.senderRole)} · ${_formatTime(message.createdAt)}',
                                  style: TextStyle(color: context.appSubtext, fontSize: 10.5),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(color: context.appText, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Type a message…',
                      filled: true,
                      fillColor: context.appCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        borderSide: BorderSide(color: context.appBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const AppIcon(AppIcons.send, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadHeader extends ConsumerWidget {
  const _ThreadHeader({required this.chat});

  final ChatModel? chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = chat != null
        ? ref.watch(patientDetailProvider(chat!.patientId))
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const AppIcon(AppIcons.back),
            onPressed: () => context.go('/chat'),
          ),
          const SizedBox(width: 4),
          AvatarWidget(firstName: patientAsync?.valueOrNull?.name ?? '?', size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              patientAsync?.valueOrNull?.name ?? 'Loading…',
              style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          const TopBarActions(),
        ],
      ),
    );
  }
}

/// Spec 6.13: "Chat messages are not part of the medical record — they
/// must not be treated as clinical advice or a diagnosis."
class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: context.appSecondaryBg,
      child: Text(
        'This chat is not for medical emergencies or clinical advice. For medical concerns, please book an appointment.',
        style: TextStyle(color: context.appSubtext, fontSize: 12),
      ),
    );
  }
}
