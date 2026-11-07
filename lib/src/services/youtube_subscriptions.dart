import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeSubscriptions {
  final _youtube = YoutubeExplode();
  final _details = <String, PublishedVideo>{};
  bool _closed = false;

  void close() {
    _closed = true;
    _details.clear();
    _youtube.close();
  }

  Future<Channel> resolveChannel(String input) async {
    final url = Uri.tryParse(input.contains('://') ? input : 'https://$input');
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
    final id = isYouTube && segments.length >= 2 && segments.first == 'channel'
        ? segments[1]
        : input;
    return await (handle != null
            ? _youtube.channels.getByHandle(handle)
            : _youtube.channels.get(id))
        .timeout(const Duration(seconds: 20));
  }

  Future<List<PublishedVideo>> loadVideos(String id) async {
    try {
      final feed = await _loadFeed(id);
      if (feed.isNotEmpty) return feed;
    } catch (_) {
      // Public feeds may fail even when the channel has public uploads.
    }

    List<Video> uploads = [];
    try {
      uploads = await _youtube.channels
          .getUploadsFromPage(id)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Try the channel's uploads playlist when its videos page is unavailable.
    }
    if (uploads.isEmpty) {
      uploads = await _youtube.channels
          .getUploads(id)
          .take(15)
          .toList()
          .timeout(const Duration(seconds: 20));
    }
    if (uploads.isEmpty) {
      throw StateError('Não foi possível obter os vídeos deste canal.');
    }
    final videos = <PublishedVideo>[];
    for (var offset = 0; offset < uploads.length && offset < 15; offset += 4) {
      if (_closed) break;
      videos.addAll(
        await Future.wait(
          uploads.take(15).skip(offset).take(4).map(_loadVideoDetails),
        ),
      );
    }
    return videos;
  }

  Future<PublishedVideo> _loadVideoDetails(Video upload) async {
    final id = upload.id.value;
    final cached = _details[id];
    if (cached != null) return cached;
    Video? details;
    try {
      details = await _youtube.videos
          .get(upload.id)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // The playlist entry can still be played if metadata is unavailable.
    }
    final published = details?.publishDate;
    final video = PublishedVideo(
      id: id,
      title: details?.title.isNotEmpty == true ? details!.title : upload.title,
      published: published,
      hasPublicationTime:
          published != null &&
          (published.hour != 0 ||
              published.minute != 0 ||
              published.second != 0),
    );
    if (!_closed &&
        details != null &&
        video.title.isNotEmpty &&
        published != null) {
      if (_details.length >= 200) _details.remove(_details.keys.first);
      _details[id] = video;
    }
    return video;
  }

  Future<List<PublishedVideo>> _loadFeed(String id) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      return await (() async {
        final request = await client.getUrl(
          Uri.https('www._youtube.com', '/feeds/videos.xml', {
            'channel_id': id,
          }),
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
                      namespace: 'http://www._youtube.com/xml/schemas/2015',
                    )
                    ?.innerText
                case final videoId?)
              PublishedVideo(
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
}

class PublishedVideo {
  const PublishedVideo({
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
