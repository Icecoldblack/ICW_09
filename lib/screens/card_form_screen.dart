import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../models/card_record.dart';
import '../models/folder.dart';

// ONE form reused for Add (card == null) and Edit (card != null).
// On a successful write it pops with a message. Cancel pops with null and
// writes nothing. A failed write keeps the typed input on screen.
class CardFormScreen extends StatefulWidget {
  const CardFormScreen({
    super.key,
    required this.repository,
    required this.initialFolderId,
    this.card,
  });

  final CatalogueRepository repository;
  final int initialFolderId;
  final CardRecord? card;

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _imageRef;
  String? _suit;
  int? _folderId;

  List<Folder> _folders = [];
  bool _foldersLoaded = false;
  bool _busy = true;
  String? _error;

  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _title = TextEditingController(text: c?.title ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _imageRef = TextEditingController(text: c?.imageRef ?? '');
    _suit = c?.suit;
    _folderId = c?.folderId ?? widget.initialFolderId;
    _loadFolders();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _imageRef.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _foldersLoaded = true;
        if (!folders.any((f) => f.id == _folderId)) _folderId = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Folder list read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = 'Could not load folders. Go back and retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateTitle(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Enter a title. Spaces alone do not count.';
    }
    return null;
  }

  Future<void> _onSave() async {
    if (_busy) return;
    setState(() => _error = null);
    // Invalid input stops here: nothing is written.
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Fix the highlighted fields. Nothing was saved.');
      return;
    }
    final folderId = _folderId!;
    final ref = _imageRef.text.trim();
    final record = CardRecord(
      id: widget.card?.id,
      title: _title.text.trim(),
      suit: _suit!,
      notes: _notes.text.trim(), // '' when omitted
      imageRef: ref.isEmpty ? null : ref, // SQL NULL when omitted
      folderId: folderId,
    );

    setState(() => _busy = true);
    try {
      if (!_editing) {
        final id = await widget.repository.insertCard(record);
        if (!mounted) return;
        Navigator.of(context).pop(
            'Added card "${record.title}" to folder ID $folderId. New card ID: $id.');
        return;
      }
      final affected = await widget.repository.updateCard(record);
      if (!mounted) return;
      if (affected == 1) {
        Navigator.of(context).pop(
            'Updated card ID ${record.id} ("${record.title}"). Rows affected: $affected.');
        return;
      }
      // Zero rows is NOT success: the card no longer exists.
      setState(() => _error =
          'Card ID ${record.id} was not found (rows affected: $affected). '
          'Nothing was updated. Your input is still here.');
    } catch (error, stackTrace) {
      debugPrint('Card write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() =>
          _error = 'Error: could not save. Your input was kept. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit card ID ${widget.card!.id}' : 'Add card'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                enabled: !_busy,
                decoration: const InputDecoration(
                    labelText: 'Title *', border: OutlineInputBorder()),
                validator: _validateTitle,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _suit,
                decoration: const InputDecoration(
                    labelText: 'Suit *', border: OutlineInputBorder()),
                items: [
                  for (final s in kSuits)
                    DropdownMenuItem(
                        value: s, child: Text('${kSuitSymbols[s]}  $s')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _suit = v),
                validator: (v) =>
                    (v == null || !kSuits.contains(v)) ? 'Choose a suit.' : null,
              ),
              const SizedBox(height: 12),
              if (!_foldersLoaded && _error == null)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<int>(
                  initialValue: _folderId,
                  decoration: const InputDecoration(
                      labelText: 'Folder *', border: OutlineInputBorder()),
                  items: [
                    for (final f in _folders)
                      DropdownMenuItem(
                          value: f.id,
                          child: Text('${f.name} (ID ${f.id})')),
                  ],
                  onChanged:
                      _busy ? null : (v) => setState(() => _folderId = v),
                  validator: (v) => (v == null ||
                          !_folders.any((f) => f.id == v))
                      ? 'Choose an existing folder.'
                      : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                enabled: !_busy,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageRef,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Image reference (optional)',
                  helperText:
                      'Bundled asset, e.g. assets/cards/sample_card.png. '
                      'Leave blank for the suit placeholder.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _onSave,
                    child: Text(_editing ? 'Save' : 'Add'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    // Cancel never writes.
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  if (_busy) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
