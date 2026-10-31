import 'dart:io';
import 'package:flutter/material.dart';

import '../models/item.dart';
import '../models/preferences.dart';
import '../services/native_media.dart';
import 'app_theme.dart';
import 'sources.dart';

class SettingsPage extends StatefulWidget {
  final List<String> folders;
  final List<MediaItem> library;
  final bool scanning;
  final PlaybackSettings settings;
  final String? errorMessage;
  final DateTime? lastScan;
  final Future<void> Function() onAddFolder;
  final Future<void> Function(String) onRemoveFolder;
  final Future<void> Function() onRefresh;
  final Future<void> Function(PlaybackSettings) onSettingsChanged;
  final Future<void> Function()? onReviewAccess;
  final bool tmdbConnected;
  final bool tmdbLoading;
  final String tmdbStatus;
  final bool musicEnabled;
  final Future<void> Function(bool)? onMusicEnabled;
  final Future<void> Function(String)? onConnectTmdb;
  final Future<void> Function()? onSyncTmdb;

  const SettingsPage({
    super.key,
    required this.folders,
    required this.library,
    required this.scanning,
    required this.settings,
    this.errorMessage,
    this.lastScan,
    required this.onAddFolder,
    required this.onRemoveFolder,
    required this.onRefresh,
    required this.onSettingsChanged,
    this.onReviewAccess,
    this.tmdbConnected = false,
    this.tmdbLoading = false,
    this.tmdbStatus = '',
    this.musicEnabled = true,
    this.onMusicEnabled,
    this.onConnectTmdb,
    this.onSyncTmdb,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _tokenController = TextEditingController();
  bool _editingToken = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final videos = widget.library.where((e) => e.type == MediaType.video).length;
    final musics = widget.library.length - videos;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            children: [
              // Cabeçalho Principal com Liquid Glass
              LiquidGlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LiquidGlassBadge(
                          label: 'LOCALFLIX CONTROL CENTER',
                          icon: Icons.tune_rounded,
                        ),
                        const Spacer(),
                        if (widget.scanning)
                          Row(
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Sincronizando acervo...',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Configurações',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Personalize a aparência do liquid glass, gerencie pastas e aperfeiçoe sua experiência de reprodução.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Cards de métricas rápidas
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        _metricChip(context, 'Vídeos no Catálogo', '$videos', Icons.movie_outlined),
                        _metricChip(context, 'Músicas e Álbuns', '$musics', Icons.music_note_outlined),
                        _metricChip(context, 'Pastas Conectadas', '${widget.folders.length}', Icons.folder_special_outlined),
                        _metricChip(context, 'Motor de Reprodução', 'FVP / Hardware', Icons.bolt_rounded),
                      ],
                    ),
                  ],
                ),
              ),

              if (widget.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x22E50914),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x66E50914)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5263)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.errorMessage!,
                            style: const TextStyle(color: Color(0xFFFF8595), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ==========================================
              // SEÇÃO: APARÊNCIA E TEMA (LIQUID GLASS)
              // ==========================================
              _sectionHeader(
                title: 'Aparência & Interface',
                subtitle: 'Estilo Liquid Glass, modo claro, escuro para OLED e acompanhamento do sistema.',
                icon: Icons.palette_outlined,
              ),

              LiquidGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo de Tema',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Escolha entre o visual translúcido claro, o preto absoluto para telas OLED ou sincronize com o seu sistema operacional.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'system',
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Sistema'),
                        ),
                        ButtonSegment(
                          value: 'light',
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Modo Claro'),
                        ),
                        ButtonSegment(
                          value: 'oled',
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Escuro OLED'),
                        ),
                      ],
                      selected: {widget.settings.themeMode},
                      showSelectedIcon: false,
                      onSelectionChanged: (values) {
                        widget.onSettingsChanged(
                          widget.settings.copyWith(themeMode: values.single),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x10FFFFFF) : const Color(0x08000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.settings.themeMode == 'oled'
                                ? Icons.battery_charging_full_rounded
                                : (widget.settings.themeMode == 'light'
                                    ? Icons.wb_sunny_outlined
                                    : Icons.sync_rounded),
                            size: 20,
                            color: const Color(0xFFE50914),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.settings.themeMode == 'oled'
                                  ? 'Escuro OLED: Fundo #000000 absoluto, perfeito para telas AMOLED/OLED. Desliga os pixels pretos e economiza energia.'
                                  : (widget.settings.themeMode == 'light'
                                      ? 'Modo Claro: Estilo Liquid Glass límpido com reflexos cristalinos e alto contraste para ambientes iluminados.'
                                      : 'Acompanhar Sistema: Alterna dinamicamente entre tema claro e escuro OLED de acordo com a configuração do aparelho.'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Modo de Exibição',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Alterne a interface para mouse/teclado ou otimizada para TV/controle remoto.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.computer_rounded),
                            label: Text('Desktop (Mouse / Teclado)'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.tv_rounded),
                            label: Text('Interface TV (Controle Remoto)'),
                          ),
                        ],
                        selected: {widget.settings.desktopTvMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (values) => widget.onSettingsChanged(
                          widget.settings.copyWith(desktopTvMode: values.single),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ==========================================
              // SEÇÃO: BIBLIOTECA & PASTAS LOCAIS
              // ==========================================
              _sectionHeader(
                title: 'Biblioteca & Pastas Locais',
                subtitle: 'Gerencie os diretórios do seu computador ou celular onde suas mídias estão salvas.',
                icon: Icons.folder_copy_outlined,
              ),

              LiquidGlassCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x1AE50914),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.create_new_folder_outlined, color: Color(0xFFE50914)),
                      ),
                      title: const Text('Adicionar nova pasta de mídia', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Selecione diretórios contendo seus filmes, séries ou músicas.'),
                      trailing: FilledButton.icon(
                        onPressed: widget.scanning ? null : widget.onAddFolder,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar'),
                      ),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.sync_rounded),
                      ),
                      title: Text(
                        widget.scanning ? 'Sincronizando acervo...' : 'Atualizar acervo agora',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        widget.lastScan == null
                            ? 'Clique para varrer as pastas e detectar novos arquivos de mídia.'
                            : 'Última varredura realizada às ${widget.lastScan!.hour.toString().padLeft(2, '0')}:${widget.lastScan!.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: widget.scanning
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : OutlinedButton.icon(
                              onPressed: widget.onRefresh,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Sincronizar'),
                            ),
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.manage_search_rounded),
                      ),
                      title: const Text('Buscar novas mídias ao iniciar o aplicativo', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Faz a varredura automática dos diretórios sempre que o Localflix é aberto.'),
                      value: widget.settings.scanOnStartup,
                      onChanged: widget.scanning
                          ? null
                          : (v) => widget.onSettingsChanged(
                              widget.settings.copyWith(scanOnStartup: v),
                            ),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.verified_user_outlined),
                      ),
                      title: const Text('Revisar permissões e tela de boas-vindas', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Reveja a introdução do app e o status das autorizações concedidas.'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.scanning ? null : widget.onReviewAccess,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Lista de Pastas Adicionadas
              if (widget.folders.isEmpty)
                LiquidGlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.folder_off_outlined, size: 44, color: Colors.white38),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenhuma pasta adicionada ainda.',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Adicione a pasta onde estão seus filmes e músicas para começar a usar o Localflix.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: widget.scanning ? null : widget.onAddFolder,
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text('Selecionar Pasta de Mídia'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'PASTAS CONECTADAS (${widget.folders.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    for (final path in widget.folders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LiquidGlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          borderRadius: 16,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0x1AE50914),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.folder_rounded, color: Color(0xFFE50914), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      folderLabel(path),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      path.startsWith('content://')
                                          ? 'Pasta autorizada pelo Android • Acesso contínuo com subpastas'
                                          : path,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (Platform.isAndroid)
                                IconButton(
                                  tooltip: 'Reautorizar pasta',
                                  icon: const Icon(Icons.autorenew_rounded),
                                  onPressed: widget.scanning ? null : widget.onAddFolder,
                                ),
                              IconButton(
                                tooltip: 'Remover da biblioteca',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: widget.scanning ? null : () => widget.onRemoveFolder(path),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Remover uma pasta apenas desconecta do catálogo Localflix. Seus arquivos de vídeo e áudio continuam intactos no disco.',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ),
                  ],
                ),

              // ==========================================
              // SEÇÃO: PLAYER & REPRODUÇÃO
              // ==========================================
              _sectionHeader(
                title: 'Player & Reprodução',
                subtitle: 'Configurações de reprodução de vídeo, áudio e controles inteligentes de tela.',
                icon: Icons.play_circle_outline_rounded,
              ),

              LiquidGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.skip_next_rounded),
                      ),
                      title: const Text('Reproduzir próximo automaticamente', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Ao término de um vídeo ou música, continua com a próxima mídia da lista.'),
                      value: widget.settings.autoNext,
                      onChanged: (v) => widget.onSettingsChanged(
                        widget.settings.copyWith(autoNext: v),
                      ),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.speed_rounded),
                      ),
                      title: const Text('Velocidade de reprodução inicial', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Velocidade padrão aplicada ao iniciar um novo vídeo ou música.'),
                      trailing: SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 0.75, label: Text('0.75x')),
                          ButtonSegment(value: 1.0, label: Text('1.0x')),
                          ButtonSegment(value: 1.25, label: Text('1.25x')),
                          ButtonSegment(value: 1.5, label: Text('1.5x')),
                          ButtonSegment(value: 2.0, label: Text('2.0x')),
                        ],
                        selected: {widget.settings.speed},
                        showSelectedIcon: false,
                        onSelectionChanged: (values) => widget.onSettingsChanged(
                          widget.settings.copyWith(speed: values.single),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.volume_up_rounded),
                      ),
                      title: Row(
                        children: [
                          const Text('Volume inicial padrão', style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(
                            '${(widget.settings.volume * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE50914)),
                          ),
                        ],
                      ),
                      subtitle: Slider(
                        value: widget.settings.volume,
                        divisions: 20,
                        label: '${(widget.settings.volume * 100).round()}%',
                        onChanged: (v) => widget.onSettingsChanged(
                          widget.settings.copyWith(volume: v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Destaque da função de toque no player solicitada
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x1AE50914),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x44E50914)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.touch_app_rounded, color: Color(0xFFE50914), size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Controle por Toque/Clique no Vídeo: Ao clicar na tela com o vídeo pausado ou rodando, os botões e a barra de controle desaparecem ou reaparecem instantaneamente.',
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ==========================================
              // SEÇÃO: METADADOS & SERVIÇOS ONLINE
              // ==========================================
              _sectionHeader(
                title: 'Capas & Metadados Online',
                subtitle: 'Conexão com TMDB para sinopses de cinema e MusicBrainz para capas de álbuns musicais.',
                icon: Icons.cloud_sync_outlined,
              ),

              SourcesCard(
                connected: widget.tmdbConnected,
                busy: widget.tmdbLoading,
                status: widget.tmdbStatus,
                musicEnabled: widget.musicEnabled,
                onMusicEnabled: widget.onMusicEnabled,
                onConnect: widget.onConnectTmdb,
                onSync: widget.onSyncTmdb,
              ),

              // ==========================================
              // SEÇÃO: NOMENCLATURA & CAPAS LOCAIS
              // ==========================================
              _sectionHeader(
                title: 'Capas e Imagens Locais (Offline)',
                subtitle: 'Saiba como nomear imagens para reconhecimento visual 100% offline.',
                icon: Icons.image_search_outlined,
              ),

              LiquidGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fileTipRow(
                      icon: Icons.movie_outlined,
                      title: 'Filmes Individuais',
                      desc: 'Coloque a imagem com o mesmo nome do vídeo (Ex: Matrix.jpg junto de Matrix.mp4).',
                    ),
                    const SizedBox(height: 12),
                    _fileTipRow(
                      icon: Icons.tv_rounded,
                      title: 'Séries e Álbuns Musicais',
                      desc: 'Coloque um arquivo poster.jpg ou cover.jpg dentro da pasta onde estão os episódios ou faixas.',
                    ),
                    const SizedBox(height: 12),
                    _fileTipRow(
                      icon: Icons.wallpaper_rounded,
                      title: 'Banners e Imagens de Fundo',
                      desc: 'Nomeie como fanart.jpg, backdrop.jpg ou NomeDoFilme-banner.jpg para o destaque principal.',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Formatos suportados: JPG, JPEG, PNG e WebP.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const SourceCredits(),

              // ==========================================
              // SEÇÃO: PERMISSÕES & PRIVACIDADE
              // ==========================================
              _sectionHeader(
                title: 'Permissões & Privacidade',
                subtitle: 'Transparência total: seus dados e arquivos nunca saem do seu aparelho.',
                icon: Icons.security_rounded,
              ),

              LiquidGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _permStatusRow(
                      title: 'Acesso às Pastas de Mídia',
                      status: widget.folders.isNotEmpty
                          ? '${widget.folders.length} pasta(s) autorizada(s)'
                          : 'Aguardando seleção de pasta',
                      granted: widget.folders.isNotEmpty,
                    ),
                    const SizedBox(height: 12),
                    _permStatusRow(
                      title: 'Conexão com a Internet',
                      status: widget.tmdbConnected
                          ? 'Ativa (TMDB & MusicBrainz conectados)'
                          : 'Opcional (usada apenas para capas online)',
                      granted: true,
                    ),
                    const SizedBox(height: 12),
                    _permStatusRow(
                      title: 'Aceleração de Hardware GPU',
                      status: 'Ativa via FVP / libmpv',
                      granted: true,
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Privacidade Absoluta: O Localflix não possui telemetria, não monitora seus hábitos e não envia seus arquivos para a internet. As consultas de capas enviam estritamente os nomes dos filmes ou músicas para o TMDB/MusicBrainz.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ==========================================
              // SEÇÃO: SOBRE O LOCALFLIX
              // ==========================================
              _sectionHeader(
                title: 'Sobre o Localflix',
                subtitle: 'Informações de versão e atalhos de teclado.',
                icon: Icons.info_outline_rounded,
              ),

              LiquidGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFFB81D24)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Localflix v1.0.0',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Player de mídia local cinematográfico • Design Liquid Glass',
                              style: TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Atalhos de Teclado no Player:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        Chip(label: Text('Espaço: Play / Pausa')),
                        Chip(label: Text('Clique no Vídeo: Mostrar / Ocultar Controles')),
                        Chip(label: Text('F: Tela Cheia')),
                        Chip(label: Text('Esc: Sair da Tela Cheia / Voltar')),
                        Chip(label: Text('Setas ← / →: Avançar / Retroceder 10s')),
                        Chip(label: Text('Setas ↑ / ↓: Volume')),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 32, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x1AE50914),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFE50914), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white54
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _metricChip(BuildContext context, String title, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x14FFFFFF) : const Color(0x0C000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x20FFFFFF) : const Color(0x12000000),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE50914)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fileTipRow({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFFE50914)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _permStatusRow({
    required String title,
    required String status,
    required bool granted,
  }) =>
      Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 18,
            color: granted ? const Color(0xFF10B981) : Colors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: granted ? const Color(0xFF10B981) : Colors.amber,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}
