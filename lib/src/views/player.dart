import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../models/item.dart';
import '../services/native_media.dart';
import '../models/preferences.dart';
import 'artwork.dart';
import 'details.dart';
import 'tv_layout.dart';

class PlayerPage extends StatefulWidget {
  final MediaItem initialMedia;
  final List<MediaItem> library;
  final PlaybackSettings settings;
  const PlayerPage({
    super.key,
    required this.initialMedia,
    required this.library,
    required this.settings,
  });
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final progress = ValueNotifier<int>(0);
  final playerFocus = FocusNode(debugLabel: 'player');
  final playFocus = FocusNode(debugLabel: 'play-pause');
  final controlsVisible = ValueNotifier<bool>(true);
  Timer? hideTimer;
  bool switchingFullscreen = false;
  bool lastBuffering = false;
  int lastProgressMs = -1;
  late final List<MediaItem> queue;
  bool lastPlaying = false;
  AudioPlayer? audio;
  VideoPlayerController? video;
  StreamSubscription<PlayerState>? audioState;
  StreamSubscription<Duration>? audioPosition;
  late MediaItem item;
  late double speed;
  late double volume;
  bool loading = true;
  bool completed = false;
  bool fullscreen = false;
  String? error;
  int generation = 0;
  int queueIndex = -1;
  Future<void> pendingLoad = Future.value();

  bool get isAudio => item.type == MediaType.audio;
  // Reuse FVP on desktop for audio-only files as well as video. This avoids
  // a second native backend and incompatible legacy WinRT audio sources.
  bool get useAudioBackend =>
      isAudio &&
      !{
        TargetPlatform.linux,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  int get index => queueIndex;
  Duration get position => useAudioBackend
      ? audio?.position ?? Duration.zero
      : video?.value.position ?? Duration.zero;
  Duration get duration => useAudioBackend
      ? audio?.duration ?? Duration.zero
      : video?.value.duration ?? Duration.zero;
  bool get playing => useAudioBackend
      ? audio?.playing ?? false
      : video?.value.isPlaying ?? false;

  @override
  void initState() {
    super.initState();
    item = widget.initialMedia;
    queue = widget.library
        .where((e) => e.type == item.type)
        .toList(growable: false);
    speed = widget.settings.speed;
    volume = widget.settings.volume;
    load(item);
  }

  Future<void> release() async {
    final oldState = audioState;
    audioState = null;
    final oldPosition = audioPosition;
    audioPosition = null;
    final oldAudio = audio;
    audio = null;
    final oldVideo = video;
    video = null;
    try {
      await oldState?.cancel();
      await oldPosition?.cancel();
    } finally {
      try {
        await oldAudio?.dispose();
      } finally {
        await oldVideo?.dispose();
      }
    }
  }

  Future<void> load(MediaItem next) {
    if (!mounted) return Future.value();
    final token = ++generation;
    setState(() {
      item = next;
      queueIndex = queue.indexWhere((entry) => entry.id == next.id);
      loading = true;
      completed = false;
      error = null;
      lastPlaying = false;
      lastBuffering = false;
      lastProgressMs = -1;
    });
    revealControls();
    pendingLoad = pendingLoad.then((_) => open(next, token));
    return pendingLoad;
  }

  Future<void> open(MediaItem next, int token) async {
    try {
      if (!mounted || token != generation) return;
      await release();
      if (!mounted || token != generation) return;
      if (useAudioBackend) {
        final controller = AudioPlayer();
        audio = controller;
        await controller.setUrl(next.uri.toString());
        if (!mounted || token != generation) return;
        await controller.setSpeed(speed);
        if (!mounted || token != generation) return;
        await controller.setVolume(volume);
        if (!mounted || token != generation) return;
        audioState = controller.playerStateStream.listen((state) {
          if (!mounted || token != generation) return;
          setState(() {});
          if (state.processingState == ProcessingState.completed) finish();
          revealControls();
        });
        audioPosition = controller.positionStream.listen((_) {
          if (mounted && token == generation) progress.value++;
        });
        unawaited(
          controller.play().catchError((Object e) {
            if (mounted && token == generation)
              setState(() => error = 'Falha na reprodução: $e');
          }),
        );
      } else {
        final controller = next.isDocument
            ? VideoPlayerController.contentUri(next.uri)
            : VideoPlayerController.file(next.file!);
        video = controller;
        await controller.initialize();
        if (!mounted || token != generation) return;
        await controller.setPlaybackSpeed(speed);
        if (!mounted || token != generation) return;
        await controller.setVolume(volume);
        if (!mounted || token != generation) return;
        controller.addListener(() {
          if (!mounted || token != generation) return;
          if (controller.value.hasError) {
            final message =
                controller.value.errorDescription ??
                'Falha ao reproduzir o arquivo.';
            if (error != message) {
              setState(() {
                error = message;
                loading = false;
              });
              revealControls();
            }
            return;
          }
          final value = controller.value;
          final positionMs = value.position.inMilliseconds;
          if ((positionMs - lastProgressMs).abs() >= 200 || value.isCompleted) {
            lastProgressMs = positionMs;
            progress.value++;
          }
          if (lastPlaying != value.isPlaying ||
              lastBuffering != value.isBuffering) {
            lastPlaying = value.isPlaying;
            lastBuffering = value.isBuffering;
            setState(() {});
            revealControls();
          }
          if (controller.value.isCompleted) finish();
        });
        await controller.play();
      }
      if (mounted && token == generation) {
        setState(() => loading = false);
        if (TvLayout.of(context)) focusControls();
      }
    } catch (e) {
      if (mounted && token == generation)
        setState(() {
          loading = false;
          error = 'Não foi possível abrir este arquivo.\n$e';
        });
    }
  }

  void finish() {
    if (completed || loading) return;
    completed = true;
    if (widget.settings.autoNext && index >= 0 && index + 1 < queue.length) {
      load(queue[index + 1]);
    } else {
      setState(() {});
    }
  }

  Future<void> seek(Duration target) async {
    if (loading || error != null) return;
    revealControls();
    final token = generation;
    try {
      final safe = Duration(
        milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds),
      );
      completed = false;
      if (useAudioBackend) {
        await audio?.seek(safe);
      } else {
        await video?.seekTo(safe);
      }
    } catch (e) {
      if (mounted && token == generation) {
        revealControls();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível avançar a reprodução.'),
          ),
        );
      }
    }
  }

  Future<void> toggle() async {
    if (loading || error != null) return;
    final token = generation;
    final currentAudio = audio;
    final currentVideo = video;
    try {
      final restart = completed;
      if (restart) await seek(Duration.zero);
      if (!mounted || token != generation || error != null) return;
      if (useAudioBackend) {
        if (currentAudio == null) return;
        if (currentAudio.playing && !restart) {
          await currentAudio.pause();
        } else {
          unawaited(
            currentAudio.play().catchError((Object e) {
              if (mounted && token == generation) setState(() => error = '$e');
            }),
          );
        }
      } else {
        if (currentVideo == null) return;
        if (currentVideo.value.isPlaying && !restart) {
          await currentVideo.pause();
        } else {
          await currentVideo.play();
        }
      }
    } catch (e) {
      if (mounted && token == generation)
        setState(() => error = 'Falha na reprodução: $e');
    }
  }

  Future<void> changeVolume(double value) async {
    if (!mounted || loading || error != null) return;
    final token = generation;
    final previousVolume = volume;
    revealControls();
    setState(() => volume = value);
    try {
      if (useAudioBackend) {
        await audio?.setVolume(value);
      } else {
        await video?.setVolume(value);
      }
    } catch (_) {
      if (mounted && token == generation) {
        setState(() => volume = previousVolume);
        revealControls();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ajustar o volume.')),
        );
      }
    }
  }

  Future<void> changeSpeed(double value) async {
    if (!mounted || loading || error != null) return;
    final token = generation;
    revealControls();
    try {
      if (useAudioBackend) {
        await audio?.setSpeed(value);
      } else {
        await video?.setPlaybackSpeed(value);
      }
      if (mounted && token == generation) setState(() => speed = value);
    } catch (_) {
      if (mounted && token == generation)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Velocidade indisponível para este arquivo.'),
          ),
        );
    }
  }

  void focusControls() {
    revealControls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !loading && error == null) playFocus.requestFocus();
    });
  }

  KeyEventResult remoteKey(FocusNode node, KeyEvent event) {
    if (!TvLayout.of(context) || event is KeyUpEvent)
      return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      toggle();
      revealControls();
      return KeyEventResult.handled;
    }
    const arrows = [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ];
    if (arrows.contains(key)) {
      final needsFocus = !controlsVisible.value || playerFocus.hasPrimaryFocus;
      revealControls();
      if (needsFocus) {
        focusControls();
        return KeyEventResult.handled;
      }
    }
    if (playerFocus.hasPrimaryFocus &&
        {
          LogicalKeyboardKey.select,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.gameButtonA,
        }.contains(key)) {
      focusControls();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void revealControls() {
    if (!mounted) return;
    hideTimer?.cancel();
    controlsVisible.value = true;
    if (!isAudio && playing && error == null) {
      hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && playing && error == null) {
          if (TvLayout.of(context)) playerFocus.requestFocus();
          controlsVisible.value = false;
        }
      });
    }
  }

  /// Oculta os controles da tela imediatamente.
  void hideControls() {
    if (!mounted || isAudio) return;
    hideTimer?.cancel();
    controlsVisible.value = false;
    if (TvLayout.of(context)) {
      playerFocus.requestFocus();
    }
  }

  /// Alterna a visibilidade dos controles na tela ao clicar no vídeo.
  /// Funciona tanto com o vídeo pausado quanto rodando:
  /// - Se os botões estão visíveis: faz desaparecer da tela imediatamente.
  /// - Se os botões estão ocultos: chama os botões para a tela e, se estiver reproduzindo,
  ///   ativa o auto-hide após 3 segundos.
  void toggleControls() {
    if (!mounted || isAudio) return;
    if (controlsVisible.value) {
      hideControls();
    } else {
      revealControls();
    }
  }

  Future<void> setFullscreen(bool value) async {
    if (isAudio || switchingFullscreen || value == fullscreen) return;
    switchingFullscreen = true;
    try {
      await NativeMedia.fullscreen(value);
      if (!mounted) {
        if (value) await NativeMedia.fullscreen(false);
        return;
      }
      setState(() => fullscreen = value);
      revealControls();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível alterar a tela cheia.'),
          ),
        );
    } finally {
      switchingFullscreen = false;
    }
  }

  @override
  void dispose() {
    generation++;
    playerFocus.dispose();
    playFocus.dispose();
    hideTimer?.cancel();
    controlsVisible.dispose();
    progress.dispose();
    unawaited(
      pendingLoad.then((_) => release()).catchError((
        Object e,
        StackTrace stack,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'localflix',
            context: ErrorDescription('ao encerrar o player'),
          ),
        );
      }),
    );
    if (fullscreen)
      unawaited(NativeMedia.fullscreen(false).catchError((Object _) {}));
    super.dispose();
  }

  String time(Duration value) {
    final parts = [
      if (value.inHours > 0) value.inHours,
      value.inMinutes.remainder(60),
      value.inSeconds.remainder(60),
    ];
    return parts.map((v) => v.toString().padLeft(2, '0')).join(':');
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (fullscreen) {
          setFullscreen(false);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyF): () =>
          setFullscreen(!fullscreen),
      const SingleActivator(LogicalKeyboardKey.f11): () =>
          setFullscreen(!fullscreen),
      const SingleActivator(LogicalKeyboardKey.space): toggle,
      if (!TvLayout.of(context))
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            seek(position - const Duration(seconds: 10)),
      if (!TvLayout.of(context))
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            seek(position + const Duration(seconds: 10)),
    },
    child: Focus(
      focusNode: playerFocus,
      onKeyEvent: remoteKey,
      autofocus: true,
      child: PopScope(
        canPop: !fullscreen,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && fullscreen) setFullscreen(false);
        },
        child: Scaffold(
          appBar: fullscreen || (!isAudio && TvLayout.of(context))
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  title: Text(
                    isAudio ? 'Sua trilha sonora' : 'Sua sessão',
                    style: const TextStyle(fontSize: 18),
                  ),
                  actions: [
                    if (!isAudio)
                      IconButton(
                        tooltip: 'Tela cheia (F)',
                        onPressed: () => setFullscreen(true),
                        icon: const Icon(Icons.fullscreen),
                      ),
                    IconButton(
                      tooltip: 'Informações',
                      onPressed: () =>
                          showMediaDetails(context, item, (next) => load(next)),
                      icon: const Icon(Icons.info_outline),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
          body: SafeArea(
            child: fullscreen
                ? videoSurface()
                : LayoutBuilder(
                    builder: (context, size) {
                      if (!isAudio) return videoSurface();
                      final desktop = size.maxWidth >= 900;
                      final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
                      final artwork = Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkTheme
                                  ? const Color(0x55000000)
                                  : const Color(0x14000000),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: RepaintBoundary(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: MediaArtwork(item: item),
                            ),
                          ),
                        ),
                      );
                      final panel = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'AGORA REPRODUZINDO',
                            style: TextStyle(
                              color: Color(0xFFE51D35),
                              letterSpacing: 2,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.displayTitle,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          MediaFacts(item: item),
                          if (loading)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  Text(
                                    error!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => load(item),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          buildControls(onVideo: false),
                          const SizedBox(height: 20),
                          Text(
                            widget.settings.autoNext
                                ? 'Próximo conteúdo automático'
                                : 'Reprodução individual',
                            style: TextStyle(
                              color: isDarkTheme
                                  ? Colors.white38
                                  : const Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (index + 1 < queue.length)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Card(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.skip_next_rounded,
                                    color: isDarkTheme
                                        ? Colors.white70
                                        : const Color(0xFFE50914),
                                  ),
                                  title: Text(
                                    'A seguir',
                                    style: TextStyle(
                                      color: isDarkTheme
                                          ? Colors.white54
                                          : const Color(0xFF6B7280),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    queue[index + 1].displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onTap: loading
                                      ? null
                                      : () => load(queue[index + 1]),
                                ),
                              ),
                            ),
                        ],
                      );
                      return SingleChildScrollView(
                        padding: EdgeInsets.all(size.maxWidth >= 700 ? 32 : 18),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: desktop
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: artwork),
                                      const SizedBox(width: 48),
                                      Expanded(child: panel),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: 360,
                                        ),
                                        child: artwork,
                                      ),
                                      const SizedBox(height: 28),
                                      panel,
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    ),
  );
  Widget videoSurface() => MouseRegion(
    onHover: (_) {
      if (!controlsVisible.value) {
        revealControls();
      }
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggleControls,
      onDoubleTap: () => setFullscreen(!fullscreen),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video?.value.isInitialized == true)
              RepaintBoundary(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: video!.value.aspectRatio > 0
                        ? video!.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(video!),
                  ),
                ),
              ),
            if (loading || (video?.value.isBuffering == true && error == null))
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (error != null)
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 40,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => load(item),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            ValueListenableBuilder<bool>(
              valueListenable: controlsVisible,
              builder: (context, visible, _) => MouseRegion(
                cursor: visible
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.none,
                child: ExcludeFocus(
                  excluding: !visible,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: toggleControls,
                        child: Stack(
                        children: [
                          if (fullscreen || TvLayout.of(context))
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black87,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          tooltip: fullscreen
                                              ? 'Sair da tela cheia (Esc)'
                                              : 'Voltar à biblioteca',
                                          onPressed: () {
                                            if (fullscreen) {
                                              setFullscreen(false);
                                            } else {
                                              Navigator.of(context).maybePop();
                                            }
                                          },
                                          icon: const Icon(Icons.arrow_back),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.displayTitle,
                                            style: TextStyle(
                                              fontSize: TvLayout.of(context)
                                                  ? 22
                                                  : 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black],
                                ),
                              ),
                              child: SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    28,
                                    12,
                                    12,
                                  ),
                                  child: buildControls(onVideo: true),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget buildControls({bool onVideo = false}) {
    final enabled = !loading && error == null;
    final tv = TvLayout.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark || onVideo;

    final containerBg = isDark
        ? const Color(0xC80A0A10)
        : const Color(0xF2FFFFFF);
    final containerBorder = isDark
        ? const Color(0x35FFFFFF)
        : const Color(0x1F000000);
    final textPrimary = isDark ? Colors.white70 : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF374151);
    final speedBadgeBg = isDark ? const Color(0x28FFFFFF) : const Color(0x0E000000);
    final speedBadgeBorder = isDark ? const Color(0x20FFFFFF) : const Color(0x18000000);
    final speedBadgeText = isDark ? Colors.white : const Color(0xFF1F2937);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: containerBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x44000000)
                        : const Color(0x10000000),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra de Progresso Compacta
                  ValueListenableBuilder<int>(
                    valueListenable: progress,
                    builder: (context, value, child) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          ),
                          child: Slider(
                            divisions: tv && duration.inSeconds > 0
                                ? (duration.inSeconds / 10).ceil().clamp(1, 36000)
                                : null,
                            value: position.inMilliseconds
                                .clamp(0, duration.inMilliseconds)
                                .toDouble(),
                            max: duration.inMilliseconds > 0
                                ? duration.inMilliseconds.toDouble()
                                : 1,
                            onChanged: enabled && duration > Duration.zero
                                ? (v) => seek(Duration(milliseconds: v.round()))
                                : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                time(position),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                time(duration),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Linha Única Integrada e Compacta
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 500;
                      return Row(
                        children: [
                          // Seção Esquerda: Volume
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: volume == 0 ? 'Ativar som' : 'Mudo',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                iconSize: 18,
                                onPressed: enabled ? () => changeVolume(volume == 0 ? 1 : 0) : null,
                                icon: Icon(
                                  volume == 0
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: iconColor,
                                ),
                              ),
                              if (!compact)
                                SizedBox(
                                  width: 72,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2.5,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                                    ),
                                    child: Slider(
                                      value: volume,
                                      onChanged: enabled ? changeVolume : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          // Seção Central: Controles de Transporte
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                IconButton(
                                  tooltip: 'Anterior',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                  iconSize: 18,
                                  onPressed: !loading && index > 0
                                      ? () => load(queue[index - 1])
                                      : null,
                                  icon: Icon(Icons.skip_previous_rounded, color: iconColor),
                                ),
                              IconButton(
                                tooltip: 'Voltar 10s',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                iconSize: 20,
                                onPressed: enabled
                                    ? () => seek(position - const Duration(seconds: 10))
                                    : null,
                                icon: Icon(Icons.replay_10_rounded, color: iconColor),
                              ),
                              const SizedBox(width: 4),
                              // Botão Play / Pause Compacto
                              IconButton.filled(
                                focusNode: playFocus,
                                tooltip: completed
                                    ? 'Repetir'
                                    : playing
                                        ? 'Pausar'
                                        : 'Reproduzir',
                                onPressed: enabled ? toggle : null,
                                style: ButtonStyle(
                                  fixedSize: WidgetStatePropertyAll(
                                    Size.square(tv ? 48 : 42),
                                  ),
                                  minimumSize: WidgetStatePropertyAll(
                                    Size.square(tv ? 48 : 42),
                                  ),
                                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                                  backgroundColor: WidgetStateProperty.resolveWith(
                                    (states) => states.contains(WidgetState.disabled)
                                        ? Colors.white12
                                        : const Color(0xFFE50914),
                                  ),
                                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                                  shape: const WidgetStatePropertyAll(CircleBorder()),
                                  elevation: WidgetStateProperty.resolveWith(
                                    (states) => states.contains(WidgetState.focused) ? 8 : 3,
                                  ),
                                  shadowColor: const WidgetStatePropertyAll(Color(0x66E50914)),
                                ),
                                iconSize: 22,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Icon(
                                    completed
                                        ? Icons.replay_rounded
                                        : playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                    key: ValueKey(
                                      completed
                                          ? 'replay'
                                          : playing
                                              ? 'pause'
                                              : 'play',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Avançar 10s',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                iconSize: 20,
                                onPressed: enabled
                                    ? () => seek(position + const Duration(seconds: 10))
                                    : null,
                                icon: Icon(Icons.forward_10_rounded, color: iconColor),
                              ),
                              if (index >= 0 && index + 1 < queue.length)
                                IconButton(
                                  tooltip: 'Próximo',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                  iconSize: 18,
                                  onPressed: !loading && index >= 0 && index + 1 < queue.length
                                      ? () => load(queue[index + 1])
                                      : null,
                                  icon: Icon(Icons.skip_next_rounded, color: iconColor),
                                ),
                            ],
                          ),
                          const Spacer(),
                          // Seção Direita: Velocidade e Tela Cheia
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<double>(
                                tooltip: 'Velocidade',
                                enabled: enabled,
                                initialValue: speed,
                                onSelected: changeSpeed,
                                itemBuilder: (_) => [0.75, 1.0, 1.25, 1.5, 2.0]
                                    .map(
                                      (value) => PopupMenuItem(
                                        value: value,
                                        child: Text('${value}x'),
                                      ),
                                    )
                                    .toList(),
                                child: Container(
                                  height: 28,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: speedBadgeBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: speedBadgeBorder),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${speed}x',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: speedBadgeText,
                                    ),
                                  ),
                                ),
                              ),
                              if (!isAudio) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: fullscreen ? 'Sair da tela cheia' : 'Tela cheia',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                  iconSize: 20,
                                  onPressed: () => setFullscreen(!fullscreen),
                                  icon: Icon(
                                    fullscreen
                                        ? Icons.fullscreen_exit_rounded
                                        : Icons.fullscreen_rounded,
                                    color: iconColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
