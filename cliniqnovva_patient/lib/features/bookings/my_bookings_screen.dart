import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/loading_widget.dart';
import '../booking/models/appointment_model.dart';
import 'providers/my_bookings_provider.dart';
import 'widgets/appointment_card.dart';

/// Bottom-nav tab (Task 6 of Part 19; real content Part 22 Task 1):
/// Upcoming/Past tabs over every appointment this patient has ever booked,
/// across every clinic (see providers/my_bookings_provider.dart).
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  bool _showUpcoming = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myBookingsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'nav_bookings'.tr(),
                    style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  _SegmentedTabs(
                    showUpcoming: _showUpcoming,
                    onChanged: (value) => setState(() => _showUpcoming = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const LoadingWidget(),
                error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
                data: (appointments) {
                  final today = todayInKigali();
                  final filtered = appointments.where((a) => isUpcoming(a, today) == _showUpcoming).toList()
                    ..sort((a, b) {
                      final aKey = '${a.date} ${a.startTime}';
                      final bKey = '${b.date} ${b.startTime}';
                      return _showUpcoming ? aKey.compareTo(bKey) : bKey.compareTo(aKey);
                    });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _showUpcoming ? 'bookings_no_upcoming'.tr() : 'bookings_no_past'.tr(),
                        style: TextStyle(color: context.appSubtext),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(myBookingsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _BookingCard(appointment: filtered[index]),
                    ),
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

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.showUpcoming, required this.onChanged});

  final bool showUpcoming;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: context.appSecondaryBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _Segment(label: 'bookings_tab_upcoming'.tr(), isSelected: showUpcoming, onTap: () => onChanged(true))),
          Expanded(child: _Segment(label: 'bookings_tab_past'.tr(), isSelected: !showUpcoming, onTap: () => onChanged(false))),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? context.appPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (context.isDark ? Colors.black : Colors.white) : context.appSubtext,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.appointment});

  final AppointmentModel appointment;

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (appointment.status == 'completed') {
      final reviewed = await ref.read(
        appointmentReviewExistsProvider((clinicId: appointment.clinicId, appointmentId: appointment.id)).future,
      );
      if (!reviewed && context.mounted) {
        final wantsToReview = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('review_prompt_title'.tr()),
            content: Text('review_prompt_body'.tr()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('action_not_now'.tr())),
              TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text('action_leave_review'.tr())),
            ],
          ),
        );
        if (wantsToReview == true && context.mounted) {
          context.go('/leave-review/${appointment.id}');
          return;
        }
      }
    }
    if (context.mounted) context.go('/my-bookings/${appointment.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ['pending', 'confirmed'].contains(appointment.status);
    return AppointmentCard(
      appointment: appointment,
      onTap: () => _onTap(context, ref),
      onReschedule: canManage ? () => context.go('/my-bookings/${appointment.id}') : null,
      onCancel: canManage ? () => context.go('/my-bookings/${appointment.id}') : null,
    );
  }
}
