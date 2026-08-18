import 'package:flutter/widgets.dart';
import 'package:heroicons/heroicons.dart';

import 'migambi_icons.dart';

/// A single icon reference — either a Heroicon or a glyph from the Migambi
/// font pack (see migambi_icons.dart). Render with the [AppIcon] widget —
/// never with the raw Material [Icon] widget directly (except [AppIcon]
/// itself, which is the one sanctioned place). 2026-08-13: Migambi is the
/// icon system everywhere, INCLUDING the bottom nav as of later the same
/// day (explicit exact-icon-name requests superseded the original "navbar
/// stays Heroicons" rule) — [offline] is the one remaining Heroicons use,
/// kept only because no matching glyph exists in the Migambi pack.
class IconRef {
  const IconRef.hero(this.hero) : font = null;
  const IconRef.font(this.font) : hero = null;

  final HeroIcons? hero;
  final IconData? font;
}

/// Icon catalog for the Patient App — grows as new screens need icons.
class AppIcons {
  AppIcons._();

  static const view = IconRef.font(MigambiIcons.eye);
  static const eyeSlash = IconRef.font(MigambiIcons.eyeSlash);
  /// 2026-08-19, explicit user instruction — switched from `arrowLeft` to
  /// the exact "arrowLeft44" glyph, app-wide.
  static const back = IconRef.font(MigambiIcons.arrowLeft44);
  static const close = IconRef.font(MigambiIcons.closeCircle);
  static const chevronRight = IconRef.font(MigambiIcons.arrowRight);
  static const logout = IconRef.font(MigambiIcons.logout);
  static const notification = IconRef.font(MigambiIcons.notificationBing);
  static const search = IconRef.font(MigambiIcons.searchNormal);
  static const star = IconRef.font(MigambiIcons.star);
  static const send = IconRef.font(MigambiIcons.send);
  static const globe = IconRef.font(MigambiIcons.global);
  static const check = IconRef.font(MigambiIcons.tickCircle);
  static const document = IconRef.font(MigambiIcons.document);
  static const receipt = IconRef.font(MigambiIcons.receipt);
  static const mapPin = IconRef.font(MigambiIcons.location);
  static const clock = IconRef.font(MigambiIcons.clock);
  static const filterList = IconRef.font(MigambiIcons.filter);
  static const calendar = IconRef.font(MigambiIcons.calendar);
  static const flag = IconRef.font(MigambiIcons.flag);
  static const clinic = IconRef.font(MigambiIcons.hospital);
  static const phone = IconRef.font(MigambiIcons.call);
  static const chat = IconRef.font(MigambiIcons.messages233);
  static const arrowRight40 = IconRef.font(MigambiIcons.arrowRight40);

  /// No wifi-slash/offline glyph exists in the Migambi pack — stays
  /// Heroicons rather than picking a wrong-shaped substitute.
  static const offline = IconRef.hero(HeroIcons.signalSlash);

  // Bottom nav (Task 6; switched to Migambi 2026-08-13 — explicit exact
  // names: "home 49", "book09", "messages34", "profile Circle", and a
  // compass ("discover") for Explore).
  static const navHome = IconRef.font(MigambiIcons.home49);
  static const navBrowse = IconRef.font(MigambiIcons.discover);
  static const navBookings = IconRef.font(MigambiIcons.book09);
  static const navChat = IconRef.font(MigambiIcons.messages34);
  static const navSettings = IconRef.font(MigambiIcons.profileCircle);
}
