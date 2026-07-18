import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/theme_ext.dart';
import 'app_icon.dart';

/// Cliniqnovva's three supported languages (spec section 1) — kept here as
/// the single list every app's language picker reads from.
const List<(String code, String label)> kSupportedLocales = [
  ('rw', 'Kinyarwanda'),
  ('en', 'English'),
  ('fr', 'Français'),
];

/// The single language-picker component. It's a "dumb"/controlled widget —
/// it doesn't know how locale switching is implemented (Riverpod, Provider,
/// setState, whatever the app uses); it just reports the chosen code via
/// [onChanged] and displays [currentLocaleCode].
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, required this.currentLocaleCode, required this.onChanged, this.size = 36});

  final String currentLocaleCode;
  final ValueChanged<String> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Language',
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) {
        return kSupportedLocales.map((locale) {
          final selected = locale.$1 == currentLocaleCode;
          return PopupMenuItem<String>(
            value: locale.$1,
            child: Row(
              children: [
                if (selected) AppIcon(AppIcons.checkRounded, size: 16, color: context.appText),
                if (selected) const SizedBox(width: 8),
                Text(locale.$2, style: TextStyle(color: context.appText, fontSize: 14)),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.appTint, shape: BoxShape.circle),
        child: Center(
          child: Text(
            currentLocaleCode.toUpperCase(),
            style: TextStyle(color: context.appText, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
