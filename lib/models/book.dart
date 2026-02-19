import 'dart:convert';
import 'dart:typed_data';

class Book {
  final String id;
  final String title;
  final String? author;
  final String filePath;
  final String format;
  final int fileSize;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final int currentPage;
  final int totalPages;
  final int readingProgress;
  final Uint8List? coverImage;

  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.filePath,
    required this.format,
    required this.fileSize,
    required this.addedAt,
    this.lastReadAt,
    this.currentPage = 0,
    this.totalPages = 0,
    this.readingProgress = 0,
    this.coverImage,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? format,
    int? fileSize,
    DateTime? addedAt,
    DateTime? lastReadAt,
    int? currentPage,
    int? totalPages,
    int? readingProgress,
    Uint8List? coverImage,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      readingProgress: readingProgress ?? this.readingProgress,
      coverImage: coverImage ?? this.coverImage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'filePath': filePath,
      'format': format,
      'fileSize': fileSize,
      'addedAt': addedAt.toIso8601String(),
      'lastReadAt': lastReadAt?.toIso8601String(),
      'currentPage': currentPage,
      'totalPages': totalPages,
      'readingProgress': readingProgress,
      'coverImage': coverImage != null ? base64Encode(coverImage!) : null,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      filePath: map['filePath'] as String,
      format: map['format'] as String,
      fileSize: map['fileSize'] as int,
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastReadAt: map['lastReadAt'] != null
          ? DateTime.parse(map['lastReadAt'] as String)
          : null,
      currentPage: map['currentPage'] as int? ?? 0,
      totalPages: map['totalPages'] as int? ?? 0,
      readingProgress: map['readingProgress'] as int? ?? 0,
      coverImage: map['coverImage'] != null
          ? base64Decode(map['coverImage'] as String)
          : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Book.fromJson(String source) =>
      Book.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
