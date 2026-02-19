import 'dart:convert';

class BookChapter {
  final String title;
  final String content;
  final int index;

  const BookChapter({
    required this.title,
    required this.content,
    required this.index,
  });

  Map<String, dynamic> toMap() {
    return {'title': title, 'content': content, 'index': index};
  }

  factory BookChapter.fromMap(Map<String, dynamic> map) {
    return BookChapter(
      title: map['title'] as String,
      content: map['content'] as String,
      index: map['index'] as int,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory BookChapter.fromJson(String source) =>
      BookChapter.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
