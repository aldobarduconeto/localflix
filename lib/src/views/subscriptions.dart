import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';
import 'package:video_player/video_player.dart' show VideoFormat;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/item.dart';
import '../models/preferences.dart';
import '../services/preferences_store.dart';
import 'player.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key, required this.settings});

  final PlaybackSettings settings;

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  static const storageKey = 'youtube_subscriptions';
  final youtube = YoutubeExplode();
  final scrollController = ScrollController();
  final channels = <String, String>{};
  final feeds = <String, Future<List<_PublishedVideo>>>{};
  String selectedChannel = '';
  Future<({List<_ChannelVideo> videos, List<String> failures})>? visibleFeed;
  bool busy = true;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    restore();
  }

  @override
  void dispose() {
    scrollController.dispose();
    youtube.close();
    super.dispose();
  }

  Future<void> restore() async {
    await update(() async {
      final prefs = await PreferencesStore.open();
      final saved = await PreferencesStore.readMap(prefs, storageKey);
      if (!mounted) return;
      setState(() {
        for (final entry in saved.entries) {
          final name = entry.value;
          if (name is String) channels[entry.key] = name;
        }
        ready = true;
        refreshGrid();
      });
    }, 'Não foi possível carregar as inscrições.');
  }

  Future<void> update(Future<void> Function() action, String error) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(Map<String, String> next) async {
    final prefs = await PreferencesStore.open();
    await prefs.setString(storageKey, jsonEncode(next));
    if (!mounted) return;
    setState(() {
      channels
        ..clear()
        ..addAll(next);
      feeds.removeWhere((id, _) => !channels.containsKey(id));
      if (!channels.containsKey(selectedChannel)) selectedChannel = '';
      refreshGrid();
    });
  }

  Future<void> add() async {
    final input = await showDialog<String>(
      context: context,
      builder: (_) => const _ChannelDialog(),
    );
    if (!mounted || input == null || input.isEmpty || busy) return;

    await update(() async {
      final url = Uri.tryParse(
        input.contains('://') ? input : 'https://$input',
      );
      final segments = url?.pathSegments ?? [];
      final isYouTube =
          url != null &&
          const {
            'youtube.com',
            'www.youtube.com',
            'm.youtube.com',
          }.contains(url.host);
      final handle = input.startsWith('@')
          ? input
          : isYouTube && segments.isNotEmpty && segments.first.startsWith('@')
          ? segments.first
          : null;
      final id =
          isYouTube && segments.length >= 2 && segments.first == 'channel'
          ? segments[1]
          : input;
      final channel =
          await (handle != null
                  ? youtube.channels.getByHandle(handle)
                  : youtube.channels.get(id))
              .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await save({...channels, channel.id.value: channel.title});
    }, 'Não foi possível adicionar o canal. Confira o link ou @canal.');
  }

  Future<List<_PublishedVideo>> loadVideos(String id) async {
    try {
      final feed = await loadFeed(id);
      if (feed.isNotEmpty) return feed;
    } catch (_) {
      // Public feeds may fail even when the channel has public uploads.
    }

    List<Video> uploads = [];
    try {
      uploads = await youtube.channels
          .getUploadsFromPage(id)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Try the channel's uploads playlist when its videos page is unavailable.
    }
    if (uploads.isEmpty) {
      uploads = await youtube.channels
          .getUploads(id)
          .take(15)
          .toList()
          .timeout(const Duration(seconds: 20));
    }
    if (uploads.isEmpty) {
      throw StateError('Não foi possível obter os vídeos deste canal.');
    }
    final videos = <_PublishedVideo>[];
    for (var offset = 0; offset < uploads.length && offset < 15; offset += 4) {
      if (!mounted) break;
      videos.addAll(
        await Future.wait(
          uploads.take(15).skip(offset).take(4).map(loadVideoDetails),
        ),
      );
    }
    return videos;
  }

  Future<_PublishedVideo> loadVideoDetails(Video upload) async {
    Video? details;
    try {
      details = await youtube.videos
          .get(upload.id)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // The playlist entry can still be played if metadata is unavailable.
    }
    final published = details?.publishDate;
    return _PublishedVideo(
      id: upload.id.value,
      title: details?.title.isNotEmpty == true ? details!.title : upload.title,
      published: published,
      hasPublicationTime:
          published != null &&
          (published.hour != 0 ||
              published.minute != 0 ||
              published.second != 0),
    );
  }

  Future<List<_PublishedVideo>> loadFeed(String id) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      return await (() async {
        final request = await client.getUrl(
          Uri.https('www.youtube.com', '/feeds/videos.xml', {'channel_id': id}),
        );
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('Feed indisponível (${response.statusCode}).');
        }
        final feed = XmlDocument.parse(
          await utf8.decoder.bind(response).join(),
        );
        if (feed.rootElement.name.local != 'feed') {
          throw const FormatException('Resposta inválida do feed do canal.');
        }
        return [
          for (final entry in feed.rootElement.findElements(
            'entry',
            namespace: '*',
          ))
            if (entry
                    .getElement(
                      'videoId',
                      namespace: 'http://www.youtube.com/xml/schemas/2015',
                    )
                    ?.innerText
                case final videoId?)
              _PublishedVideo(
                id: videoId,
                title:
                    entry
                        .getElement('title', namespace: '*')
                        ?.innerText
                        .trim() ??
                    '',
                published: DateTime.tryParse(
                  entry.getElement('published', namespace: '*')?.innerText ??
                      '',
                ),
              ),
        ];
      })().timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
    }
  }

  Future<void> play(_PublishedVideo video, String channel) async {
    final url = Uri.https('www.youtube.com', '/watch', {'v': video.id});
    if (widget.settings.openYoutubeExternally) {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Report launch failures without switching the selected player.
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o YouTube.')),
        );
      }
      return;
    }

    final item = MediaItem.document(
      uri: url,
      name: video.displayTitle,
      parent: channel,
      type: MediaType.video,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerPage(
          initialMedia: item,
          library: [item],
          settings: widget.settings,
          resolveVideoSources: () async {
            final client = YoutubeExplode();
            try {
              // Query independently so a client failure does not hide HD streams
              // returned by another client.
              final manifests = await Future.wait(
                [
                  YoutubeApiClient.androidVr,
                  YoutubeApiClient.ios,
                  YoutubeApiClient.safari,
                  YoutubeApiClient.androidSdkless,
                ].map((apiClient) async {
                  try {
                    return await client.videos.streams
                        .getManifest(
                          video.id,
                          ytClients: [apiClient],
                          requireWatchPage: false,
                        )
                        .timeout(const Duration(seconds: 20));
                  } catch (_) {
                    return null;
                  }
                }),
              );
              if (manifests.every((manifest) => manifest == null)) {
                try {
                  manifests.add(
                    await client.videos.streams
                        .getManifest(video.id)
                        .timeout(const Duration(seconds: 12)),
                  );
                } catch (_) {
                  // The watch page may expose a live HLS playlist instead.
                }
              }
              final streams = <VideoStreamInfo>[];
              final audioByVideo = <Uri, Uri>{};
              for (final manifest in manifests.whereType<StreamManifest>()) {
                final audio = manifest.audioOnly;
                if (audio.isNotEmpty) {
                  final audioUrl = audio.withHighestBitrate().url;
                  for (final stream in manifest.videoOnly) {
                    streams.add(stream);
                    audioByVideo[stream.url] = audioUrl;
                  }
                }
                streams.addAll(manifest.hls.whereType<HlsMuxedStreamInfo>());
                streams.addAll(manifest.muxed);
              }
              streams.sort((first, second) {
                final resolution = second.videoResolution.compareTo(
                  first.videoResolution,
                );
                if (resolution != 0) return resolution;
                final frameRate = second.framerate.compareTo(first.framerate);
                if (frameRate != 0) return frameRate;
                // At equal quality prefer streams with audio already attached.
                final firstHasAudio = !audioByVideo.containsKey(first.url);
                final secondHasAudio = !audioByVideo.containsKey(second.url);
                if (firstHasAudio != secondHasAudio)
                  return firstHasAudio ? -1 : 1;
                return second.bitrate.compareTo(first.bitrate);
              });
              if (streams.isEmpty) {
                final liveUrl = await client.videos.streams
                    .getHttpLiveStreamUrl(VideoId(video.id))
                    .timeout(const Duration(seconds: 10));
                final uri = Uri.parse(liveUrl);
                if (uri.scheme != 'https' || uri.host.isEmpty) {
                  throw const FormatException(
                    'Endereço de transmissão inválido.',
                  );
                }
                return [(video: uri, audio: null, format: VideoFormat.hls)];
              }
              final seen = <Uri>{};
              return [
                for (final stream in streams)
                  if (seen.add(stream.url))
                    (
                      video: stream.url,
                      audio: audioByVideo[stream.url],
                      format: stream is HlsMuxedStreamInfo
                          ? VideoFormat.hls
                          : null,
                    ),
              ];
            } catch (_) {
              throw StateError(
                'O YouTube não forneceu um formato reproduzível para este vídeo.',
              );
            } finally {
              client.close();
            }
          },
        ),
      ),
    );
  }

  void refreshGrid({bool reload = false}) {
    final visibleChannels = channels.entries
        .where(
          (channel) =>
              selectedChannel.isEmpty || selectedChannel == channel.key,
        )
        .toList();
    if (reload) {
      for (final channel in visibleChannels) {
        feeds.remove(channel.key);
      }
    }
    visibleFeed = collectVideos(visibleChannels);
  }

  Future<({List<_ChannelVideo> videos, List<String> failures})> collectVideos(
    List<MapEntry<String, String>> visibleChannels,
  ) async {
    final videos = <_ChannelVideo>[];
    final failures = <String>[];
    final ids = <String>{};
    final results = await Future.wait(
      visibleChannels.map((channel) async {
        try {
          final feed = await feeds.putIfAbsent(
            channel.key,
            () => loadVideos(channel.key),
          );
          return (channel: channel, feed: feed);
        } catch (_) {
          feeds.remove(channel.key);
          return (channel: channel, feed: null);
        }
      }),
    );
    for (final result in results) {
      final feed = result.feed;
      if (feed == null) {
        failures.add(result.channel.value);
        continue;
      }
      for (final video in feed) {
        if (ids.add(video.id)) {
          videos.add((video: video, channel: result.channel.value));
        }
      }
    }
    videos.sort((a, b) {
      final first = a.video.published;
      final second = b.video.published;
      if (first == null) return second == null ? 0 : 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });
    return (videos: videos, failures: failures);
  }

  void scrollPage(int direction) {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.85)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return SafeArea(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.gameButtonLeft1): () =>
              scrollPage(-1),
          const SingleActivator(LogicalKeyboardKey.gameButtonRight1): () =>
              scrollPage(1),
        },
        child: Scrollbar(
          controller: scrollController,
          interactive: true,
          child: CustomScrollView(
            controller: scrollController,
            scrollBehavior: behavior.copyWith(
              scrollbars: false,
              dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inscrições',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (channels.isNotEmpty)
                            SizedBox(
                              width: 260,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Canal',
                                  border: OutlineInputBorder(),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedChannel,
                                    isExpanded: true,
                                    isDense: true,
                                    items: [
                                      const DropdownMenuItem(
                                        value: '',
                                        child: Text('Mostrar todos'),
                                      ),
                                      for (final channel in channels.entries)
                                        DropdownMenuItem(
                                          value: channel.key,
                                          child: Text(
                                            channel.value,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: busy
                                        ? null
                                        : (value) {
                                            if (value == null ||
                                                value == selectedChannel)
                                              return;
                                            setState(() {
                                              selectedChannel = value;
                                              refreshGrid();
                                            });
                                          },
                                  ),
                                ),
                              ),
                            ),
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : ready
                                ? add
                                : restore,
                            icon: Icon(ready ? Icons.add : Icons.refresh),
                            label: Text(
                              ready ? 'Adicionar canal' : 'Carregar inscrições',
                            ),
                          ),
                          if (selectedChannel.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => update(
                                      () => save(
                                        {...channels}..remove(selectedChannel),
                                      ),
                                      'Não foi possível remover o canal.',
                                    ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remover canal'),
                            ),
                        ],
                      ),
                      if (busy) const LinearProgressIndicator(),
                      if (ready && channels.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            'Adicione um canal do YouTube pelo link ou @canal.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (channels.isNotEmpty)
                FutureBuilder(
                  future: visibleFeed,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SliverToBoxAdapter(
                        child: LinearProgressIndicator(),
                      );
                    }
                    final result = snapshot.data;
                    if (result == null) return const SliverToBoxAdapter();
                    return SliverMainAxisGroup(
                      slivers: [
                        if (result.failures.isNotEmpty || result.videos.isEmpty)
                          SliverToBoxAdapter(
                            child: ListTile(
                              title: Text(
                                result.failures.isEmpty
                                    ? 'Nenhum vídeo encontrado.'
                                    : 'Não foi possível carregar: ${result.failures.join(', ')}.',
                              ),
                              trailing: IconButton(
                                tooltip: 'Tentar novamente',
                                onPressed: () =>
                                    setState(() => refreshGrid(reload: true)),
                                icon: const Icon(Icons.refresh),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          sliver: SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 340,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  mainAxisExtent: 270,
                                ),
                            itemCount: result.videos.length,
                            itemBuilder: (context, index) {
                              final entry = result.videos[index];
                              return _VideoCard(
                                entry: entry,
                                onPlay: () => play(entry.video, entry.channel),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _ChannelVideo = ({_PublishedVideo video, String channel});

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.entry, required this.onPlay});

  final _ChannelVideo entry;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final video = entry.video;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                'https://i.ytimg.com/vi/${video.id}/mqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Center(child: Icon(Icons.play_circle_outline)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.displayTitle,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    video.publicationLabel,
                    style: theme.textTheme.bodySmall,
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

class _ChannelDialog extends StatefulWidget {
  const _ChannelDialog();

  @override
  State<_ChannelDialog> createState() => _ChannelDialogState();
}

class _ChannelDialogState extends State<_ChannelDialog> {
  String input = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar canal do YouTube'),
      content: TextField(
        autofocus: true,
        decoration: const InputDecoration(hintText: '@canal ou link do canal'),
        onChanged: (value) => setState(() => input = value.trim()),
        onSubmitted: (_) {
          if (input.isNotEmpty) Navigator.pop(context, input);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: input.isEmpty ? null : () => Navigator.pop(context, input),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _PublishedVideo {
  const _PublishedVideo({
    required this.id,
    required this.title,
    required this.published,
    this.hasPublicationTime = true,
  });

  final String id;
  final String title;
  final DateTime? published;
  final bool hasPublicationTime;

  String get displayTitle => title.isEmpty ? 'Vídeo do YouTube' : title;

  String get publicationLabel {
    final local = hasPublicationTime ? published?.toLocal() : published;
    if (local == null) return 'Data de publicação indisponível';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final date =
        '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year}';
    if (!hasPublicationTime) return date;
    return '$date às ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
