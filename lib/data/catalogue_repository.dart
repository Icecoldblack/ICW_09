// The ONLY place that talks SQL for folders and cards.
// Widgets call these methods and get typed objects back.
// Every value is bound with whereArgs / insert maps, never concatenated.
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/card_record.dart';
import '../models/folder.dart';

/// Thrown when a folder name already exists (UNIQUE constraint).
class DuplicateFolderNameException implements Exception {
  DuplicateFolderNameException(this.name);
  final String name;
  @override
  String toString() => 'A folder named "$name" already exists.';
}

class CatalogueRepository {
  CatalogueRepository(this._helper);

  final DatabaseHelper _helper;
  Database get _db => _helper.database;

  // ------------------------------------------------------------- folders

  /// Inserts a folder and returns the id SQLite assigned.
  /// Uses the default ConflictAlgorithm (abort). Never `replace`, because
  /// replacing a parent row would cascade-delete its cards.
  Future<int> insertFolder(String name) async {
    final folder = Folder(
      name: name,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    try {
      return await _db.insert(DatabaseHelper.foldersTable, folder.toMap());
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw DuplicateFolderNameException(name);
      }
      rethrow;
    }
  }

  /// LEFT JOIN keeps empty folders, with a count of 0.
  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id
      ORDER BY f.name COLLATE NOCASE ASC, f.id ASC
    ''');
    return rows.map(Folder.fromMap).toList();
  }

  Future<Folder?> getFolder(int id) async {
    final rows = await _db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f
      LEFT JOIN cards c ON c.folder_id = f.id
      WHERE f.id = ?
      GROUP BY f.id
    ''', [id]);
    return rows.isEmpty ? null : Folder.fromMap(rows.first);
  }

  /// Returns the number of folder rows deleted (1, or 0 if it was gone).
  /// Its cards are removed by ON DELETE CASCADE.
  Future<int> deleteFolder(int id) async {
    return await _db.delete(
      DatabaseHelper.foldersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Read-only check used after a cascade: cards still pointing at [folderId].
  Future<int> countCardsReferencingFolder(int folderId) async {
    final rows = await _db.rawQuery(
        'SELECT COUNT(*) FROM cards WHERE folder_id = ?', [folderId]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // --------------------------------------------------------------- cards

  /// Only the cards of one folder, queried by its id.
  Future<List<CardRecord>> getCards(int folderId) async {
    final rows = await _db.query(
      DatabaseHelper.cardsTable,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC, id ASC',
    );
    return rows.map(CardRecord.fromMap).toList();
  }

  Future<CardRecord?> getCard(int id) async {
    final rows = await _db.query(
      DatabaseHelper.cardsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : CardRecord.fromMap(rows.first);
  }

  /// Returns the new card id. A bad folder_id fails on the foreign key.
  Future<int> insertCard(CardRecord card) async {
    return await _db.insert(DatabaseHelper.cardsTable, card.toMap());
  }

  /// Targets the card by id. Returns rows affected (0 means not found).
  Future<int> updateCard(CardRecord card) async {
    final id = card.id;
    if (id == null) {
      throw ArgumentError('updateCard needs a card with an id');
    }
    final values = card.toMap()..remove('id');
    return await _db.update(
      DatabaseHelper.cardsTable,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns rows affected (1, or 0 if it was already gone).
  Future<int> deleteCard(int id) async {
    return await _db.delete(
      DatabaseHelper.cardsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
