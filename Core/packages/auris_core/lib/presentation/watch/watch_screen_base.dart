import 'package:flutter/material.dart';
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
class WatchScreenBase extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Favorites Logic
    final favorites = ref.watch(favoritesProvider);
    final bool isBookmarked = favorites.any((f) => f.id == contentId || f.title == (metadataTitle ?? title));
    // Resolver los episodios reales usando el provider
    final episodesParams = EpisodesParams(
      url: sourceUrl,
      source: source,
      category: category,
      title: title,
      season: season,
    );

    final episodesAsync = ref.watch(episodesProvider(episodesParams));
    final episodesData = episodesAsync.valueOrNull;
    final episodesList = playlistEpisodes ?? (episodesData?.episodes ?? []);

    // Resolver el número actual del episodio
    final int currentEpNum = int.tryParse(episode ?? '1') ?? 1;

    // Encontrar el índice real del episodio actual en la lista
    final int currentEpIndex = episodesList.indexWhere((ep) => ep.number == currentEpNum);
    final int safeIndex = currentEpIndex >= 0 ? currentEpIndex : 0;

    // Encontrar el episodio activo
    final EpisodeInfo? activeEpisode = episodesList.isNotEmpty && safeIndex < episodesList.length
        ? episodesList[safeIndex]
        : episodesList.firstWhereOrNull((ep) => ep.number == currentEpNum);

    final String realEpTitle = (activeEpisode?.title != null && activeEpisode!.title!.isNotEmpty)
        ? activeEpisode.title!
        : (episodeTitle ?? 'Episodio $currentEpNum');

    final String realSynopsis = (activeEpisode?.description != null && activeEpisode!.description!.isNotEmpty)
        ? activeEpisode.description!
        : (synopsis ?? 'Sigue las aventuras de ${title ?? metadataTitle ?? ''} con la mejor calidad en AurisTV.');

    final String realCertification = (certification != null && certification!.isNotEmpty && certification != 'NR')
        ? certification!.toUpperCase()
        : '16+';

    // Encontrar el siguiente y anterior episodio usando los índices reales
    final bool hasPrevious = safeIndex > 0;
    final bool hasNext = safeIndex < episodesList.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AdaptiveWatchLayout(
        isTheaterMode: isTheaterMode,
        playerWidget: playerWidget,
        metadataWidget: WatchEpisodeMetadata(
          seriesTitle: metadataTitle ?? title ?? '',
          episodeTitle: realEpTitle,
          episodeNumber: (activeEpisode?.number != null) ? 'E${activeEpisode!.number}' : 'E$currentEpNum',
          ratingBadge: realCertification,
          audioSubsBadge: activeEpisode?.quality ?? 'Sub | Dob',
          releaseDate: formatDisplayDate(activeEpisode?.airDate),
          isBookmarked: isBookmarked,
          onBookmarkToggle: () {
            final favItem = FavoriteItem(
              id: contentId,
              title: metadataTitle ?? title ?? '',
              posterUrl: posterUrl ?? bannerUrl ?? '',
              bannerUrl: bannerUrl ?? '',
              category: category ?? 'anime',
              source: source,
              url: sourceUrl,
              addedAt: DateTime.now(),
              profileId: 'guest_profile',
              year: year,
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
        nextEpisodeWidget: hasNext
            ? WatchNavCard(
                sectionLabel: 'SIGUIENTE EPISODIO',
                episodeNumber: 'E${episodesList[safeIndex + 1].number}',
                episodeTitle: episodesList[safeIndex + 1].title ?? '',
                thumbnailUrl: episodesList[safeIndex + 1].thumbnail,
                audioSubsBadge: episodesList[safeIndex + 1].quality ?? 'Sub | Dob',
                onTap: onNextEpisode,
              )
            : const SizedBox.shrink(),
        previousEpisodeWidget: hasPrevious
            ? WatchNavCard(
                sectionLabel: 'EPISODIO ANTERIOR',
                episodeNumber: 'E${episodesList[safeIndex - 1].number}',
                episodeTitle: episodesList[safeIndex - 1].title ?? '',
                thumbnailUrl: episodesList[safeIndex - 1].thumbnail,
                audioSubsBadge: episodesList[safeIndex - 1].quality ?? 'Sub | Dob',
                onTap: onPreviousEpisode,
              )
            : const SizedBox.shrink(),
        playlistSidebarWidget: episodesList.isNotEmpty
            ? WatchPlaylistSidebar(
                episodes: episodesList,
                activeEpisode: (activeEpisode?.number ?? currentEpNum).toString(),
                onEpisodeSelected: onEpisodeSelected ?? (_) {},
              )
            : null,
      ),
    );
  }
}
