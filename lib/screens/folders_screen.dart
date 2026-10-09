import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../database_helper.dart';
import '../models/folder.dart';
import 'cards_screen.dart';
import 'diagnostics_screen.dart';
import 'roster_screen.dart';

// Home screen: every folder with its card count.
class FoldersScreen extends StatefulWidget {
  const FoldersScreen(
      {super.key, required this.helper, required this.repository});

  final DatabaseHelper helper;
  final CatalogueRepository repository;

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  List<Folder> _folders = [];
  bool _hasLoaded = false;
  bool _busy = true; // ONE busy flag for every database action here.
  String? _readError;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _initialLoad(); // first read here, never in build()
  }

  Future<bool> _reload() async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return false;
      setState(() {
        _folders = folders;
        _hasLoaded = true;
        _readError = null;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Folder read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() =>
          _readError = 'Could not read folders. Press Refresh to retry.');
      return false;
    }
  }

  Future<void> _initialLoad() async {
    try {
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRefresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      if (await _reload() && mounted) {
        setState(() => _feedback = 'Refreshed from the database.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------ create

  Future<void> _onNewFolder() async {
    if (_busy) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewFolderDialog(),
    );
    if (!mounted) return;
    if (name == null) {
      setState(() => _feedback = 'New folder canceled. Nothing was saved.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    String message;
    bool wrote = false;
    try {
      final id = await widget.repository.insertFolder(name);
      wrote = true;
      message = 'Created folder "$name". New folder ID: $id.';
    } on DuplicateFolderNameException catch (e) {
      message = 'Error: $e Nothing was saved. Choose a different name.';
    } catch (error, stackTrace) {
      debugPrint('Folder insert failed: $error\n$stackTrace');
      message = 'Error: could not create the folder. Nothing was saved.';
    }
    try {
      final refreshed = await _reload();
      if (!mounted) return;
      setState(() => _feedback = (wrote && !refreshed)
          ? 'Saved, but refresh failed. Press Refresh (do not create it again). $message'
          : message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------ delete

  Future<void> _onDeleteFolder(Folder folder) async {
    if (_busy) return;
    final id = folder.id!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
            'Delete folder ID $id ("${folder.name}")? Its ${folder.cardCount} '
            'card(s) will also be deleted (ON DELETE CASCADE). '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _feedback =
          'Delete of folder "${folder.name}" canceled. Nothing was changed.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    String message;
    try {
      final deleted = await widget.repository.deleteFolder(id);
      final leftover =
          await widget.repository.countCardsReferencingFolder(id);
      message = deleted == 1
          ? 'Deleted folder ID $id ("${folder.name}"). Folder rows affected: '
              '$deleted. Cards still referencing folder $id: $leftover.'
          : 'Folder ID $id was not found (rows affected: $deleted). List reloaded.';
    } catch (error, stackTrace) {
      debugPrint('Folder delete failed: $error\n$stackTrace');
      message = 'Error: could not delete folder ID $id. Nothing was changed.';
    }
    try {
      final refreshed = await _reload();
      if (!mounted) return;
      setState(() => _feedback =
          refreshed ? message : 'Refresh failed after delete. $message');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------------- open

  Future<void> _openFolder(Folder folder) async {
    if (_busy) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CardsScreen(
          repository: widget.repository, folderId: folder.id!),
    ));
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _reload(); // counts may have changed inside the folder
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
        actions: [
          IconButton(
            tooltip: 'Part I guest roster',
            icon: const Icon(Icons.people_outline),
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RosterScreen(helper: widget.helper))),
          ),
          IconButton(
            tooltip: 'Database diagnostics',
            icon: const Icon(Icons.storage_outlined),
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DiagnosticsScreen(helper: widget.helper))),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _onRefresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _onNewFolder,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New folder'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Folders in database: ${_folders.length}',
                  style: Theme.of(context).textTheme.titleMedium),
              if (_feedback != null) ...[
                const SizedBox(height: 4),
                Text(_feedback!, key: const Key('folders-feedback')),
              ],
              const SizedBox(height: 8),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_busy && !_hasLoaded && _readError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_readError != null) {
      return Center(child: Text('Error: $_readError'));
    }
    if (_folders.isEmpty) {
      return const Center(
          child: Text('No folders yet. Tap "New folder" to create one.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final f = _folders[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(f.name),
            subtitle: Text('Folder ID ${f.id}  ·  ${f.cardCount} card(s)'),
            onTap: _busy ? null : () => _openFolder(f),
            trailing: IconButton(
              tooltip: 'Delete folder ${f.name}',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : () => _onDeleteFolder(f),
            ),
          ),
        );
      },
    );
  }
}

// Asks for a folder name. Blank/whitespace names are rejected here with
// visible feedback, so nothing reaches the database.
class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog();

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() =>
          _error = 'Enter a folder name. Spaces alone do not count.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Folder name',
          errorText: _error,
          errorMaxLines: 2,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
