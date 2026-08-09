import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../models/slot_model.dart';
import '../providers/booking_provider.dart';
import 'booking_chip.dart';

/// GET /api/v1/appointments/available-slots, rendered as tappable chips —
/// the SAME slot list Booking's slot step (Task 1) and Booking Detail's
/// reschedule flow (Task 2) both read from; no separate slot logic.
class SlotChipPicker extends ConsumerWidget {
  const SlotChipPicker({
    super.key,
    required this.doctorId,
    required this.branchId,
    required this.serviceId,
    required this.date,
    required this.selected,
    required this.onSelected,
  });

  final String doctorId;
  final String branchId;
  final String serviceId;
  final DateTime date;
  final SlotModel? selected;
  final ValueChanged<SlotModel?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final async = ref.watch(
      availableSlotsProvider((doctorId: doctorId, branchId: branchId, serviceId: serviceId, date: dateStr)),
    );

    return async.when(
      loading: () => const LoadingWidget(),
      error: (e, st) => Text(e.friendlyMessage, style: TextStyle(color: context.appSubtext)),
      data: (slots) {
        if (slots.isEmpty) {
          return Text('booking_no_slots'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 13));
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots
              .map(
                (s) => BookingChip(
                  label: s.startTime,
                  isSelected: selected?.startTime == s.startTime,
                  onTap: () => onSelected(s),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
