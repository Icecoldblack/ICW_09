// Typed model for one row of the `cards` table (the child).
// Named CardRecord so it does not collide with Flutter's Card widget.

/// The only suit values the app accepts.
const List<String> kSuits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

/// Symbol used by the image fallback for each suit.
const Map<String, String> kSuitSymbols = {
  'Hearts': '♥',
  'Diamonds': '♦',
  'Clubs': '♣',
  'Spades': '♠',
};

class CardRecord {
  const CardRecord({
    this.id,
    required this.title,
    required this.suit,
    this.notes = '',
    this.imageRef,
    required this.folderId,
  });

  /// null until SQLite assigns it on insert.
  final int? id;
  final String title;
  final String suit;

  /// Stored as '' when omitted (column is NOT NULL DEFAULT '').
  final String notes;

  /// Nullable reference to where an image lives (asset path or URL).
  /// It is never the image bytes themselves.
  final String? imageRef;

  /// Foreign key to folders.id.
  final int folderId;

  factory CardRecord.fromMap(Map<String, Object?> map) {
    return CardRecord(
      id: map['id'] as int,
      title: map['title'] as String,
      suit: map['suit'] as String,
      notes: (map['notes'] as String?) ?? '',
      imageRef: map['image_ref'] as String?,
      folderId: map['folder_id'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'suit': suit,
      'notes': notes,
      'image_ref': imageRef,
      'folder_id': folderId,
    };
  }

  CardRecord copyWith({int? id}) => CardRecord(
        id: id ?? this.id,
        title: title,
        suit: suit,
        notes: notes,
        imageRef: imageRef,
        folderId: folderId,
      );
}
