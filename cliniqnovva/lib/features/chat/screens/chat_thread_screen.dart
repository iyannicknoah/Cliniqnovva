import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Placeholder screen (Part 1 — Project Foundation). Real content lands in
/// a later part of the build plan.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({super.key, this.chatId});

  final String? chatId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chat',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (chatId != null) ...[
              const SizedBox(height: 8),
              Text(
                'chatId: $chatId',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
