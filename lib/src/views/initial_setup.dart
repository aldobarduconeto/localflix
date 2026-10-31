import 'dart:io';
import 'package:flutter/material.dart';
import 'app_theme.dart';

class SetupChoice {
  final String folderAccess;
  const SetupChoice(this.folderAccess);
}

class InitialSetup extends StatefulWidget {
  final int savedFolders;
  final Future<bool> Function() onRequestFolder;

  const InitialSetup({
    super.key,
    required this.savedFolders,
    required this.onRequestFolder,
  });

  @override
  State<InitialSetup> createState() => _InitialSetupState();
}

class _InitialSetupState extends State<InitialSetup> {
  bool busy = false;
  late int authorizedFolders;
  String? status;

  @override
  void initState() {
    super.initState();
    authorizedFolders = widget.savedFolders;
  }

  Future<void> request() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final granted = await widget.onRequestFolder();
      if (!mounted) return;
      setState(() {
        if (granted) authorizedFolders++;
        status = granted
            ? 'Pasta autorizada com sucesso!'
            : 'Nenhuma pasta selecionada. Você pode escolher a qualquer momento.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Não foi possível abrir o seletor. Tente novamente nas configurações.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasFolders = authorizedFolders > 0;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: LiquidGlassCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabeçalho de Boas-Vindas
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE50914), Color(0xFFB81D24)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66E50914),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_circle_filled_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const LiquidGlassBadge(
                            label: 'BEM-VINDO AO LOCALFLIX',
                            icon: Icons.auto_awesome,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sua Central de Mídia Privada',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cinema, séries e músicas locais com reprodução fluida e visual moderno.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),

                // Conteúdo rolável
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Destaques do aplicativo
                        Text(
                          'O que você pode fazer com o Localflix:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _featureRow(
                          context,
                          icon: Icons.movie_filter_outlined,
                          title: 'Reprodução local de alto desempenho',
                          desc: 'Assista a vídeos 4K/HDR e ouça suas faixas de áudio sem travamentos e com aceleração nativa.',
                        ),
                        const SizedBox(height: 10),
                        _featureRow(
                          context,
                          icon: Icons.auto_stories_outlined,
                          title: 'Capas, sinopses e metadados',
                          desc: 'Identificação inteligente de pôsteres e sinopses via TMDB e MusicBrainz para seu acervo.',
                        ),
                        const SizedBox(height: 10),
                        _featureRow(
                          context,
                          icon: Icons.lock_outline_rounded,
                          title: '100% Offline e Privado',
                          desc: 'Seus arquivos permanecem exclusivamente no seu aparelho. Sem anúncios e sem rastreamento.',
                        ),

                        const SizedBox(height: 22),

                        // Bloco de Permissões Requeridas
                        Text(
                          'PERMISSÕES NECESSÁRIAS',
                          style: TextStyle(
                            color: const Color(0xFFE50914),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0x14FFFFFF)
                                : const Color(0x0C000000),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: hasFolders
                                  ? const Color(0xFF10B981)
                                  : (isDark
                                      ? const Color(0x28FFFFFF)
                                      : const Color(0x18000000)),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    hasFolders
                                        ? Icons.check_circle_rounded
                                        : Icons.folder_shared_outlined,
                                    color: hasFolders
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFE50914),
                                    size: 26,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Acesso às Pastas de Mídia',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          hasFolders
                                              ? '$authorizedFolders pasta(s) autorizada(s) no sistema'
                                              : 'Necessário para indexar e reproduzir seus arquivos',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasFolders
                                                ? const Color(0xFF10B981)
                                                : (isDark
                                                    ? Colors.white60
                                                    : const Color(0xFF6B7280)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                Platform.isAndroid
                                    ? 'No Android, toque no botão abaixo, selecione a pasta dos seus filmes ou músicas e confirme em "Usar esta pasta".'
                                    : 'Selecione uma pasta com seus vídeos ou músicas para que o Localflix monte seu catálogo automaticamente.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: busy ? null : request,
                                icon: Icon(
                                  hasFolders
                                      ? Icons.create_new_folder_outlined
                                      : Icons.folder_open_rounded,
                                ),
                                label: Text(
                                  busy
                                      ? 'Aguardando seleção...'
                                      : (hasFolders
                                          ? 'Adicionar outra pasta'
                                          : 'Autorizar pasta de mídia agora'),
                                ),
                              ),
                              if (busy)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(),
                                ),
                              if (status != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    status!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: hasFolders
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.network_check_rounded,
                              size: 18,
                              color: Colors.white38,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Acesso à internet é opcional, usado somente para buscar capas e sinopses do TMDB ou MusicBrainz. Não requer permissões invasivas (câmera, microfone ou contatos).',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Ações Finais
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.pop(
                              context,
                              const SetupChoice('skipped'),
                            ),
                      child: Text(
                        hasFolders ? 'Fechar' : 'Pular por enquanto',
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.pop(
                              context,
                              SetupChoice(
                                hasFolders ? 'selected' : 'skipped',
                              ),
                            ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Começar a Usar'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x18FFFFFF) : const Color(0x0E000000),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFE50914)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
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
}
