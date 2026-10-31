# Localflix

Aplicativo Flutter para filmes, séries e músicas locais, com navegação adaptada a celular, desktop e TV. A navegação contém apenas **Biblioteca** e **Configurações**; o player abre ao selecionar conteúdo e encerra a reprodução ao voltar.

## Biblioteca e interface

- Grade construída sob demanda, busca com debounce e capas com tamanho de decodificação limitado.
- Navegação inferior no celular/tablet; navegação lateral a partir de 1000 px.
- Destaque adaptável, cartões com interação por mouse e painel de detalhes rolável.
- Visual inspirado em serviços de streaming: preto e grafite, vermelho intenso, destaque cinematográfico e busca/filtros na mesma linha em telas largas.
- Player de áudio em duas colunas no desktop, controles que se reorganizam em telas estreitas e vídeo em tela cheia.
- Varredura de disco em isolate, deduplicação de pastas/arquivos, avisos para pastas inacessíveis e gravação serializada das preferências.
- Nomes e termos de busca calculados sob demanda e reutilizados; atualizações de metadados agrupadas para reduzir reconstruções da interface.
- Leitura inicial de preferências em lote, restauração dos caches em paralelo, descarte de gravações de sliders já ultrapassadas e escrita apenas dos valores de reprodução alterados. Preferências numéricas inválidas e caches corrompidos usam valores seguros.

Em **Configurações → Adicionar pasta**, escolha suas pastas de mídia. A leitura inclui subpastas. Pastas e preferências são restauradas ao abrir o aplicativo.

## Primeira inicialização e permissões

Na primeira abertura após instalar esta versão, a tela **Prepare sua biblioteca** explica os requisitos e oferece **Autorizar pasta de mídia**. O botão abre o seletor nativo do sistema. É possível escolher **Agora não** ou continuar sem pasta; essa decisão também fica salva, sem repetir a solicitação em cada abertura.

Em **Configurações → Permissões e acesso → Revisar acessos do aplicativo**, a configuração pode ser reaberta a qualquer momento. Se uma autorização expirar, a pasta for movida ou o provedor ficar indisponível, selecione a pasta novamente. A informação salva não substitui a autorização real do sistema.

| Plataforma | Solicitação e manutenção do acesso |
| --- | --- |
| Android / Android TV | Seletor de pastas do sistema, confirmação em **Usar esta pasta** e autorização persistente de URI pelo `ContentResolver` |
| iOS / iPadOS | Seletor de documentos em modo de abertura, bookmark e acesso security-scoped restaurado antes da varredura |
| macOS | `NSOpenPanel`, bookmark security-scoped de leitura e restauração do acesso antes da varredura |
| Windows / Linux | Seletor nativo de diretórios e caminhos salvos; o acesso continua sujeito às permissões de arquivos do sistema |

A reprodução local não requer câmera, microfone, localização ou notificações. A conexão de internet usada pelas capas é opcional e não corresponde a um diálogo de permissão de rede em todas as plataformas. O TMDB continua exigindo configuração de credencial. Não são criados pedidos de acesso administrativo ou de dispositivos que o aplicativo não utiliza.

Consultas automáticas de metadados aguardam a conclusão da configuração inicial. O Android continua concedendo acesso pelo seletor de pastas, sem depender de uma permissão global de armazenamento. No iOS/macOS, bookmarks são restaurados sem abrir novos diálogos; acessos indisponíveis precisam ser renovados pelo usuário. Ao remover uma pasta da biblioteca Apple, seu bookmark é removido e o acesso mantido pelo processo é liberado.

## Preferências com SharedPreferencesAsync

Pastas, modo Desktop/TV, preferências de reprodução, opção MusicBrainz, caches de metadados e decisões da configuração inicial usam **`SharedPreferencesAsync`**. Um backend compartilhado por processo centraliza as operações. A API antiga `SharedPreferences` é usada somente para a migração inicial oficial, sem apagar o armazenamento legado.

A migração copia as preferências e caches existentes e grava o marcador `localflix_async_preferences_migrated_v1` ao terminar, evitando sobrescrever escolhas novas nas aberturas seguintes. No Android, o backend assíncrono usa as opções padrão do plugin, incluindo DataStore quando disponível. Os tokens TMDB digitados continuam apenas na memória da sessão.

| Chave | Conteúdo |
| --- | --- |
| `initial_setup_completed_v1` | Configuração inicial concluída |
| `initial_setup_folder_choice_v1` | `selected`, `existing` ou `skipped`; registra a escolha, não uma concessão permanente |
| `initial_setup_platform_v1` | Plataforma onde a configuração foi concluída |
| `initial_setup_updated_at_v1` | Horário da última configuração em milissegundos desde a época Unix |
| `library_folders` | Caminhos ou URIs das pastas selecionadas |
| `apple_folder_bookmarks_v1` | Bookmarks usados para restaurar acesso no iOS/macOS |
| `desktop_tv_mode` | Preferência de modo de exibição nos computadores |

Limpar os dados do aplicativo ou reinstalá-lo pode exigir uma nova configuração e nova autorização das pastas. As preferências não são um banco de dados de permissões do sistema.

## Pastas no Android

O Android usa o Storage Access Framework: as pastas são referências `content://`, com autorização de leitura persistida. O aplicativo consulta o provedor de documentos, percorre as subpastas em uma thread de trabalho e abre áudio e vídeo pela URI original. Os arquivos de mídia não são copiados para o cache.

1. Abra **Configurações → Adicionar pasta**.
2. Escolha a pasta de mídia no seletor do Android e confirme em **Usar esta pasta**.
3. Aguarde a varredura. A autorização será reutilizada ao reabrir o aplicativo.

Autorizações antigas ainda válidas são recuperadas quando podem ser associadas ao caminho salvo. Caso o acesso tenha sido revogado ou a pasta tenha sido movida, use o botão de pasta na lista para selecioná-la novamente. Caminhos antigos do armazenamento interno e cartão SD são substituídos pela URI autorizada ao selecionar a mesma pasta.

O Android pode impedir a seleção de pastas raiz, da raiz Downloads e de diretórios protegidos como `Android/data`. Escolha uma subpasta permitida. Alguns aparelhos de TV não incluem um seletor de documentos; o aplicativo informa quando não consegue abri-lo.

Capas locais também são abertas pelo provedor de documentos. Elas são reduzidas no código nativo antes de serem enviadas à interface, com consultas simultâneas reaproveitadas e cache de bytes limitado a 12 MiB/24 imagens. As mídias são deduplicadas e as capas ficam associadas à pasta correta.

## TVs e controle remoto

As builds mantêm as interfaces de **celular, tablet e TV juntas**, sem APK separado ou configuração obrigatória. Em Android TV/Leanback, a interface de TV é detectada automaticamente, independentemente da resolução. Celulares e tablets usam a interface responsiva por tamanho e orientação, sem mudar para TV apenas por terem uma tela grande. O aplicativo possui entrada no launcher de TV e não exige touchscreen.

Em **Windows, Linux e macOS**, o usuário escolhe em **Configurações → Modo de exibição → Desktop ou TV**. Desktop é o padrão; a preferência fica salva localmente e é restaurada nas próximas aberturas. Maximizar a janela não altera a escolha. A opção manual aparece somente nos computadores.

- Catálogo em fileiras horizontais de músicas, filmes/vídeos e séries em todos os tamanhos de tela, com setas, barra de rolagem e arraste por mouse ou toque.
- Navegação lateral expandida, textos e controles maiores e borda branca no cartão ou botão em foco.
- Foco com rolagem automática para manter o item selecionado visível.
- Botões e cartões operáveis sem mouse; o botão de informações de cada cartão também é acessível por foco. Toque prolongado no cartão abre os detalhes em dispositivos com toque.

| Controle | Ação |
| --- | --- |
| Setas do controle remoto | Mover o foco entre os itens e controles |
| OK / Select / botão A | Ativar o item ou botão em foco |
| Voltar | Retornar; nas configurações, voltar à biblioteca |
| Esc no teclado | Sair da tela cheia ou retornar à tela anterior |
| Play/Pause do controle, no player | Pausar ou retomar |
| Setas, com controles do vídeo ocultos | Mostrar os controles e focar o botão de reprodução |
| Setas, com a barra de progresso em foco | Ajustar a posição em passos próximos de 10 segundos |

No player de vídeo em modo TV, título, progresso e ações ficam sobre a imagem. Os controles se ocultam durante a reprodução e deixam de participar da navegação enquanto estão invisíveis. Áudio mantém a capa e o painel de reprodução, com os mesmos controles focáveis. Fora do modo TV, esquerda/direita continuam avançando ou voltando 10 segundos diretamente.

## TMDB: filmes e séries

Em **Configurações → Capas e informações online → Conectar TMDB**, insira seu token de leitura ou chave da API, criado em https://www.themoviedb.org/settings/api. A credencial digitada fica apenas na memória durante a sessão; não é gravada no cache. Para compilar com credencial, use `--dart-define=TMDB_TOKEN=...` (o valor passa a integrar o binário; não distribua credenciais privadas dessa forma).

A integração usa título, ano e padrões como `S01E02` ou `1x02` para identificar filmes e séries; remove indicações de resolução e codec antes da busca. Busca pôster, backdrop, título, sinopse, gêneros, elenco, duração e avaliação, com idioma pt-BR. Episódios usam os dados da série e preservam o número do episódio. Há cache de metadados por sete dias, incluindo buscas sem resultado, e reaproveitamento de consultas simultâneas.

A atualização manual nas configurações força uma nova consulta ao TMDB, ignorando o cache, inclusive resultados anteriores sem correspondência. Os cartões recebem as informações ao longo da atualização. Sem uma credencial válida, o aplicativo só pode exibir dados já armazenados e capas locais; não consulta novos pôsteres no TMDB.

### Biblioteca e popup de séries

A biblioteca separa **Filmes e vídeos**, **Séries** e **Músicas** em fileiras horizontais. Use as setas, arraste a barra de rolagem, deslize com o dedo ou arraste com o mouse. Trackpads e eventos de rolagem horizontal também seguem o comportamento nativo do Flutter. As setas ficam desativadas nos limites da fileira. A navegação por foco mantém o cartão visível no modo TV.

A busca tem um botão de limpar discreto, sem fundo ou elevação, exibido apenas quando há texto. O tema compartilhado usa ícones sem blocos de fundo em repouso, preservando estados de interação e foco. Os cartões são construídos sob demanda nas fileiras.

Episódios com o mesmo ID de série no TMDB são agrupados em um cartão. Antes da identificação online, nomes compatíveis com `Nome.S01E02.mkv` ou `Nome.1x02.mkv` são agrupados pelo título e ano extraídos. Clique no cartão da série ou em suas informações para abrir o popup:

- Total de temporadas regulares e episódios, conforme o TMDB; especiais aparecem no seletor quando disponíveis.
- Seletor com nome da temporada e quantidade de episódios.
- Lista com número, título, sinopse e duração de cada episódio quando esses dados existem no TMDB.
- Reprodução apenas de arquivos locais correspondentes à série, temporada e episódio; os demais aparecem como ausentes da biblioteca.
- Carregamento, nova tentativa em falhas e acesso aos arquivos locais caso o TMDB esteja indisponível ou desconectado.

A consulta usa [detalhes da série](https://developer.themoviedb.org/reference/tv-series-details) e [detalhes da temporada](https://developer.themoviedb.org/reference/tv-season-details) em pt-BR, com a credencial da sessão. As temporadas são consultadas sob demanda, e respostas e consultas simultâneas são reutilizadas na sessão; esse catálogo de episódios não é persistido entre aberturas. Os metadados gerais mantêm seu cache existente de sete dias. O aplicativo não baixa episódios nem oferece streaming pelo TMDB. Arquivos sem numeração reconhecível podem ser reproduzidos pela seção **Arquivos locais** ou pela lista exibida quando a consulta falha, mas não são associados automaticamente a um episódio online.

## MusicBrainz e Cover Art Archive

Ative **MusicBrainz + Cover Art Archive** nas configurações. Não exige chave. O formato `Artista - Música.mp3` melhora a identificação; prefixos numéricos de faixas são removidos. São consultados gravação, artista, álbum, data e duração no MusicBrainz; a capa do lançamento vem do Cover Art Archive. O destaque de música usa a capa do álbum, não uma fotografia oficial panorâmica do artista.

Consultas MusicBrainz são serializadas com intervalo mínimo de 1,1 segundo e User-Agent identificável. Resultados com baixa confiança ou artistas ambíguos não são associados. A busca usa nomes de arquivos, não impressão digital de áudio nem tags embutidas. Não é possível garantir a edição exata de um álbum apenas pelo nome da faixa.

Atualize as informações pelo botão nas configurações. Falhas de rede mantêm a biblioteca utilizável; uma fonte indisponível não interrompe a outra. Os arquivos e caminhos locais não são enviados aos serviços. Apenas termos da busca são enviados. Metadados ficam em cache local limitado a 1500 entradas por fonte. Imagens remotas usam o cache de memória do Flutter e podem exigir rede ao reabrir o aplicativo.

## Capas locais

Imagens locais têm prioridade sobre as online. Formatos: JPG, JPEG, PNG e WebP.

- `Filme.mp4` + `Filme.jpg` ou `Filme-poster.jpg`: capa específica.
- `Filme-fanart.jpg` ou `Filme-banner.jpg`: destaque específico.
- `poster.jpg`, `cover.jpg`, `folder.jpg`, `album.jpg`: capa dos arquivos da pasta.
- `fanart.jpg`, `backdrop.jpg`, `banner.jpg`: destaque dos arquivos da pasta.

Sem imagem disponível, é exibida arte padrão. As correspondências online podem não ser exatas; a imagem local permite substituí-las.

## Organização do código

A camada de serviços contém quatro módulos: `native_media.dart` concentra seleção e recuperação de pastas, bookmarks Apple, capas locais Android e tela cheia; `preferences_store.dart` centraliza preferências e persistência dos caches; `tmdb.dart` e `musicbrainz.dart` mantêm as consultas específicas de cada provedor. Os nomes dos canais nativos e as chaves de armazenamento foram preservados.

Áudio e vídeo compartilham os controles de reprodução, volume e velocidade. A posição atualiza apenas o progresso e os tempos. No Android, a seleção de pasta é gravada no lado nativo antes de retornar ao Flutter, e só é descartada dessa fila após salvar as preferências. A varredura não bloqueia a conclusão da seleção.

## Executar e validar

O projeto declara Dart `^3.13.5` e requer uma versão do Flutter que inclua um SDK compatível. As dependências resolvidas estão em `pubspec.lock`.

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

Para executar e compilar no Windows:

```sh
flutter run -d windows
flutter build windows --release
```

O executável é gerado em `build/windows/x64/runner/Release/localflix.exe`. Distribua a pasta `Release` inteira, incluindo `data` e as DLLs; copiar somente o `.exe` não é suficiente.

Os testes em `test/` cobrem navegação horizontal com mouse e setas em telas de computador e celular, além do carregamento de temporadas, reutilização de consultas, recuperação de falhas e reprodução local pelo popup de séries. Eles não reproduzem vídeo real nem executam os componentes GTK, NSWindow ou Win32. Consultas autenticadas reais ao TMDB dependem da credencial do usuário.

**Validação desta atualização (27/10/2026):** a revisão da biblioteca e do popup é validada por análise estática e testes Flutter com respostas TMDB simuladas. Esses testes não substituem reprodução em dispositivo nem consultas autenticadas reais. Nenhum APK ou executável foi recompilado nesta atualização. Builds Apple exigem macOS/Xcode; Linux exige ambiente Linux.

## Reprodução e plataformas

| Plataforma | Áudio | Vídeo | Tela cheia |
| --- | --- | --- | --- |
| Windows | FVP/MDK | FVP/MDK | Janela Win32 sem bordas no monitor atual |
| Linux | FVP/MDK, mantendo a interface de música | FVP/MDK | Janela GTK |
| macOS | `just_audio` | `video_player` / AVFoundation | `NSWindow` |
| Android | `just_audio` | `video_player` / backend Android | `SystemChrome` |
| iOS | `just_audio` | `video_player` / AVFoundation | `SystemChrome` |
| Web | Não suportado pelo aplicativo | Não suportado pelo aplicativo | Não disponível |

O player usa `just_audio` e `video_player`. Windows e Linux usam FVP/MDK tanto para áudio quanto para vídeo. O antigo `just_audio_windows` foi removido por incompatibilidade com o compilador atual do Windows. Android, iOS e macOS usam os backends oficiais de áudio e vídeo. O backend FVP oferece decodificação por hardware e fallback por software conforme o formato e o dispositivo. Distribua a pasta Release inteira, incluindo as DLLs de reprodução. A biblioteca usa `dart:io` e não é compatível com Flutter Web.

A tela cheia usa janelas nativas no Windows, GTK no Linux e NSWindow no macOS; Android/iOS usam SystemChrome. O macOS tem os entitlements de leitura de arquivos selecionados e de bookmarks de escopo do aplicativo; macOS/iOS restauram os bookmarks salvos antes de ler a biblioteca. A disponibilidade de codecs e as restrições de acesso a pastas dependem do sistema. Testes Dart de roteamento de tela cheia não substituem compilar e reproduzir arquivos em cada plataforma; builds Apple exigem macOS/Xcode e o build Linux exige um ambiente Linux.

O vídeo se ajusta à área disponível, mantendo a proporção original. No Windows, a tela cheia remove a barra de título e cobre o monitor atual, restaurando a posição anterior ao sair. Use **F**, **F11**, duplo clique ou o botão de tela cheia para alternar; **Esc** sai, **Espaço** pausa/reproduz e as setas avançam/voltam 10 segundos. Os controles sobre o vídeo se ocultam após três segundos de reprodução e reaparecem ao mover o mouse ou tocar na tela. Volume, velocidade e progresso continuam acessíveis em tela cheia.

### Compilação e diagnóstico

- **Windows:** requer Visual Studio com as ferramentas de desenvolvimento C++ para desktop. Áudio e vídeo compartilham o FVP; o projeto não compila mais as fontes WinRT antigas de `just_audio_windows` que causavam os erros C4596 e de corrotinas. A instalação aceita a ausência da pasta opcional `build/native_assets/windows`.
- **Android:** `file_picker` 13.2.0 substitui a versão antiga que compilava contra Android 34. O módulo `android_file_picker` acompanha o compileSdk do Flutter, evitando a incompatibilidade de AAR com dependências que exigem API 36. Avisos Java sobre `source/target 8` emitidos por outras dependências não são, isoladamente, uma falha de build.
- **FVP/MDK:** a primeira compilação pode baixar bibliotecas nativas e exigir acesso à rede. Um download interrompido deve ser resolvido antes de considerar a versão pronta para distribuição.
- **Linux:** requer o ambiente de compilação Flutter/GTK e as ferramentas GLib. A compilação nativa precisa ocorrer em Linux.
- **macOS/iOS:** exigem macOS e Xcode. O sandbox do macOS permite leitura das pastas escolhidas pelo usuário; bookmarks security-scoped restauram o acesso, mas podem expirar ou deixar de resolver se o recurso for removido ou o sistema revogar a autorização.
- **`UnimplementedError: init()` ou `MissingPluginException`:** verifique os backends e o registro dos plugins, execute `flutter pub get` e faça uma compilação completa. Reinício a quente não incorpora plugins nativos recém-adicionados.

### Acessibilidade no Windows

Há uma contenção para um crash nativo do Flutter na atualização da árvore de acessibilidade: a exposição da interface a leitores de tela fica desativada por padrão **somente no Windows**. Essa limitação permanece até que a correção do motor seja validada. Para gerar uma versão com acessibilidade habilitada:

```sh
flutter build windows --release --dart-define=WINDOWS_ACCESSIBILITY=true
```

Essa opção reativa o caminho afetado pelo crash e precisa ser testada com a versão do Flutter e os recursos de acessibilidade utilizados. Android, iOS, macOS e Linux não usam essa contenção.

## Créditos

This product uses the TMDB API but is not endorsed or certified by TMDB.

- TMDB: https://www.themoviedb.org — logotipo oficial em `assets/tmdb.svg`, obtido da página de atribuição do TMDB.
- MusicBrainz: https://musicbrainz.org
- Cover Art Archive: https://coverartarchive.org

## Ícone do aplicativo

A arte original está em `assets/localflix-icon.png`. A configuração no `pubspec.yaml` usa `flutter_launcher_icons: ^0.14.3` (o lockfile pode resolver a atualização compatível 0.14.4).

Para regenerar os ícones Android, iOS, Web, Windows e macOS:

```sh
flutter pub get
dart run flutter_launcher_icons
```

Android inclui os recursos adaptativos e iOS remove o canal alfa. Para Linux, que não é coberto pelo gerador, o CMake incorpora a mesma imagem no executável GTK com GResource e inclui ícone e arquivo `.desktop` no bundle. Ao distribuir no Linux, instale o arquivo desktop em um diretório de aplicativos reconhecido pelo ambiente e mantenha os caminhos de instalação atualizados. A compilação Linux requer `glib-compile-resources`, fornecido pelas ferramentas de desenvolvimento GLib/GTK.
