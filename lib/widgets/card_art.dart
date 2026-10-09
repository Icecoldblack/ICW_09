// Shows a card's image from its image_ref, or a stable suit-symbol
// placeholder when the reference is missing, malformed, or unavailable.
// The card's title/suit/ID always stay visible; a broken image never
// deletes or hides the record.
import 'package:flutter/material.dart';

import '../models/card_record.dart';

/// Why the placeholder is showing (also used as a visible label).
enum ArtStatus { none, assetMissing, urlUnavailable, malformed }

String artStatusLabel(ArtStatus status) {
  switch (status) {
    case ArtStatus.none:
      return 'No image (image_ref is null)';
    case ArtStatus.assetMissing:
      return 'Bundled asset not found';
    case ArtStatus.urlUnavailable:
      return 'Image URL unavailable';
    case ArtStatus.malformed:
      return 'Unsupported image reference';
  }
}

class CardArt extends StatelessWidget {
  const CardArt({
    super.key,
    required this.suit,
    required this.imageRef,
    this.size = 56,
    this.showReason = false,
  });

  final String suit;
  final String? imageRef;
  final double size;

  /// When true, the placeholder also prints why it is showing.
  final bool showReason;

  @override
  Widget build(BuildContext context) {
    final ref = imageRef?.trim();
    if (ref == null || ref.isEmpty) {
      return _placeholder(ArtStatus.none);
    }
    if (ref.startsWith('assets/')) {
      return _frame(Image.asset(
        ref,
        width: size,
        height: size * 1.4,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('Asset image failed for "$ref": $error');
          return _placeholder(ArtStatus.assetMissing);
        },
      ));
    }
    final uri = Uri.tryParse(ref);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return _frame(Image.network(
        ref,
        width: size,
        height: size * 1.4,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size * 1.4,
            child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (_, error, __) {
          debugPrint('Network image failed for "$ref": $error');
          return _placeholder(ArtStatus.urlUnavailable);
        },
      ));
    }
    return _placeholder(ArtStatus.malformed);
  }

  Widget _frame(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: child,
      );

  Widget _placeholder(ArtStatus status) {
    final red = suit == 'Hearts' || suit == 'Diamonds';
    final symbol = kSuitSymbols[suit] ?? '?';
    final box = Container(
      key: ValueKey('fallback-${status.name}'),
      width: size,
      height: size * 1.4,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black26),
      ),
      alignment: Alignment.center,
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: size * 0.6,
          color: red ? Colors.red.shade700 : Colors.black87,
        ),
      ),
    );
    if (!showReason) {
      return Semantics(label: artStatusLabel(status), child: box);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        const SizedBox(height: 6),
        Text(artStatusLabel(status),
            style: const TextStyle(fontStyle: FontStyle.italic)),
      ],
    );
  }
}
