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
  final AsyncValue<GroupedEpisodesResult?> episodesAsync;
  final String category;
  final String title;
  final String? bannerUrl;
  final Function(EpisodeInfo, SearchResult?, int total) onPlayEpisode;
  /// OP/ED vía /api/themes (ver Movil/Web): el overlay muestra la sección
  /// "Trailers y más" solo cuando hay datos (o mientras cargan).
  final AsyncValue<AnimeThemesData>? themesAsync;

  const EpisodesDetailOverlay({
    super.key,
    required this.detailData,
    required this.sources,
    this.currentSource,
    required this.totalSeasons,
    required this.currentSeason,
    required this.onSeasonSelected,
    required this.episodesAsync,
    required this.category,
    required this.title,
    this.bannerUrl,
    required this.onPlayEpisode,
    this.themesAsync,
  });

  @override
  ConsumerState<EpisodesDetailOverlay> createState() => _EpisodesDetailOverlayState();
}

class _EpisodesDetailOverlayState extends ConsumerState<EpisodesDetailOverlay> {
  int _selectedMenuId = 0;
  final ScrollController _episodesScrollController = ScrollController();

  @override
  void dispose() {
    _episodesScrollController.dispose();
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
                    padding: const EdgeInsets.fromLTRB(40, 60, 60, 40),
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 32,
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

  /// OP/ED: en anime llegan de /api/themes; en pelis vienen en el detail.
  List<AnimeThemeInfo> get _openings {
    final d = widget.detailData;
    if (d is MovieDetail) return d.openings;
    return widget.themesAsync?.valueOrNull?.openings ?? const [];
  }

  List<AnimeThemeInfo> get _endings {
    final d = widget.detailData;
    if (d is MovieDetail) return d.endings;
    return widget.themesAsync?.valueOrNull?.endings ?? const [];
  }

  bool get _hasExtras => _openings.isNotEmpty || _endings.isNotEmpty;

  /// La entrada "Trailers y más" se muestra mientras los themes cargan o
  /// cuando hay datos; se oculta solo si cargó vacío o falló (igual que
  /// Movil/Web, que solo agregan el tab 'Extras' con datos).
  bool get _showExtrasMenu {
    if (widget.detailData is MovieDetail) return _hasExtras;
    final t = widget.themesAsync;
    if (t == null) return false;
    return t.isLoading || _hasExtras;
  }

  // Ids estables de menú (la lista es dinámica: Extras puede no estar).
  static const int _menuEpisodes = 0;
  static const int _menuExtras = 1;
  static const int _menuDetails = 2;
  static const int _menuGallery = 3;

  List<Map<String, dynamic>> _menuItems() {
    return [
      {'id': _menuEpisodes, 'label': widget.totalSeasons > 1 ? 'Temporada ${widget.currentSeason}' : 'Episodios', 'icon': Icons.layers_outlined},
      if (_showExtrasMenu) {'id': _menuExtras, 'label': 'Trailers y m\u00E1s', 'icon': Icons.movie_outlined},
      {'id': _menuDetails, 'label': 'Detalles', 'icon': Icons.info_outline_rounded},
      {'id': _menuGallery, 'label': 'Galer\u00EDa', 'icon': Icons.photo_library_outlined},
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
      case _menuDetails: return _buildDetailsView();
      case _menuGallery: return _buildGalleryPlaceholder();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildEpisodesView() {
    return widget.episodesAsync.when(
      data: (result) {
        final eps = result?.response.episodes ?? [];
        if (eps.isEmpty) return const Center(child: CircularProgressIndicator(color: Colors.white24));

        // Senior Instant-Load Logic: Precarga especulativa de miniaturas
        final int startEp = ref.read(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title)?.episode != null
            ? (int.tryParse(ref.read(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title)!.episode!) ?? 1)
            : 1;
        
        // Disparamos la precarga de la ventana de episodios (actual + 12)
        ref.listenManual(episodeImagePrefetchProvider((episodes: eps, startFrom: startEp - 1)), (_, __) {});

        return ListView.separated(
          controller: _episodesScrollController,
          itemCount: eps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 24),
          itemBuilder: (context, index) {
            final ep = eps[index];
            final epSource = result?.sourceForNumber(ep.number) ?? widget.currentSource;
            return _ExpandedEpisodeCard(
              episode: ep,
              index: index,
              onTap: () => widget.onPlayEpisode(ep, epSource, eps.length),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white24)),
      error: (e, _) => Center(child: Text('Error al cargar episodios: $e', style: const TextStyle(color: Colors.white70))),
    );
  }

  Widget _buildExtrasView() {
    // En pelis los OP/ED vienen en el detail; en anime llegan de /api/themes.
    if (widget.detailData is! MovieDetail) {
      final t = widget.themesAsync;
      if (t == null) {
        return const Center(child: Text('Contenido adicional no disponible', style: TextStyle(color: Colors.white38, fontSize: 20)));
      }
      return t.when(
        data: (_) => _buildExtrasList(),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white24)),
        error: (e, _) => Center(child: Text('Error al cargar extras: $e', style: const TextStyle(color: Colors.white70))),
      );
    }
    return _buildExtrasList();
  }

  Widget _buildExtrasList() {
    final ops = _openings;
    final eds = _endings;
    if (ops.isEmpty && eds.isEmpty) {
      return const Center(child: Text('Contenido adicional no disponible', style: TextStyle(color: Colors.white38, fontSize: 20)));
    }
    return ListView(
      children: [
        if (ops.isNotEmpty) ...[
          Text('Openings', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...ops.map((th) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _ThemeRowCard(theme: th, isOP: true, onTap: () => _playTheme(th, true)),
              )),
          const SizedBox(height: 16),
        ],
        if (eds.isNotEmpty) ...[
          Text('Endings', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...eds.map((th) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _ThemeRowCard(theme: th, isOP: false, onTap: () => _playTheme(th, false)),
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

  Widget _buildDetailsView() {
    final d = widget.detailData;
    if (d == null) return const SizedBox.shrink();
    final String overview = (d is AnimeDetail) ? (d.overview ?? '') : (d is MovieDetail ? (d.overview ?? '') : '');
    final List<String> languages = (d is MovieDetail) ? d.languages : [];
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sinopsis', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Text(
            overview.isNotEmpty ? overview : 'No hay descripci\u00F3n disponible.',
            style: const TextStyle(color: Colors.white70, fontSize: 20, height: 1.6),
          ),
          if (languages.isNotEmpty) ...[
            const SizedBox(height: 40),
            Text('Pa\u00EDs', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(() {
              return languages.map((l) {
                final country = l.toLowerCase();
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
                
                return emoji.isNotEmpty ? '$emoji $l' : l;
              }).join('  ');
            }(), style: const TextStyle(color: Colors.white60, fontSize: 18)),
          ],
          if (d is MovieDetail && d.cast.isNotEmpty) ...[
            const SizedBox(height: 40),
            Text('Reparto', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(d.cast.take(10).map((c) => c.name).join(', '), style: const TextStyle(color: Colors.white60, fontSize: 18)),
          ],
        ],
      ),
    );
  }

  Widget _buildGalleryPlaceholder() {
    return const Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.photo_library_outlined, size: 80, color: Colors.white12),
        SizedBox(height: 20),
        Text('Galer\u00EDa de im\u00E1genes', style: TextStyle(color: Colors.white38, fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    ));
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.isSelected,
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
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
            border: Border(
              left: BorderSide(
                color: active ? const Color(0xFFE50914) : Colors.transparent,
                width: 5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: active ? Colors.white : Colors.white38, size: 28),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white38,
                    fontSize: 20,
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
  final VoidCallback onTap;

  const _ExpandedEpisodeCard({
    required this.episode,
    required this.index,
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
      onFocusChange: (f) => setState(() => _focused = f),
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
              border: Border.all(color: _focused ? Colors.white24 : Colors.transparent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miniatura 16:9 (el ancho va FUERA del AspectRatio: dentro de
                // un ListView vertical ambos ejes llegan ilimitados y crashea).
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 280,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: (widget.episode.thumbnail?.isNotEmpty ?? false)
                        ? CachedNetworkImage(
                            imageUrl: ApiEndpoints.proxyImage(widget.episode.thumbnail!),
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.white.withOpacity(0.05)),
                            errorWidget: (_, __, ___) => Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 40)),
                          )
                        : Container(color: Colors.white.withOpacity(0.05), child: const Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 40)),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${widget.episode.number}. ${widget.episode.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            widget.episode.duration ?? (widget.episode.runtime != null ? '${widget.episode.runtime}m' : '40m'),
                            style: const TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (widget.episode.description?.isNotEmpty ?? false)
                          ? widget.episode.description!
                          : 'Sinopsis no disponible para este episodio.',
                        maxLines: 3,
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

class _ThemeRowCard extends StatefulWidget {
  final AnimeThemeInfo theme;
  final bool isOP;
  final VoidCallback onTap;

  const _ThemeRowCard({
    required this.theme,
    required this.isOP,
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
      onFocusChange: (f) => setState(() => _focused = f),
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
