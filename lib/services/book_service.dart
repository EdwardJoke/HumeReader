import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hume/models/book.dart';
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

      if (extension != 'txt') {
        return null;
      }

      final title = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
      final fileSize = await file.length();
      final booksDir = await _getBooksDirectory();
      final newFileName = '${_uuid.v4()}.$extension';
      final newFile = File('${booksDir.path}/$newFileName');
      await file.copy(newFile.path);

      final book = Book(
        id: _uuid.v4(),
        title: title,
        filePath: newFile.path,
        format: extension,
        fileSize: fileSize,
        addedAt: DateTime.now(),
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
    try {
      return await file.readAsString();
    } catch (e) {
      // Check if this is a permission error (macOS sandbox)
      if (Platform.isMacOS && _isPermissionError(e)) {
        throw FilePermissionException(
          'File access permission denied. Please grant file access in System Settings > Privacy & Security > Files and Folders.',
          book.filePath,
        );
      }
      rethrow;
    }
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
    final statsJson = _prefs.getString(_statsKey);
    if (statsJson == null) {
      return const ReadingStats();
    }
    return ReadingStats.fromMap(jsonDecode(statsJson) as Map<String, dynamic>);
  }

  Future<void> updateStats(ReadingStats stats) async {
    await _prefs.setString(_statsKey, jsonEncode(stats.toMap()));
  }

  Future<void> _updateStatsBookCount() async {
    final books = await getBooks();
    final stats = await getStats();
    await updateStats(stats.copyWith(totalBooks: books.length));
  }

  Future<void> updateReadingProgress(
    Book book,
    int currentPage,
    int totalPages,
  ) async {
    final progress = totalPages > 0
        ? ((currentPage / totalPages) * 100).round()
        : 0;
    final updatedBook = book.copyWith(
      currentPage: currentPage,
      totalPages: totalPages,
      readingProgress: progress,
      lastReadAt: DateTime.now(),
    );
    await updateBook(updatedBook);

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
