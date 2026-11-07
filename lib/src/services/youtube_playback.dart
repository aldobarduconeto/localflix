import 'package:video_player/video_player.dart' show VideoFormat;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

typedef NetworkVideoSource = ({
  Uri video,
  Uri? audio,
  VideoFormat? format,
  int? height,
});

Future<List<NetworkVideoSource>> resolveYoutubeVideo(String videoId) async {
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
                videoId,
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
              .getManifest(videoId)
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
      if (firstHasAudio != secondHasAudio) return firstHasAudio ? -1 : 1;
      return second.bitrate.compareTo(first.bitrate);
    });
    if (streams.isEmpty) {
      final liveUrl = await client.videos.streams
          .getHttpLiveStreamUrl(VideoId(videoId))
          .timeout(const Duration(seconds: 10));
      final uri = Uri.parse(liveUrl);
      if (uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Endereço de transmissão inválido.');
      }
      return [(video: uri, audio: null, format: VideoFormat.hls, height: null)];
    }
    final seen = <Uri>{};
    return [
      for (final stream in streams)
        if (seen.add(stream.url))
          (
            video: stream.url,
            height: stream.videoResolution.height,
            audio: audioByVideo[stream.url],
            format: stream is HlsMuxedStreamInfo ? VideoFormat.hls : null,
          ),
    ];
  } catch (_) {
    throw StateError(
      'O YouTube não forneceu um formato reproduzível para este vídeo.',
    );
  } finally {
    client.close();
  }
}
