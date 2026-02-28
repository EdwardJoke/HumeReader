import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hume/models/text_highlight.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class HighlightProvider extends ChangeNotifier {
  static const String _highlightsKey = 'text_highlights';
  final Uuid _uuid = const Uuid();

  List<TextHighlight> _highlights = [];
  String? _currentBookId;
  int? _currentChapterIndex;

  List<TextHighlight> get highlights => _highlights;
  String? get currentBookId => _currentBookId;
  int? get currentChapterIndex => _currentChapterIndex;

  Future<void> loadHighlights(String bookId) async {
    _currentBookId = bookId;
    final prefs = await SharedPreferences.getInstance();
    final String? highlightsJson = prefs.getString('${_highlightsKey}_$bookId');

    if (highlightsJson != null) {
      final List<dynamic> decoded = jsonDecode(highlightsJson);
      _highlights = decoded
          .map((e) => TextHighlight.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _highlights = [];
    }
    notifyListeners();
  }

  void setCurrentChapter(int chapterIndex) {
    _currentChapterIndex = chapterIndex;
    notifyListeners();
  }

  List<TextHighlight> getHighlightsForChapter(int chapterIndex) {
    return _highlights.where((h) => h.chapterIndex == chapterIndex).toList();
  }

  Future<TextHighlight> addHighlight({
    required int startOffset,
    required int endOffset,
    required String selectedText,
    required Color color,
    required HighlightStyle style,
  }) async {
    if (_currentBookId == null) {
      throw Exception('No book selected');
    }

    final highlight = TextHighlight(
      id: _uuid.v4(),
      bookId: _currentBookId!,
      chapterIndex: _currentChapterIndex ?? 0,
      startOffset: startOffset,
      endOffset: endOffset,
      selectedText: selectedText,
      color: color,
      style: style,
      createdAt: DateTime.now(),
    );

    _highlights.add(highlight);
    await _saveHighlights();
    notifyListeners();
    return highlight;
  }

  Future<void> removeHighlight(String highlightId) async {
    _highlights.removeWhere((h) => h.id == highlightId);
    await _saveHighlights();
    notifyListeners();
  }

  Future<void> updateHighlightColor(String highlightId, Color newColor) async {
    final index = _highlights.indexWhere((h) => h.id == highlightId);
    if (index != -1) {
      _highlights[index] = _highlights[index].copyWith(color: newColor);
      await _saveHighlights();
      notifyListeners();
    }
  }

  Future<void> updateHighlightStyle(
    String highlightId,
    HighlightStyle newStyle,
  ) async {
    final index = _highlights.indexWhere((h) => h.id == highlightId);
    if (index != -1) {
      _highlights[index] = _highlights[index].copyWith(style: newStyle);
      await _saveHighlights();
      notifyListeners();
    }
  }

  Future<void> clearHighlightsForBook() async {
    if (_currentBookId == null) return;
    _highlights.clear();
    await _saveHighlights();
    notifyListeners();
  }

  TextHighlight? findHighlightAtOffset(int offset) {
    try {
      return _highlights.firstWhere(
        (h) =>
            h.chapterIndex == _currentChapterIndex &&
            offset >= h.startOffset &&
            offset < h.endOffset,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveHighlights() async {
    if (_currentBookId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _highlights.map((h) => h.toJson()).toList(),
    );
    await prefs.setString('${_highlightsKey}_$_currentBookId', encoded);
  }
}
