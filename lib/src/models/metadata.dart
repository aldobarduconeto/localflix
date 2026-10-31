class MediaMetadata {
  final int id;
  final String kind;
  final String title;
  final String overview;
  final String? poster;
  final String? backdrop;
  final String date;
  final double rating;
  final int runtime;
  final List<String> genres;
  final List<String> cast;
  final String artist;
  final String album;
  final String musicId;
  final int durationSeconds;
  const MediaMetadata({
    required this.id,
    required this.kind,
    required this.title,
    this.overview = '',
    this.poster,
    this.backdrop,
    this.date = '',
    this.rating = 0,
    this.runtime = 0,
    this.genres = const [],
    this.cast = const [],
    this.artist = '',
    this.album = '',
    this.musicId = '',
    this.durationSeconds = 0,
  });
  String get year => date.length >= 4 ? date.substring(0, 4) : '';
  String? image(bool banner) {
    if (kind == 'music') {
      if (!RegExp(
        r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
      ).hasMatch(musicId))
        return null;
      return 'https://coverartarchive.org/release/$musicId/front-${banner ? 1200 : 500}';
    }
    final path = banner ? backdrop ?? poster : poster;
    if (path == null || !RegExp(r'^/[a-zA-Z0-9_.-]+$').hasMatch(path))
      return null;
    return 'https://image.tmdb.org/t/p/${banner ? 'w1280' : 'w500'}$path';
  }

  factory MediaMetadata.fromJson(Map<String, dynamic> json) => MediaMetadata(
    id: (json['id'] as num).toInt(),
    kind: json['kind'] as String,
    title: json['title'] as String,
    overview: json['overview'] as String? ?? '',
    poster: json['poster'] as String?,
    backdrop: json['backdrop'] as String?,
    date: json['date'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    runtime: (json['runtime'] as num?)?.toInt() ?? 0,
    genres: List<String>.from(json['genres'] ?? []),
    cast: List<String>.from(json['cast'] ?? []),
    artist: json['artist'] as String? ?? '',
    album: json['album'] as String? ?? '',
    musicId: json['musicId'] as String? ?? '',
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'overview': overview,
    'poster': poster,
    'backdrop': backdrop,
    'date': date,
    'rating': rating,
    'runtime': runtime,
    'genres': genres,
    'cast': cast,
    'artist': artist,
    'album': album,
    'musicId': musicId,
    'durationSeconds': durationSeconds,
  };
}

class MediaQueryName {
  final String title;
  final int? year;
  final String? episode;
  const MediaQueryName(this.title, {this.year, this.episode});
  bool get isSeries => episode != null;
  String get cacheKey =>
      '${isSeries ? 'tv' : 'movie'}:${title.toLowerCase()}:${year ?? ''}';
  factory MediaQueryName.parse(String filename) {
    var text = filename
        .replaceFirst(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[._]'), ' ');
    final episode = RegExp(
      r'\b(s\d{1,2}\s?e\d{1,3}|\d{1,2}x\d{1,3})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (episode != null) text = text.substring(0, episode.start);
    final yearMatch = RegExp(r'\b(19\d{2}|20\d{2})\b').firstMatch(text);
    final year = yearMatch == null ? null : int.parse(yearMatch.group(0)!);
    if (yearMatch != null && yearMatch.start > 0)
      text = text.substring(0, yearMatch.start);
    text = text.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ');
    text = text
        .split(
          RegExp(
            r'\b(480p|720p|1080p|2160p|4k|bluray|brrip|webrip|web[- ]?dl|hdtv|x264|x265|h264|h265|hevc|remux|dublado|legendado|dual)\b',
            caseSensitive: false,
          ),
        )
        .first;
    text = text
        .replaceAll(RegExp(r'[\[\]()]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'[\s-]+$'), '')
        .trim();
    return MediaQueryName(
      text,
      year: year,
      episode: episode?.group(0)?.toUpperCase().replaceAll(' ', ''),
    );
  }
}
