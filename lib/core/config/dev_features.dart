import 'package:flutter/foundation.dart';

/// Central gate for development-only tools.
///
/// Keep every temporary development feature behind this class so the complete
/// developer surface can be removed later without touching production logic.
class DevFeatures {
  const DevFeatures._();

  /// Available in the ordinary GitHub Actions debug APK, never in release.
  static const bool navigationSimulator = kDebugMode;
}
