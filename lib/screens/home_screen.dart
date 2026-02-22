import 'package:flutter/material.dart';
import 'package:hume/screens/library_screen.dart';
import 'package:hume/screens/stats_screen.dart';
import 'package:hume/screens/user_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Use const for the screen widgets to enable widget caching
  static const List<Widget> _screens = [
    LibraryScreen(),
    StatsScreen(),
    UserScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Theme is already handled by MaterialApp - no need for AnimatedBuilder here
    // Using indexed stack would keep all screens alive, but for memory efficiency
    // we use direct indexing which disposes unused screens
    return Scaffold(
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
    );
  }
}
