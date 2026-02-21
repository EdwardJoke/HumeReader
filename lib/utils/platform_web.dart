/// Platform detection stub for web.
/// This file is used when dart:io is not available (web platform).
library;

/// Stub Platform class that always returns false for platform checks.
/// On web, platform-specific features are not available.
class Platform {
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
}
