import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/public_holiday_model.dart';

/// Every configured public holiday (spec section 1) — the Doctor Schedule
/// screen shows these as auto-blocked (Part 8 Task 2).
final publicHolidaysProvider = FutureProvider.autoDispose<
  List<PublicHolidayModel>
>((ref) async {
  final response = await ApiService.instance.get<Map<String, dynamic>>(
    '/api/v1/publicHolidays',
  );
  final data = response.data!['holidays'] as List<dynamic>;
  return data
      .map((e) => PublicHolidayModel.fromJson(e as Map<String, dynamic>))
      .toList();
});
