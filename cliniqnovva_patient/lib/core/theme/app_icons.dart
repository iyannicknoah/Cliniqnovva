import 'package:heroicons/heroicons.dart';

/// A single icon reference — always a Heroicon. Render with the [AppIcon]
/// widget — never with the raw Material [Icon] widget (same rule as
/// cliniqnovva/lib/core/theme/app_icons.dart: Heroicons everywhere).
class IconRef {
  const IconRef.hero(this.hero);

  final HeroIcons hero;
}

/// Icon catalog for the Patient App — grows as new screens need icons.
class AppIcons {
  AppIcons._();

  static const view = IconRef.hero(HeroIcons.eye);
  static const eyeSlash = IconRef.hero(HeroIcons.eyeSlash);
  static const back = IconRef.hero(HeroIcons.arrowLeft);
  static const close = IconRef.hero(HeroIcons.xMark);
  static const chevronRight = IconRef.hero(HeroIcons.chevronRight);
  static const logout = IconRef.hero(HeroIcons.arrowRightStartOnRectangle);
  static const notification = IconRef.hero(HeroIcons.bell);
  static const search = IconRef.hero(HeroIcons.magnifyingGlass);
  static const star = IconRef.hero(HeroIcons.star);
  static const send = IconRef.hero(HeroIcons.paperAirplane);
  static const globe = IconRef.hero(HeroIcons.globeAlt);
  static const check = IconRef.hero(HeroIcons.checkCircle);
  static const document = IconRef.hero(HeroIcons.documentText);
  static const receipt = IconRef.hero(HeroIcons.receiptPercent);
  static const mapPin = IconRef.hero(HeroIcons.mapPin);
  static const clock = IconRef.hero(HeroIcons.clock);
  static const filterList = IconRef.hero(HeroIcons.adjustmentsHorizontal);
  static const calendar = IconRef.hero(HeroIcons.calendarDays);
  static const flag = IconRef.hero(HeroIcons.flag);
  static const offline = IconRef.hero(HeroIcons.signalSlash);

  // Bottom nav (Task 6).
  static const navHome = IconRef.hero(HeroIcons.home);
  static const navBrowse = IconRef.hero(HeroIcons.magnifyingGlass);
  static const navBookings = IconRef.hero(HeroIcons.calendarDays);
  static const navChat = IconRef.hero(HeroIcons.chatBubbleOvalLeftEllipsis);
  static const navSettings = IconRef.hero(HeroIcons.userCircle);
}
