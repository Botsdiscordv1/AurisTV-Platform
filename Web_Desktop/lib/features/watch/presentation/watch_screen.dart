import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';
import '../../player/presentation/player_screen.dart';
import '../../../core/utils/url_utils.dart';

/// Pantalla WatchScreen para Web.
///
/// Reutiliza `WatchScreenBase` (UI compartida) e inyecta un reproductor
/// que resuelve la fuente mediante el provider del repositorio.
class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({
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
    this.synopsis,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.onEpisodeSelected,
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
  final String? synopsis;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final ValueChanged<EpisodeInfo>? onEpisodeSelected;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  bool _isTheaterMode = false;
  final GlobalKey _playerKey = GlobalKey(debugLabel: 'embedded_player_global_key');

  @override
  Widget build(BuildContext context) {
    // Resolver la fuente real del video
    final extractAsync = ref.watch(extractStreamProvider(ExtractParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
    )));

    final String resolvedUrl = extractAsync.valueOrNull?.url ?? widget.sourceUrl;

    // Resolver episodios para navegación y etiquetas
    final episodesParams = EpisodesParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
      title: widget.title,
      season: widget.season,
    );

    final episodesAsync = ref.watch(episodesProvider(episodesParams));
    final episodesData = episodesAsync.valueOrNull;
    final episodesList = widget.playlistEpisodes ?? (episodesData?.episodes ?? []);

    final int currentEpNum = int.tryParse(widget.episode ?? '1') ?? 1;
    final int currentEpIndex = episodesList.indexWhere((ep) => ep.number == currentEpNum);
    final int safeIndex = currentEpIndex >= 0 ? currentEpIndex : 0;

    final bool hasPrevious = safeIndex > 0;
    final bool hasNext = safeIndex < episodesList.length - 1;

    final String realEpLabel = (widget.episode != null && widget.episode!.isNotEmpty)
        ? 'Episodio ${widget.episode}'
        : 'En este video';

    return WatchScreenBase(
      contentId: widget.contentId,
      sourceUrl: widget.sourceUrl,
      source: widget.source,
      episode: widget.episode,
      season: widget.season,
      serverName: widget.serverName,
      category: widget.category,
      title: widget.title,
      metadataTitle: widget.metadataTitle,
      episodeTitle: widget.episodeTitle,
      posterUrl: widget.posterUrl,
      bannerUrl: widget.bannerUrl,
      logoUrl: widget.logoUrl,
      year: widget.year,
      certification: widget.certification,
      totalEpisodes: widget.totalEpisodes,
      skipResume: widget.skipResume,
      isLive: widget.isLive,
      playlistEpisodes: widget.playlistEpisodes,
      playlistIndex: widget.playlistIndex,
      synopsis: widget.synopsis,
      onNextEpisode: widget.onNextEpisode,
      onPreviousEpisode: widget.onPreviousEpisode,
      onEpisodeSelected: widget.onEpisodeSelected,
      isTheaterMode: _isTheaterMode,
      playerWidget: resolvedUrl.isNotEmpty 
        ? KeyedSubtree(
            key: _playerKey,
            child: CleanEmbeddedPlayer(
              key: ValueKey(resolvedUrl),
              sourceUrl: resolvedUrl,
              source: widget.source,
              category: widget.category,
              onExpandPressed: () => _openFullscreenPlayer(context),
              onNextEpisode: widget.onNextEpisode,
              onPreviousEpisode: widget.onPreviousEpisode,
              hasPrevious: hasPrevious,
              hasNext: hasNext,
              episodeLabel: realEpLabel,
              isTheaterMode: _isTheaterMode,
              onTheaterModeToggle: () => setState(() => _isTheaterMode = !_isTheaterMode),
            ),
          )
        : const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
    );
  }

  void _openFullscreenPlayer(BuildContext context) {
    final player = PlayerScreen(
      contentId: widget.contentId,
      sourceUrl: widget.sourceUrl,
      source: widget.source,
      episode: widget.episode,
      season: widget.season,
      serverName: widget.serverName,
      category: widget.category,
      title: widget.title,
      metadataTitle: widget.metadataTitle,
      episodeTitle: widget.episodeTitle,
      posterUrl: widget.posterUrl,
      bannerUrl: widget.bannerUrl,
      logoUrl: widget.logoUrl,
      year: widget.year,
      certification: widget.certification,
      totalEpisodes: widget.totalEpisodes,
      skipResume: widget.skipResume,
      isLive: widget.isLive,
    );
    
    UrlUtils.openPlayer(context, player);
  }
}