import 'package:flutter/material.dart';
import 'package:hume/models/reading_stats.dart';
import 'package:hume/services/book_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<BookService> _bookServiceFuture;
  ReadingStats _stats = const ReadingStats();

  @override
  void initState() {
    super.initState();
    _bookServiceFuture = BookService.create();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final service = await _bookServiceFuture;
    final stats = await service.getStats();
    setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatCard(
            icon: Icons.library_books,
            title: 'Total Books',
            value: _stats.totalBooks.toString(),
            color: colorScheme.primaryContainer,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            icon: Icons.book,
            title: 'Avg Progress',
            value: '${_stats.booksReadAverage}%',
            color: colorScheme.secondaryContainer,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            icon: Icons.article,
            title: 'Pages Read',
            value: _stats.totalPagesRead.toString(),
            color: colorScheme.tertiaryContainer,
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            icon: Icons.timer,
            title: 'Reading Time',
            value: _stats.formattedReadingTime,
            color: colorScheme.primaryContainer,
          ),
          const SizedBox(height: 24),
          Text('Streaks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStreakCard(
                  icon: Icons.local_fire_department,
                  title: 'Current',
                  value: _stats.currentStreak,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStreakCard(
                  icon: Icons.emoji_events,
                  title: 'Longest',
                  value: _stats.longestStreak,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard({
    required IconData icon,
    required String title,
    required int value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              '$value days',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
