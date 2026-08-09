import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/loading_widget.dart';
import '../booking/providers/booking_provider.dart';
import '../browse/providers/browse_provider.dart';
import 'providers/chats_provider.dart';

/// Pushed on top of the shell (Task 6: detail flows have no bottom nav).
/// Part 25 Task 2: real-time thread view via Firestore listeners (the one
/// deliberate exception to "no direct client writes," already documented
/// in `firebase/firestore.rules`), a fixed disclaimer banner, and an
/// appointment-context banner when the thread is linked to one.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  bool _markedRead = false;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _markReadOnce() {
    if (_markedRead) return;
    _markedRead = true;
    ref.read(chatsNotifierProvider.notifier).markStaffMessagesRead(widget.chatId);
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref.read(chatsNotifierProvider.notifier).sendMessage(widget.chatId, text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatDetailStreamProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesStreamProvider(widget.chatId));
    final chat = chatAsync.valueOrNull;
    final branchAsync = chat != null ? ref.watch(branchDetailProvider(chat.branchId)) : null;

    if (messagesAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markReadOnce());
    }

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/chat'),
        ),
        title: Text(
          branchAsync?.valueOrNull?.branch.name ?? 'nav_chat'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: context.appSecondaryBg,
            child: Text(
              'chat_disclaimer'.tr(),
              style: TextStyle(color: context.appSubtext, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
          if (chat?.appointmentId != null) _AppointmentContextBanner(appointmentId: chat!.appointmentId!),
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, st) => Center(child: Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext))),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(child: Text('chat_thread_empty'.tr(), style: TextStyle(color: context.appSubtext)));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    return _MessageBubble(isMine: message.senderRole == 'patient', text: message.text, createdAt: message.createdAt);
                  },
                );
              },
            ),
          ),
          _Composer(controller: _controller, isSending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _AppointmentContextBanner extends ConsumerWidget {
  const _AppointmentContextBanner({required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appointmentDetailProvider(appointmentId));
    final appointment = async.valueOrNull;
    if (appointment == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => context.go('/my-bookings/${appointment.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.pillTealBg,
        child: Row(
          children: [
            AppIcon(AppIcons.calendar, size: 14, color: AppColors.pillTealText),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'chat_appointment_context'.tr(
                  namedArgs: {'date': DateFormat.yMMMd().format(DateFormat('yyyy-MM-dd').parse(appointment.date))},
                ),
                style: const TextStyle(color: AppColors.pillTealText, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.isMine, required this.text, this.createdAt});

  final bool isMine;
  final String text;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? context.appPrimary : context.appSecondaryBg;
    final fg = isMine ? (context.isDark ? Colors.black : Colors.white) : context.appText;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: TextStyle(color: fg, fontSize: 14)),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(DateFormat.Hm().format(createdAt!), style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.isSending, required this.onSend});

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: context.appSecondaryBg, borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(color: context.appText, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'chat_message_hint'.tr(),
                    hintStyle: TextStyle(color: context.appSubtext, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: isSending ? null : onSend,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: context.appPrimary, shape: BoxShape.circle),
                child: isSending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.isDark ? Colors.black : Colors.white),
                      )
                    : AppIcon(AppIcons.send, size: 18, color: context.isDark ? Colors.black : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
