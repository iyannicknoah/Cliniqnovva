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

  static const organizations = IconRef.hero(HeroIcons.buildingOffice2);
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
  static const chat = IconRef.hero(HeroIcons.chatBubbleOvalLeftEllipsis);
  static const notification = IconRef.hero(HeroIcons.bell);
  static const search = IconRef.hero(HeroIcons.magnifyingGlass);
  static const overview = IconRef.hero(HeroIcons.squares2x2);
  static const trash = IconRef.hero(HeroIcons.trash);
  static const plus = IconRef.hero(HeroIcons.plus);
  static const department = IconRef.hero(HeroIcons.buildingOffice);
  static const generate = IconRef.hero(HeroIcons.arrowPath);
}
