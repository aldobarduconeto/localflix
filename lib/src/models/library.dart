import 'dart:io';
import 'dart:isolate';

import 'item.dart';
import '../services/native_media.dart';

class LibraryScan {
  final List<MediaItem> items;
  final List<String> warnings;
  final Map<String, String> folderMigrations;
  const LibraryScan(
    this.items,
    this.warnings, {
    this.folderMigrations = const {},
  });
}

Future<List<MediaItem>> readLibrary(List<String> folders) async =>
    (await scanFolders(folders)).items;

Future<LibraryScan> scanFolders(List<String> folders) => folders.isEmpty
    ? Future.value(const LibraryScan([], []))
    : Platform.isAndroid
    ? NativeMedia.scan(folders)
          .then((scan) => Isolate.run(() => parseDocumentScan(scan)))
    : Isolate.run(() => _scan(folders));

/// Android document IDs are opaque. Match sidecar art by display name within
/// its parent document, never by converting a content URI into a file path.
LibraryScan parseDocumentScan(Map<Object?, Object?> scan) {
  final rows = (scan['files'] as List? ?? []).whereType<Map>().toList();
  final images = <String, String>{};
  final media = <String, Map>{};
  for (final row in rows) {
    if (row['uri'] is! String ||
        row['name'] is! String ||
        row['parent'] is! String)
      continue;
    final name = row['name'] as String;
    final uri = row['uri'] as String;
    if (Uri.tryParse(uri)?.scheme != 'content') continue;
    final extension = extensionOf(name);
    if (audioExtensions.contains(extension) ||
        videoExtensions.contains(extension)) {
      media[uri] = row;
    } else if ({'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)) {
      images['${row['parent']}\u0000${name.toLowerCase()}'] = uri;
    }
  }
  String? artwork(String parent, List<String> stems) {
    for (final stem in stems) {
      for (final extension in ['.jpg', '.jpeg', '.png', '.webp']) {
        final match = images['$parent\u0000${stem.toLowerCase()}$extension'];
        if (match != null) return match;
      }
    }
    return null;
  }

  final items =
      media.values.map((row) {
        final name = row['name'] as String;
        final parent = row['parent'] as String;
        final extension = extensionOf(name);
        final stem = name.substring(0, name.length - extension.length);
        return MediaItem.document(
          uri: Uri.parse(row['uri'] as String),
          name: name,
          parent: parent,
          type: audioExtensions.contains(extension)
              ? MediaType.audio
              : MediaType.video,
          artworkPath: artwork(parent, [
            stem,
            '$stem-poster',
            'poster',
            'cover',
            'folder',
            'album',
          ]),
          bannerPath: artwork(parent, [
            '$stem-fanart',
            '$stem-banner',
            'fanart',
            'backdrop',
            'banner',
          ]),
        );
      }).toList()..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  final migrations = <String, String>{};
  final rawMigrations = scan['migrations'];
  if (rawMigrations is Map) {
    for (final entry in rawMigrations.entries) {
      if (entry.key is String &&
          entry.value is String &&
          Uri.tryParse(entry.value)?.scheme == 'content') {
        migrations[entry.key as String] = entry.value as String;
      }
    }
  }
  return LibraryScan(
    items,
    (scan['warnings'] as List? ?? []).whereType<String>().toList(),
    folderMigrations: migrations,
  );
}

Future<LibraryScan> _scan(List<String> folders) async {
  String pathKey(String path) =>
      Platform.isWindows ? path.replaceAll('/', '\\').toLowerCase() : path;
  final media = <String, File>{};
  final images = <String, String>{};
  final warnings = <String>[];
  final visited = <String>{};
  for (final path in folders) {
    final dir = Directory(path);
    final normalized = dir.absolute.path;
    if (!visited.add(pathKey(normalized))) continue;
    try {
      if (!await dir.exists())
        throw FileSystemException('Pasta indisponível', path);
      await for (final entry in dir.list(recursive: true, followLinks: false)) {
        if (entry is! File) continue;
        final ext = extensionOf(entry.path);
        if (audioExtensions.contains(ext) || videoExtensions.contains(ext)) {
          media[pathKey(entry.absolute.path)] = entry;
        } else if ({'.jpg', '.jpeg', '.png', '.webp'}.contains(ext)) {
          images[pathKey(entry.path).toLowerCase()] = entry.path;
        }
      }
    } on FileSystemException {
      warnings.add('Não foi possível ler a pasta: $path');
    }
  }
  String? find(List<String> stems) {
    for (final stem in stems) {
      for (final ext in ['.jpg', '.jpeg', '.png', '.webp']) {
        final match = images[pathKey('$stem$ext').toLowerCase()];
        if (match != null) return match;
      }
    }
    return null;
  }

  final items = <MediaItem>[];
  for (final file in media.values) {
    final ext = extensionOf(file.path);
    final stem = file.path.substring(0, file.path.length - ext.length);
    final folder = '${file.parent.path}${Platform.pathSeparator}';
    items.add(
      MediaItem(
        file,
        audioExtensions.contains(ext) ? MediaType.audio : MediaType.video,
        artworkPath: find([
          stem,
          '$stem-poster',
          '${folder}poster',
          '${folder}cover',
          '${folder}folder',
          '${folder}album',
        ]),
        bannerPath: find([
          '$stem-fanart',
          '$stem-banner',
          '${folder}fanart',
          '${folder}backdrop',
          '${folder}banner',
        ]),
      ),
    );
  }
  items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return LibraryScan(items, warnings);
}
