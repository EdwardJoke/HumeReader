import 'package:flutter/material.dart';
import 'package:hume/providers.dart';
import 'package:hume/screens/home_screen.dart';
import 'package:hume/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeProvider.loadPreferences();
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
