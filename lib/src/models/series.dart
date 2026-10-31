class SeriesSeason {
  final int number;
  final String name;
  final int episodeCount;
  const SeriesSeason(this.number, this.name, this.episodeCount);
  factory SeriesSeason.fromJson(Map json) => SeriesSeason(
    (json['season_number'] as num?)?.toInt() ?? 0,
    json['name'] as String? ?? 'Temporada',
    (json['episode_count'] as num?)?.toInt() ?? 0,
  );
}

class SeriesInfo {
  final List<SeriesSeason> seasons;
  final int episodeCount;
  const SeriesInfo(this.seasons, this.episodeCount);
  factory SeriesInfo.fromJson(Map json) => SeriesInfo(
    (json['seasons'] as List? ?? [])
        .whereType<Map>()
        .map(SeriesSeason.fromJson)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number)),
    (json['number_of_episodes'] as num?)?.toInt() ?? 0,
  );
}

class SeriesEpisode {
  final int number;
  final String name;
  final String overview;
  final int runtime;
  const SeriesEpisode(this.number, this.name, this.overview, this.runtime);
  factory SeriesEpisode.fromJson(Map json) => SeriesEpisode(
    (json['episode_number'] as num?)?.toInt() ?? 0,
    json['name'] as String? ?? 'Episódio',
    json['overview'] as String? ?? '',
    (json['runtime'] as num?)?.toInt() ?? 0,
  );
}
