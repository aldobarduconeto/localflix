import 'package:flutter/material.dart';

import '../models/item.dart';
import 'artwork.dart';
import 'tv_layout.dart';

Future<void> showMediaDetails(
  BuildContext context,
  MediaItem item,
  ValueChanged<MediaItem> onPlay,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 780),
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: 0.85,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    expand: false,
    builder: (context, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: TvLayout.of(context) ? 4 : 16 / 9,
            child: MediaArtwork(item: item, banner: true),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.displayTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Fechar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MediaFacts(item: item),
        const SizedBox(height: 20),
        FilledButton.icon(
          autofocus: TvLayout.of(context),
          onPressed: () {
            Navigator.pop(context);
            onPlay(item);
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Reproduzir arquivo local'),
        ),
        const SizedBox(height: 24),
        Text(
          item.metadata?.overview.isNotEmpty == true
              ? item.metadata!.overview
              : 'Nenhuma sinopse disponível para este arquivo.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : const Color(0xFF374151),
            height: 1.7,
            fontSize: 15,
          ),
        ),
        if (item.metadata?.cast.isNotEmpty == true) ...[
          const SizedBox(height: 20),
          const Text('Elenco', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            item.metadata!.cast.join(', '),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : const Color(0xFF6B7280),
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Arquivo no dispositivo',
            style: TextStyle(fontSize: 14),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(
                item.isDocument ? item.name : item.id,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white38
                      : const Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        if (item.metadata != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              'Informações online identificadas pelo nome do arquivo. A correspondência pode não ser exata.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38
                    : const Color(0xFF9CA3AF),
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  ),
);

class MediaFacts extends StatelessWidget {
  final MediaItem item;
  const MediaFacts({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    final metadata = item.metadata;
    final facts = <String>[
      metadata?.kind == 'tv'
          ? 'Série'
          : item.type == MediaType.audio
          ? 'Música'
          : 'Vídeo',
      if (metadata?.artist.isNotEmpty == true) metadata!.artist,
      if (metadata?.album.isNotEmpty == true) metadata!.album,
      if ((metadata?.durationSeconds ?? 0) > 0)
        '${metadata!.durationSeconds ~/ 60}:${(metadata.durationSeconds % 60).toString().padLeft(2, '0')}',
      if (metadata?.year.isNotEmpty == true) metadata!.year,
      if ((metadata?.rating ?? 0) > 0)
        '★ ${metadata!.rating.toStringAsFixed(1)}',
      if ((metadata?.runtime ?? 0) > 0) '${metadata!.runtime} min',
      ...?metadata?.genres.take(3),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: facts
          .map(
            (text) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x0E000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0x18FFFFFF) : const Color(0x15000000),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF374151),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
