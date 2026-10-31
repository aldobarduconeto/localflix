import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models/item.dart';
import '../services/tmdb.dart';
import 'series_details.dart';
import 'artwork.dart';
import 'details.dart';
import 'tv_layout.dart';

class HomePage extends StatefulWidget {
  final List<MediaItem> library;
  final TmdbService? tmdb;
  final bool scanning;
  final String? errorMessage;
  final String? metadataStatus;
  final VoidCallback onOpenSettings;
  final ValueChanged<MediaItem> onPlay;
  const HomePage({
    super.key,
    required this.library,
    this.tmdb,
    required this.scanning,
    required this.errorMessage,
    this.metadataStatus,
    required this.onOpenSettings,
    required this.onPlay,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int filter = 0;
  String query = '';
  Timer? debounce;
  final search = TextEditingController();
  List<MediaItem> videos = [];
  List<MediaItem> music = [];
  List<MediaItem> series = [];

  bool isSeries(MediaItem item) =>
      item.metadata?.kind == 'tv' || item.queryName.isSeries;

  void openDetails(MediaItem item) {
    if (isSeries(item)) {
      showSeriesDetails(
        context,
        item,
        widget.library,
        widget.tmdb,
        widget.onPlay,
      );
    } else {
      showMediaDetails(context, item, widget.onPlay);
    }
  }

  void selectItem(MediaItem item) {
    if (isSeries(item)) {
      openDetails(item);
    } else {
      widget.onPlay(item);
    }
  }

  @override
  void initState() {
    super.initState();
    updateResults();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.library != widget.library) updateResults();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void updateResults() {
    final normalized = query.trim().toLowerCase();
    videos = [];
    music = [];
    series = [];
    final seriesKeys = <String>{};
    for (final item in widget.library) {
      if (!item.searchText.contains(normalized)) continue;
      if (item.type == MediaType.video && filter != 2) {
        if (isSeries(item)) {
          final key = item.metadata?.kind == 'tv'
              ? 'tmdb:${item.metadata!.id}'
              : item.queryName.cacheKey;
          if (seriesKeys.add(key)) series.add(item);
        } else {
          videos.add(item);
        }
      }
      if (item.type == MediaType.audio && filter != 1) music.add(item);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, size) {
        final tv = TvLayout.of(context);
        final wide = tv || size.maxWidth >= 760;
        final inset = size.maxWidth >= 1200
            ? 48.0
            : wide
            ? 32.0
            : 18.0;
        final candidates = [...videos, ...series, ...music];
        final featured =
            candidates
                .where(
                  (item) =>
                      item.bannerPath != null ||
                      item.metadata?.backdrop != null,
                )
                .firstOrNull ??
            candidates.firstOrNull;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final filters = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in [
              'Explorar',
              'Filmes e séries',
              'Músicas',
            ].asMap().entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: filter == entry.key,
                showCheckmark: false,
                selectedColor: isDark ? Colors.white : const Color(0xFFE50914),
                backgroundColor: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                labelStyle: TextStyle(
                  color: filter == entry.key
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : const Color(0xFF374151)),
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: filter == entry.key
                      ? (isDark ? Colors.white : const Color(0xFFE50914))
                      : (isDark ? const Color(0x24FFFFFF) : const Color(0x18000000)),
                ),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() {
                  filter = entry.key;
                  updateResults();
                }),
              ),
          ],
        );
        final searchField = TextField(
          controller: search,
          onChanged: (value) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 180), () {
              if (mounted)
                setState(() {
                  query = value;
                  updateResults();
                });
            });
          },
          decoration: InputDecoration(
            hintText: 'Encontre seu próximo play',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: search,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Limpar busca',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white54,
                        elevation: 0,
                        side: BorderSide.none,
                      ),
                      iconSize: 18,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        debounce?.cancel();
                        search.clear();
                        setState(() {
                          query = '';
                          updateResults();
                        });
                      },
                    ),
            ),
          ),
        );
        return CustomScrollView(
          key: const PageStorageKey('library_scroll'),
          scrollCacheExtent: ScrollCacheExtent.pixels(tv ? 900 : 250),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 24, inset, 24),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LOCALFLIX',
                            style: TextStyle(
                              color: Color(0xFFE50914),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'CINEMA, SÉRIES E MÚSICA. DO SEU JEITO.',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: widget.onOpenSettings,
                      tooltip: 'Gerenciar biblioteca',
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, 20),
              sliver: SliverToBoxAdapter(
                child:
                    size.maxWidth >= 1050 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 18
                    ? Row(
                        children: [
                          Expanded(child: filters),
                          const SizedBox(width: 24),
                          SizedBox(width: 340, child: searchField),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          filters,
                          const SizedBox(height: 14),
                          searchField,
                        ],
                      ),
              ),
            ),
            if (widget.scanning)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (widget.metadataStatus != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    widget.metadataStatus!,
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (widget.errorMessage != null)
              SliverPadding(
                padding: EdgeInsets.all(inset),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    widget.errorMessage!,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                ),
              ),
            if (query.isEmpty && featured != null)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                sliver: SliverToBoxAdapter(
                  child: _Featured(
                    item: featured,
                    wide: wide,
                    onPlay: selectItem,
                    onDetails: openDetails,
                    onSettings: widget.onOpenSettings,
                  ),
                ),
              ),
            if (videos.isNotEmpty)
              ...section(
                'Filmes e vídeos',
                'Histórias para a sua próxima sessão',
                videos,
                inset,
                false,
                size.maxWidth,
              ),
            if (series.isNotEmpty)
              ...section(
                'Séries',
                'Temporadas e episódios em um só lugar',
                series,
                inset,
                false,
                size.maxWidth,
              ),
            if (music.isNotEmpty)
              ...section(
                'Músicas',
                'A trilha sonora do seu dia',
                music,
                inset,
                true,
                size.maxWidth,
              ),
            if (videos.isEmpty &&
                series.isEmpty &&
                music.isEmpty &&
                !widget.scanning)
              SliverPadding(
                padding: EdgeInsets.all(inset),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Icon(
                            query.isEmpty
                                ? Icons.video_library_outlined
                                : Icons.search_off,
                            size: 40,
                            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            query.isEmpty
                                ? 'Seu próximo play começa aqui.'
                                : 'Nenhum resultado para “$query”.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF11141A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Escolha suas pastas ou experimente outro filtro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                          ),
                          if (widget.library.isEmpty)
                            TextButton(
                              autofocus: TvLayout.of(context),
                              onPressed: widget.onOpenSettings,
                              child: const Text('Adicionar minha biblioteca →'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.all(inset),
              sliver: const SliverToBoxAdapter(
                child: Text(
                  'LOCALFLIX  /  A MELHOR HISTÓRIA É A SUA',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  List<Widget> section(
    String title,
    String subtitle,
    List<MediaItem> items,
    double inset,
    bool audio,
    double width,
  ) {
    final tv = TvLayout.of(context);
    final columns = ((width - inset * 2 + 16) / (audio ? 190 : 180))
        .floor()
        .clamp(2, audio ? 7 : 8);
    final cardWidth = tv
        ? ((width - inset * 2) / 4.2).clamp(160.0, 240.0)
        : (width - inset * 2 - (columns - 1) * 14) / columns;
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight =
        scaler.scale(tv ? 18 : 14) * 3.2 + scaler.scale(tv ? 14 : 11) * 2 + 44;
    return [
      SliverPadding(
        key: ValueKey('shelf-$title'),
        padding: EdgeInsets.fromLTRB(inset, 28, inset, 0),
        sliver: SliverToBoxAdapter(
          child: _LibraryShelf(
            title: title,
            subtitle: subtitle,
            height: cardWidth * (audio ? 1 : 1.45) + titleHeight,
            itemCount: items.length,
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: _MediaCard(
                key: ValueKey(items[index].id),
                item: items[index],
                audio: audio,
                onPlay: selectItem,
                onDetails: openDetails,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _LibraryShelf extends StatefulWidget {
  final String title;
  final String subtitle;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const _LibraryShelf({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_LibraryShelf> createState() => _LibraryShelfState();
}

class _LibraryShelfState extends State<_LibraryShelf> {
  final controller = ScrollController();
  bool canGoBack = false;
  bool canGoForward = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(updateControls);
  }

  void updateControls() {
    if (!mounted || !controller.hasClients) return;
    final position = controller.position;
    final back = position.pixels > position.minScrollExtent + 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != canGoBack || forward != canGoForward) {
      setState(() {
        canGoBack = back;
        canGoForward = forward;
      });
    }
  }

  void move(int direction) {
    if (!controller.hasClients) return;
    final position = controller.position;
    controller.animateTo(
      (position.pixels + direction * position.viewportDimension * 0.8).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.title} · ${widget.itemCount}',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white38
                        : const Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Voltar em ${widget.title}',
            onPressed: canGoBack ? () => move(-1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Avançar em ${widget.title}',
            onPressed: canGoForward ? () => move(1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      const SizedBox(height: 12),
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          WidgetsBinding.instance.addPostFrameCallback((_) => updateControls());
          return false;
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: {
              ...ScrollConfiguration.of(context).dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: Scrollbar(
            controller: controller,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SizedBox(
              height: widget.height + 16,
              child: ListView.separated(
                controller: controller,
                primary: false,
                padding: const EdgeInsets.only(top: 6, bottom: 16),
                key: PageStorageKey('library-shelf-${widget.title}'),
                scrollDirection: Axis.horizontal,
                scrollCacheExtent: const ScrollCacheExtent.pixels(600),
                itemCount: widget.itemCount,
                separatorBuilder: (_, index) => const SizedBox(width: 18),
                itemBuilder: widget.itemBuilder,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Featured extends StatelessWidget {
  final MediaItem? item;
  final bool wide;
  final ValueChanged<MediaItem> onPlay;
  final ValueChanged<MediaItem> onDetails;
  final VoidCallback onSettings;
  const _Featured({
    required this.item,
    required this.wide,
    required this.onPlay,
    required this.onDetails,
    required this.onSettings,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      children: [
        Positioned.fill(child: MediaArtwork(item: item, banner: true)),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xF5101014), Color(0x15101014)],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xFF101014)],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(wide ? 40 : 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: wide ? 260 : 280,
              maxWidth: 720,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EM DESTAQUE',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 2,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  (item?.metadata?.kind == 'tv'
                          ? item?.metadata?.title
                          : item?.displayTitle) ??
                      'O seu cinema.\nNo seu ritmo.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: wide ? 48 : 34,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 16),
                if (item != null) MediaFacts(item: item!),
                const SizedBox(height: 16),
                Text(
                  item?.metadata?.overview.isNotEmpty == true
                      ? item!.metadata!.overview
                      : 'Filmes, séries e músicas que já fazem parte da sua história. Dê o play no seu acervo.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.6,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      autofocus: TvLayout.of(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: item == null
                          ? onSettings
                          : () => onPlay(item!),
                      icon: Icon(
                        item == null
                            ? Icons.add_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        item == null
                            ? 'Adicionar pasta'
                            : (item!.metadata?.kind == 'tv' ||
                                      item!.queryName.isSeries
                                  ? 'Ver episódios'
                                  : 'Reproduzir'),
                      ),
                    ),
                    if (item != null)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xB3484848),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => onDetails(item!),
                        icon: const Icon(Icons.info_outline_rounded),
                        label: const Text('Mais informações'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MediaCard extends StatefulWidget {
  final MediaItem item;
  final bool audio;
  final ValueChanged<MediaItem> onPlay;
  final ValueChanged<MediaItem> onDetails;
  const _MediaCard({
    super.key,
    required this.item,
    required this.audio,
    required this.onPlay,
    required this.onDetails,
  });
  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  bool hover = false;
  bool focused = false;
  bool get active => hover || focused;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, active ? -5 : 0, 0),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0x28FFFFFF) : const Color(0x0E000000))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focused
                ? const Color(0xFFE50914)
                : active
                    ? (isDark ? const Color(0x35FFFFFF) : const Color(0x22000000))
                    : Colors.transparent,
            width: 2.5,
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: widget.audio ? 1 : 1 / 1.45,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaArtwork(item: widget.item),
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB3000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB3101014),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.audio
                            ? 'MÚSICA'
                            : (widget.item.metadata?.kind == 'tv' ||
                                      widget.item.queryName.isSeries
                                  ? 'SÉRIE'
                                  : 'VÍDEO'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onPlay(widget.item),
                      onLongPress: () => widget.onDetails(widget.item),
                      onFocusChange: (value) {
                        setState(() => focused = value);
                        if (value)
                          Scrollable.ensureVisible(
                            context,
                            duration: const Duration(milliseconds: 180),
                            alignment: 0.5,
                          );
                      },
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE50914),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 0, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.metadata?.kind == 'tv' ||
                                widget.item.queryName.isSeries
                            ? widget.item.metadata?.title ??
                                  widget.item.queryName.title
                            : widget.item.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: TvLayout.of(context) ? 18 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.metadata?.year.isNotEmpty == true
                            ? widget.item.metadata!.year
                            : 'Arquivo local',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          fontSize: TvLayout.of(context) ? 14 : 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: TvLayout.of(context) ? 48 : 32,
                  height: TvLayout.of(context) ? 48 : 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Informações de ${widget.item.displayTitle}',
                    onPressed: () => widget.onDetails(widget.item),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
