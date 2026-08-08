import '../../shared/widgets/coming_soon_screen.dart';

/// Pushed on top of the shell (Task 6: detail flows have no bottom nav).
class ChatThreadScreen extends ComingSoonScreen {
  const ChatThreadScreen({super.key, required this.chatId})
    : super(title: 'Chat', showBackButton: true);

  final String chatId;
}
