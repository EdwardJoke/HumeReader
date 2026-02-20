import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:hume/models/book.dart';
import 'package:hume/models/book_chapter.dart';
import 'package:hume/models/reading_stats.dart';
import 'package:hume/models/shelf.dart';
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

class BookService {
  static const String _booksKey = 'books';
  static const String _statsKey = 'reading_stats';
  static const String _shelvesKey = 'shelves';
  static const String _booksDir = 'books';

  final SharedPreferences _prefs;
  final Uuid _uuid = const Uuid();

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

  Future<Book?> importBook(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      if (extension != 'txt' && extension != 'epub') {
        return null;
      }

      final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final fileSize = await file.length();
      final booksDir = await _getBooksDirectory();
      final newFileName = '${_uuid.v4()}.$extension';
      final newFile = File('${booksDir.path}/$newFileName');
      await file.copy(newFile.path);

      String? bookTitle = title;
      String? author;
      Uint8List? coverImage;

      if (extension == 'epub') {
        final bytes = await file.readAsBytes();
        final epubBook = await EpubReader.readBook(bytes);

        bookTitle = epubBook.Title?.isNotEmpty == true
            ? epubBook.Title!
            : title;
        author = epubBook.Author;

        if (epubBook.CoverImage != null) {
          coverImage = epubBook.CoverImage!.getBytes();
        }
      }

      final book = Book(
        id: _uuid.v4(),
        title: bookTitle,
        author: author,
        filePath: newFile.path,
        format: extension,
        fileSize: fileSize,
        addedAt: DateTime.now(),
        coverImage: coverImage,
      );

      await _saveBook(book);
      await _updateStatsBookCount();

      return book;
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

    books.removeWhere((b) => b.id == bookId);
    await _prefs.setString(
      _booksKey,
      jsonEncode(books.map((b) => b.toMap()).toList()),
    );
    await _updateStatsBookCount();
  }

  Future<List<Book>> getBooks() async {
    final booksJson = _prefs.getString(_booksKey);
    if (booksJson == null) return [];

    final List<dynamic> decoded = jsonDecode(booksJson) as List<dynamic>;
    return decoded.map((b) => Book.fromMap(b as Map<String, dynamic>)).toList();
  }

  Future<String> getBookContent(Book book) async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw Exception('Book file not found');
    }

    if (book.format == 'epub') {
      return getEpubFullContent(book);
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
    final chapters = await getEpubChapters(book);
    return chapters.map((c) => c.content).join('\n\n');
  }

  Future<List<BookChapter>> getEpubChapters(Book book) async {
    final file = File(book.filePath);
    if (!await file.exists()) {
      throw Exception('Book file not found');
    }

    final bytes = await file.readAsBytes();
    final epubBook = await EpubReader.readBook(bytes);

    final chapters = <BookChapter>[];
    int index = 0;

    void collectChapters(List<EpubChapter> epubChapters) {
      for (final chapter in epubChapters) {
        final title = chapter.Title ?? 'Chapter ${index + 1}';
        final htmlContent = chapter.HtmlContent ?? '';

        chapters.add(
          BookChapter(
            title: title,
            content: _stripHtml(htmlContent),
            htmlContent: _cleanHtml(htmlContent),
            index: index,
          ),
        );
        index++;

        if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
          collectChapters(chapter.SubChapters!);
        }
      }
    }

    if (epubBook.Chapters != null && epubBook.Chapters!.isNotEmpty) {
      collectChapters(epubBook.Chapters!);
    } else {
      final allHtmlContent = StringBuffer();
      final allTextContent = StringBuffer();
      epubBook.Content?.Html?.forEach((key, value) {
        final html = value.Content ?? '';
        allHtmlContent.write(html);
        allTextContent.write(_stripHtml(html));
        allTextContent.write('\n\n');
      });
      if (allHtmlContent.isNotEmpty) {
        chapters.add(
          BookChapter(
            title: book.title,
            content: allTextContent.toString().trim(),
            htmlContent: _cleanHtml(allHtmlContent.toString()),
            index: 0,
          ),
        );
      }
    }

    return chapters;
  }

  String _cleanHtml(String html) {
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

  String _stripHtml(String html) {
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
    await updateStats(
      stats.copyWith(
        totalReadingTimeMinutes: stats.totalReadingTimeMinutes + minutes,
        lastReadDate: DateTime.now(),
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
    // Calculate progress based on EPUB chapters or TXT pages
    int progress = book.readingProgress;

    if (book.format == 'epub' && chapterIndex != null) {
      // For EPUB, we estimate progress based on chapters
      // Get total chapters to calculate percentage
      final chapters = await getEpubChapters(book);
      if (chapters.isNotEmpty) {
        progress = ((chapterIndex / chapters.length) * 100).round();
      }
    } else if (currentPage != null && totalPages != null && totalPages > 0) {
      progress = ((currentPage / totalPages) * 100).round();
    }

    // Only update max progress if new progress is higher (never decreases)
    final maxProgress = progress > book.maxReadingProgress
        ? progress
        : book.maxReadingProgress;

    final updatedBook = book.copyWith(
      currentChapterIndex: chapterIndex ?? book.currentChapterIndex,
      scrollPosition: scrollPosition ?? book.scrollPosition,
      currentPage: currentPage ?? book.currentPage,
      totalPages: totalPages ?? book.totalPages,
      readingProgress: progress,
      maxReadingProgress: maxProgress,
      lastReadAt: DateTime.now(),
    );

    await updateBook(updatedBook);
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
    await updateStats(
      stats.copyWith(
        totalPagesRead: stats.totalPagesRead + 1,
        lastReadDate: DateTime.now(),
      ),
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
