// Based on the STARTER CODE supplied by the instructor (database_helper.txt)
// and my In-Class Activity 08 version. Part I code is kept as it was.
// ICA 09 changes are marked with "ICA 09" comments:
//   * schema version 1 -> 2 (same database file name, MyDatabase.db)
//   * onConfigure turns foreign keys on for every connection
//   * onCreate builds the full schema (Part I table + catalogue tables)
//   * onUpgrade adds only the catalogue tables for databases coming from v1
//   * read-only diagnostics used as T1 evidence
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  // Same file name as Part I. Renaming it would orphan the Part I data.
  static const _databaseName = "MyDatabase.db";
  // ICA 09: raised by exactly one (Part I shipped version 1).
  static const _databaseVersion = 2;

  // Part I guest table (unchanged).
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  // ICA 09: catalogue tables.
  static const foldersTable = 'folders';
  static const cardsTable = 'cards';

  late Database _db;

  // ICA 09: the repository needs the same open connection.
  Database get database => _db;

  // ICA 09: remembered so the diagnostics screen can show which path ran.
  int? upgradedFromVersion;
  bool createdFresh = false;

  // This opens the database (and creates it if it doesn't exist).
  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      // ICA 09: runs before onCreate/onUpgrade on every open. Without it,
      // ON DELETE CASCADE is silently ignored by SQLite.
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Fresh install: build the COMPLETE version 2 schema.
  // sqflite already wraps onCreate in a transaction, so no nested
  // db.transaction() here. Errors propagate so opening fails visibly.
  Future _onCreate(Database db, int version) async {
    createdFresh = true;
    await createPartOneTables(db);
    await createCatalogueTables(db);
  }

  // ICA 09: existing install. Only add what the old version lacks.
  // The Part I table and its rows are never dropped or recreated.
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    upgradedFromVersion = oldVersion;
    if (oldVersion < 2) {
      await createCatalogueTables(db);
    }
    // A future version 3 adds its own `if (oldVersion < 3)` block here.
  }

  // Part I statement, unchanged from the starter code.
  static Future<void> createPartOneTables(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');
  }

  // ICA 09: one execute per statement.
  static Future<void> createCatalogueTables(Database db) async {
    await db.execute('''
      CREATE TABLE $foldersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $cardsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES $foldersTable(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_cards_folder_id ON $cardsTable(folder_id)');
  }

  // ------------------------------------------------ Part I (starter code)

  // Inserts a row. Each key in the map is a column name. The return value
  // is the id of the inserted row.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

  // All of the rows are returned as a list of maps.
  // STUDENT CHANGE (ICA 08): added orderBy so the list is always in ID order.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(table, orderBy: '$columnId ASC');
  }

  // Uses a raw query to give the row count.
  Future<int> queryRowCount() async {
    final results = await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(results) ?? 0;
  }

  // The id column in the map must be set. The other column values are used
  // to update the row. Returns the number of affected rows.
  Future<int> update(Map<String, dynamic> row) async {
    int id = row[columnId];
    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Deletes the row specified by the id. The number of affected rows is
  // returned. This should be 1 as long as the row exists.
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // ------------------------------------------- ICA 09: read-only diagnostics

  // Every statement here only reads. Used for T1 evidence.
  Future<Map<String, Object?>> diagnostics() async {
    Future<List<Map<String, Object?>>> q(String sql) => _db.rawQuery(sql);
    final userVersion = Sqflite.firstIntValue(await q('PRAGMA user_version'));
    final foreignKeys = Sqflite.firstIntValue(await q('PRAGMA foreign_keys'));
    final tables = await q(
        "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' "
        "AND name NOT LIKE 'android_%' ORDER BY type, name");
    final fkList = await q('PRAGMA foreign_key_list(cards)');
    final indexList = await q('PRAGMA index_list(cards)');
    final fkCheck = await q('PRAGMA foreign_key_check');
    final orphans = Sqflite.firstIntValue(await q(
        'SELECT COUNT(*) FROM cards WHERE folder_id NOT IN (SELECT id FROM folders)'));
    final guests = await queryAllRows();
    final folders = await q(
        'SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count '
        'FROM folders f LEFT JOIN cards c ON c.folder_id = f.id '
        'GROUP BY f.id ORDER BY f.id');
    final cards = await q(
        'SELECT id, title, suit, notes, image_ref, folder_id FROM cards ORDER BY id');
    return {
      'path_taken': createdFresh
          ? 'onCreate (fresh install, v$_databaseVersion)'
          : upgradedFromVersion != null
              ? 'onUpgrade from v$upgradedFromVersion to v$_databaseVersion'
              : 'opened existing v$_databaseVersion (no create/upgrade this launch)',
      'user_version': userVersion,
      'foreign_keys': foreignKeys,
      'schema_objects': tables,
      'foreign_key_list(cards)': fkList,
      'index_list(cards)': indexList,
      'foreign_key_check': fkCheck,
      'orphan_cards': orphans,
      'part1_guest_rows': guests,
      'folders_with_counts': folders,
      'cards': cards,
    };
  }
}
