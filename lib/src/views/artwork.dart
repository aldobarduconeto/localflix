import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/item.dart';
import '../services/native_media.dart';

class MediaArtwork extends StatelessWidget {
  final MediaItem? item;
  final bool banner;
  const MediaArtwork({super.key, this.item, this.banner = false});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final width = size.maxWidth.isFinite ? size.maxWidth : 400;
      final decodeWidth = (width * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(100, banner ? 1920 : 800);
      final local = banner
          ? item?.bannerPath ?? item?.artworkPath
          : item?.artworkPath;
      final remote = item?.metadata?.image(banner);
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final fallback = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF381016), Color(0xFF1C1C22), Color(0xFF0F0F14)]
                : const [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFFB0BDCE)],
          ),
        ),
        child: Center(
          child: Icon(
            item?.type == MediaType.audio
                ? Icons.album_outlined
                : Icons.local_movies_outlined,
            size: banner ? 88 : 48,
            color: isDark ? Colors.white24 : const Color(0x40000000),
          ),
        ),
      );
      Widget network() => remote == null
          ? fallback
          : Image.network(
              remote,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: decodeWidth,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, synchronous) =>
                  frame == null ? fallback : child,
              errorBuilder: (_, error, stack) => fallback,
            );
      return RepaintBoundary(
        child: local == null
            ? network()
            : local.startsWith('content://')
            ? _DocumentArtwork(
                uri: local,
                width: decodeWidth,
                fallback: network(),
              )
            : Image.file(
                File(local),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: decodeWidth,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, error, stack) => network(),
              ),
      );
    },
  );
}

class _DocumentArtwork extends StatefulWidget {
  final String uri;
  final int width;
  final Widget fallback;
  const _DocumentArtwork({
    required this.uri,
    required this.width,
    required this.fallback,
  });
  @override
  State<_DocumentArtwork> createState() => _DocumentArtworkState();
}

class _DocumentArtworkState extends State<_DocumentArtwork> {
  late Future<Uint8List?> bytes;
  int get width => widget.width <= 400
      ? 400
      : widget.width <= 800
      ? 800
      : 1280;
  @override
  void initState() {
    super.initState();
    bytes = NativeMedia.artwork(widget.uri, width);
  }

  @override
  void didUpdateWidget(covariant _DocumentArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri || oldWidget.width != widget.width) {
      bytes = NativeMedia.artwork(widget.uri, width);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (context, snapshot) => snapshot.data == null
        ? widget.fallback
        : Image.memory(
            snapshot.data!,
            cacheWidth: widget.width,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, error, stack) => widget.fallback,
          ),
  );
}
