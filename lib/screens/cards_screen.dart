import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../models/card_record.dart';
import '../models/folder.dart';
import '../widgets/card_art.dart';
import 'card_detail_screen.dart';
import 'card_form_screen.dart';

// One folder's cards, always queried by the folder's integer ID.
class CardsScreen extends StatefulWidget {
  const CardsScreen(
      {super.key, required this.repository, required this.folderId});

  final CatalogueRepository repository;
  final int folderId;

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  Folder? _folder;
  List<CardRecord> _cards = [];
  bool _hasLoaded = false;
  bool _busy = true;
  String? _readError;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<bool> _reload() async {
    try {
      final folder = await widget.repository.getFolder(widget.folderId);
      final cards = await widget.repository.getCards(widget.folderId);
      debugPrint('getCards(folderId: ${widget.folderId}) -> '
          '${cards.map((c) => c.id).toList()}');
      if (!mounted) return false;
      setState(() {
        _folder = folder;
        _cards = cards;
        _hasLoaded = true;
        _readError = null;
      });
      return true;
    } catch (error, stackTrace) {
      debugPrint('Card read failed: $error\n$stackTrace');
      if (!mounted) return false;
      setState(() => _readError =
          'Could not read cards for folder ID ${widget.folderId}. '
          'Press Refresh to retry. Your cards were not deleted.');
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

  Future<void> _refreshWith(String? message, {bool wrote = false}) async {
    setState(() => _busy = true);
    try {
      final ok = await _reload();
      if (!mounted) return;
      setState(() {
        if (message != null) {
          _feedback = (wrote && !ok)
              ? 'Saved, but refresh failed. Press Refresh; do NOT save '
                  'again. $message'
              : message;
        } else if (ok) {
          _feedback = 'Refreshed from the database.';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Add (card == null) or Edit. The form does the write and returns a
  // message; null means Cancel, which wrote nothing.
  Future<void> _openForm({CardRecord? card}) async {
    if (_busy) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CardFormScreen(
          repository: widget.repository,
          card: card,
          initialFolderId: widget.folderId,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _feedback = card == null
          ? 'Add canceled. Nothing was saved.'
          : 'Edit of card ID ${card.id} canceled. Nothing was changed.');
      return;
    }
    await _refreshWith(result, wrote: true);
  }

  Future<void> _onDelete(CardRecord card) async {
    if (_busy) return;
    final id = card.id!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text(
            'Delete card ID $id ("${card.title}")? This cannot be undone.'),
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
          'Delete of card ID $id canceled. Nothing was changed.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    String message;
    try {
      final deleted = await widget.repository.deleteCard(id);
      message = deleted == 1
          ? 'Deleted card ID $id ("${card.title}"). Rows affected: $deleted.'
          : 'Card ID $id was not found (rows affected: $deleted). List reloaded.';
    } catch (error, stackTrace) {
      debugPrint('Card delete failed: $error\n$stackTrace');
      message = 'Error: could not delete card ID $id. Nothing was changed.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _refreshWith(message);
  }

  @override
  Widget build(BuildContext context) {
    final name = _folder?.name ?? 'Folder ${widget.folderId}';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : () => _refreshWith(null),
          ),
        ],
      ),
      floatingActionButton: (_hasLoaded && _folder != null)
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add card'),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Folder ID ${widget.folderId}  ·  cards in this folder: '
                '${_cards.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 4),
                Text(_feedback!),
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
    if (_folder == null) {
      return Center(
          child: Text('Folder ID ${widget.folderId} no longer exists.'));
    }
    if (_cards.isEmpty) {
      return const Center(
        child: Text('This folder has no cards yet.\nTap "Add card" to add one.',
            textAlign: TextAlign.center),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _cards.length,
      itemBuilder: (context, index) {
        final c = _cards[index];
        return Card(
          child: ListTile(
            leading: CardArt(suit: c.suit, imageRef: c.imageRef, size: 34),
            title: Text(c.title),
            subtitle: Text(
              'Card ID ${c.id}  ·  ${c.suit}'
              '${c.notes.isEmpty ? '' : '\n${c.notes}'}',
            ),
            isThreeLine: c.notes.isNotEmpty,
            onTap: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CardDetailScreen(card: c))),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit ${c.title}',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _busy ? null : () => _openForm(card: c),
                ),
                IconButton(
                  tooltip: 'Delete ${c.title}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy ? null : () => _onDelete(c),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
