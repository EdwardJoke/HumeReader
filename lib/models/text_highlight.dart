import 'package:flutter/material.dart';

enum HighlightStyle {
  /// Markpen/highlighter style - semi-transparent background color
  markpen,

  /// Underline style - solid line below the text
  underline,
}

class TextHighlight {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final Color color;
  final HighlightStyle style;
  final DateTime createdAt;

  const TextHighlight({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    required this.color,
    required this.style,
    required this.createdAt,
  });

  TextHighlight copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    int? startOffset,
    int? endOffset,
    String? selectedText,
    Color? color,
    HighlightStyle? style,
    DateTime? createdAt,
  }) {
    return TextHighlight(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      selectedText: selectedText ?? this.selectedText,
      color: color ?? this.color,
      style: style ?? this.style,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'selectedText': selectedText,
      'color': color.toARGB32(),
      'style': style.index,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TextHighlight.fromJson(Map<String, dynamic> json) {
    return TextHighlight(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      chapterIndex: json['chapterIndex'] as int,
      startOffset: json['startOffset'] as int,
      endOffset: json['endOffset'] as int,
      selectedText: json['selectedText'] as String,
      color: Color(json['color'] as int),
      style: HighlightStyle.values[json['style'] as int],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextHighlight && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined highlight colors for quick selection
class HighlightColors {
  static const List<Color> colors = [
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFF9800), // Orange
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Deep Orange
  ];

  static const List<String> colorNames = [
    'Yellow',
    'Orange',
    'Pink',
    'Purple',
    'Blue',
    'Green',
    'Cyan',
    'Red',
  ];
}
