import 'package:flutter/material.dart';

import '../theme/theme_ext.dart';

/// The single modal/dialog wrapper used everywhere — gives every dialog in
/// the app the same card styling, corner radius, and max width. Never call
/// `showDialog` directly with a raw `Dialog`/`AlertDialog` in a screen — use
/// `AppDialogShell.show(...)`.
class AppDialogShell {
  const AppDialogShell._();

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    AlignmentGeometry alignment = Alignment.center,
    double maxWidth = 460,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: alignment,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
