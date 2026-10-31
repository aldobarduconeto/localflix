import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_store.dart';

import 'package:flutter/services.dart';

/// Shared entry point for native folders, artwork and window integration.
class NativeMedia {
  static const channel = MethodChannel('localflix/documents');
  static final _images = LinkedHashMap<String, Uint8List>();
  static final _pending = <String, Future<Uint8List?>>{};
  static int _imageBytes = 0;

  static bool get isApple => Platform.isMacOS || Platform.isIOS;
  static const _foldersChannel = MethodChannel('localflix/folders');
  static const _windowChannel = MethodChannel('localflix/window');
  static const bookmarksKey = 'apple_folder_bookmarks_v1';

  static Future<bool> isTelevision() async =>
      Platform.isAndroid &&
      (await channel.invokeMethod<bool>('isTelevision') ?? false);

  static Future<String?> pickFolder() {
    if (Platform.isAndroid) return channel.invokeMethod<String>('pickFolder');
    if (isApple) return _pickAppleFolder();
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Selecione uma pasta de músicas ou vídeos',
    );
  }

  static Future<List<String>> pendingFolders() async =>
      await channel.invokeListMethod<String>('pendingFolders') ?? [];

  static Future<void> acknowledgeFolders(List<String> folders) =>
      channel.invokeMethod<void>('acknowledgeFolders', folders);

  static Future<bool> recoverFolders(
    List<String> saved,
    Future<void> Function(List<String>) persist,
  ) async {
    final pending = await pendingFolders();
    if (pending.isEmpty) return false;
    await persist(mergeSelectedFolders(saved, pending));
    // Never consume the native handoff before Flutter preferences are durable.
    await acknowledgeFolders(pending);
    return true;
  }

  static Future<Map<Object?, Object?>> scan(List<String> folders) async =>
      await channel.invokeMapMethod<Object?, Object?>('scanFolders', folders) ??
      {};

  static Future<Uint8List?> artwork(String uri, int width) {
    final key = '$width:$uri';
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return Future.value(cached);
    }
    return _pending.putIfAbsent(
      key,
      () => _readArtwork(uri, width, key).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  static Future<Uint8List?> _readArtwork(
    String uri,
    int width,
    String key,
  ) async {
    try {
      final bytes = await channel.invokeMethod<Uint8List>('readArtwork', {
        'uri': uri,
        'width': width,
      });
      if (bytes == null || bytes.length > 12 * 1024 * 1024) return bytes;
      _images[key] = bytes;
      _imageBytes += bytes.length;
      while (_images.length > 24 || _imageBytes > 12 * 1024 * 1024) {
        _imageBytes -= _images.remove(_images.keys.first)!.length;
      }
      return bytes;
    } on PlatformException {
      return null;
    }
  }

  static Future<Map<String, String>> _bookmarks(
    SharedPreferencesAsync prefs,
  ) async {
    final raw = await PreferencesStore.readMap(prefs, bookmarksKey);
    return Map.fromEntries(
      raw.entries
          .where((entry) => entry.value is String)
          .map((entry) => MapEntry(entry.key, entry.value as String)),
    );
  }

  static Future<String?> _pickAppleFolder() async {
    final selected = await _foldersChannel.invokeMapMethod<String, dynamic>(
      'pickFolder',
    );
    if (selected == null) return null;
    final path = selected['path'] as String;
    final prefs = await PreferencesStore.open();
    final bookmarks = await _bookmarks(prefs);
    bookmarks[path] = selected['bookmark'] as String;
    await prefs.setString(bookmarksKey, jsonEncode(bookmarks));
    return path;
  }

  static Future<Map<String, String>> restoreFolders(
    SharedPreferencesAsync prefs,
  ) async {
    final bookmarks = await _bookmarks(prefs);
    if (bookmarks.isEmpty) return {};
    final entries =
        await _foldersChannel.invokeListMethod<dynamic>(
          'restoreFolders',
          bookmarks,
        ) ??
        [];
    final migrations = <String, String>{};
    for (final entry in entries.whereType<Map>()) {
      if (entry['oldPath'] is! String ||
          entry['path'] is! String ||
          entry['bookmark'] is! String)
        continue;
      final oldPath = entry['oldPath'] as String;
      final path = entry['path'] as String;
      bookmarks.remove(oldPath);
      bookmarks[path] = entry['bookmark'] as String;
      migrations[oldPath] = path;
    }
    await prefs.setString(bookmarksKey, jsonEncode(bookmarks));
    return migrations;
  }

  static Future<void> forgetFolder(String path) async {
    final prefs = await PreferencesStore.open();
    final bookmarks = (await _bookmarks(prefs))..remove(path);
    await prefs.setString(bookmarksKey, jsonEncode(bookmarks));
    await _foldersChannel.invokeMethod<void>('releaseFolder', path);
  }

  static Future<void> fullscreen(bool enabled) async {
    if ({
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform)) {
      await _windowChannel.invokeMethod<void>('setFullscreen', enabled);
    } else if ({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }.contains(defaultTargetPlatform)) {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } else {
      throw UnsupportedError('Tela cheia indisponível nesta plataforma.');
    }
  }
}

List<String> mergeSelectedFolders(List<String> saved, List<String> selected) {
  final legacy = selected.map(legacyPathForTree).whereType<String>().toSet();
  return {
    ...saved.where(
      (folder) => !legacy.contains(folder.replaceFirst(RegExp(r'/+$'), '')),
    ),
    ...selected,
  }.toList();
}

String folderLabel(String source) {
  final uri = Uri.tryParse(source);
  if (uri?.scheme == 'content') {
    final id = uri!.pathSegments.lastOrNull ?? source;
    final name =
        id.split('/').where((part) => part.isNotEmpty).lastOrNull ?? id;
    return name.replaceFirst(RegExp(r'^primary:'), 'Armazenamento interno: ');
  }
  return source
          .replaceAll('\\', '/')
          .split('/')
          .where((part) => part.isNotEmpty)
          .lastOrNull ??
      source;
}

String? legacyPathForTree(String source) {
  final uri = Uri.tryParse(source);
  if (uri?.scheme != 'content' ||
      uri?.host != 'com.android.externalstorage.documents')
    return null;
  final parts = uri!.pathSegments;
  final treeIndex = parts.indexOf('tree');
  if (treeIndex < 0 || treeIndex + 1 >= parts.length) return null;
  final id = parts[treeIndex + 1];
  final colon = id.indexOf(':');
  if (colon < 0) return null;
  final volume = id.substring(0, colon);
  final relative = id.substring(colon + 1);
  return '${volume == 'primary' ? '/storage/emulated/0' : '/storage/$volume'}${relative.isEmpty ? '' : '/$relative'}';
}
