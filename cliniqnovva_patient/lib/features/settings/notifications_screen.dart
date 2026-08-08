import '../../shared/widgets/coming_soon_screen.dart';

/// Pushed on top of the shell — reached from Settings, not a bottom-nav tab.
class NotificationsScreen extends ComingSoonScreen {
  const NotificationsScreen({super.key}) : super(title: 'Notifications', showBackButton: true);
}
