import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';

class EpisodesDetailOverlay extends ConsumerStatefulWidget {
  final dynamic detailData;
  final List<SearchResult> sources;
  final SearchResult? currentSource;
  final int totalSeasons;
  final int currentSeason;
  final ValueChanged<int> onSeasonSelected;
  /// Params del provider unificado: el overlay observa en VIVO (episodios +
  /// themes progresivos). Pasar el AsyncValue como snapshot lo dejaba
  /// congelado (spinner eterno si se abría antes de resolver, sin updates
  /// del full) y con temporada vieja tras cambiar de season.
  final UnifiedDetailParams detailParams;
  final String category;
  final String title;
  /// Logo del detalle: se muestra en la cabecera del panel izquierdo con
  /// fallback al título en texto (mismo HeroTitle que el content).
  final String? logoUrl;
  final String? bannerUrl;
  final Function(EpisodeInfo, SearchResult?, int total) onPlayEpisode;

  const EpisodesDetailOverlay({
    super.key,
    required this.detailData,
    required this.sources,
    this.currentSource,
    required this.totalSeasons,
    required this.currentSeason,
    required this.onSeasonSelected,
    required this.detailParams,
    required this.category,
    required this.title,
    this.logoUrl,
    this.bannerUrl,
    required this.onPlayEpisode,
  });

  @override
  ConsumerState<EpisodesDetailOverlay> createState() => _EpisodesDetailOverlayState();
}

class _EpisodesDetailOverlayState extends ConsumerState<EpisodesDetailOverlay> {
  int _selectedMenuId = 0;
  final ScrollController _episodesScrollController = ScrollController();
  /// Foco del primer ítem del panel derecho (episodios o OP/ED): el DPAD
  /// derecha desde el menú izquierdo salta aquí.
  final FocusNode _rightFirstItemNode = FocusNode(debugLabel: 'right_first_item');
  final int _tInit = DateTime.now().millisecondsSinceEpoch;
  bool _loggedEpsData = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[perf] overlay init t=$_tInit');
  }

  @override
  void dispose() {
    _episodesScrollController.dispose();
    _rightFirstItemNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Backdrop con Blur
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(color: Colors.black.withOpacity(0.92)),
              ),
            ),
          ),

          // 2. Contenido Principal (Master-Detail)
          SafeArea(
            child: Row(
              children: [
                // PANEL IZQUIERDO: MENÚ
                Container(
                  width: width * 0.28,
                  padding: EdgeInsets.only(left: ResponsiveUtils.horizontalPadding(context), top: 60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfo(),
                      const SizedBox(height: 60),
                      Expanded(child: _buildSideMenu()),
                    ],
                  ),
                ),

                // PANEL DERECHO: CONTENIDO
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(40, 40, 60, 0),
                    child: _buildRightPanelContent(),
                  ),
                ),
              ],
            ),
          ),

          // Botón Cerrar
          Positioned(
            top: 40,
            right: 40,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 32),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() {
    final d = widget.detailData;
    final String? releaseDate = (d is MovieDetail) ? d.releaseDate : null;
    final int? year = (d is AnimeDetail) ? d.year : (releaseDate != null ? int.tryParse(releaseDate.substring(0, 4)) : null);

    // Logo en vivo del provider unificado (el overlay ya lo observa): si el
    // detalle llega después de abrir el overlay —o se pulsó "Episodios y
    // más" antes de tenerlo— el logo aparece sin reabrir. Fallback: el logo
    // capturado al abrir.
    final liveLogo = _live.detail.valueOrNull?.main?.logo;
    final String? logoUrl =
        (liveLogo is String && liveLogo.isNotEmpty) ? liveLogo : widget.logoUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo del detalle con fallback al título en texto (HeroTitle,
        // igual que en content).
        HeroTitle(
          title: widget.title,
          logo: logoUrl,
          logoReady: true,
          maxWidth: MediaQuery.sizeOf(context).width * 0.24,
          maxHeight: 64,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        if (d is MovieDetail && d.originalTitle != null && d.originalTitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            d.originalTitle!,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.5),
              fontSize: 20,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            if (releaseDate != null || year != null) ...[
              Text(releaseDate ?? '$year', style: const TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
            ],
            if (widget.totalSeasons > 0)
              Text('${widget.totalSeasons} Temporada${widget.totalSeasons > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  /// Estado vivo del provider unificado (misma instancia que content_screen:
  /// la family cachea por params, no refetchea).
  UnifiedContentState get _live => ref.watch(unifiedContentProvider(widget.detailParams));

  /// OP/ED: en anime llegan de /api/themes; en pelis vienen en el detail.
  List<AnimeThemeInfo> get _openings {
    final d = widget.detailData;
    if (d is MovieDetail) return d.openings;
    return _live.themes.valueOrNull?.openings ?? const [];
  }

  List<AnimeThemeInfo> get _endings {
    final d = widget.detailData;
    if (d is MovieDetail) return d.endings;
    return _live.themes.valueOrNull?.endings ?? const [];
  }

  bool get _hasExtras => _openings.isNotEmpty || _endings.isNotEmpty;

  /// La entrada "Opening/Ending" se muestra mientras los themes cargan o
  /// cuando hay datos; se oculta solo si cargó vacío o falló (igual que
  /// Movil/Web, que solo agregan el tab 'Extras' con datos).
  bool get _showExtrasMenu {
    if (widget.detailData is MovieDetail) return _hasExtras;
    final t = _live.themes;
    return t.isLoading || _hasExtras;
  }

  // Ids estables de menú (la lista es dinámica: Extras puede no estar).
  static const int _menuEpisodes = 0;
  static const int _menuExtras = 1;

  List<Map<String, dynamic>> _menuItems() {
    return [
      {'id': _menuEpisodes, 'label': widget.totalSeasons > 1 ? 'Temporada ${widget.currentSeason}' : 'Episodios', 'icon': Icons.layers_outlined},
      if (_showExtrasMenu) {'id': _menuExtras, 'label': 'Opening/Ending', 'icon': Icons.movie_outlined},
    ];
  }

  Widget _buildSideMenu() {
    final menuItems = _menuItems();
    final int selectedIndex = menuItems.indexWhere((m) => m['id'] == _selectedMenuId);
    final int safeIndex = (selectedIndex == -1 ? 0 : selectedIndex).clamp(0, menuItems.length - 1);

    return ListView.separated(
      itemCount: menuItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bool isSelected = safeIndex == index;
        return _MenuButton(
          label: menuItems[index]['label'],
          icon: menuItems[index]['icon'],
          isSelected: isSelected,
          // Al abrir el overlay el foco arranca en la primera sección.
          autofocus: index == 0,
          onNavigateRight: () {
            // DPAD derecha: primer ítem del panel derecho.
            _rightFirstItemNode.requestFocus();
          },
          onPressed: () => setState(() => _selectedMenuId = menuItems[index]['id'] as int),
        );
      },
    );
  }

  Widget _buildRightPanelContent() {
    final menuItems = _menuItems();
    final int selectedIndex = menuItems.indexWhere((m) => m['id'] == _selectedMenuId);
    final int safeIndex = (selectedIndex == -1 ? 0 : selectedIndex).clamp(0, menuItems.length - 1);
    switch (menuItems[safeIndex]['id']) {
      case _menuEpisodes: return _buildEpisodesView();
      case _menuExtras: return _buildExtrasView();
      default: return _buildEpisodesView();
    }
  }

  Widget _buildEpisodesView() {
    return _live.episodes.when(
      data: (result) {
        if (!_loggedEpsData) {
          _loggedEpsData = true;
          debugPrint('[perf] overlay episodes data t=${DateTime.now().millisecondsSinceEpoch} (+${DateTime.now().millisecondsSinceEpoch - _tInit}ms desde init)');
        }
        final eps = result?.response.episodes ?? [];
        if (eps.isEmpty) return const Center(child: CircularProgressIndicator(color: Colors.white24));

        // Senior Instant-Load Logic: Precarga especulativa de miniaturas
        final int startEp = ref.read(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title)?.episode != null
            ? (int.tryParse(ref.read(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title)!.episode!) ?? 1)
            : 1;
        
        // Disparamos la precarga de la ventana de episodios (actual + 12)
        ref.listenManual(episodeImagePrefetchProvider((episodes: eps, startFrom: startEp - 1)), (_, __) {});

        return LayoutBuilder(builder: (context, constraints) {
          // Objetivo TizenTube: 3 tarjetas enteras + 1 media visibles. La
          // miniatura se dimensiona desde el alto disponible, así el cálculo
          // es idéntico en 720p/1080p/4K (22 = padding vertical 16 +
          // separador 6).
          const double cardsVisible = 3.5;
          final double thumbH = (constraints.maxHeight / cardsVisible - 22).clamp(120.0, 900.0);
          final double thumbW = thumbH * 16 / 9;
          return ListView.separated(
            controller: _episodesScrollController,
            itemCount: eps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final ep = eps[index];
              final epSource = result?.sourceForNumber(ep.number) ?? widget.currentSource;
              return _ExpandedEpisodeCard(
                episode: ep,
                index: index,
                thumbWidth: thumbW,
                focusNode: index == 0 ? _rightFirstItemNode : null,
                onTap: () => widget.onPlayEpisode(ep, epSource, eps.length),
              );
            },
          );
        });
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white24)),
      error: (e, _) => Center(child: Text('Error al cargar episodios: $e', style: const TextStyle(color: Colors.white70))),
    );
  }

  Widget _buildExtrasView() {
    // En pelis los OP/ED vienen en el detail; en anime llegan de /api/themes.
    if (widget.detailData is! MovieDetail) {
      final t = _live.themes;
      if (t.isLoading) {
        return const Center(child: CircularProgressIndicator(color: Colors.white24));
      }
      if (t.hasError) {
        return Center(child: Text('Error al cargar extras: ${t.error}', style: const TextStyle(color: Colors.white70)));
      }
    }
    return _buildExtrasList();
  }

  Widget _buildExtrasList() {
    final ops = _openings;
    final eds = _endings;
    if (ops.isEmpty && eds.isEmpty) {
      return const Center(child: Text('Contenido adicional no disponible', style: TextStyle(color: Colors.white38, fontSize: 20)));
    }
    // Nodo de salto del menú izquierdo: primer OP, o primer ED si no hay OP.
    final bool opsFirst = ops.isNotEmpty;
    FocusNode? nodeFor(AnimeThemeInfo th) =>
        (opsFirst ? identical(th, ops.first) : identical(th, eds.first))
            ? _rightFirstItemNode
            : null;
    return ListView(
      children: [
        if (ops.isNotEmpty) ...[
          Text('Openings', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...ops.map((th) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _ThemeRowCard(theme: th, isOP: true, focusNode: nodeFor(th), onTap: () => _playTheme(th, true)),
              )),
          const SizedBox(height: 16),
        ],
        if (eds.isNotEmpty) ...[
          Text('Endings', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...eds.map((th) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _ThemeRowCard(theme: th, isOP: false, focusNode: nodeFor(th), onTap: () => _playTheme(th, false)),
              )),
        ],
      ],
    );
  }

  /// Reproduce un OP/ED en el player (mismos parámetros que Movil: el player
  /// TV ya soporta flujo directo Themes/YouTube con episode=OP/ED sin
  /// historial ni autoplay).
  void _playTheme(AnimeThemeInfo theme, bool isOP) {
    final typeLabel = isOP ? 'OP' : 'ED';
    final dynamic d = widget.detailData;
    String logo = '';
    try {
      final l = d?.logo as String?;
      if (l != null && l.isNotEmpty) logo = '&logoUrl=${Uri.encodeComponent(l)}';
    } catch (_) {}
    final titleParam = '&title=${Uri.encodeComponent(widget.title)}&episodeTitle=${Uri.encodeComponent(theme.title)}$logo';

    String url = theme.videoUrl;
    if (!url.startsWith('http')) {
      // Solo ID de YouTube (igual que Movil): el player lo abre en embed.
      url = 'https://www.youtube.com/watch?v=$url';
      context.push('/player/${Uri.encodeComponent(theme.title)}?source=YouTube&url=${Uri.encodeComponent(url)}&episode=$typeLabel&serverName=YouTube$titleParam');
      return;
    }
    final v720 = (theme.video720?.isNotEmpty ?? false) ? '&video720=${Uri.encodeComponent(theme.video720!)}' : '';
    final v1080 = (theme.video1080?.isNotEmpty ?? false) ? '&video1080=${Uri.encodeComponent(theme.video1080!)}' : '';
    context.push('/player/${Uri.encodeComponent(theme.title)}?source=&url=${Uri.encodeComponent(url)}&episode=$typeLabel&serverName=Themes$v720$v1080$titleParam');
  }

}

/// Ficha técnica del contenido con los datos que entrega el servidor:
/// título original, duración/formato, estado, géneros, sinopsis,
/// plataformas (logos), dirección, estudio, reparto, país y advertencias.
/// La usa el botón de información del content (pantalla fullscreen).
class ContentDetailsPanel extends StatelessWidget {
  final dynamic detailData;

  const ContentDetailsPanel({super.key, required this.detailData});

  @override
  Widget build(BuildContext context) {
    final d = detailData;
    if (d == null) return const SizedBox.shrink();

    final bool isMovie = d is MovieDetail;

    // Título original (inglés/japonés en anime).
    final List<String> altTitles = [];
    if (isMovie) {
      final ot = d.originalTitle ?? '';
      if (ot.isNotEmpty) altTitles.add(ot);
    } else if (d is AnimeDetail) {
      if ((d.titleEnglish ?? '').isNotEmpty) altTitles.add(d.titleEnglish!);
      if ((d.titleJapanese ?? '').isNotEmpty) altTitles.add(d.titleJapanese!);
    }

    // Fecha de estreno completa (antes solo el año) — movida desde la ficha
    // de la izquierda a "Ficha técnica".
    String? releaseLabel;
    if (isMovie) {
      releaseLabel = d.releaseDate;
    } else if (d is AnimeDetail) {
      releaseLabel = d.releaseDate ?? d.year?.toString();
    }

    // Duración / formato / estado.
    final List<String> facts = [];
    if (releaseLabel != null && releaseLabel.isNotEmpty) facts.add(releaseLabel);
    if (isMovie) {
      if (d.runtime != null && d.runtime! > 0) facts.add('Duración ${_formatMinutes(d.runtime!)}');
    } else if (d is AnimeDetail) {
      if (d.duration != null && d.duration! > 0) facts.add('${d.duration} min por episodio');
      if (d.episodes != null && d.episodes! > 0) facts.add('${d.episodes} episodios');
    }
    final status = (d is MovieDetail) ? d.status : (d is AnimeDetail ? d.status : null);
    if (status != null && status.isNotEmpty) facts.add('Estado: $status');

    final List<PlatformInfo> platforms = (d is MovieDetail)
        ? d.platforms
        : (d is AnimeDetail ? d.platforms : <PlatformInfo>[]);
    final List<String> directors = isMovie ? d.directors : <String>[];
    final List<String> studios = isMovie
        ? d.productionCompanies
        : (d is AnimeDetail ? d.studios : <String>[]);
    final List<String> cast = isMovie
        ? d.cast.take(8).map((c) => c.name).toList()
        : (d is AnimeDetail
            ? d.characters
                .expand((c) => c.voiceActors.map((v) => v.name))
                .take(8)
                .toList()
            : <String>[]);
    final List<String> languages = isMovie ? d.languages : <String>[];
    final String? cert =
        (d is MovieDetail) ? d.certification : (d is AnimeDetail ? d.certification : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Título original
        if (altTitles.isNotEmpty) ...[
          _sectionTitle('Título original'),
          const SizedBox(height: 6),
          for (final t in altTitles)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 20),
        ],

        // 2. Advertencias de contenido (debajo del Título original)
        if (cert != null) ...[
          const SizedBox(height: 4),
          _sectionTitle('Advertencias de contenido'),
          const SizedBox(height: 6),
          Text(
            getWarningText(cert),
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Ficha técnica: duración / formato / estado
        if (facts.isNotEmpty) ...[
          _sectionTitle('Ficha técnica'),
          const SizedBox(height: 6),
          Text(facts.join('  •  '), style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
        ],

        // 3. Disponible en (logos de plataformas)
        if (platforms.isNotEmpty) ...[
          _sectionTitle('Disponible en'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: platforms.map((p) => _PlatformLogo(platform: p, size: 44)).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // 6. Dirección
        if (directors.isNotEmpty) ...[
          _detailRow('Dirección', directors.join(', ')),
        ],

        // 7. Estudio / Producción
        if (studios.isNotEmpty) ...[
          _detailRow(isMovie ? 'Producción' : 'Estudio', studios.join(', ')),
        ],

        // 8. Cast (solo nombres: pelis → reparto, anime → seiyuus)
        if (cast.isNotEmpty) ...[
          _detailRow('Cast', cast.join(', ')),
        ],

        // 9. País
        if (languages.isNotEmpty) ...[
          _detailRow('País', languages.map(_flagFor).join('  ')),
        ],
      ],
    );
  }

  static Widget _sectionTitle(String text) => Text(
    text,
    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
  );

  static Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(label),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
      ],
    ),
  );
}

/// "56min" / "1h 10min" / "1h".
String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}min';
}

/// Bandera emoji para un idioma/país (mismo mapa que Movil/Web).
String _flagFor(String language) {
  final country = language.toLowerCase();
  String emoji = '';
  if (country.contains('jap')) emoji = '🇯🇵';
  else if (country.contains('cor')) emoji = '🇰🇷';
  else if (country.contains('usa') || country.contains('estat') || country.contains('eeuu')) emoji = '🇺🇸';
  else if (country.contains('esp') || country.contains('spain')) emoji = '🇪🇸';
  else if (country.contains('mex')) emoji = '🇲🇽';
  else if (country.contains('chi')) emoji = '🇨🇳';
  else if (country.contains('fra')) emoji = '🇫🇷';
  else if (country.contains('ing') || country.contains('uk')) emoji = '🇬🇧';
  else if (country.contains('ale') || country.contains('ger')) emoji = '🇩🇪';
  else if (country.contains('ita')) emoji = '🇮🇹';
  return emoji.isNotEmpty ? '$emoji $language' : language;
}

/// Logo cuadrado de plataforma con fallback a la inicial del nombre.
class _PlatformLogo extends StatelessWidget {
  final PlatformInfo platform;
  final double size;

  const _PlatformLogo({required this.platform, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: platform.providerName,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: CachedNetworkImage(
            imageUrl: platform.logo ?? '',
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Center(
              child: Text(
                platform.providerName.isNotEmpty
                    ? platform.providerName.substring(0, 1).toUpperCase()
                    : '?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  /// Focus inicial al montar (el overlay abre con la primera sección enfocada).
  final bool autofocus;
  /// DPAD derecha: llevar el foco al panel derecho.
  final VoidCallback? onNavigateRight;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.autofocus = false,
    this.onNavigateRight,
    required this.onPressed,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected || _focused;
    
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      // TV: el OK del control (select/enter/space) debe activar el botón,
      // GestureDetector solo responde a puntero.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        // DPAD derecha: salto explícito al primer ítem del panel derecho
        // (el traversal por geometría no cruza de panel de forma fiable).
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowRight &&
            widget.onNavigateRight != null) {
          widget.onNavigateRight!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: active ? Colors.white : Colors.white38, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white38,
                    fontSize: 15,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedEpisodeCard extends StatefulWidget {
  final EpisodeInfo episode;
  final int index;
  /// Ancho de la miniatura, calculado desde el alto del viewport para que
  /// quepan 3 tarjetas enteras + 1 media (objetivo TizenTube).
  final double thumbWidth;
  /// Nodo del primer ítem del panel derecho (salto desde el menú izquierdo).
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const _ExpandedEpisodeCard({
    required this.episode,
    required this.index,
    required this.thumbWidth,
    this.focusNode,
    required this.onTap,
  });

  @override
  State<_ExpandedEpisodeCard> createState() => _ExpandedEpisodeCardState();
}

class _ExpandedEpisodeCardState extends State<_ExpandedEpisodeCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      // TV: el OK del control (select/enter/space) debe abrir el episodio,
      // GestureDetector solo responde a puntero.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          // Sin cápsula de foco: el episodio activo se marca solo con el
          // leve zoom (antes se envolvía en una caja blanca redondeada).
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniatura 16:9 (el ancho va FUERA del AspectRatio: dentro de
                // un ListView vertical ambos ejes llegan ilimitados y crashea).
                // Foco estilo TizenTube: borde blanco en los bordes del thumb.
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: _focused ? Border.all(color: Colors.white, width: 3) : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: widget.thumbWidth,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: (widget.episode.thumbnail?.isNotEmpty ?? false)
                          ? CachedNetworkImage(
                              imageUrl: ApiEndpoints.proxyImage(widget.episode.thumbnail!),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.white.withOpacity(0.05)),
                              errorWidget: (_, __, ___) => Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 30)),
                            )
                          : Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 30)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Información: 1 título -> 3 sinopsis -> 1 duración (entre
                // paréntesis, línea propia al final).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.episode.number}. ${widget.episode.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (widget.episode.description?.isNotEmpty ?? false)
                          ? widget.episode.description!
                          : 'Sinopsis no disponible para este episodio.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '(${widget.episode.duration ?? (widget.episode.runtime != null ? '${widget.episode.runtime}m' : '40m')})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeRowCard extends StatefulWidget {
  final AnimeThemeInfo theme;
  final bool isOP;
  /// Nodo del primer ítem del panel derecho (salto desde el menú izquierdo).
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const _ThemeRowCard({
    required this.theme,
    required this.isOP,
    this.focusNode,
    required this.onTap,
  });

  @override
  State<_ThemeRowCard> createState() => _ThemeRowCardState();
}

class _ThemeRowCardState extends State<_ThemeRowCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isOP ? Colors.blueAccent : Colors.pinkAccent;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      // TV: el OK del control (select/enter/space) debe reproducir el tema,
      // GestureDetector solo responde a puntero.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _focused ? Colors.white.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _focused ? accent.withOpacity(0.6) : Colors.transparent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniatura 16:9 (ancho fuera del AspectRatio: ver tarjeta episodio).
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 280,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: (widget.theme.imageUrl?.isNotEmpty ?? false)
                        ? CachedNetworkImage(
                            imageUrl: ApiEndpoints.proxyImage(widget.theme.imageUrl!),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.white.withOpacity(0.05)),
                            errorWidget: (_, __, ___) => Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 40)),
                          )
                        : Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 40)),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: accent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              widget.isOP ? 'OP' : 'ED',
                              style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.theme.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.theme.artist.isNotEmpty ? widget.theme.artist : 'Artista desconocido',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
