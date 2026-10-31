import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'services/preferences_store.dart';

import 'models/item.dart';
import 'models/library.dart';
import 'models/metadata.dart';
import 'models/preferences.dart';
import 'services/tmdb.dart';
import 'services/musicbrainz.dart';
import 'services/native_media.dart';

import 'package:flutter/services.dart';

import 'views/app_theme.dart';
import 'views/home.dart';
import 'views/player.dart';
import 'views/settings.dart';
import 'views/tv_layout.dart';
import 'views/initial_setup.dart';

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final List<String> folders = [];
  List<MediaItem> library = [];
  PlaybackSettings settings = const PlaybackSettings();
  TmdbService? tmdb;
  final musicbrainz = MusicBrainzService();
  bool musicEnabled = true;
  String credential = const String.fromEnvironment('TMDB_TOKEN');
  String tmdbStatus = 'Conecte o TMDB para descobrir capas e informações.';
  bool metadataLoading = false;
  int syncGeneration = 0;
  int page = 0;
  bool scanning = false;
  bool choosingFolder = false;
  bool television = false;
  bool loading = true;
  bool setupCompleted = false;
  bool setupShowing = false;
  bool recoveringFolders = false;
  bool rescanRequested = false;
  String? errorMessage;
  DateTime? lastScan;
  Future<void> preferenceWrite = Future.value();
  int preferenceRevision = 0;
  PlaybackSettings? persistedSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restore();
    if (Platform.isAndroid) {
      NativeMedia.isTelevision()
          .then((value) {
            if (mounted) setState(() => television = value);
          })
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    syncGeneration++;
    tmdb?.close();
    musicbrainz.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading && !choosingFolder) {
      unawaited(recoverFolderSelection());
    }
  }

  Future<bool> recoverFolderSelection() async {
    if (!Platform.isAndroid || recoveringFolders || !mounted) return false;
    recoveringFolders = true;
    try {
      final recovered = await NativeMedia.recoverFolders(folders, saveFolders);
      if (recovered && mounted && !loading) unawaited(scanLibrary());
      return recovered;
    } catch (_) {
      message(
        'Não foi possível recuperar a pasta selecionada. Tente novamente nas configurações.',
      );
      return false;
    } finally {
      recoveringFolders = false;
    }
  }

  Future<void> restore() async {
    String? accessWarning;
    var recoveredSelection = false;
    try {
      final prefs = await PreferencesStore.open();
      final service = TmdbService(credential);
      await Future.wait([service.restore(prefs), musicbrainz.restore(prefs)]);
      if (!mounted) {
        service.close();
        return;
      }
      final values = await prefs.getAll(
        allowList: {
          'library_folders',
          'music_metadata_enabled',
          'scan_on_startup',
          'auto_next',
          'speed',
          'volume',
          'desktop_tv_mode',
          'theme_mode',
          'initial_setup_completed_v1',
        },
      );
      if (NativeMedia.isApple) {
        try {
          final migrations = await NativeMedia.restoreFolders(prefs);
          final saved = values['library_folders'];
          if (saved is List && migrations.isNotEmpty) {
            final updated = saved
                .whereType<String>()
                .map((path) => migrations[path] ?? path)
                .toSet()
                .toList();
            await prefs.setStringList('library_folders', updated);
            values['library_folders'] = updated;
          }
        } catch (_) {
          accessWarning = 'Não foi possível restaurar o acesso às pastas. Revise as autorizações nas configurações.';
        }
      }
      if (!mounted) {
        service.close();
        return;
      }
      tmdb = service;
      setState(() {
        folders
          ..clear()
          ..addAll(
            values['library_folders'] is List
                ? (values['library_folders'] as List).whereType<String>()
                : const <String>[],
          );
        settings = PlaybackSettings.fromValues(values);
        persistedSettings = settings;
        musicEnabled = values['music_metadata_enabled'] != false;
        setupCompleted = values['initial_setup_completed_v1'] == true;
      });
      recoveredSelection = await recoverFolderSelection();
    } catch (_) {
      if (mounted)
        setState(
          () => errorMessage = 'Não foi possível restaurar a biblioteca.',
        );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          if (accessWarning != null)
            errorMessage = [
              errorMessage,
              accessWarning,
            ].whereType<String>().join('\n');
        });
        // Render the app before reading a potentially slow document provider.
        if (folders.isNotEmpty &&
            (settings.scanOnStartup || recoveredSelection)) {
          unawaited(scanLibrary());
        }
        if (!setupCompleted)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(showInitialSetup());
          });
      }
    }
  }

  Future<void> showInitialSetup({bool force = false}) async {
    if (!mounted || loading || setupShowing || (setupCompleted && !force))
      return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    setupShowing = true;
    try {
      final choice = await showDialog<SetupChoice>(
        context: context,
        barrierDismissible: false,
        builder: (_) => InitialSetup(
          savedFolders: folders.length,
          onRequestFolder: chooseFolder,
        ),
      );
      if (choice == null || !mounted) return;
      final prefs = await PreferencesStore.open();
      await prefs.setString(
        'initial_setup_folder_choice_v1',
        choice.folderAccess,
      );
      await prefs.setString(
        'initial_setup_platform_v1',
        Platform.operatingSystem,
      );
      await prefs.setInt(
        'initial_setup_updated_at_v1',
        DateTime.now().millisecondsSinceEpoch,
      );
      // Completion is written last so an interrupted save can be retried.
      await prefs.setBool('initial_setup_completed_v1', true);
      if (mounted) {
        setState(() => setupCompleted = true);
        unawaited(syncMetadata());
      }
    } catch (_) {
      message(
        'Não foi possível salvar a configuração inicial. Revise os acessos nas configurações.',
      );
    } finally {
      setupShowing = false;
    }
  }

  void message(String text) =>
      messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> updateSettings(PlaybackSettings value) async {
    if (!mounted || loading) return;
    setState(() => settings = value);
    final revision = ++preferenceRevision;
    // Serialize writes and skip obsolete queued snapshots from rapid sliders.
    preferenceWrite = preferenceWrite
        .then((_) async {
          if (revision != preferenceRevision) return;
          final prefs = await PreferencesStore.open();
          if (revision != preferenceRevision) return;
          await value.save(prefs, previous: persistedSettings);
          persistedSettings = value;
        })
        .catchError((Object _) {
          message('Não foi possível salvar as preferências.');
        });
    await preferenceWrite;
  }

  Future<void> saveFolders(List<String> value) async {
    final prefs = await PreferencesStore.open();
    await prefs.setStringList('library_folders', value);
    if (mounted)
      setState(() {
        folders
          ..clear()
          ..addAll(value);
      });
  }

  Future<void> addFolder() async {
    await chooseFolder();
  }

  Future<bool> chooseFolder() async {
    if (scanning || loading || choosingFolder) return false;
    setState(() => choosingFolder = true);
    try {
      final path = await NativeMedia.pickFolder();
      if (!mounted || path == null || path.trim().isEmpty) return false;
      if (folders.contains(path)) {
        if (Platform.isAndroid || NativeMedia.isApple) {
          if (Platform.isAndroid) await NativeMedia.acknowledgeFolders([path]);
          message('Acesso à pasta renovado. Atualizando biblioteca…');
          unawaited(scanLibrary());
          return true;
        }
        message('Essa pasta já foi adicionada.');
        return true;
      }
      await saveFolders(mergeSelectedFolders(folders, [path]));
      if (Platform.isAndroid) await NativeMedia.acknowledgeFolders([path]);
      unawaited(scanLibrary());
      return true;
    } on PlatformException catch (e) {
      message(
        e.message ?? 'Não foi possível autorizar a pasta. Tente novamente.',
      );
    } catch (_) {
      message('Não foi possível adicionar a pasta.');
    } finally {
      if (mounted) setState(() => choosingFolder = false);
    }
    return false;
  }

  Future<void> removeFolder(String path) async {
    if (scanning || loading || choosingFolder) return;
    try {
      await saveFolders(folders.where((folder) => folder != path).toList());
      if (NativeMedia.isApple) {
        try {
          await NativeMedia.forgetFolder(path);
        } catch (_) {
          message(
            'Pasta removida da biblioteca; não foi possível liberar a autorização salva.',
          );
        }
      }
      await scanLibrary();
    } catch (_) {
      message('Não foi possível remover a pasta.');
    }
  }

  Future<void> scanLibrary() async {
    if (!mounted) return;
    if (scanning) {
      rescanRequested = true;
      return;
    }
    syncGeneration++;
    setState(() {
      scanning = true;
      metadataLoading = false;
      errorMessage = null;
    });
    try {
      final result = await scanFolders(List.of(folders));
      if (!mounted) return;
      if (result.folderMigrations.isNotEmpty) {
        try {
          await saveFolders(
            folders
                .map((folder) => result.folderMigrations[folder] ?? folder)
                .toSet()
                .toList(),
          );
        } catch (_) {
          message(
            'Biblioteca carregada, mas não foi possível salvar as autorizações recuperadas.',
          );
        }
        if (!mounted) return;
      }
      setState(() {
        library = result.items
            .map(
              (item) => item.type == MediaType.video
                  ? item.withMetadata(tmdb?.cached(item.queryName))
                  : item.withMetadata(
                      musicbrainz.cached(MusicQuery.parse(item.name)),
                    ),
            )
            .toList();
        errorMessage = result.warnings.isEmpty
            ? null
            : result.warnings.join('\n');
        lastScan = DateTime.now();
      });
    } catch (_) {
      if (mounted)
        setState(
          () => errorMessage = 'Não foi possível atualizar a biblioteca.',
        );
    } finally {
      if (mounted) setState(() => scanning = false);
    }
    if (mounted && rescanRequested) {
      rescanRequested = false;
      unawaited(scanLibrary());
    } else if (mounted) {
      unawaited(syncMetadata());
    }
  }

  Future<void> connectTmdb(String value) async {
    if (metadataLoading) return;
    final service = TmdbService(value.trim());
    try {
      if (value.trim().isNotEmpty) await service.validate();
      final prefs = await PreferencesStore.open();
      await Future.wait([service.restore(prefs), musicbrainz.restore(prefs)]);
      if (!mounted) {
        service.close();
        return;
      }
      syncGeneration++;
      tmdb?.close();
      tmdb = service;
      setState(() {
        credential = value.trim();
        tmdbStatus = credential.isEmpty
            ? 'TMDB desconectado. Dados em cache foram mantidos.'
            : 'Conectado ao TMDB.';
      });
      unawaited(syncMetadata());
    } catch (e) {
      service.close();
      rethrow;
    }
  }

  Future<void> setMusicEnabled(bool value) async {
    final prefs = await PreferencesStore.open();
    await prefs.setBool('music_metadata_enabled', value);
    if (!mounted) return;
    syncGeneration++;
    setState(() {
      musicEnabled = value;
      metadataLoading = false;
    });
    if (value) await syncMetadata();
  }

  Future<void> syncMetadata({bool force = false}) async {
    if (metadataLoading || scanning || !mounted || !setupCompleted) return;
    final token = ++syncGeneration;
    final snapshot = List<MediaItem>.of(library);
    if (snapshot.isEmpty) return;
    setState(() {
      metadataLoading = true;
      tmdbStatus = 'Atualizando capas e informações…';
    });
    var done = 0;
    var lastPaint = DateTime.now();
    final failures = <String>{};
    final failedTypes = <MediaType>{};
    final results = <String, MediaMetadata>{};
    for (final item in snapshot) {
      if (!mounted || token != syncGeneration) return;
      if (item.type == MediaType.video && (credential.isEmpty || tmdb == null))
        continue;
      if (item.type == MediaType.audio && !musicEnabled) continue;
      if (failedTypes.contains(item.type)) continue;
      try {
        final data = item.type == MediaType.video
            ? await tmdb!.lookup(item.queryName, force: force)
            : await musicbrainz.lookup(MusicQuery.parse(item.name));
        if (data != null) results[item.id] = data;
      } catch (e) {
        failures.add(
          e is TmdbException ? e.message : 'Falha na busca de informações.',
        );
        // Avoid hammering an unavailable provider for every file.
        failedTypes.add(item.type);
        continue;
      }
      done++;
      final now = DateTime.now();
      if (mounted &&
          token == syncGeneration &&
          (done % 8 == 0 || now.difference(lastPaint).inMilliseconds >= 300)) {
        lastPaint = now;
        setState(() {
          library = library
              .map(
                (entry) => results.containsKey(entry.id)
                    ? entry.withMetadata(results[entry.id])
                    : entry,
              )
              .toList();
          tmdbStatus = 'Informações • $done arquivos consultados';
        });
      }
    }
    if (!mounted || token != syncGeneration) return;
    setState(() {
      library = library
          .map(
            (item) => results.containsKey(item.id)
                ? item.withMetadata(results[item.id])
                : item,
          )
          .toList();
      metadataLoading = false;
      final matched = library.where((e) => e.metadata != null).length;
      tmdbStatus =
          credential.isEmpty && library.any((e) => e.type == MediaType.video)
          ? 'Conecte o TMDB para buscar pôsteres de filmes e séries. $matched arquivos identificados.'
          : failures.isEmpty
          ? '$matched de ${library.length} arquivos identificados. Capas locais têm prioridade.'
          : failures.join('\n');
    });
    try {
      final prefs = await PreferencesStore.open();
      await tmdb?.persist(prefs);
      await musicbrainz.persist(prefs);
    } catch (_) {
      if (mounted)
        message('Dados carregados, mas não foi possível salvar o cache.');
    }
  }

  void playMedia(MediaItem item) => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerPage(
        initialMedia: item,
        library: List.of(library),
        settings: settings,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ThemeMode themeMode;
    switch (settings.themeMode) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'oled':
        themeMode = ThemeMode.dark;
        break;
      default:
        themeMode = ThemeMode.system;
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Localflix',
      theme: liquidGlassLightTheme,
      darkTheme: liquidGlassOledTheme,
      themeMode: themeMode,
    // Flutter Windows #175041: reparented accessibility nodes can crash the
    // native engine. Keep a single semantics root until the engine is fixed.
    // Builds needing screen readers can explicitly opt back in.
    builder: (context, child) => ExcludeSemantics(
      excluding:
          Platform.isWindows &&
          !const bool.fromEnvironment('WINDOWS_ACCESSIBILITY'),
      child: TvFrame(
        television: Platform.isWindows || Platform.isLinux || Platform.isMacOS
            ? settings.desktopTvMode
            : television,
        onBack: () async {
          final popped = await navigatorKey.currentState?.maybePop() ?? false;
          if (!popped && mounted && page != 0) setState(() => page = 0);
        },
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: LayoutBuilder(
      builder: (context, constraints) {
        final tv = TvLayout.of(context);
        final desktop = tv || constraints.maxWidth >= 1000;
        final content = IndexedStack(
          index: page,
          children: [
            HomePage(
              tmdb: tmdb,
              library: library,
              scanning: scanning || loading || choosingFolder,
              errorMessage: errorMessage,
              metadataStatus: metadataLoading ? tmdbStatus : null,
              onOpenSettings: () => setState(() => page = 1),
              onPlay: playMedia,
            ),
            SettingsPage(
              folders: folders,
              library: library,
              scanning: scanning || loading || choosingFolder,
              settings: settings,
              errorMessage: errorMessage,
              lastScan: lastScan,
              onReviewAccess: () => showInitialSetup(force: true),
              onAddFolder: addFolder,
              onRemoveFolder: removeFolder,
              onRefresh: scanLibrary,
              onSettingsChanged: updateSettings,
              tmdbConnected: credential.isNotEmpty,
              musicEnabled: musicEnabled,
              onMusicEnabled: setMusicEnabled,
              tmdbLoading: metadataLoading,
              tmdbStatus: tmdbStatus,
              onConnectTmdb: connectTmdb,
              onSyncTmdb: () => syncMetadata(force: true),
            ),
          ],
        );
        return PopScope(
          canPop: page == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && page != 0) setState(() => page = 0);
          },
          child: Scaffold(
            body: Row(
              children: [
                if (desktop)
                  SafeArea(
                    child: NavigationRail(
                      selectedIndex: page,
                      extended: tv || constraints.maxWidth >= 1400,
                      minExtendedWidth: tv ? 200 : 256,
                      minWidth: 88,
                      backgroundColor: null,
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Color(0xFFE51D35),
                          size: 36,
                        ),
                      ),
                      onDestinationSelected: (value) =>
                          setState(() => page = value),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.video_library_outlined),
                          selectedIcon: Icon(Icons.video_library),
                          label: Text('Biblioteca'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: Text('Configurações'),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: content),
              ],
            ),
            bottomNavigationBar: desktop
                ? null
                : NavigationBar(
                    selectedIndex: page,
                    onDestinationSelected: (value) =>
                        setState(() => page = value),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.video_library_outlined),
                        selectedIcon: Icon(Icons.video_library),
                        label: 'Biblioteca',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: 'Configurações',
                      ),
                    ],
                  ),
          ),
        );
      },
    ),
    );
  }
}
