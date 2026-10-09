// Typed model for one row of the `folders` table (the parent).
class Folder {
  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });

  /// null until SQLite assigns it on insert.
  final int? id;
  final String name;

  /// ISO-8601 text, as stored in `created_at`.
  final String createdAt;

  /// Not a column. Filled by the LEFT JOIN in getFoldersWithCounts().
  final int cardCount;

  factory Folder.fromMap(Map<String, Object?> map) {
    return Folder(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: map['created_at'] as String,
      cardCount: (map['card_count'] as int?) ?? 0,
    );
  }

  /// Only real columns. `id` is left out when null so SQLite assigns it.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }
}
