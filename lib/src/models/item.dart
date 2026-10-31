import 'metadata.dart';

import 'dart:io';

enum MediaType { audio, video }

class MediaItem {
  final File? file;
  final Uri? documentUri;
  final String? documentName;
  final String? documentFolder;
  String get id => documentUri?.toString() ?? file!.path;
  Uri get uri => documentUri ?? file!.uri;
  bool get isDocument => documentUri != null;
  final MediaType type;

  final String? artworkPath;
  final String? bannerPath;
  final MediaMetadata? metadata;
  MediaItem(
    File localFile,
    this.type, {
    this.artworkPath,
    this.bannerPath,
    this.metadata,
  }) : file = localFile,
       documentUri = null,
       documentName = null,
       documentFolder = null;

  MediaItem.document({
    required Uri uri,
    required String name,
    required String parent,
    required this.type,
    this.artworkPath,
    this.bannerPath,
    this.metadata,
  }) : file = null,
       documentUri = uri,
       documentName = name,
       documentFolder = parent;

  MediaItem withMetadata(MediaMetadata? value) => identical(value, metadata)
      ? this
      : isDocument
      ? MediaItem.document(
          uri: documentUri!,
          name: name,
          parent: folder,
          type: type,
          artworkPath: artworkPath,
          bannerPath: bannerPath,
          metadata: value,
        )
      : MediaItem(
          file!,
          type,
          artworkPath: artworkPath,
          bannerPath: bannerPath,
          metadata: value,
        );
  String get displayTitle {
    if (metadata == null) return title;
    final episode = queryName.episode;
    return '${metadata!.title}${episode == null ? '' : ' • $episode'}';
  }

  late final MediaQueryName queryName = MediaQueryName.parse(name);
  late final String searchText = '$displayTitle $title'.toLowerCase();

  late final String title = name
      .replaceFirst(RegExp(r'\.[^.]+$'), '')
      .replaceAll('_', ' ');

  late final String name =
      documentName ??
      (file!.uri.pathSegments.isNotEmpty
          ? file!.uri.pathSegments.last
          : file!.path);

  String get folder => documentFolder ?? file!.parent.path;
}

const audioExtensions = {
  '.mp3',
  '.m4a',
  '.aac',
  '.wav',
  '.flac',
  '.ogg',
  '.opus',
  '.aiff',
  '.wma',
};

const videoExtensions = {
  '.mp4',
  '.m4v',
  '.mov',
  '.mkv',
  '.webm',
  '.avi',
  '.3gp',
  '.mpeg',
  '.mpg',
};

String extensionOf(String path) {
  final name = path.split(Platform.pathSeparator).last.toLowerCase();
  final dot = name.lastIndexOf('.');
  return dot == -1 ? '' : name.substring(dot);
}
