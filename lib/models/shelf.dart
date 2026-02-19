import 'dart:convert';

/// Represents a shelf/collection for organizing books.
class Shelf {
  final String id;
  final String name;
  final String? icon;
  final DateTime createdAt;
  final List<String> bookIds;

  const Shelf({
    required this.id,
    required this.name,
    this.icon,
    required this.createdAt,
    this.bookIds = const [],
  });

  Shelf copyWith({
    String? id,
    String? name,
    String? icon,
    DateTime? createdAt,
    List<String>? bookIds,
  }) {
    return Shelf(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      bookIds: bookIds ?? this.bookIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'createdAt': createdAt.toIso8601String(),
      'bookIds': bookIds,
    };
  }

  factory Shelf.fromMap(Map<String, dynamic> map) {
    return Shelf(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      bookIds: (map['bookIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Shelf.fromJson(String source) =>
      Shelf.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
