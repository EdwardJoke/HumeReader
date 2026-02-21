import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hume/providers.dart';
import 'package:hume/screens/home_screen.dart';
import 'package:hume/services/fullscreen_service.dart';
import 'package:hume/services/window_service.dart';
import 'package:hume/theme/app_theme.dart';
import 'package:hume/utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeProvider.loadPreferences();

  if (PlatformUtils.isDesktop) {
    await WindowService.initialize();
  }

  // Enable full-screen mode on mobile devices
  if (PlatformUtils.isMobile) {
    // Use native Android 14+ fullscreen API for Android
    if (PlatformUtils.isAndroid) {
      await FullscreenService.enterFullscreen();
    } else {
      // Fallback for iOS using SystemChrome
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    }
    // Lock orientation to portrait for consistent mobile experience
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const HumeApp());
}

class HumeApp extends StatelessWidget {
  const HumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeProvider,
      builder: (context, child) {
        return MaterialApp(
          title: 'Hume Reader',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(themeProvider.selectedColor),
          darkTheme: AppTheme.darkTheme(themeProvider.selectedColor),
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const HomeScreen(),
        );
      },
    );
  }
}
