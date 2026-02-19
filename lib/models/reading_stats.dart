class ReadingStats {
  final int totalBooks;
  final int booksRead;
  final int totalPagesRead;
  final int totalReadingTimeMinutes;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastReadDate;

  const ReadingStats({
    this.totalBooks = 0,
    this.booksRead = 0,
    this.totalPagesRead = 0,
    this.totalReadingTimeMinutes = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastReadDate,
  });

  ReadingStats copyWith({
    int? totalBooks,
    int? booksRead,
    int? totalPagesRead,
    int? totalReadingTimeMinutes,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastReadDate,
  }) {
    return ReadingStats(
      totalBooks: totalBooks ?? this.totalBooks,
      booksRead: booksRead ?? this.booksRead,
      totalPagesRead: totalPagesRead ?? this.totalPagesRead,
      totalReadingTimeMinutes:
          totalReadingTimeMinutes ?? this.totalReadingTimeMinutes,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastReadDate: lastReadDate ?? this.lastReadDate,
    );
  }

  String get formattedReadingTime {
    final hours = totalReadingTimeMinutes ~/ 60;
    final minutes = totalReadingTimeMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Map<String, dynamic> toMap() {
    return {
      'totalBooks': totalBooks,
      'booksRead': booksRead,
      'totalPagesRead': totalPagesRead,
      'totalReadingTimeMinutes': totalReadingTimeMinutes,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastReadDate': lastReadDate?.toIso8601String(),
    };
  }

  factory ReadingStats.fromMap(Map<String, dynamic> map) {
    return ReadingStats(
      totalBooks: map['totalBooks'] as int? ?? 0,
      booksRead: map['booksRead'] as int? ?? 0,
      totalPagesRead: map['totalPagesRead'] as int? ?? 0,
      totalReadingTimeMinutes: map['totalReadingTimeMinutes'] as int? ?? 0,
      currentStreak: map['currentStreak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      lastReadDate: map['lastReadDate'] != null
          ? DateTime.parse(map['lastReadDate'] as String)
          : null,
    );
  }
}
