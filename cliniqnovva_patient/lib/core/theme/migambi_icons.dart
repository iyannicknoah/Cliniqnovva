import 'package:flutter/widgets.dart';

/// Trimmed subset of the "Migambi VIP Icons" font pack (IcoMoon export,
/// ~1900 glyphs total — full source at
/// Migambi-VIP-Icons-v1.0/Migambi-VIP-Icons_icons.dart if a new icon is
/// ever needed) — only the handful this app actually uses, renamed off
/// the generator's raw `snake_case_with_trailing_digits` names to plain
/// semantic ones. Codepoints are copied verbatim from the generated file;
/// do not renumber them.
class MigambiIcons {
  MigambiIcons._();

  static const String _fontFamily = 'Migambi-VIP-Icons';

  static const IconData eye = IconData(0xea62, fontFamily: _fontFamily);
  static const IconData eyeSlash = IconData(0xea63, fontFamily: _fontFamily);
  static const IconData arrowLeft = IconData(0xe933, fontFamily: _fontFamily);
  static const IconData arrowRight = IconData(0xe937, fontFamily: _fontFamily);
  static const IconData closeCircle = IconData(0xe9d9, fontFamily: _fontFamily);
  static const IconData logout = IconData(0xeb1e, fontFamily: _fontFamily);
  static const IconData notificationBing = IconData(0xeb93, fontFamily: _fontFamily);
  static const IconData searchNormal = IconData(0xefd6, fontFamily: _fontFamily);
  static const IconData star = IconData(0xec50, fontFamily: _fontFamily);
  static const IconData send = IconData(0xec14, fontFamily: _fontFamily);
  static const IconData global = IconData(0xeaa5, fontFamily: _fontFamily);
  static const IconData tickCircle = IconData(0xec79, fontFamily: _fontFamily);
  static const IconData document = IconData(0xea2b, fontFamily: _fontFamily);
  static const IconData receipt = IconData(0xebd6, fontFamily: _fontFamily);
  static const IconData location = IconData(0xeb11, fontFamily: _fontFamily);
  static const IconData clock = IconData(0xe9d7, fontFamily: _fontFamily);
  static const IconData filter = IconData(0xea69, fontFamily: _fontFamily);
  static const IconData calendar = IconData(0xe99b, fontFamily: _fontFamily);
  static const IconData flag = IconData(0xea73, fontFamily: _fontFamily);
  static const IconData hospital = IconData(0xeadf, fontFamily: _fontFamily);
  static const IconData call = IconData(0xe9a4, fontFamily: _fontFamily);

  /// The exact "messages233" glyph named in the FlutterFlow reference
  /// (`FFIcons.kmessages233`) — was `message02` (0xeb37), a different
  /// glyph, before the user pointed out the exact name to use.
  static const IconData messages233 = IconData(0xeb45, fontFamily: _fontFamily);

  /// The exact "arrowRight40" glyph named in the FlutterFlow reference
  /// (`FFIcons.karrowRight40`) — used for "View all" tiles.
  static const IconData arrowRight40 = IconData(0xed1c, fontFamily: _fontFamily);

  /// The exact "arrowLeft44" glyph (2026-08-19, explicit user instruction)
  /// — codepoint confirmed against the full icon pack's own generated
  /// `Migambi-VIP-Icons_icons.dart` (`Documents\Migambi-VIP-Icons-v1.0\`),
  /// not guessed. Now the app-wide back icon — see `AppIcons.back`.
  static const IconData arrowLeft44 = IconData(0xed18, fontFamily: _fontFamily);

  // Bottom nav (2026-08-13) — explicit exact-name requests, switching the
  // nav off Heroicons/mini onto this font too (see app_icons.dart's
  // updated "Bottom nav" note — supersedes the earlier "navbar stays
  // Heroicons" rule).
  static const IconData home49 = IconData(0xead8, fontFamily: _fontFamily);
  static const IconData book09 = IconData(0xe975, fontFamily: _fontFamily);
  static const IconData messages34 = IconData(0xeb44, fontFamily: _fontFamily);
  static const IconData profileCircle = IconData(0xebc0, fontFamily: _fontFamily);

  /// "The type of icon in screenshot" for the Explore tab — a compass,
  /// which is what Iconsax's "discover" glyphs actually are.
  static const IconData discover = IconData(0xea27, fontFamily: _fontFamily);
}
