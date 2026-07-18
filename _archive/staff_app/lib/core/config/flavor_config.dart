enum Flavor { dev, staging, prod }

/// Per-environment settings (spec section: separate Firebase projects per
/// dev/staging/prod, see /firebase/.firebaserc). Set once in `main_<flavor>.dart`
/// before runApp — read anywhere via FlavorConfig.instance.
class FlavorConfig {
  final Flavor flavor;
  final String apiBaseUrl;
  final String firebaseProjectId;

  static FlavorConfig? _instance;

  factory FlavorConfig({
    required Flavor flavor,
    required String apiBaseUrl,
    required String firebaseProjectId,
  }) {
    _instance ??= FlavorConfig._internal(flavor, apiBaseUrl, firebaseProjectId);
    return _instance!;
  }

  FlavorConfig._internal(this.flavor, this.apiBaseUrl, this.firebaseProjectId);

  static FlavorConfig get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'FlavorConfig has not been initialized. Call FlavorConfig(...) in main_<flavor>.dart before runApp.',
      );
    }
    return instance;
  }

  static bool get isProd => instance.flavor == Flavor.prod;
}
