# Card Catalogue (In-Class Activity 09, Local Storage Part II)

* Student: Uyiosa Nehikhuere
* Course/section: Mobile Application Development, section ACS05
* Declared pathway: **Undergraduate** (reflection prompts 1 to 3, AI Lab U1 and U4)
* Builds on: my In-Class Activity 08 app (Fall Festival Roster). The Part I `DatabaseHelper`, its `my_table` guest table and the roster screen are kept and still reachable from the people icon on the home screen.

## Setup, run, build, test

* Flutter 3.47.2 (stable), Dart 3.13.2, Windows 11 host
* Targets: Android emulator Pixel 9 Pro XL (API 37, `emulator-5554`) for the upgrade tests; Android emulator Pixel 5 as the disposable device for the release APK smoke test
* Packages (unchanged from Part I): `sqflite ^2.4.1`, `path_provider ^2.1.5`, `path ^1.9.0`. No new dependencies.

```
flutter pub get
flutter analyze 2>&1 | Tee-Object -FilePath .\evidence\analysis_output.txt   # PowerShell
flutter run -d <device-id>
flutter build apk --release        # -> build\app\outputs\flutter-apk\app-release.apk
```

Separate install for the fresh-database test (T1b). Setting the environment variable gives the build a different package id (`edu.gsu.mad.local_storage_lab.fresh`), so the upgraded Part I install is never touched:

```
set ICA09_FRESH=1
flutter build apk --debug
adb install build\app\outputs\flutter-apk\app-debug.apk
```

No automated test suite is required; all tests below were run by hand on the emulator.

## Database and migration

| Item | Value |
| --- | --- |
| File | `MyDatabase.db` in the app documents directory (same name as Part I) |
| Version | Part I = 1, this activity = **2** (raised by exactly one) |
| Part I table | `my_table(_id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL)`, unchanged |
| New tables | `folders(id PK AUTOINCREMENT, name TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL)` and `cards(id PK AUTOINCREMENT, title, suit, notes TEXT NOT NULL DEFAULT '', image_ref TEXT NULL, folder_id INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE)` |
| Index | `idx_cards_folder_id ON cards(folder_id)` |

Where it lives (`lib/database_helper.dart`):

* `onConfigure` runs `PRAGMA foreign_keys = ON` on every open, before create/upgrade.
* `onCreate` (fresh install) calls `createPartOneTables` then `createCatalogueTables`, so both paths end with the same schema.
* `onUpgrade` has the version gate `if (oldVersion < 2) createCatalogueTables(db)`. It never drops, renames or recreates `my_table`. Both callbacks already run inside sqflite's transaction, so there is no nested `db.transaction()`, and errors are not caught: if the upgrade fails, opening fails, the transaction rolls back, and `main()` shows an error screen instead of pretending.
* No seed data. Nothing is inserted from `build()` or on launch, so relaunch cannot duplicate rows.

Before upgrading I recorded the Part I database (version 1, 3 rows: ID 2 River 35, ID 3 Acorn 0, ID 4 Oak 130) and pulled a read-only copy of the device database with `adb exec-out run-as edu.gsu.mad.local_storage_lab cat app_flutter/MyDatabase.db` as a backup (kept outside the repo). I also kept the ICW_08 project folder unchanged as the source backup.

### Delete policy

`ON DELETE CASCADE`: in this app a card belongs to exactly one folder and has no meaning without it, so deleting the folder deletes its cards. The confirmation dialog names the folder ID, name and how many cards will go with it. Alternatives: `RESTRICT` (refuse to delete a non-empty folder), reassigning cards to an "Unfiled" folder, or archiving (soft delete with a `deleted_at` column). Those are better when children have value on their own, for example invoices in a customer folder, where deleting the parent should never silently remove records.

## Code map (rubric to file)

| Rubric item | Where |
| --- | --- |
| Version-gated upgrade and fresh create | `lib/database_helper.dart` (`_onConfigure`, `_onCreate`, `_onUpgrade`, `createCatalogueTables`) |
| Typed models | `lib/models/folder.dart` (`Folder.fromMap/toMap`), `lib/models/card_record.dart` (`CardRecord.fromMap/toMap`, `kSuits`) |
| Repository, parameterized SQL | `lib/data/catalogue_repository.dart`: `insertFolder`, `getFoldersWithCounts` (LEFT JOIN + COUNT), `getFolder`, `deleteFolder`, `countCardsReferencingFolder`, `getCards(folderId)`, `getCard`, `insertCard`, `updateCard`, `deleteCard`. Every value is bound with `whereArgs`/`?`. Duplicate folder names are caught as `DuplicateFolderNameException`; `ConflictAlgorithm.replace` is never used. |
| Folders screen (name + count, create, confirmed delete) | `lib/screens/folders_screen.dart` |
| Cards of one folder by ID, empty state, confirmed delete | `lib/screens/cards_screen.dart` |
| One Add/Edit form, validation, Cancel, busy flag, keeps input on failure | `lib/screens/card_form_screen.dart` |
| Image reference and fallback | `lib/widgets/card_art.dart`, `lib/screens/card_detail_screen.dart`, asset `assets/cards/sample_card.png` |
| Part I screen still available | `lib/screens/roster_screen.dart` (moved from Part I `main.dart`, logic unchanged) |
| Read-only PRAGMA diagnostics (T1 evidence) | `DatabaseHelper.diagnostics()` and `lib/screens/diagnostics_screen.dart` (storage icon on home) |

UI rules followed: no SQL in widgets; edits and deletes target integer IDs; a zero-row update/delete is reported as "not found", not success; the write and the following refresh report separately ("Saved, but refresh failed... do NOT save again"); one `_busy` flag per screen disables buttons during async work; `mounted` is checked after every `await`.

### Image reference choice

`image_ref` is a nullable TEXT column holding a **bundled asset path** (I used `assets/cards/sample_card.png`, registered in `pubspec.yaml`). Trade-off: it works offline and needs no file lifecycle, but it grows the app and a new image needs a new build. `CardArt` also understands `http(s)` URLs (with loading and error builders) but no test depends on the network. When the reference is null, a missing asset, an unreachable URL or malformed text, a suit-symbol placeholder is drawn and the reason is printed on the detail screen. The card row is never deleted or hidden because of its image.

## Test results (T1 to T6)

All data is fictional. Target for T1a and T2 to T6: the existing Part I install `edu.gsu.mad.local_storage_lab` on the Pixel 9 Pro XL emulator, upgraded in place with `adb install -r` (no uninstall, no Clear storage).

| Test | Action and input | Expected | Observed (actual IDs, values, counts) | Result |
| --- | --- | --- | --- | --- |
| T1a Upgrade | Open the existing v1 install with the v2 helper | Same Part I IDs/values; new tables and index | Before (v1, `T1_before.png`): `user_version` 1, tables `my_table` only, rows ID 2 River 35, ID 3 Acorn 0, ID 4 Oak 130 (count 3). After: `path_taken` = onUpgrade from v1 to v2, `user_version` 2, `foreign_keys` 1, objects `folders`, `cards`, `idx_cards_folder_id`, `my_table`; `foreign_key_list(cards)` = folders.id, on_delete CASCADE; `index_list(cards)` = idx_cards_folder_id; Part I rows identical (ID 2 River 35, ID 3 Acorn 0, ID 4 Oak 130). Part I roster screen still shows count 3. | Pass |
| T1b Fresh create | Install v2 as separate package `...local_storage_lab.fresh`, launch, open an empty folder | Both original and catalogue tables; empty folder opens with no schema error | `path_taken` = onCreate (fresh install, v2), `user_version` 2, `foreign_keys` 1, same four schema objects, Part I table present and empty. Created folder "Scratch" (ID 1); opening it shows "This folder has no cards yet." | Pass |
| T2 Parent-child create | Create Moon, Lantern; add Echo, Echo to Moon; Beacon to Lantern (image_ref null) | 3 distinct card IDs; Moon 2, Lantern 1 | Folders: Moon = ID 1, Lantern = ID 2. Cards: ID 1 Echo (Hearts, `assets/cards/sample_card.png`, folder 1), ID 2 Echo (Spades, null, folder 1), ID 3 Beacon (Diamonds, null, folder 2). Counts Moon 2, Lantern 1. Each card listed only under its folder. | Pass |
| T3 Edit identity | Edit card ID 1 to "Echo revised", notes "Revised during T3", Save. Edit card ID 2, type " CANCEL ME", Cancel | Save affects 1 row; only ID 1 changes; Cancel writes nothing | Save: "Updated card ID 1 ("Echo revised"). Rows affected: 1." Card ID 2 still "Echo", Spades, notes empty. Cancel: "Edit of card ID 2 canceled. Nothing was changed." Counts Moon 2, Lantern 1. | Pass |
| T4 Restart | Record state, App info then Force stop (not Clear storage), relaunch | Same folders, IDs, values, counts; no duplicates | Before (`T4_before_diagnostics.png`): PID 4604; folders 1 Moon (2), 2 Lantern (1); cards 1 Echo revised/Hearts/"Revised during T3"/asset/folder 1, 2 Echo/Spades/""/null/folder 1, 3 Beacon/Diamonds/""/null/folder 2; Part I 3 rows. After Force stop: `pidof` empty. After relaunch: new PID 11149, `path_taken` = opened existing v2, identical folders, cards, values, counts and Part I rows. No new rows. | Pass |
| T5 Delete and cascade | Cancel delete of card ID 2, then confirm. Cancel delete of Moon, then confirm | Cancels change nothing; card delete 1; folder delete 1 parent row; Moon's remaining card gone; Lantern/Beacon intact | Card cancel: count stays 2. Card confirm: "Deleted card ID 2 ("Echo"). Rows affected: 1." Moon count 1. Folder cancel: "Delete of folder "Moon" canceled", 2 folders. Folder confirm (dialog: "Delete folder ID 1 ("Moon")? Its 1 card(s) will also be deleted"): "Folder rows affected: 1. Cards still referencing folder 1: 0." Diagnostics: only folder 2 Lantern (count 1), only card ID 3 Beacon, orphan_cards 0, foreign_key_check none, Part I rows unchanged. | Pass |
| T6 Validation and fallback | Open Beacon (null image_ref); Add with title of spaces; New folder with spaces; New folder "Lantern" | Fallback shows; each invalid attempt rejected visibly; rows unchanged | Beacon detail: red diamond placeholder, "No image (image_ref is null)". Spaces title: "Enter a title. Spaces alone do not count." and "Fix the highlighted fields. Nothing was saved." Blank folder: "Enter a folder name. Spaces alone do not count." (dialog stays open, no write). Duplicate: "Error: A folder named "Lantern" already exists. Nothing was saved." Diagnostics after: still 1 folder (ID 2), 1 card (ID 3), Part I 3 rows. | Pass |

Extra (fresh install only, not a required test): card ID 1 "Ghost" with `image_ref = assets/cards/missing.png` shows the clubs placeholder with "Bundled asset not found" while its title, ID and reference stay visible (`evidence/extra_missing_asset_fallback.png`).

### Evidence files (`evidence/`)

* Required: `T1_before.png` (Part I app at v1 before the upgrade), `T2_cards.png` (folders with counts, Moon cards, Lantern cards), `T4_after.png` (after Force stop and relaunch, with diagnostics), `analysis_output.txt`
* Supporting: `T1a_diagnostics_after_upgrade.png`, `T1a_part1_roster_after_upgrade.png`, `T1b_fresh_install_diagnostics.png`, `T1b_fresh_empty_folder.png`, `T2a_folders.png`, `T2b_moon_cards.png`, `T2c_lantern_cards.png`, `T3a_saved_card1.png`, `T3b_cancel_form_before.png`, `T3b_cancel_card2.png`, `T4_before_diagnostics.png`, `T4_after_diagnostics.png`, `T5_delete_cascade.png`, `T6a_beacon_fallback.png`, `T6b_whitespace_title_rejected.png`, `T6c_blank_folder_rejected.png`, `T6d_duplicate_lantern_rejected.png`, `T6e_diagnostics_after_invalid_attempts.png`, `extra_missing_asset_fallback.png`, `release_smoke_test.png`

Cold restart method (T4): Android Settings, App info for Card Catalogue, Force stop, OK; confirmed with `adb shell pidof` (empty), then launched the same installation from the launcher intent. Not hot reload, not uninstall, not Clear storage.

Analyzer: `flutter analyze` reported **No issues found** (`evidence/analysis_output.txt`).

## Release APK smoke test

* Build: `flutter build apk --release` succeeded ("Built build\\app\\outputs\\flutter-apk\\app-release.apk (49.0MB)"), copied and renamed to `Activity09_Nehikhuere_Uyiosa.apk` (SHA-256 `4dfd531ed55dba79db564b8556c4319ad9d8a9e97dc3215c31390e89a905715b`).
* Target: a separate, disposable Android emulator (Pixel 5 AVD, `emulator-5556`) so the upgraded Part I install on the Pixel 9 Pro XL was not touched. Installed the exact renamed file with `adb install Activity09_Nehikhuere_Uyiosa.apk`.

| Check | Observed | Result |
| --- | --- | --- |
| Launch | Opens to "Card Catalogue", no DEBUG banner, "Folders in database: 0" (fresh database via onCreate) | Pass |
| Folder create/read | Created "Smoke": "New folder ID: 1", list shows "Folder ID 1 · 0 card(s)" | Pass |
| Empty state and Cancel | Opened Smoke: "This folder has no cards yet."; leaving the Add form without saving showed "Add canceled. Nothing was saved." | Pass |
| Card create | "Probe" (Hearts, `assets/cards/sample_card.png`) = card ID 1; "Plain" (Clubs, no image) = card ID 2; count 2 | Pass |
| Image and fallback | Probe shows the bundled image in the release build; Plain shows the clubs placeholder | Pass |
| Card edit | Probe to "Probe edited": "Updated card ID 1 ("Probe edited"). Rows affected: 1." | Pass |
| Confirmed delete | Dialog "Delete card ID 2 ("Plain")?", Delete: "Rows affected: 1.", count 1 | Pass |
| Cold restart | `adb shell am force-stop`, `pidof` empty, relaunched: Smoke still has card ID 1 "Probe edited", count 1 | Pass |

Screenshot: `evidence/release_smoke_test.png` (before delete, after delete, after force stop and relaunch).

## Known limitations

* Folder rename and card move between folders by drag are not implemented (not required). A card can be moved by choosing another folder in the Edit form.
* No sync, backup or encryption of the local database. Cascade delete cannot be undone.
* Folder name uniqueness is SQLite's default case-sensitive comparison, so "Moon" and "moon" are allowed as different folders.
* The release APK is signed with the Flutter debug key (template default), which is fine for this course but not for a store release.
* Tests were driven on the emulator with `adb shell input` taps and `adb exec-out screencap` for screenshots instead of manual clicks; the app behaviour is the same.

## Credits and assistance

* Part I `DatabaseHelper` starter code by the instructor (`database_helper.txt`), extended as marked with "ICA 09" comments.
* Schema, lifecycle pattern and repository flow follow the In-Class Activity 09 instructions; references: sqflite package docs, Flutter "Persist data with SQLite" recipe, SQLite foreign key docs.
* `assets/cards/sample_card.png` is an original placeholder image generated for this project.
* AI assistance: Claude (Anthropic) was used to help write and test the code, run the emulator tests and draft documentation. Every result in this README was read back from the running app or the device database.
