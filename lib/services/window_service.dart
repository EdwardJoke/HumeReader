import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hume/utils/platform_utils.dart';

class WindowService {
  static const double minWidth = 800.0;
  static const double minHeight = 600.0;

  static Future<void> initialize() async {
    if (!PlatformUtils.isDesktop) return;

    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: const Size(800, 600),
      minimumSize: const Size(minWidth, minHeight),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Hume Reader',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> setMinimumSize(double width, double height) async {
    if (!PlatformUtils.isDesktop) return;
    await windowManager.setMinimumSize(Size(width, height));
  }
}
