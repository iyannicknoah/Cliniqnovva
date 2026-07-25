import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../patients/providers/patients_provider.dart';
import '../providers/chats_provider.dart';

/// Part 15 Task 4 — staff starting a thread on a patient's behalf, since
/// there's no Patient App yet. Same right-edge slide-out pattern as every
/// other "+ Add" panel in this app.
Future<void> showNewChatPanel(
  BuildContext context, {
  required String branchId,
  required String clinicId,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'New chat',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: _NewChatPanel(branchId: branchId, clinicId: clinicId),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

class _NewChatPanel extends ConsumerStatefulWidget {
  const _NewChatPanel({required this.branchId, required this.clinicId});

  final String branchId;
  final String clinicId;

  @override
  ConsumerState<_NewChatPanel> createState() => _NewChatPanelState();
}

class _NewChatPanelState extends ConsumerState<_NewChatPanel> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _starting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _start(String patientId) async {
    setState(() => _starting = true);
    try {
      final chatId = await runWithFeedback(
        context,
        () => ref.read(chatsNotifierProvider.notifier).startChat(
          patientId: patientId,
          branchId: widget.branchId,
          clinicId: widget.clinicId,
        ),
        loadingMessage: 'Starting chat…',
        successMessage: 'Chat ready.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/chat/$chatId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCard,
      child: Container(
        width: 420,
        height: double.infinity,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: context.appBorder)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'New Chat',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Search for a patient to start a conversation on their behalf.',
                  style: TextStyle(color: context.appSubtext, fontSize: 13),
                ),
                const SizedBox(height: 16),
                CliniqnovvaTextField(
                  label: 'Search',
                  controller: _searchController,
                  hint: 'Name, phone, or National ID',
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                if (_starting) const LoadingWidget(),
                if (!_starting && _query.isNotEmpty)
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final resultsAsync = ref.watch(
                          patientsSearchProvider((branchId: widget.branchId, query: _query)),
                        );
                        return resultsAsync.when(
                          loading: () => const LoadingWidget(),
                          error: (e, _) => Text('$e', style: TextStyle(color: context.appSubtext)),
                          data: (results) => results.isEmpty
                              ? Text('No matches.', style: TextStyle(color: context.appSubtext))
                              : ListView(
                                  children: results
                                      .map(
                                        (p) => InkWell(
                                          onTap: () => _start(p.id),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Row(
                                              children: [
                                                AvatarWidget(firstName: p.name, size: 28),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        p.name,
                                                        style: TextStyle(
                                                          color: context.appText,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                      Text(
                                                        p.phone,
                                                        style: TextStyle(
                                                          color: context.appSubtext,
                                                          fontSize: 12.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
