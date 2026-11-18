import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';
import 'package:collection/collection.dart';
import 'adaptive_watch_layout.dart';
import 'widgets/watch_top_bar.dart';
import 'widgets/watch_episode_metadata.dart';
import 'widgets/watch_action_bar.dart';
import 'widgets/watch_synopsis.dart';
import 'widgets/watch_nav_card.dart';
import 'widgets/watch_playlist_sidebar.dart';

/// Pantalla base compartida para WatchScreen (Web y Móvil).
///
/// Contiene toda la UI (layout adaptativo, metadatos, barra de acciones,
/// sinopsis, navegación entre episodios, playlist sidebar).
///
/// Esta versión consume `episodesProvider` para obtener los datos de episodios
/// y los usa para poblar los widgets de metadata y sinopsis, unificando el
/// comportamiento entre Web y Móvil.
class WatchScreenBase extends ConsumerStatefulWidget {
  const WatchScreenBase({
    super.key,
    required this.contentId,
    required this.sourceUrl,
    required this.source,
    this.episode,
    this.season,
    this.serverName,
    this.availableServers,
    this.onServerSelected,
    this.category,
    this.title,
    this.metadataTitle,
    this.episodeTitle,
    this.posterUrl,
    this.bannerUrl,
    this.logoUrl,
    this.year,
    this.certification,
    this.totalEpisodes,
    this.skipResume = false,
    this.isLive = false,
    this.playlistEpisodes,
    this.playlistIndex = 0,
    required this.playerWidget,
    this.synopsis,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.onEpisodeSelected,
    this.onBack,
    this.isTheaterMode = false,
    this.isFullscreen = false,
    this.showPlaylistSidebar = true,
    this.isAmbientGlowEnabled = true,
  });

  final String contentId;
  final String sourceUrl;
  final String source;
  final String? episode;
  final int? season;
  final String? serverName;
  final List<String>? availableServers;
  final ValueChanged<String>? onServerSelected;
  final String? category;
  final String? title;
  final String? metadataTitle;
  final String? episodeTitle;
  final String? posterUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final int? year;
  final String? certification;
  final int? totalEpisodes;
  final bool skipResume;
  final bool isLive;
  final List<EpisodeInfo>? playlistEpisodes;
  final int playlistIndex;
  final Widget playerWidget;
  final String? synopsis;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final ValueChanged<EpisodeInfo>? onEpisodeSelected;
  final VoidCallback? onBack;
  final bool isTheaterMode;

  /// Pantalla completa del reproductor: el layout se colapsa al player sin
  /// reubicarlo, para no recrear el player ni pausar el vídeo.
  final bool isFullscreen;
  final bool showPlaylistSidebar;

  /// Controla el halo ambiental que rodea al reproductor en el watch.
  final bool isAmbientGlowEnabled;

  @override
  ConsumerState<WatchScreenBase> createState() => _WatchScreenBaseState();
}

class _WatchScreenBaseState extends ConsumerState<WatchScreenBase> {
  int _visibleEpisodesLimit = 0;

  @override
  void dispose() {
    try {
      final bool isMiniplayerActive = ref.read(isGlobalMiniplayerActiveProvider);
      if (!isMiniplayerActive) {
        ref.read(activePlayerProvider.notifier).disposePlayer();
      }
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Favorites Logic
    final favorites = ref.watch(favoritesProvider);
    final bool isBookmarked = favorites.any((f) => f.id == widget.contentId || f.title == (widget.metadataTitle ?? widget.title));
    final String seriesTitle = widget.metadataTitle ?? widget.title ?? widget.contentId;
    final bool isMovie = isMovieLike(widget.category, seriesTitle);
    final bool isTheme = widget.source == 'Themes' ||
        widget.source == 'YouTube' ||
        widget.sourceUrl.contains('animethemes.moe');

    final cachedEpisodesData = (isMovie || isTheme)
        ? null
        : ProgressiveContentNotifier.lookupCachedEpisodesResponse(
            title: widget.title ?? widget.contentId,
            metadataTitle: widget.metadataTitle,
            season: widget.season ?? 1,
          );

    final episodesParams = EpisodesParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
      title: seriesTitle,
      season: widget.season,
    );

    final episodesData = (isMovie || isTheme)
        ? null
        : (cachedEpisodesData ?? ref.watch(episodesProvider(episodesParams)).valueOrNull);
    final List<EpisodeInfo> episodesList = (isMovie || isTheme)
        ? const []
        : (widget.playlistEpisodes ?? (episodesData?.episodes ?? []));

    // Resolver el número actual del episodio
    final int? parsedEpNum = int.tryParse(widget.episode ?? '');
    final int currentEpNum = parsedEpNum ?? 1;

    // Encontrar el episodio activo por número exacto (solo si no es película ni tema y es un número válido)
    final EpisodeInfo? activeEpisode = (isMovie || isTheme || parsedEpNum == null)
        ? null
        : episodesList.firstWhereOrNull((ep) => ep.number == currentEpNum);

    final String? epTitle = activeEpisode?.title;
    final String rawEpTitle = (epTitle != null && epTitle.isNotEmpty)
        ? epTitle
        : (widget.episodeTitle ?? (isTheme ? (widget.episode ?? 'Tema Musical') : 'Episodio $currentEpNum'));

    final String realEpTitle = (isMovie || isTheme)
        ? (widget.episodeTitle ?? (isTheme ? (widget.episode ?? 'Tema Musical') : seriesTitle))
        : formatEpisodeTitle(currentEpNum, rawEpTitle);

    final String realSynopsis = (isMovie || isTheme)
        ? (widget.synopsis ?? (isTheme ? 'Tema musical de $seriesTitle: $realEpTitle' : 'Disfruta de $seriesTitle con la mejor calidad en AurisTV.'))
        : ((activeEpisode?.description != null && activeEpisode!.description!.isNotEmpty)
            ? activeEpisode.description!
            : (widget.synopsis ?? 'Sigue las aventuras de $seriesTitle en este episodio $realEpTitle con la mejor calidad en AurisTV.'));

    final String rawDate = (activeEpisode?.airDate != null && activeEpisode!.airDate!.isNotEmpty)
        ? activeEpisode.airDate!
        : (episodesData?.seasonAirDate ?? episodesData?.releaseDate ?? (widget.year != null ? widget.year.toString() : ''));

    final String realReleaseDate = formatDisplayDate(rawDate);

    final String realBadges = isTheme
        ? (widget.episode ?? 'OP/ED')
        : ((activeEpisode?.quality != null && activeEpisode!.quality!.isNotEmpty)
            ? activeEpisode.quality!
            : 'Sub | Dob');

    final String realCertification = (widget.certification != null && widget.certification!.isNotEmpty && widget.certification != 'NR')
        ? widget.certification!.toUpperCase()
        : '16+';

    // Calcular episodio siguiente y anterior por número de episodio real (solo para series)
    EpisodeInfo? nextEp;
    EpisodeInfo? prevEp;
    if (!isMovie && !isTheme) {
      for (final ep in episodesList) {
        if (ep.number == currentEpNum + 1) nextEp = ep;
        if (ep.number == currentEpNum - 1) prevEp = ep;
      }
    }

    final Widget nextEpisodeWidget = (!isMovie && !isTheme && nextEp != null)
        ? WatchNavCard(
            sectionLabel: 'SIGUIENTE EPISODIO',
            episodeNumber: 'E${nextEp.number}',
            episodeTitle: (nextEp.title != null && nextEp.title!.isNotEmpty) ? nextEp.title! : 'Episodio ${nextEp.number}',
            thumbnailUrl: nextEp.thumbnail ?? widget.bannerUrl,
            duration: nextEp.duration ?? (nextEp.runtime != null ? '${nextEp.runtime}m' : '24m'),
            audioSubsBadge: (nextEp.airDate != null && nextEp.airDate!.isNotEmpty && formatDisplayDate(nextEp.airDate) != 'N/A')
                ? formatDisplayDate(nextEp.airDate)
                : (nextEp.quality ?? 'Sub | Dob'),
            onTap: (widget.onEpisodeSelected != null)
                ? () => widget.onEpisodeSelected!(nextEp!)
                : widget.onNextEpisode,
          )
        : const SizedBox.shrink();

    final Widget previousEpisodeWidget = (!isMovie && !isTheme && prevEp != null)
        ? WatchNavCard(
            sectionLabel: 'EPISODIO ANTERIOR',
            episodeNumber: 'E${prevEp.number}',
            episodeTitle: (prevEp.title != null && prevEp.title!.isNotEmpty) ? prevEp.title! : 'Episodio ${prevEp.number}',
            thumbnailUrl: prevEp.thumbnail ?? widget.bannerUrl,
            duration: prevEp.duration ?? (prevEp.runtime != null ? '${prevEp.runtime}m' : '24m'),
            audioSubsBadge: (prevEp.airDate != null && prevEp.airDate!.isNotEmpty && formatDisplayDate(prevEp.airDate) != 'N/A')
                ? formatDisplayDate(prevEp.airDate)
                : (prevEp.quality ?? 'Sub | Dob'),
            onTap: (widget.onEpisodeSelected != null)
                ? () => widget.onEpisodeSelected!(prevEp!)
                : widget.onPreviousEpisode,
          )
        : const SizedBox.shrink();

    final String epNumDisplay = isMovie
        ? 'Película'
        : (isTheme
            ? (widget.episode ?? 'Tema')
            : ((activeEpisode?.number != null)
                ? 'E${activeEpisode!.number}'
                : (widget.episode != null ? 'E${widget.episode}' : 'E$currentEpNum')));

    final VoidCallback toggleBookmark = () {
      final favItem = FavoriteItem(
        id: widget.contentId,
        title: seriesTitle,
        posterUrl: widget.posterUrl ?? widget.bannerUrl ?? '',
        bannerUrl: widget.bannerUrl ?? '',
        category: widget.category ?? 'anime',
        source: widget.source,
        url: widget.sourceUrl,
        addedAt: DateTime.now(),
        profileId: 'guest_profile',
        year: widget.year,
      );
      ref.read(favoritesProvider.notifier).toggleFavorite(favItem);
    };

    final bool isDesktopWeb = MediaQuery.sizeOf(context).width >= 1024;
    final bool effectiveTheaterMode = widget.isTheaterMode || ((isTheme || isMovie) && isDesktopWeb);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AdaptiveWatchLayout(
        isTheaterMode: effectiveTheaterMode,
        isFullscreen: widget.isFullscreen,
        ambientArtUrl: !widget.isAmbientGlowEnabled
            ? null
            : (widget.bannerUrl?.trim().isNotEmpty ?? false)
                ? widget.bannerUrl
                : widget.posterUrl,
        topBarWidget: WatchTopBar(
          onBack: widget.onBack,
          category: widget.category,
          seriesTitle: seriesTitle,
          episodeNumber: (isMovie || isTheme) ? (widget.episode ?? '') : epNumDisplay,
          serverName: widget.serverName,
          isBookmarked: isBookmarked,
          onBookmarkToggle: toggleBookmark,
          onSharePressed: () {},
        ),
        playerWidget: widget.playerWidget,
        metadataWidget: WatchEpisodeMetadata(
          seriesTitle: seriesTitle,
          episodeTitle: realEpTitle,
          episodeNumber: epNumDisplay,
          ratingBadge: realCertification,
          audioSubsBadge: realBadges,
          releaseDate: realReleaseDate,
          isBookmarked: isBookmarked,
          onBookmarkToggle: toggleBookmark,
        ),
        actionBarWidget: WatchActionBar(
          likeCount: '20.4K',
          dislikeCount: '142',
          onLikePressed: () {},
          onDislikePressed: () {},
          onSharePressed: () {},
        ),
        synopsisWidget: WatchSynopsis(
          synopsis: realSynopsis,
        ),
        nextEpisodeWidget: nextEpisodeWidget,
        previousEpisodeWidget: previousEpisodeWidget,
        playlistSidebarWidget: (widget.showPlaylistSidebar && !isMovie && !isTheme && episodesList.isNotEmpty)
            ? WatchPlaylistSidebar(
                episodes: episodesList,
                activeEpisode: (activeEpisode?.number ?? currentEpNum).toString(),
                onEpisodeSelected: widget.onEpisodeSelected ?? (_) {},
              )
            : null,
        rightColumnWidget: widget.showPlaylistSidebar && !isMovie && !isTheme
            ? (episodesList.isNotEmpty
                ? WatchPlaylistSidebar(
                    episodes: episodesList,
                    activeEpisode: (activeEpisode?.number ?? currentEpNum).toString(),
                    onEpisodeSelected: widget.onEpisodeSelected ?? (_) {},
                  )
                : null)
            : (!isMovie && !isTheme && episodesList.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      nextEp != null ? nextEpisodeWidget : const SizedBox.shrink(),
                      if (nextEp != null) const SizedBox(height: 12),
                      _buildVerMasEpisodiosButton(
                        context,
                        episodesList,
                        (activeEpisode?.number ?? currentEpNum).toString(),
                        widget.onEpisodeSelected ?? (_) {},
                      ),
                    ],
                  )
                : null),
        mobileEpisodesWidget: (!isMovie && !isTheme && episodesList.isNotEmpty)
            ? _buildMobileEpisodesSection(
                context,
                episodesList,
                (activeEpisode?.number ?? currentEpNum).toString(),
                widget.onEpisodeSelected ?? (_) {},
                nextEpisodeWidget: nextEpisodeWidget,
                previousEpisodeWidget: previousEpisodeWidget,
              )
            : null,
      ),
    );
  }

  Widget _buildMobileEpisodesSection(
    BuildContext context,
    List<EpisodeInfo> episodesList,
    String activeEpisodeNum,
    ValueChanged<EpisodeInfo> onEpisodeSelected, {
    Widget? nextEpisodeWidget,
    Widget? previousEpisodeWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Siguiente episodio" solo se muestra cuando la lista está colapsada
        if (_visibleEpisodesLimit == 0) ...[
          if (nextEpisodeWidget != null) nextEpisodeWidget,
          if (previousEpisodeWidget != null) previousEpisodeWidget,
        ],

        // Lista in-line paginada de 28 en 28
        if (_visibleEpisodesLimit > 0) ...[
          Padding(
            // Mismo padding que el label de WatchNavCard (top:12, bottom:8)
            // para que "EPISODIOS" ocupe la posición exacta de "SIGUIENTE EPISODIO"
            padding: const EdgeInsets.only(bottom: 8, top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'EPISODIOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _visibleEpisodesLimit = 0;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...episodesList.take(_visibleEpisodesLimit).map((ep) {
            final bool isCurrent = ep.number.toString() == activeEpisodeNum;
            final String epTitle = (ep.title != null && ep.title!.isNotEmpty)
                ? ep.title!
                : 'Episodio ${ep.number}';
            final String durationStr =
                ep.duration ?? (ep.runtime != null ? '${ep.runtime}m' : '24m');
            final String epDate = (ep.airDate != null && ep.airDate!.isNotEmpty)
                ? formatDisplayDate(ep.airDate)
                : '';
            final String qualityStr = (epDate.isNotEmpty && epDate != 'N/A')
                ? epDate
                : (ep.quality ?? 'Sub | Dob');
            final String thumbUrl =
                ep.thumbnail ?? widget.bannerUrl ?? widget.posterUrl ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onEpisodeSelected(ep),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail 16:9 con Badge de Duración y REPRODUCIENDO
                    SizedBox(
                      width: 140,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: thumbUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(thumbUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.white10,
                          ),
                          child: Stack(
                            children: [
                              if (isCurrent)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AurisPalette.brand,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'REPRODUCIENDO',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    durationStr,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Título y Calidad
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            AurisStringUtils.formatEpisodeTitle(ep.number, epTitle),
                            style: TextStyle(
                              color: isCurrent
                                  ? AurisPalette.brand
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            qualityStr,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        // Botón VER MÁS EPISODIOS
        if (_visibleEpisodesLimit < episodesList.length) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBBBBBB),
              side: const BorderSide(color: Color(0xFFBBBBBB), width: 2.0),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () {
              setState(() {
                _visibleEpisodesLimit += 28;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AurisIcon(AurisIcons.episodes, color: const Color(0xFFBBBBBB), size: 24),
                const SizedBox(width: 8),
                Text(
                  _visibleEpisodesLimit == 0
                      ? 'VER MÁS EPISODIOS'
                      : 'VER MÁS EPISODIOS (${episodesList.length - _visibleEpisodesLimit})',
                  style: const TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVerMasEpisodiosButton(
    BuildContext context,
    List<EpisodeInfo> episodesList,
    String activeEpisodeNum,
    ValueChanged<EpisodeInfo> onEpisodeSelected,
  ) {
    if (episodesList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: const Color(0xFF141414),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white10),
              ),
              child: Container(
                width: 480,
                height: 650,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.playlist_play, color: AurisPalette.brand, size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'Episodios',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    Expanded(
                      child: WatchPlaylistSidebar(
                        episodes: episodesList,
                        activeEpisode: activeEpisodeNum,
                        onEpisodeSelected: (ep) {
                          Navigator.pop(context);
                          onEpisodeSelected(ep);
                        },
                        title: 'Todos los episodios',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.zero,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: const Color(0xFFBBBBBB), width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(
                  '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path d="M21 10a1 1 0 011 1v9a1 1 0 01-1 1H3a1 1 0 01-1-1v-9a1 1 0 011-1h18zm-1 2H4v7h16v-7zm0-5a1 1 0 010 2H4a1 1 0 110-2h16zm-2-3a1 1 0 010 2H6a1 1 0 110-2h12z" fill="currentColor"/></svg>''',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(AurisPalette.brand, BlendMode.srcIn),
                ),
                const SizedBox(width: 8),
                const Text(
                  'VER MÁS EPISODIOS',
                  style: TextStyle(
                    color: Color(0xFFBBBBBB),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
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
