import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:hume/models/book.dart';
import 'package:hume/models/book_chapter.dart';
import 'package:hume/models/reading_stats.dart';
import 'package:hume/models/shelf.dart';
import 'package:hume/services/mobi_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Exception thrown when file access is denied due to permission issues.
class FilePermissionException implements Exception {
  final String message;
  final String? path;

  const FilePermissionException(this.message, [this.path]);

  @override
  String toString() => 'FilePermissionException: $message';
}

Future<Map<String, dynamic>> _extractBookMetadata(
  Map<String, dynamic> payload,
) async {
  final bytes = payload['bytes'] as Uint8List;
  final extension = payload['extension'] as String;
  final fallbackTitle = payload['fallbackTitle'] as String;

  String title = fallbackTitle;
  String? author;
  Uint8List? coverImage;

  if (extension == 'epub') {
    final epubBook = await EpubReader.readBook(bytes);
    title = epubBook.Title?.isNotEmpty == true
        ? epubBook.Title!
        : fallbackTitle;
    author = epubBook.Author;
    if (epubBook.CoverImage != null) {
      coverImage = epubBook.CoverImage!.getBytes();
    }
  } else if (['mobi', 'azw', 'azw3'].contains(extension)) {
    final mobiData = await MobiService.parse(bytes);
    if (mobiData != null) {
      title = mobiData.title.isNotEmpty ? mobiData.title : fallbackTitle;
      author = mobiData.author;
      coverImage = mobiData.coverImage;
    }
  }

  return {'title': title, 'author': author, 'coverImage': coverImage};
}

Future<List<Map<String, dynamic>>> _extractEpubChapters(
  Map<String, dynamic> payload,
) async {
  final bytes = payload['bytes'] as Uint8List;
  final epubBook = await EpubReader.readBook(bytes);
  final chapters = <Map<String, dynamic>>[];
  int index = 0;

  void collectChapters(List<EpubChapter> epubChapters) {
    for (final chapter in epubChapters) {
      final title = chapter.Title ?? 'Chapter ${index + 1}';
      final htmlContent = chapter.HtmlContent ?? '';
      final href = chapter.ContentFileName;

      chapters.add({
        'title': title,
        'content': _stripHtmlText(htmlContent),
        'htmlContent': _cleanHtmlText(htmlContent),
        'index': index,
        'href': href,
      });
      index++;

      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        collectChapters(chapter.SubChapters!);
      }
    }
  }

  if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
    collectChapters(epubBook.Chapters!);
  } else {
    epubBook.Content?.Html?.forEach((key, value) {
      final html = value.Content ?? '';
      if (html.isNotEmpty) {
        chapters.add({
          'title': value.FileName ?? key,
          'content': _stripHtmlText(html),
          'htmlContent': _cleanHtmlText(html),
          'index': chapters.length,
          'href': value.FileName ?? key,
        });
      }
    });
  }

  return chapters;
}

Future<List<Map<String, dynamic>>> _extractMobiChapters(
  Map<String, dynamic> payload,
) async {
  final bytes = payload['bytes'] as Uint8List;
  final chapters = await MobiService.extractChapters(bytes);
  return chapters.map((chapter) => chapter.toMap()).toList();
}

String _cleanHtmlText(String html) {
  return html
      .replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
        '',
      )
      .trim();
}

String _stripHtmlText(String html) {
  return html
      .replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class BookService {
  static const String _booksKey = 'books';
  static const String _statsKey = 'reading_stats';
  static const String _shelvesKey = 'shelves';
  static const String _booksDir = 'books';
  static const int _chapterCacheVersion = 2;
  static const int _recentChapterCacheRadius = 2;

  final SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();
  final Map<String, List<BookChapter>> _sessionChapterCache = {};

  BookService(this._prefs);

  static Future<BookService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return BookService(prefs);
  }

  Future<Directory> _getBooksDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/$_booksDir');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  // ==================== Chapter Caching ====================

  Future<File> _getChapterCacheFile(Book book) async {
    final booksDir = await _getBooksDirectory();
    return File('${booksDir.path}/${book.id}_chapters.json');
  }

  Future<File> _getCoverImageFile(Book book) async {
    final booksDir = await _getBooksDirectory();
    return File('${booksDir.path}/${book.id}_cover.jpg');
  }

  List<int> _buildRecentChapterIndexes({
    required int centerIndex,
    required int totalChapters,
  }) {
    if (totalChapters <= 0) return const [];
    final safeCenter = centerIndex.clamp(0, totalChapters - 1);
    final indexes = <int>[];
    final start = safeCenter - _recentChapterCacheRadius;
    final end = safeCenter + _recentChapterCacheRadius;
    for (int i = start; i <= end; i++) {
      if (i >= 0 && i < totalChapters) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  /// Cache only recently read chapter content, but keep metadata for all chapters.
  Future<void> _cacheChapters(
    Book book,
    List<BookChapter> chapters, {
    int? centerIndex,
  }) async {
    try {
      if (chapters.isEmpty) return;
      final cacheFile = await _getChapterCacheFile(book);
      final recentIndexes = _buildRecentChapterIndexes(
        centerIndex: centerIndex ?? book.currentChapterIndex,
        totalChapters: chapters.length,
      ).toSet();

      final metadata = chapters
          .map(
            (chapter) => {
              'title': chapter.title,
              'index': chapter.index,
              'href': chapter.href,
            },
          )
          .toList();

      final recentContent = chapters
          .where((chapter) => recentIndexes.contains(chapter.index))
          .map(
            (chapter) => {
              'index': chapter.index,
              'content': chapter.content,
              'htmlContent': chapter.htmlContent,
            },
          )
          .toList();

      final jsonData = jsonEncode({
        'version': _chapterCacheVersion,
        'metadata': metadata,
        'recentContent': recentContent,
      });
      await cacheFile.writeAsString(jsonData);
    } catch (e) {
      debugPrint('Error caching chapters: $e');
    }
  }

  /// Load chapters from cache - returns null if cache doesn't exist or is invalid
  Future<List<BookChapter>?> _loadCachedChapters(Book book) async {
    try {
      final cacheFile = await _getChapterCacheFile(book);
      if (!await cacheFile.exists()) return null;

      final decoded = jsonDecode(await cacheFile.readAsString());

      // Backward compatibility with legacy full-cache format.
      if (decoded is List<dynamic>) {
        return decoded
            .map((c) => BookChapter.fromMap(c as Map<String, dynamic>))
            .toList();
      }

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final metadata = decoded['metadata'] as List<dynamic>? ?? const [];
      if (metadata.isEmpty) return null;

      final recentContent =
          decoded['recentContent'] as List<dynamic>? ?? const [];
      final contentByIndex = <int, Map<String, dynamic>>{};
      for (final item in recentContent) {
        final map = item as Map<String, dynamic>;
        final index = map['index'];
        if (index is int) {
          contentByIndex[index] = map;
        }
      }

      final chapters = metadata.map((item) {
        final map = item as Map<String, dynamic>;
        final index = map['index'] as int;
        final cached = contentByIndex[index];
        return BookChapter(
          title: map['title'] as String? ?? 'Chapter ${index + 1}',
          content: cached?['content'] as String? ?? '',
          htmlContent: cached?['htmlContent'] as String?,
          index: index,
          href: map['href'] as String?,
        );
      }).toList();
      chapters.sort((a, b) => a.index.compareTo(b.index));
      return chapters;
    } catch (e) {
      debugPrint('Error loading cached chapters: $e');
      return null;
    }
  }

  Future<List<BookChapter>> _parseEpubChapters(Book book) async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw Exception('Book file not found');
    }

    final bytes = await file.readAsBytes();
    final chapterMaps = await compute(_extractEpubChapters, {'bytes': bytes});
    return chapterMaps
        .map(
          (map) => BookChapter(
            title: map['title'] as String? ?? 'Chapter',
            content: map['content'] as String? ?? '',
            htmlContent: map['htmlContent'] as String?,
            index: map['index'] as int? ?? 0,
            href: map['href'] as String?,
          ),
        )
        .toList();
  }

  Future<List<BookChapter>> _parseMobiChapters(Book book) async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw Exception('Book file not found');
    }
    final bytes = await file.readAsBytes();
    final chapterMaps = await compute(_extractMobiChapters, {'bytes': bytes});
    return chapterMaps.map(BookChapter.fromMap).toList();
  }

  /// Save cover image to file instead of storing in SharedPreferences
  /// Returns the file path if successful, null otherwise
  Future<String?> saveCoverImage(Book book, Uint8List? coverImage) async {
    if (coverImage == null) return null;
    try {
      final coverFile = await _getCoverImageFile(book);
      await coverFile.writeAsBytes(coverImage);
      return coverFile.path;
    } catch (e) {
      debugPrint('Error saving cover image: $e');
      return null;
    }
  }

  /// Load cover image from file path - public method for lazy loading
  Future<Uint8List?> loadCoverImage(String? coverPath) async {
    if (coverPath == null) return null;
    try {
      final file = File(coverPath);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('Error loading cover image: $e');
      return null;
    }
  }

  /// Load cover image for a book - checks both filePath and legacy coverImage
  Future<Uint8List?> loadBookCover(Book book) async {
    // First try loading from file path
    if (book.coverImageFilePath != null) {
      final image = await loadCoverImage(book.coverImageFilePath);
      if (image != null) return image;
    }
    // Fallback to in-memory coverImage (for migration)
    return book.coverImage;
  }

  /// Delete cached data when book is deleted
  Future<void> _deleteBookCache(Book book) async {
    try {
      final cacheFile = await _getChapterCacheFile(book);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      final coverFile = await _getCoverImageFile(book);
      if (await coverFile.exists()) {
        await coverFile.delete();
      }
    } catch (e) {
      debugPrint('Error deleting book cache: $e');
    }
  }

  Future<Book?> importBook(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final bytes = await file.readAsBytes();
      final fileSize = await file.length();
      return _importBookFromBytes(
        bytes: bytes,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('Error importing book: $e');
      return null;
    }
  }

  Future<Book?> importBookBytes(Uint8List bytes, String fileName) async {
    return _importBookFromBytes(
      bytes: bytes,
      fileName: fileName,
      fileSize: bytes.length,
    );
  }

  Future<Book?> _importBookFromBytes({
    required Uint8List bytes,
    required String fileName,
    required int fileSize,
  }) async {
    try {
      final extension = fileName.split('.').last.toLowerCase();

      if (extension != 'txt' &&
          extension != 'epub' &&
          extension != 'mobi' &&
          extension != 'azw' &&
          extension != 'azw3') {
        return null;
      }

      final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final booksDir = await _getBooksDirectory();
      final newFileName = '${_uuid.v4()}.$extension';
      final newFile = File('${booksDir.path}/$newFileName');
      await newFile.writeAsBytes(bytes);

      String? bookTitle = title;
      String? author;
      Uint8List? coverImage;

      try {
        final metadata = await compute(_extractBookMetadata, {
          'bytes': bytes,
          'extension': extension,
          'fallbackTitle': title,
        });
        bookTitle = metadata['title'] as String?;
        author = metadata['author'] as String?;
        coverImage = metadata['coverImage'] as Uint8List?;
      } catch (e) {
        debugPrint('Background metadata parsing failed, using fallback: $e');
      }

      final bookId = _uuid.v4();
      final book = Book(
        id: bookId,
        title: bookTitle ?? title,
        author: author,
        filePath: newFile.path,
        format: extension,
        fileSize: fileSize,
        addedAt: DateTime.now(),
        coverImage: coverImage, // Keep for backward compatibility
      );

      // Save cover image to file and update book with file path
      String? coverFilePath;
      if (coverImage != null) {
        coverFilePath = await saveCoverImage(book, coverImage);
      }

      final finalBook = coverFilePath != null
          ? book.copyWith(
              coverImageFilePath: coverFilePath,
              clearCoverImage: true,
            )
          : book;

      await _saveBook(finalBook);
      await _updateStatsBookCount();

      return finalBook;
    } catch (e) {
      debugPrint('Error importing book: $e');
      return null;
    }
  }

  Future<void> _saveBook(Book book) async {
    final books = await getBooks();
    final existingIndex = books.indexWhere((b) => b.id == book.id);
    if (existingIndex >= 0) {
      books[existingIndex] = book;
    } else {
      books.add(book);
    }
    await _prefs.setString(
      _booksKey,
      jsonEncode(books.map((b) => b.toMap()).toList()),
    );
  }

  Future<void> updateBook(Book book) async {
    await _saveBook(book);
  }

  Future<void> deleteBook(String bookId) async {
    final books = await getBooks();
    final book = books.firstWhere((b) => b.id == bookId);

    final file = File(book.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Clean up cached chapter data and cover image
    await _deleteBookCache(book);
    _sessionChapterCache.remove(book.id);

    books.removeWhere((b) => b.id == bookId);
    await _prefs.setString(
      _booksKey,
      jsonEncode(books.map((b) => b.toMap()).toList()),
    );

    final shelves = await getShelves();
    bool shelvesChanged = false;
    final updatedShelves = shelves.map((shelf) {
      if (!shelf.bookIds.contains(bookId)) return shelf;
      shelvesChanged = true;
      final updatedBookIds = shelf.bookIds.where((id) => id != bookId).toList();
      return shelf.copyWith(bookIds: updatedBookIds);
    }).toList();
    if (shelvesChanged) {
      await _prefs.setString(
        _shelvesKey,
        jsonEncode(updatedShelves.map((s) => s.toMap()).toList()),
      );
    }

    await _updateStatsBookCount();
  }

  Future<List<Book>> getBooks() async {
    final booksJson = _prefs.getString(_booksKey);
    if (booksJson == null) return [];

    final List<dynamic> decoded = jsonDecode(booksJson) as List<dynamic>;
    return decoded.map((b) => Book.fromMap(b as Map<String, dynamic>)).toList();
  }

  /// Migrate existing books from base64 cover images to file storage
  /// Call this once during app startup to optimize existing data
  Future<void> migrateCoverImagesToFiles() async {
    final books = await getBooks();
    bool needsSave = false;

    for (final book in books) {
      // Skip if already migrated (has file path) or no cover image
      if (book.coverImageFilePath != null || book.coverImage == null) continue;

      // Save cover to file
      final coverFilePath = await saveCoverImage(book, book.coverImage);
      if (coverFilePath != null) {
        final updatedBook = book.copyWith(
          coverImageFilePath: coverFilePath,
          clearCoverImage: true,
        );
        await _saveBook(updatedBook);
        needsSave = true;
        debugPrint('Migrated cover image for: ${book.title}');
      }
    }

    if (needsSave) {
      debugPrint('Cover image migration complete');
    }
  }

  Future<String> getBookContent(Book book) async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw Exception('Book file not found');
    }

    if (book.format == 'epub') {
      return getEpubFullContent(book);
    }

    if (['mobi', 'azw', 'azw3'].contains(book.format)) {
      return getMobiFullContent(book);
    }

    try {
      return await file.readAsString();
    } catch (e) {
      if (Platform.isMacOS && _isPermissionError(e)) {
        throw FilePermissionException(
          'File access permission denied. Please grant file access in System Settings > Privacy & Security > Files and Folders.',
          book.filePath,
        );
      }
      rethrow;
    }
  }

  Future<String> getEpubFullContent(Book book) async {
    final chapters = await _parseEpubChapters(book);
    return chapters.map((c) => c.content).join('\n\n');
  }

  /// Get EPUB chapters with caching - major performance optimization
  /// First access: parses file and caches chapters
  /// Subsequent accesses: loads from cache (instant, no file I/O or parsing)
  Future<List<BookChapter>> getEpubChapters(Book book) async {
    final sessionChapters = _sessionChapterCache[book.id];
    if (sessionChapters != null && sessionChapters.isNotEmpty) {
      return sessionChapters;
    }

    // Try to load from cache first - avoids expensive re-parsing
    final cachedChapters = await _loadCachedChapters(book);
    if (cachedChapters != null) {
      _sessionChapterCache[book.id] = cachedChapters;
      return cachedChapters;
    }

    final chapters = await _parseEpubChapters(book);
    _sessionChapterCache[book.id] = chapters;
    await _cacheChapters(book, chapters, centerIndex: book.currentChapterIndex);

    return chapters;
  }

  Future<String> getMobiFullContent(Book book) async {
    final chapters = await _parseMobiChapters(book);
    return chapters.map((c) => c.content).join('\n\n');
  }

  /// Get MOBI/AZW3 chapters with caching - major performance optimization
  /// First access: parses file and caches chapters
  /// Subsequent accesses: loads from cache (instant, no file I/O or parsing)
  Future<List<BookChapter>> getMobiChapters(Book book) async {
    final sessionChapters = _sessionChapterCache[book.id];
    if (sessionChapters != null && sessionChapters.isNotEmpty) {
      return sessionChapters;
    }

    // Try to load from cache first - avoids expensive re-parsing
    final cachedChapters = await _loadCachedChapters(book);
    if (cachedChapters != null) {
      _sessionChapterCache[book.id] = cachedChapters;
      return cachedChapters;
    }

    final chapters = await _parseMobiChapters(book);
    _sessionChapterCache[book.id] = chapters;
    await _cacheChapters(book, chapters, centerIndex: book.currentChapterIndex);

    return chapters;
  }

  Future<BookChapter?> getEpubChapterByIndex(Book book, int index) async {
    final chapters = await getEpubChapters(book);
    if (index < 0 || index >= chapters.length) return null;

    final chapter = chapters[index];
    if (chapter.content.isNotEmpty ||
        (chapter.htmlContent?.isNotEmpty ?? false)) {
      return chapter;
    }

    final parsedChapters = await _parseEpubChapters(book);
    _sessionChapterCache[book.id] = parsedChapters;
    await _cacheChapters(book, parsedChapters, centerIndex: index);
    if (index < 0 || index >= parsedChapters.length) return null;
    return parsedChapters[index];
  }

  Future<BookChapter?> getMobiChapterByIndex(Book book, int index) async {
    final chapters = await getMobiChapters(book);
    if (index < 0 || index >= chapters.length) return null;

    final chapter = chapters[index];
    if (chapter.content.isNotEmpty) {
      return chapter;
    }

    final parsedChapters = await _parseMobiChapters(book);
    _sessionChapterCache[book.id] = parsedChapters;
    await _cacheChapters(book, parsedChapters, centerIndex: index);
    if (index < 0 || index >= parsedChapters.length) return null;
    return parsedChapters[index];
  }

  /// Checks if an error is related to file permission issues.
  bool _isPermissionError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('permission') ||
        errorString.contains('access') ||
        errorString.contains('denied') ||
        errorString.contains('unauthorized') ||
        errorString.contains('not allowed') ||
        errorString.contains('operation not permitted');
  }

  Future<ReadingStats> getStats() async {
    final books = await getBooks();

    // Calculate real-time stats from actual book data
    int totalBooks = books.length;
    int booksReadAverage = 0;

    if (books.isNotEmpty) {
      // Use maxReadingProgress (never decreases) instead of current readingProgress
      final totalProgress = books.fold<int>(
        0,
        (sum, book) => sum + book.maxReadingProgress,
      );
      booksReadAverage = (totalProgress / books.length).round();
    }

    // Get stored stats for streak/time data (not calculated from books)
    final statsJson = _prefs.getString(_statsKey);
    ReadingStats storedStats = const ReadingStats();
    if (statsJson != null) {
      storedStats = ReadingStats.fromMap(
        jsonDecode(statsJson) as Map<String, dynamic>,
      );
    }

    return storedStats.copyWith(
      totalBooks: totalBooks,
      booksReadAverage: booksReadAverage,
    );
  }

  Future<void> updateStats(ReadingStats stats) async {
    await _prefs.setString(_statsKey, jsonEncode(stats.toMap()));
  }

  /// Add reading time to total stats
  Future<void> addReadingTime(int minutes) async {
    if (minutes <= 0) return;
    final stats = await getStats();
    final updatedStreakStats = _updateStreaks(stats, DateTime.now());
    await updateStats(
      updatedStreakStats.copyWith(
        totalReadingTimeMinutes: stats.totalReadingTimeMinutes + minutes,
      ),
    );
  }

  Future<void> _updateStatsBookCount() async {
    final books = await getBooks();
    final stats = await getStats();

    // Calculate average reading progress across all books
    // Use maxReadingProgress (never decreases) instead of current readingProgress
    int averageProgress = 0;
    if (books.isNotEmpty) {
      final totalProgress = books.fold<int>(
        0,
        (sum, book) => sum + book.maxReadingProgress,
      );
      averageProgress = (totalProgress / books.length).round();
    }

    await updateStats(
      stats.copyWith(
        totalBooks: books.length,
        booksReadAverage: averageProgress,
      ),
    );
  }

  /// Save reading position (chapter index, scroll position) and update progress
  Future<void> saveReadingPosition({
    required Book book,
    int? chapterIndex,
    double? scrollPosition,
    int? currentPage,
    int? totalPages,
  }) async {
    final books = await getBooks();
    final currentIndex = books.indexWhere((b) => b.id == book.id);
    final currentBook = currentIndex >= 0 ? books[currentIndex] : book;
    final chapterChanged =
        chapterIndex != null && chapterIndex != currentBook.currentChapterIndex;

    // Calculate progress based on EPUB chapters or TXT pages
    int progress = currentBook.readingProgress;

    if (currentBook.format == 'epub' && chapterIndex != null) {
      final chapters = await getEpubChapters(currentBook);
      if (chapters.isNotEmpty) {
        progress = (((chapterIndex + 1) / chapters.length) * 100).round();
      }
    } else if (['mobi', 'azw', 'azw3'].contains(currentBook.format) &&
        chapterIndex != null) {
      final chapters = await getMobiChapters(currentBook);
      if (chapters.isNotEmpty) {
        progress = (((chapterIndex + 1) / chapters.length) * 100).round();
      }
    } else if (currentPage != null && totalPages != null && totalPages > 0) {
      progress = ((currentPage / totalPages) * 100).round();
    }
    progress = progress.clamp(0, 100).toInt();

    // Only update max progress if new progress is higher (never decreases)
    final maxProgress = progress > currentBook.maxReadingProgress
        ? progress
        : currentBook.maxReadingProgress;

    final updatedBook = currentBook.copyWith(
      currentChapterIndex: chapterIndex ?? currentBook.currentChapterIndex,
      scrollPosition: scrollPosition ?? currentBook.scrollPosition,
      currentPage: currentPage ?? currentBook.currentPage,
      totalPages: totalPages ?? currentBook.totalPages,
      readingProgress: progress,
      maxReadingProgress: maxProgress,
      lastReadAt: DateTime.now(),
    );

    await updateBook(updatedBook);
    if (chapterChanged) {
      final chapters = _sessionChapterCache[updatedBook.id];
      if (chapters != null && chapters.isNotEmpty) {
        await _cacheChapters(updatedBook, chapters, centerIndex: chapterIndex);
      }
    }
    await _updateStatsBookCount();
  }

  Future<void> updateReadingProgress(
    Book book,
    int currentPage,
    int totalPages,
  ) async {
    await saveReadingPosition(
      book: book,
      currentPage: currentPage,
      totalPages: totalPages,
    );

    final stats = await getStats();
    final updatedStreakStats = _updateStreaks(stats, DateTime.now());
    await updateStats(
      updatedStreakStats.copyWith(totalPagesRead: stats.totalPagesRead + 1),
    );
  }

  ReadingStats _updateStreaks(ReadingStats stats, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final last = stats.lastReadDate;
    if (last == null) {
      return stats.copyWith(
        currentStreak: 1,
        longestStreak: stats.longestStreak < 1 ? 1 : stats.longestStreak,
        lastReadDate: now,
      );
    }

    final lastDay = DateTime(last.year, last.month, last.day);
    final dayDiff = today.difference(lastDay).inDays;

    if (dayDiff <= 0) {
      return stats.copyWith(lastReadDate: now);
    }

    if (dayDiff == 1) {
      final currentStreak = stats.currentStreak + 1;
      final longestStreak = currentStreak > stats.longestStreak
          ? currentStreak
          : stats.longestStreak;
      return stats.copyWith(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastReadDate: now,
      );
    }

    return stats.copyWith(
      currentStreak: 1,
      longestStreak: stats.longestStreak < 1 ? 1 : stats.longestStreak,
      lastReadDate: now,
    );
  }

  // ==================== Shelf Operations ====================

  Future<List<Shelf>> getShelves() async {
    final shelvesJson = _prefs.getString(_shelvesKey);
    if (shelvesJson == null) return [];
    final List<dynamic> decoded = jsonDecode(shelvesJson) as List<dynamic>;
    return decoded
        .map((s) => Shelf.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  Future<Shelf> createShelf(String name, {String? icon}) async {
    final shelves = await getShelves();
    final shelf = Shelf(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      createdAt: DateTime.now(),
    );
    shelves.add(shelf);
    await _prefs.setString(
      _shelvesKey,
      jsonEncode(shelves.map((s) => s.toMap()).toList()),
    );
    return shelf;
  }

  Future<void> updateShelf(Shelf shelf) async {
    final shelves = await getShelves();
    final index = shelves.indexWhere((s) => s.id == shelf.id);
    if (index >= 0) {
      shelves[index] = shelf;
      await _prefs.setString(
        _shelvesKey,
        jsonEncode(shelves.map((s) => s.toMap()).toList()),
      );
    }
  }

  Future<void> deleteShelf(String shelfId) async {
    final shelves = await getShelves();
    shelves.removeWhere((s) => s.id == shelfId);
    await _prefs.setString(
      _shelvesKey,
      jsonEncode(shelves.map((s) => s.toMap()).toList()),
    );
  }

  Future<void> addBookToShelf(String shelfId, String bookId) async {
    final shelves = await getShelves();
    final index = shelves.indexWhere((s) => s.id == shelfId);
    if (index >= 0) {
      final shelf = shelves[index];
      if (!shelf.bookIds.contains(bookId)) {
        final updatedShelf = shelf.copyWith(
          bookIds: [...shelf.bookIds, bookId],
        );
        await updateShelf(updatedShelf);
      }
    }
  }

  Future<void> removeBookFromShelf(String shelfId, String bookId) async {
    final shelves = await getShelves();
    final index = shelves.indexWhere((s) => s.id == shelfId);
    if (index >= 0) {
      final shelf = shelves[index];
      final updatedBookIds = shelf.bookIds.where((id) => id != bookId).toList();
      await updateShelf(shelf.copyWith(bookIds: updatedBookIds));
    }
  }

  Future<List<Book>> getBooksInShelf(String shelfId) async {
    final shelves = await getShelves();
    final shelf = shelves.where((s) => s.id == shelfId).firstOrNull;
    if (shelf == null) return [];

    final allBooks = await getBooks();
    return allBooks.where((b) => shelf.bookIds.contains(b.id)).toList();
  }
}
