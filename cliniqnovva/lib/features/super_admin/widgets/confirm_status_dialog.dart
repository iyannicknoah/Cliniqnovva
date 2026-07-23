import 'package:flutter/material.dart';

/// Shared confirmation dialog for activating/suspending an organization —
/// used by both the organizations list's quick action and the detail
/// screen's toggle, so the wording/behavior can't drift between the two.
Future<bool> confirmOrganizationStatusChange(
  BuildContext context, {
  required String organizationName,
  required bool activate,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(activate ? 'Activate clinic?' : 'Suspend clinic?'),
      content: Text(
        activate
            ? '$organizationName will regain access immediately.'
            : '$organizationName and every user under it will immediately lose access.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(activate ? 'Activate' : 'Suspend')),
      ],
    ),
  );
  return confirmed ?? false;
}
