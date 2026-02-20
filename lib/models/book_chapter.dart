import 'dart:convert';

class BookChapter {
  final String title;
  final String content;
  final String? htmlContent;
  final int index;
  final String? href; // Original file path in EPUB (e.g., "text/chapter1.html")

  const BookChapter({
    required this.title,
    required this.content,
    this.htmlContent,
    required this.index,
    this.href,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'htmlContent': htmlContent,
      'index': index,
      'href': href,
    };
  }

  factory BookChapter.fromMap(Map<String, dynamic> map) {
    return BookChapter(
      title: map['title'] as String,
      content: map['content'] as String,
      htmlContent: map['htmlContent'] as String?,
      index: map['index'] as int,
      href: map['href'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BookChapter.fromJson(String source) =>
      BookChapter.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
