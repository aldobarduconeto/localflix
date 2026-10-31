import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';

class SourcesCard extends StatefulWidget {
  final bool connected;
  final bool busy;
  final String status;
  final bool musicEnabled;
  final Future<void> Function(bool)? onMusicEnabled;
  final Future<void> Function(String)? onConnect;
  final Future<void> Function()? onSync;
  const SourcesCard({
    super.key,
    required this.connected,
    required this.busy,
    required this.status,
    required this.musicEnabled,
    this.onMusicEnabled,
    this.onConnect,
    this.onSync,
  });
  @override
  State<SourcesCard> createState() => _SourcesCardState();
}

class _SourcesCardState extends State<SourcesCard> {
  Future<void> connect() async {
    final controller = TextEditingController();
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Conectar ao TMDB'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Insira seu token de leitura ou chave da API. A credencial será usada somente nesta sessão.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Credencial TMDB',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(height: 12),
                const SelectableText(
                  'Crie sua credencial em:\nhttps://www.themoviedb.org/settings/api',
                  style: TextStyle(color: Theme.of(dialog).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (controller.text.trim().isEmpty) {
                        update(() => error = 'Informe uma credencial.');
                        return;
                      }
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        // Capture the value before the dialog can be dismissed.
                        final value = controller.text.trim();
                        await widget.onConnect?.call(value);
                        if (dialog.mounted) Navigator.pop(dialog);
                      } catch (e) {
                        if (dialog.mounted)
                          update(() {
                            saving = false;
                            error = '$e';
                          });
                      }
                    },
              child: Text(saving ? 'Conectando…' : 'Conectar'),
            ),
          ],
        ),
      ),
    );
    // The dialog route may animate while the field is still mounted.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.movie_filter_outlined, color: Color(0xFFE50914)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TMDB',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.connected
                            ? 'Conectado • Filmes e séries'
                            : 'Filmes e séries',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pôsteres, banners, sinopses, elenco, gêneros e avaliações em português.',
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: widget.busy || widget.onConnect == null
                    ? null
                    : connect,
                icon: const Icon(Icons.link),
                label: Text(
                  widget.connected ? 'Trocar credencial' : 'Conectar TMDB',
                ),
              ),
              if (widget.connected)
                TextButton(
                  onPressed: widget.busy
                      ? null
                      : () => widget.onConnect?.call(''),
                  child: const Text('Desconectar'),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('MusicBrainz + Cover Art Archive'),
            subtitle: const Text(
              'Artistas, álbuns, datas, duração e capas. Não requer chave.',
            ),
            value: widget.musicEnabled,
            onChanged: widget.busy || widget.onMusicEnabled == null
                ? null
                : widget.onMusicEnabled,
          ),
          const SizedBox(height: 8),
          Text(
            'Dica: use “Artista - Música.mp3”. Capas de álbuns também ilustram o destaque; não são banners oficiais do artista.',
            style: TextStyle(
              color: isDark ? Colors.white38 : const Color(0xFF6B7280),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: widget.busy ? null : widget.onSync,
            icon: const Icon(Icons.sync),
            label: Text(
              widget.busy
                  ? 'Consultando fontes…'
                  : 'Atualizar informações online',
            ),
          ),
          if (widget.busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (widget.status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                widget.status,
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  fontSize: 12,
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

class SourceCredits extends StatelessWidget {
  const SourceCredits({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fontes e créditos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SvgPicture.asset(
          'assets/tmdb.svg',
          width: 180,
          semanticsLabel: 'The Movie Database',
        ),
        const SizedBox(height: 12),
        Text(
          'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white38
                : const Color(0xFF9CA3AF),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          'https://www.themoviedb.org\nhttps://musicbrainz.org • Dados MusicBrainz\nhttps://coverartarchive.org • Imagens de álbuns',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white38
                : const Color(0xFF9CA3AF),
            fontSize: 12,
            height: 1.7,
          ),
        ),
      ],
    ),
  );
}
