import 'package:flutter/material.dart';

import 'data/catalogue_repository.dart';
import 'database_helper.dart';
import 'screens/folders_screen.dart';

// Entry point. The database (now version 2) must be open BEFORE the first
// screen asks for rows, so we await init() here. If opening or the
// migration fails, we show an honest error screen; we never swallow a
// migration error and pretend the upgrade worked.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not open local storage (the schema upgrade may have '
              'failed). Nothing was deleted. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    ));
    return;
  }
  runApp(CatalogueApp(helper: helper));
}

// Root widget. One helper and one repository are created once and passed down.
class CatalogueApp extends StatelessWidget {
  CatalogueApp({super.key, required this.helper})
      : repository = CatalogueRepository(helper);

  final DatabaseHelper helper;
  final CatalogueRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Catalogue',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: FoldersScreen(helper: helper, repository: repository),
    );
  }
}
