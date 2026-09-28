/// Central gate for development-only tools.
///
/// During active development GitHub Actions explicitly enables the simulator
/// in the single signed APK with `GOVIA_NAV_SIMULATOR=true`. For the final
/// production build the define is removed (or set to false), which removes the
/// developer entry points without coupling navigation logic to the simulator.
class DevFeatures {
  const DevFeatures._();

  static const bool navigationSimulator = bool.fromEnvironment(
    'GOVIA_NAV_SIMULATOR',
    defaultValue: false,
  );
}
