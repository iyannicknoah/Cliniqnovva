import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/cliniqnovva_button.dart';
import '../../shared/widgets/cliniqnovva_card.dart';
import '../../shared/widgets/loading_widget.dart';
import '../../shared/widgets/status_badge.dart';
import '../booking/models/appointment_model.dart';
import '../booking/models/slot_model.dart';
import '../booking/providers/booking_provider.dart';
import '../booking/widgets/date_strip_picker.dart';
import '../booking/widgets/slot_chip_picker.dart';
import '../browse/providers/browse_provider.dart';

const _timelineStatuses = ['pending', 'confirmed', 'checkedIn', 'completed'];

/// Pushed on top of the shell (Part 19 Task 6). Part 21 Tasks 2/3: view one
/// appointment, reschedule (re-validates availability via the same
/// available-slots/reschedule endpoints staff use), and cancel (frees the
/// slot). The My Bookings LIST this is normally reached from is Part 22 —
/// this screen only needs a known appointment id, which the Booking success
/// screen (Part 21 Task 1) already provides.
class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _rescheduling = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appointmentDetailProvider(widget.bookingId));

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: context.appText, size: 20),
          onPressed: () => context.canPop() ? context.pop() : context.go('/my-bookings'),
        ),
        title: Text(
          'booking_detail_title'.tr(),
          style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('$e', style: TextStyle(color: context.appSubtext))),
        data: (appointment) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AppointmentInfoCard(appointment: appointment),
              if (appointment.status != 'cancelled') ...[
                const SizedBox(height: 20),
                _StatusTimeline(status: appointment.status),
              ],
              if (['pending', 'confirmed'].contains(appointment.status)) ...[
                const SizedBox(height: 20),
                if (!_rescheduling)
                  Row(
                    children: [
                      Expanded(
                        child: CliniqnovvaButton.text(
                          label: 'action_reschedule'.tr(),
                          isFullWidth: true,
                          onPressed: () => setState(() => _rescheduling = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CliniqnovvaButton.text(
                          label: 'action_cancel_appointment'.tr(),
                          color: AppColors.errorRed,
                          isFullWidth: true,
                          onPressed: () => _confirmCancel(context, appointment),
                        ),
                      ),
                    ],
                  )
                else
                  _ReschedulePanel(
                    appointment: appointment,
                    onDone: () => setState(() => _rescheduling = false),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, AppointmentModel appointment) async {
    String? doctorName;
    try {
      doctorName = (await ref.read(doctorDetailProvider(appointment.doctorId).future)).name;
    } catch (_) {
      doctorName = null;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('cancel_confirm_title'.tr()),
        content: Text(
          'cancel_confirm_body'.tr(
            namedArgs: {
              'date': DateFormat.yMMMd().format(DateFormat('yyyy-MM-dd').parse(appointment.date)),
              'doctor': doctorName ?? '',
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('action_no_keep_it'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('action_yes_cancel'.tr(), style: const TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(appointmentActionsProvider.notifier).cancel(appointment.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('cancel_success'.tr())));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _AppointmentInfoCard extends ConsumerWidget {
  const _AppointmentInfoCard({required this.appointment});

  final AppointmentModel appointment;

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

  Future<void> _openMap(String address) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': address});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchDetailProvider(appointment.branchId));
    final doctorAsync = ref.watch(doctorDetailProvider(appointment.doctorId));
    final serviceAsync = ref.watch(serviceDetailProvider(appointment.serviceId));
    final address = branchAsync.valueOrNull?.branch.address;
    final service = serviceAsync.valueOrNull;

    return CliniqnovvaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(text: 'status_${appointment.status}'.tr(), type: _badgeTypeFor(appointment.status)),
          const SizedBox(height: 14),
          _Row(
            label: 'booking_detail_when'.tr(),
            value: '${DateFormat.yMMMd().format(DateFormat('yyyy-MM-dd').parse(appointment.date))}, ${appointment.startTime}',
          ),
          _Row(label: 'booking_detail_clinic'.tr(), value: branchAsync.valueOrNull?.branch.name ?? '…'),
          if (address != null && address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: Text('booking_detail_address'.tr(), style: TextStyle(color: context.appSubtext, fontSize: 12)),
                  ),
                  Expanded(child: Text(address, style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w500))),
                  InkWell(
                    onTap: () => _openMap(address),
                    child: AppIcon(AppIcons.mapPin, size: 18, color: context.appPrimary),
                  ),
                ],
              ),
            ),
          _Row(label: 'booking_detail_doctor'.tr(), value: doctorAsync.valueOrNull?.name ?? '…'),
          _Row(
            label: 'booking_detail_service'.tr(),
            value: service != null
                ? 'booking_service_meta'.tr(
                    namedArgs: {
                      'minutes': '${service.defaultDurationMins}',
                      'price': NumberFormat.decimalPattern().format(service.defaultPriceRwf),
                    },
                  )
                : '…',
          ),
          if (service != null) Text(service.name, style: TextStyle(color: context.appSubtext, fontSize: 12)),
          if (appointment.queueNumber != null)
            _Row(label: 'booking_detail_queue_number'.tr(), value: '#${appointment.queueNumber}'),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _timelineStatuses.indexOf(status);

    return CliniqnovvaCard(
      title: 'booking_status_timeline'.tr(),
      child: Row(
        children: [
          for (var i = 0; i < _timelineStatuses.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(height: 2, color: i <= currentIndex ? context.appPrimary : context.appBorder),
              ),
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentIndex ? context.appPrimary : context.appBorder,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'status_${_timelineStatuses[i]}'.tr(),
                  style: TextStyle(
                    color: i <= currentIndex ? context.appText : context.appSubtext,
                    fontSize: 10,
                    fontWeight: i == currentIndex ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: context.appSubtext, fontSize: 12))),
          Expanded(child: Text(value, style: TextStyle(color: context.appText, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _ReschedulePanel extends ConsumerStatefulWidget {
  const _ReschedulePanel({required this.appointment, required this.onDone});

  final AppointmentModel appointment;
  final VoidCallback onDone;

  @override
  ConsumerState<_ReschedulePanel> createState() => _ReschedulePanelState();
}

class _ReschedulePanelState extends ConsumerState<_ReschedulePanel> {
  late DateTime _date = DateFormat('yyyy-MM-dd').parse(widget.appointment.date);
  SlotModel? _slot;
  String? _error;

  Future<void> _confirm() async {
    if (_slot == null) return;
    setState(() => _error = null);
    try {
      await ref.read(appointmentActionsProvider.notifier).reschedule(
            widget.appointment.id,
            date: DateFormat('yyyy-MM-dd').format(_date),
            startTime: _slot!.startTime,
            endTime: _slot!.endTime,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('reschedule_success'.tr())));
        widget.onDone();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(appointmentActionsProvider).isLoading;

    return CliniqnovvaCard(
      title: 'booking_step_date'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateStripPicker(
            selected: _date,
            onSelected: (d) => setState(() {
              _date = d;
              _slot = null;
            }),
          ),
          const SizedBox(height: 16),
          SlotChipPicker(
            doctorId: widget.appointment.doctorId,
            branchId: widget.appointment.branchId,
            serviceId: widget.appointment.serviceId,
            date: _date,
            selected: _slot,
            onSelected: (s) => setState(() => _slot = s),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CliniqnovvaButton.text(
                  label: 'action_cancel'.tr(),
                  isFullWidth: true,
                  onPressed: widget.onDone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CliniqnovvaButton(
                  label: 'action_confirm_reschedule'.tr(),
                  isLoading: isLoading,
                  onPressed: _slot == null ? null : _confirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
