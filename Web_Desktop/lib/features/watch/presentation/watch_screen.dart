import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _isAmbientLightingEnabled = true;

  /// URL del último stream que se abrió en el player.
  /// Evita re-abrir el mismo stream en cada rebuild del árbol.
  String _lastOpenedUrl = '';

  @override
  void initState() {
    super.initState();
    // Inicializar el player si no está activo (sin detener uno existente).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activePlayerProvider.notifier).initPlayerIfNeeded();
      ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.full);
      debugPrint('[WebWatch] initState: player inicializado.');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Resolver la fuente real del video via SSE/extract
    final extractAsync = ref.watch(extractStreamProvider(ExtractParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
    )));

    // ── Guardia de URL: sólo actualizamos cuando llega una URL nueva ──
    // Sin esto, cada rebuild (theater mode, etc.) re-abría el stream.
    extractAsync.whenData((result) {
      final resolvedUrl = result.url.isNotEmpty
          ? result.url
          : (result.tracks.firstOrNull?.url ?? '');

      if (resolvedUrl.isNotEmpty && _lastOpenedUrl != resolvedUrl) {
        _lastOpenedUrl = resolvedUrl;
        debugPrint('[WebWatch] Nueva URL resuelta: $resolvedUrl');

        // Actualizar tracks en el provider sin detener la reproducción activa
        final playableTracks =
            result.tracks.where((t) => !t.isDownload).toList();
        if (playableTracks.isNotEmpty) {
          Future.microtask(() {
            if (!mounted) return;
            ref
                .read(activePlayerProvider.notifier)
                .updateSession(tracks: playableTracks);
          });
        }
      }
    });

    // ── SSE listener: captura CADA evento SSE para acumular tracks ──
    // Cuando llegan más streams después del primero, los tracks se acumulan
    // correctamente en el provider.
    ref.listen(
      extractStreamProvider(ExtractParams(
        url: widget.sourceUrl,
        source: widget.source,
        category: widget.category,
      )),
      (prev, next) {
        if (!mounted) return;
        next.whenData((result) {
          final playableTracks =
              result.tracks.where((t) => !t.isDownload).toList();
          final prevCount =
              prev?.value?.tracks.where((t) => !t.isDownload).length ?? 0;
          if (playableTracks.length > prevCount) {
            debugPrint(
              '[WebWatch SSE] Tracks actualizados: $prevCount → ${playableTracks.length}',
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref
                  .read(activePlayerProvider.notifier)
                  .updateSession(tracks: playableTracks);
            });
          }
        });
      },
    );

    // ── URL resuelta para el embedded player ──
    // Usamos _lastOpenedUrl si ya se resolvió; de lo contrario mostramos
    // spinner hasta que el extract devuelva algo concreto.
    final String resolvedUrl = _lastOpenedUrl.isNotEmpty
        ? _lastOpenedUrl
        : (extractAsync.valueOrNull?.url ?? '');

    // ── Episodios para navegación ──
    final cachedEpisodesData = ProgressiveContentNotifier.lookupCachedEpisodesResponse(
      title: widget.title ?? widget.contentId,
      metadataTitle: widget.metadataTitle,
      season: widget.season ?? 1,
    );

    final episodesParams = EpisodesParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
      title: widget.title,
      season: widget.season,
    );

    final episodesData = cachedEpisodesData ?? ref.watch(episodesProvider(episodesParams)).valueOrNull;
    final episodesList =
        widget.playlistEpisodes ?? (episodesData?.episodes ?? []);

    final int currentEpNum = int.tryParse(widget.episode ?? '1') ?? 1;
    final int currentEpIndex =
        episodesList.indexWhere((ep) => ep.number == currentEpNum);
    final int safeIndex = currentEpIndex >= 0 ? currentEpIndex : 0;

    final bool hasPrevious = safeIndex > 0;
    final bool hasNext = safeIndex < episodesList.length - 1;

    final String realEpLabel = (widget.episode != null &&
            widget.episode!.isNotEmpty)
        ? 'Episodio ${widget.episode}'
        : 'En este video';

    // Callbacks para cambiar de episodio de forma consistente si no vienen inyectados
    final effectiveOnNext = widget.onNextEpisode ??
        (hasNext
            ? () {
                final nextEp = episodesList[safeIndex + 1];
                _handleEpisodeSelected(nextEp);
              }
            : null);

    final effectiveOnPrevious = widget.onPreviousEpisode ??
        (hasPrevious
            ? () {
                final prevEp = episodesList[safeIndex - 1];
                _handleEpisodeSelected(prevEp);
              }
            : null);

    final effectiveOnSelected = widget.onEpisodeSelected ?? _handleEpisodeSelected;

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
      onNextEpisode: effectiveOnNext,
      onPreviousEpisode: effectiveOnPrevious,
      onEpisodeSelected: effectiveOnSelected,
      isTheaterMode: _isTheaterMode,
      // Siempre renderizamos CleanEmbeddedPlayer para que el Stack(fit:expand)
      // siempre tenga constraints correctos. El player muestra su propio spinner
      // interno mientras la URL no esté lista (_hasLoadedFirstFrame = false).
      playerWidget: CleanEmbeddedPlayer(
        // ValueKey garantiza que el widget se reconstruye cuando cambia
        // el episodio o la URL, forzando la carga limpia del nuevo episodio
        key: ValueKey('${widget.episode}_${resolvedUrl.isNotEmpty ? resolvedUrl : "__loading__"}'),
        sourceUrl: resolvedUrl,
        source: widget.source,
        category: widget.category,
        contentId: widget.contentId,
        title: widget.title ?? widget.metadataTitle,
        episode: widget.episode,
        season: widget.season,
        posterUrl: widget.posterUrl,
        bannerUrl: widget.bannerUrl,
        episodeTitle: widget.episodeTitle,
        onExpandPressed: () => _openFullscreenPlayer(context),
        onNextEpisode: effectiveOnNext,
        onPreviousEpisode: effectiveOnPrevious,
        hasPrevious: hasPrevious,
        hasNext: hasNext,
        episodeLabel: realEpLabel,
        isTheaterMode: _isTheaterMode,
        onTheaterModeToggle: () =>
            setState(() => _isTheaterMode = !_isTheaterMode),
        isAmbientLightingEnabled: _isAmbientLightingEnabled,
        onAmbientLightingToggle: (val) =>
            setState(() => _isAmbientLightingEnabled = val),
        onBack: _handleBackToContent,
      ),
    );
  }

  void _handleBackToContent() {
    if (UrlUtils.lastContentUri != null && UrlUtils.lastContentUri!.isNotEmpty) {
      context.go(UrlUtils.lastContentUri!);
    } else {
      // Si entró directamente por URL/bookmark y no hay lastContentUri,
      // reconstruye la URL de la ficha para volver a ella.
      final fallbackContentUri = UrlUtils.buildShareableUri(
        title: widget.title ?? widget.metadataTitle ?? '',
        source: widget.source,
        url: widget.sourceUrl,
        category: widget.category,
        season: widget.season,
      );
      context.go(fallbackContentUri);
    }
  }

  void _handleEpisodeSelected(EpisodeInfo ep) {
    setState(() {
      _lastOpenedUrl = '';
    });
    final targetUrl = ep.url.isNotEmpty
        ? ep.url
        : buildEpisodeUrl(widget.sourceUrl, widget.source, ep.number);
    final uri = UrlUtils.buildPlayerUri(
      title: widget.title ?? widget.metadataTitle ?? '',
      contentId: widget.contentId,
      episode: ep.number.toString(),
      source: widget.source,
      url: targetUrl,
      season: widget.season,
      serverName: widget.serverName,
      category: widget.category,
      totalEpisodes: widget.totalEpisodes,
      posterUrl: ep.thumbnail ?? widget.posterUrl,
      bannerUrl: widget.bannerUrl,
      logoUrl: widget.logoUrl,
      episodeTitle: ep.title,
      certification: widget.certification,
      year: widget.year,
    );
    context.pushReplacement(uri);
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
