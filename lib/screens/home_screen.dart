import 'package:flutter/material.dart';
import 'package:hume/providers.dart';
import 'package:hume/screens/library_screen.dart';
import 'package:hume/screens/stats_screen.dart';
import 'package:hume/screens/user_screen.dart';
import 'package:hume/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    LibraryScreen(),
    StatsScreen(),
    UserScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeProvider,
      builder: (context, child) {
        return AnimatedTheme(
          data: themeProvider.isDarkMode
              ? AppTheme.darkTheme(themeProvider.selectedColor)
              : AppTheme.lightTheme(themeProvider.selectedColor),
          duration: const Duration(milliseconds: 300),
          child: Scaffold(
            body: _screens[_selectedIndex],
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Library',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Stats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'User',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
