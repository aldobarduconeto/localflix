import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/metadata.dart';
import 'preferences_store.dart';
import 'tmdb.dart';

typedef MusicRequest = Future<Map<String, dynamic>> Function(Uri uri);

class MusicQuery {
  final String title;
  final String artist;
  const MusicQuery(this.title, [this.artist = '']);
  factory MusicQuery.parse(String filename) {
    final clean = filename
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .replaceAll('_', ' ')
        .replaceFirst(RegExp(r'^\d{1,3}[\s.\-]+'), '')
        .trim();
    final parts = clean.split(RegExp(r'\s+[-–]\s+'));
    return parts.length >= 2
        ? MusicQuery(parts.skip(1).join(' - '), parts.first)
        : MusicQuery(clean);
  }
  String get key =>
      '${TmdbService.normalize(artist)}:${TmdbService.normalize(title)}';
}

class MusicBrainzService {
  final MusicRequest? request;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  final Map<String, dynamic> _cache = {};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest;
  bool _closed = false;
  MusicBrainzService({this.request});
  static const cachePreference = 'musicbrainz_metadata_v1';
  static const userAgent =
      'Localflix/1.0 (local media library; MusicBrainz metadata client)';

  Future<void> restore(SharedPreferencesAsync prefs) async {
    _cache.addAll(await PreferencesStore.readMap(prefs, cachePreference));
  }

  Future<void> persist(SharedPreferencesAsync prefs) =>
      PreferencesStore.writeCache(prefs, cachePreference, _cache);

  MediaMetadata? cached(MusicQuery query) {
    try {
      final entry = _cache[query.key];
      return entry is Map && entry['data'] is Map
          ? MediaMetadata.fromJson(Map<String, dynamic>.from(entry['data']))
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<MediaMetadata?> lookup(MusicQuery query) {
    final result = Completer<MediaMetadata?>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await _lookup(query));
      } catch (e, stack) {
        result.completeError(e, stack);
      }
    });
    return result.future;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    if (_closed) throw const TmdbException('Consulta cancelada.');
    if (request != null) return request!(uri);
    final wait = _lastRequest == null
        ? 0
        : 1100 - DateTime.now().difference(_lastRequest!).inMilliseconds;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
    if (_closed) throw const TmdbException('Consulta cancelada.');
    _lastRequest = DateTime.now();
    try {
      final req = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      req.headers.set(HttpHeaders.userAgentHeader, userAgent);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await req.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 429 || response.statusCode == 503)
        throw const TmdbException(
          'MusicBrainz ocupado. Tente atualizar mais tarde.',
        );
      if (response.statusCode != 200)
        throw const TmdbException(
          'MusicBrainz indisponível. Tente mais tarde.',
        );
      return jsonDecode(body) as Map<String, dynamic>;
    } on TmdbException {
      rethrow;
    } catch (_) {
      throw const TmdbException('Não foi possível conectar ao MusicBrainz.');
    }
  }

  static String quote(String text) =>
      '"${text.replaceAll(RegExp(r'["\\]'), ' ')}"';
  Future<MediaMetadata?> _lookup(MusicQuery query) async {
    if (query.title.isEmpty) return null;
    final entry = _cache[query.key];
    if (entry is Map &&
        entry['time'] is int &&
        DateTime.now().millisecondsSinceEpoch - entry['time'] <
            const Duration(days: 7).inMilliseconds)
      return cached(query);
    final json = await _get(
      Uri.https('musicbrainz.org', '/ws/2/recording/', {
        'fmt': 'json',
        'limit': '8',
        'query':
            'recording:${quote(query.title)}${query.artist.isEmpty ? '' : ' AND artist:${quote(query.artist)}'}',
      }),
    );
    final candidates = (json['recordings'] as List? ?? [])
        .whereType<Map>()
        .where((row) {
          final score = int.tryParse('${row['score']}') ?? 0;
          final titleMatch =
              TmdbService.normalize('${row['title']}') ==
              TmdbService.normalize(query.title);
          final artists = (row['artist-credit'] as List? ?? [])
              .whereType<Map>()
              .map(
                (e) => '${e['name'] ?? (e['artist'] as Map?)?['name'] ?? ''}',
              )
              .join(' ');
          return score >= 95 &&
              titleMatch &&
              (query.artist.isEmpty ||
                  TmdbService.normalize(artists)
                      .contains(TmdbService.normalize(query.artist)));
        })
        .toList();
    MediaMetadata? metadata;
    if (candidates.isNotEmpty) {
      final match = candidates.first;
      final artists = (match['artist-credit'] as List? ?? [])
          .whereType<Map>()
          .map((e) => '${e['name'] ?? (e['artist'] as Map?)?['name'] ?? ''}')
          .where((e) => e.isNotEmpty)
          .join(', ');
      // Without an artist hint, refuse results naming different performers.
      final ambiguous =
          query.artist.isEmpty &&
          candidates.any(
            (row) =>
                jsonEncode(row['artist-credit']) !=
                jsonEncode(match['artist-credit']),
          );
      final releases = (match['releases'] as List? ?? [])
          .whereType<Map>()
          .toList();
      releases.sort(
        (a, b) => (b['status'] == 'Official' ? 1 : 0).compareTo(
          a['status'] == 'Official' ? 1 : 0,
        ),
      );
      if (!ambiguous) {
        final release = releases.firstOrNull;
        metadata = MediaMetadata(
          id: 0,
          kind: 'music',
          title: '${match['title']}',
          artist: artists,
          album: '${release?['title'] ?? ''}',
          musicId: '${release?['id'] ?? ''}',
          date: '${match['first-release-date'] ?? release?['date'] ?? ''}',
          durationSeconds: ((match['length'] as num?)?.toInt() ?? 0) ~/ 1000,
          overview:
              '${artists.isEmpty ? '' : 'Artista: $artists. '}${release == null ? '' : 'Álbum: ${release['title']}.'}',
        );
      }
    }
    _cache[query.key] = {
      'time': DateTime.now().millisecondsSinceEpoch,
      'data': metadata?.toJson(),
    };
    return metadata;
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}
