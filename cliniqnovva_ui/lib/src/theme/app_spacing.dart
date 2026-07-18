/// Spacing scale — always use these instead of hardcoding padding/margin
/// numbers, so the whole app's rhythm can be tuned from one place.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Standard page-level horizontal/vertical padding.
  static const double section = 24;
}

/// Corner-radius scale — same idea as [AppSpacing], for `BorderRadius`.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 100;
}
