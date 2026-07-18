import 'package:flutter/material.dart';

/// Every icon in the app is referenced as an [IconRef], never a raw
/// `Icons.xxx` — if we ever swap the icon set (e.g. for a custom font),
/// only this file and [AppIcon]'s implementation need to change.
typedef IconRef = IconData;

abstract final class AppIcons {
  // Navigation / actions
  static const IconRef addRounded = Icons.add_rounded;
  static const IconRef editOutlined = Icons.edit_outlined;
  static const IconRef deleteOutlineRounded = Icons.delete_outline_rounded;
  static const IconRef closeRounded = Icons.close_rounded;
  static const IconRef arrowForwardIosRounded = Icons.arrow_forward_ios_rounded;
  static const IconRef searchRounded = Icons.search_rounded;
  static const IconRef moreVertRounded = Icons.more_vert_rounded;
  static const IconRef checkRounded = Icons.check_rounded;
  static const IconRef logoutRounded = Icons.logout_rounded;
  static const IconRef settingsOutlined = Icons.settings_outlined;
  static const IconRef languageRounded = Icons.language_rounded;
  static const IconRef warningAmberRounded = Icons.warning_amber_rounded;
  static const IconRef categoryOutlined = Icons.category_outlined;
  static const IconRef businessRounded = Icons.business_rounded;
  static const IconRef notificationsRounded = Icons.notifications_rounded;

  // Clinic domain
  static const IconRef calendarMonthRounded = Icons.calendar_month_rounded;
  static const IconRef eventAvailableRounded = Icons.event_available_rounded;
  static const IconRef personAddRounded = Icons.person_add_alt_1_rounded;
  static const IconRef personRounded = Icons.person_rounded;
  static const IconRef groupRounded = Icons.groups_rounded;
  static const IconRef medicalServicesRounded = Icons.medical_services_rounded;
  static const IconRef vaccinesRounded = Icons.vaccines_rounded;
  static const IconRef receiptLongRounded = Icons.receipt_long_rounded;
  static const IconRef paymentsRounded = Icons.payments_rounded;
  static const IconRef chatBubbleRounded = Icons.chat_bubble_rounded;
  static const IconRef starRounded = Icons.star_rounded;
  static const IconRef barChartRounded = Icons.bar_chart_rounded;
  static const IconRef trendingUpRounded = Icons.trending_up_rounded;
}
