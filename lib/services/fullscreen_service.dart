import 'package:flutter/services.dart';
import 'package:hume/utils/platform_utils.dart';

/// Service for controlling fullscreen mode on Android 14+.
/// Uses native platform channels to call the new WindowInsetsControllerCompat API.
class FullscreenService {
  static const _channel = MethodChannel('com.example.hume/fullscreen');

  /// Enable edge-to-edge mode where content draws behind system bars.
  /// This is the recommended modern look for Android 14+.
  static Future<void> enableEdgeToEdge() async {
    if (!PlatformUtils.isAndroid) return;
    await _channel.invokeMethod<void>('enableEdgeToEdge');
  }

  /// Enter fullscreen mode by hiding all system bars.
  /// User can swipe from edges to temporarily reveal bars.
  static Future<void> enterFullscreen() async {
    if (!PlatformUtils.isAndroid) return;
    await _channel.invokeMethod<void>('enterFullscreen');
  }

  /// Exit fullscreen mode by showing system bars.
  static Future<void> exitFullscreen() async {
    if (!PlatformUtils.isAndroid) return;
    await _channel.invokeMethod<void>('exitFullscreen');
  }

  /// Toggle between fullscreen and normal mode.
  static Future<void> toggleFullscreen() async {
    if (!PlatformUtils.isAndroid) return;
    await _channel.invokeMethod<void>('toggleFullscreen');
  }

  /// Check if currently in fullscreen mode.
  static Future<bool> isFullscreen() async {
    if (!PlatformUtils.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isFullscreen') ?? false;
  }
}
