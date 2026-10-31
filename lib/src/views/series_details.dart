import 'package:flutter/material.dart';

import '../models/item.dart';
import '../models/series.dart';
import '../services/tmdb.dart';

bool sameSeries(MediaItem a, MediaItem b) {
  if (a.metadata?.kind == 'tv' && b.metadata?.kind == 'tv') {
    return a.metadata!.id == b.metadata!.id;
  }
  return a.queryName.cacheKey == b.queryName.cacheKey;
}

(int, int)? episodeNumbers(MediaItem item) {
  final label = item.queryName.episode;
  if (label == null) return null;
  final numbers = RegExp(r'\d+').allMatches(label).toList();
  if (numbers.length != 2) return null;
  return (int.parse(numbers[0].group(0)!), int.parse(numbers[1].group(0)!));
}

Future<void> showSeriesDetails(
  BuildContext context,
  MediaItem item,
  List<MediaItem> library,
  TmdbService? tmdb,
  ValueChanged<MediaItem> onPlay,
) => showDialog<void>(
  context: context,
  builder: (_) => _SeriesDialog(
    item: item,
    local: library
        .where((e) => e.type == MediaType.video && sameSeries(item, e))
        .toList(),
    tmdb: tmdb,
    onPlay: onPlay,
  ),
);

class _SeriesDialog extends StatefulWidget {
  final MediaItem item;
  final List<MediaItem> local;
  final TmdbService? tmdb;
  final ValueChanged<MediaItem> onPlay;
  const _SeriesDialog({
    required this.item,
    required this.local,
    required this.tmdb,
    required this.onPlay,
  });
  @override
  State<_SeriesDialog> createState() => _SeriesDialogState();
}

class _SeriesDialogState extends State<_SeriesDialog> {
  late Future<SeriesInfo> info;
  Future<List<SeriesEpisode>>? episodes;
  int? seriesId;
  int? season;
  final Map<(int, int), MediaItem> localEpisodes = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.local) {
      final numbers = episodeNumbers(item);
      if (numbers != null) localEpisodes.putIfAbsent(numbers, () => item);
    }
    info = load();
  }

  Future<SeriesInfo> load() async {
    final service = widget.tmdb;
    if (service == null)
      throw const TmdbException(
        'Conecte o TMDB nas configurações para ver as temporadas e os nomes dos episódios.',
      );
    final metadata = widget.item.metadata?.kind == 'tv'
        ? widget.item.metadata
        : await service.lookup(widget.item.queryName);
    if (metadata?.kind != 'tv')
      throw const TmdbException(
        'Série não encontrada no TMDB. Os arquivos locais continuam disponíveis abaixo.',
      );
    seriesId = metadata!.id;
    final result = await service.seriesDetails(seriesId!);
    if (!mounted) return result;
    final preferred = episodeNumbers(widget.item)?.$1;
    season =
        result.seasons
            .where((s) => s.number == preferred)
            .firstOrNull
            ?.number ??
        result.seasons.where((s) => s.number > 0).firstOrNull?.number ??
        result.seasons.firstOrNull?.number;
    if (season != null) episodes = service.seasonEpisodes(seriesId!, season!);
    return result;
  }

  void play(MediaItem item) {
    Navigator.pop(context);
    widget.onPlay(item);
  }

  Widget failure(Object? error, VoidCallback retry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(error.toString(), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFFE50914))),
        TextButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );

  Widget localFiles() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(
        'Na sua biblioteca · ${widget.local.length} arquivos',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      for (final item in widget.local)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.name),
          trailing: const Icon(Icons.play_arrow_rounded),
          onTap: () => play(item),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 760,
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEMPORADAS E EPISÓDIOS',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.item.metadata?.title ??
                            widget.item.queryName.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<SeriesInfo>(
              future: info,
              builder: (context, snapshot) => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (snapshot.connectionState != ConnectionState.done)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError) ...[
                    failure(
                      snapshot.error,
                      () => setState(() => info = load()),
                    ),
                    localFiles(),
                  ] else if (snapshot.hasData) ...[
                    Text(
                      '${snapshot.data!.seasons.where((s) => s.number > 0).length} temporadas · ${snapshot.data!.episodeCount} episódios',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white60
                            : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (snapshot.data!.seasons.isEmpty) ...[
                      const Text('Nenhuma temporada disponível no TMDB.'),
                      localFiles(),
                    ] else ...[
                      DropdownButtonFormField<int>(
                        key: ValueKey(season),
                        initialValue: season,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Temporada',
                        ),
                        items: [
                          for (final s in snapshot.data!.seasons)
                            DropdownMenuItem(
                              value: s.number,
                              child: Text(
                                '${s.name} · ${s.episodeCount} episódios',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            season = value;
                            episodes = widget.tmdb!.seasonEpisodes(
                              seriesId!,
                              value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<SeriesEpisode>>(
                        future: episodes,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          if (snapshot.hasError)
                            return Column(
                              children: [
                                failure(
                                  snapshot.error,
                                  () => setState(
                                    () => episodes = widget.tmdb!
                                        .seasonEpisodes(seriesId!, season!),
                                  ),
                                ),
                                localFiles(),
                              ],
                            );
                          final rows = snapshot.data ?? [];
                          if (rows.isEmpty)
                            return const Text(
                              'Nenhum episódio disponível nesta temporada.',
                            );
                          return Column(
                            children: [
                              for (final episode in rows) episodeTile(episode),
                            ],
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Arquivos locais (${widget.local.length})'),
                      children: [localFiles()],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget episodeTile(SeriesEpisode episode) {
    final local = localEpisodes[(season, episode.number)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            '${episode.number.toString().padLeft(2, '0')} · ${episode.name}',
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              [
                if (episode.runtime > 0) '${episode.runtime} min',
                local == null
                    ? 'Não está na biblioteca'
                    : 'Disponível no dispositivo',
                if (episode.overview.isNotEmpty) episode.overview,
              ].join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: Icon(
            local == null
                ? Icons.cloud_outlined
                : Icons.play_circle_outline_rounded,
            color: local == null ? (Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFF9CA3AF)) : (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF11141A)),
          ),
          onTap: local == null ? null : () => play(local),
        ),
      ),
    );
  }
}
