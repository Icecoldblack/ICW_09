import 'package:flutter/material.dart';

import '../models/card_record.dart';
import '../widgets/card_art.dart';

// Read-only view of one card, with a large image or suit fallback.
class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({super.key, required this.card});

  final CardRecord card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(card.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CardArt(
              suit: card.suit,
              imageRef: card.imageRef,
              size: 140,
              showReason: true,
            ),
          ),
          const SizedBox(height: 24),
          Text(card.title, style: text.headlineSmall),
          const SizedBox(height: 8),
          Text('Card ID: ${card.id}'),
          Text('Suit: ${card.suit}'),
          Text('Folder ID: ${card.folderId}'),
          Text('Notes: ${card.notes.isEmpty ? '(none)' : card.notes}'),
          Text('image_ref: ${card.imageRef ?? 'NULL'}'),
        ],
      ),
    );
  }
}
