import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hume/providers.dart';
import 'package:hume/screens/home_screen.dart';
import 'package:hume/services/book_service.dart';
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

  // Migrate cover images from SharedPreferences to file storage
  // This is a one-time operation for existing books
  try {
    final bookService = await BookService.create();
    await bookService.migrateCoverImagesToFiles();
  } catch (e) {
    debugPrint('Error migrating cover images: $e');
  }

  runApp(const HumeApp());
}

class HumeApp extends StatelessWidget {
  const HumeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use ListenableBuilder instead of AnimatedBuilder for better semantics
    // Only rebuild theme-related parts, not the entire MaterialApp
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: highlightProvider),
      ],
      child: ListenableBuilder(
        listenable: themeProvider,
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
      ),
    );
  }
}
