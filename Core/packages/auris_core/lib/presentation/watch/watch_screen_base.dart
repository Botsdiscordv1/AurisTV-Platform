import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';
import 'package:collection/collection.dart';
import 'adaptive_watch_layout.dart';
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
    this.isTheaterMode = false,
    this.showPlaylistSidebar = true,
  });

  final String contentId;
  final String sourceUrl;
  final String source;
  final String? episode;
  final int? season;
  final String? serverName;
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
  final bool isTheaterMode;
  final bool showPlaylistSidebar;

  @override
  ConsumerState<WatchScreenBase> createState() => _WatchScreenBaseState();
}

class _WatchScreenBaseState extends ConsumerState<WatchScreenBase> {
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

    final episodesParams = EpisodesParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
      title: seriesTitle,
      season: widget.season,
    );

    final episodesData = isMovie ? null : ref.watch(episodesProvider(episodesParams)).valueOrNull;
    final List<EpisodeInfo> episodesList = isMovie
        ? const []
        : (widget.playlistEpisodes ?? (episodesData?.episodes ?? []));

    // Resolver el número actual del episodio
    final int currentEpNum = int.tryParse(widget.episode ?? '1') ?? 1;

    // Encontrar el episodio activo por número exacto
    final EpisodeInfo? activeEpisode = isMovie ? null : episodesList.firstWhereOrNull((ep) => ep.number == currentEpNum);

    final String realEpTitle = isMovie
        ? (widget.episodeTitle ?? seriesTitle)
        : ((activeEpisode?.title != null && activeEpisode!.title!.isNotEmpty)
            ? activeEpisode.title!
            : (widget.episodeTitle ?? 'Episodio $currentEpNum'));

    final String realSynopsis = isMovie
        ? (widget.synopsis ?? 'Disfruta de $seriesTitle con la mejor calidad en AurisTV.')
        : ((activeEpisode?.description != null && activeEpisode!.description!.isNotEmpty)
            ? activeEpisode.description!
            : (widget.synopsis ?? 'Sigue las aventuras de $seriesTitle en este episodio $realEpTitle con la mejor calidad en AurisTV.'));

    final String rawDate = (activeEpisode?.airDate != null && activeEpisode!.airDate!.isNotEmpty)
        ? activeEpisode.airDate!
        : (episodesData?.seasonAirDate ?? episodesData?.releaseDate ?? (widget.year != null ? widget.year.toString() : ''));

    final String realReleaseDate = formatDisplayDate(rawDate);

    final String realBadges = (activeEpisode?.quality != null && activeEpisode!.quality!.isNotEmpty)
        ? activeEpisode.quality!
        : 'Sub | Dob';

    final String realCertification = (widget.certification != null && widget.certification!.isNotEmpty && widget.certification != 'NR')
        ? widget.certification!.toUpperCase()
        : '16+';

    // Calcular episodio siguiente y anterior por número de episodio real (solo para series)
    EpisodeInfo? nextEp;
    EpisodeInfo? prevEp;
    if (!isMovie) {
      for (final ep in episodesList) {
        if (ep.number == currentEpNum + 1) nextEp = ep;
        if (ep.number == currentEpNum - 1) prevEp = ep;
      }
    }

    final Widget nextEpisodeWidget = (!isMovie && nextEp != null)
        ? WatchNavCard(
            sectionLabel: 'SIGUIENTE EPISODIO',
            episodeNumber: 'E${nextEp.number}',
            episodeTitle: (nextEp.title != null && nextEp.title!.isNotEmpty) ? nextEp.title! : 'Episodio ${nextEp.number}',
            thumbnailUrl: nextEp.thumbnail ?? widget.bannerUrl,
            duration: nextEp.duration ?? (nextEp.runtime != null ? '${nextEp.runtime}m' : '24m'),
            audioSubsBadge: nextEp.quality ?? 'Sub | Dob',
            onTap: (widget.onEpisodeSelected != null)
                ? () => widget.onEpisodeSelected!(nextEp!)
                : widget.onNextEpisode,
          )
        : const SizedBox.shrink();

    final Widget previousEpisodeWidget = (!isMovie && prevEp != null)
        ? WatchNavCard(
            sectionLabel: 'EPISODIO ANTERIOR',
            episodeNumber: 'E${prevEp.number}',
            episodeTitle: (prevEp.title != null && prevEp.title!.isNotEmpty) ? prevEp.title! : 'Episodio ${prevEp.number}',
            thumbnailUrl: prevEp.thumbnail ?? widget.bannerUrl,
            duration: prevEp.duration ?? (prevEp.runtime != null ? '${prevEp.runtime}m' : '24m'),
            audioSubsBadge: prevEp.quality ?? 'Sub | Dob',
            onTap: (widget.onEpisodeSelected != null)
                ? () => widget.onEpisodeSelected!(prevEp!)
                : widget.onPreviousEpisode,
          )
        : const SizedBox.shrink();

    final String epNumDisplay = isMovie ? 'Película' : ((activeEpisode?.number != null) ? 'E${activeEpisode!.number}' : (widget.episode != null ? 'E${widget.episode}' : 'E$currentEpNum'));

    return Scaffold(
      backgroundColor: Colors.black,
      body: AdaptiveWatchLayout(
        isTheaterMode: widget.isTheaterMode,
        playerWidget: widget.playerWidget,
        metadataWidget: WatchEpisodeMetadata(
          seriesTitle: seriesTitle,
          episodeTitle: realEpTitle,
          episodeNumber: epNumDisplay,
          ratingBadge: realCertification,
          audioSubsBadge: realBadges,
          releaseDate: realReleaseDate,
          isBookmarked: isBookmarked,
          onBookmarkToggle: () {
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
          },
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
        playlistSidebarWidget: (widget.showPlaylistSidebar && !isMovie && episodesList.isNotEmpty)
            ? WatchPlaylistSidebar(
                episodes: episodesList,
                activeEpisode: (activeEpisode?.number ?? currentEpNum).toString(),
                onEpisodeSelected: widget.onEpisodeSelected ?? (_) {},
              )
            : null,
        rightColumnWidget: widget.showPlaylistSidebar && !isMovie
            ? (episodesList.isNotEmpty
                ? WatchPlaylistSidebar(
                    episodes: episodesList,
                    activeEpisode: (activeEpisode?.number ?? currentEpNum).toString(),
                    onEpisodeSelected: widget.onEpisodeSelected ?? (_) {},
                  )
                : null)
            : (episodesList.isNotEmpty
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
      ),
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
                        const Icon(Icons.playlist_play, color: Color(0xFFEF7A1E), size: 24),
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
                  colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
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
