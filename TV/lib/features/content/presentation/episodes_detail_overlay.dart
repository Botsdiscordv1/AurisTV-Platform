import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';

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
  });

  @override
  ConsumerState<EpisodesDetailOverlay> createState() => _EpisodesDetailOverlayState();
}

class _EpisodesDetailOverlayState extends ConsumerState<EpisodesDetailOverlay> {
  int _selectedMenuIndex = 0;
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
    final int? year = (d is AnimeDetail) ? d.year : (d is MovieDetail ? int.tryParse(d.releaseDate?.substring(0, 4) ?? '') : null);
    
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
        const SizedBox(height: 16),
        Row(
          children: [
            if (year != null) ...[
              Text('$year', style: const TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
            ],
            if (widget.totalSeasons > 0)
              Text('${widget.totalSeasons} Temporada${widget.totalSeasons > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildSideMenu() {
    final List<Map<String, dynamic>> menuItems = [
      {'label': widget.totalSeasons > 1 ? 'Temporada ${widget.currentSeason}' : 'Episodios', 'icon': Icons.layers_outlined},
      {'label': 'Trailers y m\u00E1s', 'icon': Icons.movie_outlined},
      {'label': 'Detalles', 'icon': Icons.info_outline_rounded},
      {'label': 'Galer\u00EDa', 'icon': Icons.photo_library_outlined},
    ];

    return ListView.separated(
      itemCount: menuItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bool isSelected = _selectedMenuIndex == index;
        return _MenuButton(
          label: menuItems[index]['label'],
          icon: menuItems[index]['icon'],
          isSelected: isSelected,
          onPressed: () => setState(() => _selectedMenuIndex = index),
        );
      },
    );
  }

  Widget _buildRightPanelContent() {
    switch (_selectedMenuIndex) {
      case 0: return _buildEpisodesView();
      case 1: return const Center(child: Text('Contenido adicional no disponible', style: TextStyle(color: Colors.white38, fontSize: 20)));
      case 2: return _buildDetailsView();
      case 3: return _buildGalleryPlaceholder();
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

  Widget _buildDetailsView() {
    final d = widget.detailData;
    if (d == null) return const SizedBox.shrink();
    final String overview = (d is AnimeDetail) ? (d.overview ?? '') : (d is MovieDetail ? (d.overview ?? '') : '');
    
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
                // Miniatura 16:9
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: SizedBox(
                      width: 280,
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
