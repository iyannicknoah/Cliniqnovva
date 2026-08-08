import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../booking/models/appointment_model.dart';
import '../../browse/providers/browse_provider.dart';

/// One appointment row — My Bookings' Upcoming/Past tabs (Part 22 Task 1)
/// both use this. Clinic/doctor/service names are resolved per-card via the
/// same providers Booking Detail already uses (Part 21) — appointments
/// don't denormalize those names, and a patient's booking list is small
/// enough that per-card fetches are simpler than a bespoke batch endpoint.
class AppointmentCard extends ConsumerWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.onReschedule,
    this.onCancel,
  });

  final AppointmentModel appointment;
  final VoidCallback onTap;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;

  BadgeType _badgeTypeFor(String status) {
    switch (status) {
      case 'completed':
      case 'confirmed':
        return BadgeType.success;
      case 'cancelled':
        return BadgeType.error;
      default:
        return BadgeType.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchDetailProvider(appointment.branchId));
    final doctorAsync = ref.watch(doctorDetailProvider(appointment.doctorId));

    final showActions = ['pending', 'confirmed'].contains(appointment.status) && (onReschedule != null || onCancel != null);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: CliniqnovvaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat.yMMMd().format(DateFormat('yyyy-MM-dd').parse(appointment.date))}, ${appointment.startTime}',
                    style: TextStyle(color: context.appText, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                StatusBadge(text: 'status_${appointment.status}'.tr(), type: _badgeTypeFor(appointment.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(branchAsync.valueOrNull?.branch.name ?? '…', style: TextStyle(color: context.appText, fontSize: 13)),
            if (doctorAsync.valueOrNull?.name != null)
              Text('Dr. ${doctorAsync.valueOrNull!.name}', style: TextStyle(color: context.appSubtext, fontSize: 12)),
            if (appointment.queueNumber != null) ...[
              const SizedBox(height: 6),
              Text(
                'booking_queue_badge'.tr(namedArgs: {'number': '${appointment.queueNumber}'}),
                style: const TextStyle(color: AppColors.skyBlue, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onReschedule != null)
                    Expanded(
                      child: CliniqnovvaButton.text(
                        label: 'action_reschedule'.tr(),
                        isFullWidth: true,
                        onPressed: onReschedule,
                      ),
                    ),
                  if (onReschedule != null && onCancel != null) const SizedBox(width: 8),
                  if (onCancel != null)
                    Expanded(
                      child: CliniqnovvaButton.text(
                        label: 'action_cancel_appointment'.tr(),
                        color: AppColors.errorRed,
                        isFullWidth: true,
                        onPressed: onCancel,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
