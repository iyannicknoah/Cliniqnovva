import 'package:heroicons/heroicons.dart';

/// A single icon reference — always a Heroicon. Render with the [AppIcon]
/// widget — never with the raw Material [Icon] widget (design rule
/// 2026-07-23: Heroicons everywhere, copied from the HRNova reference).
class IconRef {
  const IconRef.hero(this.hero);

  final HeroIcons hero;
}

/// Icon catalog — grows as new icons are needed. Add new entries here
/// rather than reaching for a raw `Icons.*`/`HeroIcons.*` value in a screen.
class AppIcons {
  AppIcons._();

  static const clinics = IconRef.hero(HeroIcons.buildingOffice2);
  static const billing = IconRef.hero(HeroIcons.banknotes);
  static const oversight = IconRef.hero(HeroIcons.shieldCheck);
  static const close = IconRef.hero(HeroIcons.xMark);
  static const view = IconRef.hero(HeroIcons.eye);
  static const eyeSlash = IconRef.hero(HeroIcons.eyeSlash);
  static const pause = IconRef.hero(HeroIcons.pauseCircle);
  static const play = IconRef.hero(HeroIcons.playCircle);
  static const warning = IconRef.hero(HeroIcons.exclamationTriangle);
  static const logout = IconRef.hero(HeroIcons.arrowRightStartOnRectangle);
  static const moreHoriz = IconRef.hero(HeroIcons.ellipsisHorizontal);
  static const chevronRight = IconRef.hero(HeroIcons.chevronRight);
  static const back = IconRef.hero(HeroIcons.arrowLeft);
  static const chat = IconRef.hero(HeroIcons.chatBubbleOvalLeftEllipsis);
  static const send = IconRef.hero(HeroIcons.paperAirplane);
  static const star = IconRef.hero(HeroIcons.star);
  static const trophy = IconRef.hero(HeroIcons.trophy);
  static const notification = IconRef.hero(HeroIcons.bell);
  static const search = IconRef.hero(HeroIcons.magnifyingGlass);
  static const overview = IconRef.hero(HeroIcons.squares2x2);
  static const trash = IconRef.hero(HeroIcons.trash);
  static const plus = IconRef.hero(HeroIcons.plus);
  static const department = IconRef.hero(HeroIcons.buildingOffice);
  static const generate = IconRef.hero(HeroIcons.arrowPath);
  static const branchLocation = IconRef.hero(HeroIcons.mapPin);
  static const service = IconRef.hero(HeroIcons.wrenchScrewdriver);

  // Part 17 — sidebar nav icons.
  static const patients = IconRef.hero(HeroIcons.users);
  static const appointments = IconRef.hero(HeroIcons.calendarDays);
  static const staff = IconRef.hero(HeroIcons.identification);
  static const inventory = IconRef.hero(HeroIcons.archiveBox);
  static const reports = IconRef.hero(HeroIcons.chartBar);
  static const offline = IconRef.hero(HeroIcons.signalSlash);
  static const today = IconRef.hero(HeroIcons.clock);

  // 2026-07-29 — Laboratorian role / lab orders + audit log viewer.
  static const labOrders = IconRef.hero(HeroIcons.beaker);
  static const auditLog = IconRef.hero(HeroIcons.clipboardDocumentList);
}
