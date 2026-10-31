import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/metadata.dart';
import '../models/series.dart';
import 'preferences_store.dart';

typedef TmdbRequest = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, String> query,
);

class TmdbException implements Exception {
  final String message;
  const TmdbException(this.message);
  @override
  String toString() => message;
}

class TmdbService {
  final String credential;
  final TmdbRequest? request;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  final Map<String, dynamic> _cache = {};
  final Map<String, Future<MediaMetadata?>> _pending = {};
  bool _closed = false;
  final Map<int, Future<SeriesInfo>> _series = {};
  final Map<String, Future<List<SeriesEpisode>>> _seasons = {};

  Future<SeriesInfo> seriesDetails(int id) => _series.putIfAbsent(id, () async {
    try {
      return SeriesInfo.fromJson(await _get('tv/$id'));
    } catch (_) {
      _series.remove(id);
      rethrow;
    }
  });

  Future<List<SeriesEpisode>> seasonEpisodes(int id, int season) {
    final key = '$id:$season';
    return _seasons.putIfAbsent(key, () async {
      try {
        final data = await _get('tv/$id/season/$season');
        return (data['episodes'] as List? ?? [])
            .whereType<Map>()
            .map(SeriesEpisode.fromJson)
            .toList();
      } catch (_) {
        _seasons.remove(key);
        rethrow;
      }
    });
  }

  static const cachePreference = 'tmdb_metadata_v1';
  TmdbService(this.credential, {this.request});

  Future<void> restore(SharedPreferencesAsync prefs) async {
    _cache.addAll(await PreferencesStore.readMap(prefs, cachePreference));
  }

  Future<void> persist(SharedPreferencesAsync prefs) =>
      PreferencesStore.writeCache(prefs, cachePreference, _cache);

  MediaMetadata? cached(MediaQueryName name) {
    try {
      final entry = _cache[name.cacheKey];
      return entry is Map && entry['data'] is Map
          ? MediaMetadata.fromJson(Map<String, dynamic>.from(entry['data']))
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String> params = const {},
  ]) async {
    if (_closed) throw const TmdbException('Consulta cancelada.');
    if (request != null) return request!(path, params);
    final token = credential.trim().replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    if (token.isEmpty)
      throw const TmdbException('Configure sua credencial do TMDB.');
    final isKey = RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(token);
    final uri = Uri.https('api.themoviedb.org', '/3/$path', {
      'language': 'pt-BR',
      ...params,
      if (isKey) 'api_key': token,
    });
    try {
      final req = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      if (!isKey)
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await req.close().timeout(const Duration(seconds: 12));
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 401 || response.statusCode == 403)
        throw const TmdbException('Credencial TMDB inválida ou sem acesso.');
      if (response.statusCode == 429)
        throw const TmdbException(
          'Limite do TMDB atingido. Tente novamente mais tarde.',
        );
      if (response.statusCode != 200)
        throw const TmdbException(
          'TMDB indisponível. Tente novamente mais tarde.',
        );
      return jsonDecode(body) as Map<String, dynamic>;
    } on TmdbException {
      rethrow;
    } catch (_) {
      throw const TmdbException(
        'Não foi possível conectar ao TMDB. Verifique a conexão.',
      );
    }
  }

  Future<void> validate() async {
    await _get('configuration');
  }

  Future<MediaMetadata?> lookup(MediaQueryName name, {bool force = false}) {
    if (name.title.isEmpty) return Future.value(null);
    return _pending.putIfAbsent(
      name.cacheKey,
      () => _lookup(name, force: force).whenComplete(() {
        _pending.remove(name.cacheKey);
      }),
    );
  }

  Future<MediaMetadata?> _lookup(
    MediaQueryName name, {
    bool force = false,
  }) async {
    final entry = _cache[name.cacheKey];
    if (!force &&
        entry is Map &&
        entry['time'] is int &&
        DateTime.now().millisecondsSinceEpoch - entry['time'] <
            const Duration(days: 7).inMilliseconds) {
      return cached(name);
    }
    final result = await _get(name.isSeries ? 'search/tv' : 'search/multi', {
      'query': name.title,
      'include_adult': 'false',
    });
    final candidates = (result['results'] as List? ?? [])
        .whereType<Map>()
        .where(
          (r) =>
              name.isSeries ||
              r['media_type'] == 'movie' ||
              r['media_type'] == 'tv',
        )
        .toList();
    double score(Map row) {
      final titles = [
        row['title'],
        row['name'],
        row['original_title'],
        row['original_name'],
      ].whereType<String>();
      final target = normalize(name.title);
      var best = 0.0;
      for (final title in titles) {
        final normalized = normalize(title);
        final a = target.split(' ').toSet();
        final b = normalized.split(' ').toSet();
        final similarity = normalized == target
            ? 1.0
            : a.intersection(b).length / a.union(b).length;
        if (similarity > best) best = similarity;
      }
      if (name.year != null) {
        final date = (row['release_date'] ?? row['first_air_date'] ?? '')
            .toString();
        if (date.startsWith('${name.year}')) {
          best += 0.15;
        } else if (!name.isSeries) {
          best -= 0.2;
        }
      }
      return best;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));
    MediaMetadata? metadata;
    if (candidates.isNotEmpty && score(candidates.first) >= 0.72) {
      final match = candidates.first;
      final kind = name.isSeries || match['media_type'] == 'tv'
          ? 'tv'
          : 'movie';
      final details = await _get('$kind/${match['id']}', {
        'append_to_response': 'credits',
      });
      final credits = details['credits'] as Map?;
      metadata = MediaMetadata(
        id: (details['id'] as num).toInt(),
        kind: kind,
        title: (details['title'] ?? details['name'] ?? name.title).toString(),
        overview: details['overview'] as String? ?? '',
        poster: (details['poster_path'] ?? match['poster_path']) as String?,
        backdrop:
            (details['backdrop_path'] ?? match['backdrop_path']) as String?,
        date: (details['release_date'] ?? details['first_air_date'] ?? '')
            .toString(),
        rating: (details['vote_average'] as num?)?.toDouble() ?? 0,
        runtime:
            (details['runtime'] as num?)?.toInt() ??
            ((details['episode_run_time'] as List?)?.firstOrNull as num?)
                ?.toInt() ??
            0,
        genres: (details['genres'] as List? ?? [])
            .whereType<Map>()
            .map((e) => e['name'].toString())
            .toList(),
        cast: (credits?['cast'] as List? ?? [])
            .whereType<Map>()
            .take(5)
            .map((e) => e['name'].toString())
            .toList(),
      );
    }
    _cache[name.cacheKey] = {
      'time': DateTime.now().millisecondsSinceEpoch,
      'data': metadata?.toJson(),
    };
    return metadata;
  }

  static String normalize(String value) {
    var text = value.toLowerCase();
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    for (var i = 0; i < accents.length; i++) {
      text = text.replaceAll(accents[i], plain[i]);
    }
    return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}
