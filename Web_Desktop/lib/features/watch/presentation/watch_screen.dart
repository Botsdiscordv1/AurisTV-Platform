import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../player/presentation/player_screen.dart';
import '../../../core/utils/app_fullscreen.dart';
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
    this.video720,
    this.video1080,
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
  final String? video720;
  final String? video1080;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  bool _isTheaterMode = false;
  bool _isAmbientLightingEnabled = true;

  /// Modo pantalla completa real (solo Web): el navegador entra en fullscreen
  /// y la WatchScreen se colapsa al reproductor.
  bool _isFullscreen = false;
  StreamSubscription<void>? _fullscreenSub;

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

    // Sincroniza el estado cuando el navegador sale de fullscreen por su cuenta
    // (Esc, botón del navegador o gesto del sistema).
    if (kIsWeb) {
      _fullscreenSub = onFullscreenChanged()?.listen((_) {
        if (!mounted) return;
        final bool isActive = isAppFullscreen();
        if (isActive != _isFullscreen) {
          setState(() => _isFullscreen = isActive);
        }
      });
    }
  }

  @override
  void dispose() {
    _fullscreenSub?.cancel();
    if (kIsWeb && _isFullscreen) {
      setAppFullscreen(false);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(WatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourceUrl != oldWidget.sourceUrl || widget.episode != oldWidget.episode) {
      _lastOpenedUrl = '';
    }
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
    final bool isTheme = widget.source == 'Themes' || widget.source == 'YouTube' || widget.sourceUrl.contains('animethemes.moe');

    final cachedEpisodesData = isTheme
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
      title: widget.title,
      season: widget.season,
    );

    final episodesData = isTheme
        ? null
        : (cachedEpisodesData ?? ref.watch(episodesProvider(episodesParams)).valueOrNull);
    final episodesList = isTheme
        ? const <EpisodeInfo>[]
        : (widget.playlistEpisodes ?? (episodesData?.episodes ?? []));

    final int? parsedEpNum = int.tryParse(widget.episode ?? '');
    final int currentEpNum = parsedEpNum ?? 1;
    final int currentEpIndex = (isTheme || parsedEpNum == null)
        ? -1
        : episodesList.indexWhere((ep) => ep.number == currentEpNum);
    final int safeIndex = currentEpIndex >= 0 ? currentEpIndex : 0;

    final bool hasPrevious = !isTheme && safeIndex > 0;
    final bool hasNext = !isTheme && episodesList.isNotEmpty && safeIndex < episodesList.length - 1;

    final String realEpLabel = isTheme
        ? (widget.episode ?? 'Tema Musical')
        : ((widget.episode != null && widget.episode!.isNotEmpty)
            ? 'Episodio ${widget.episode}'
            : 'En este video');

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

    // Player compartido entre el layout normal y el modo pantalla completa.
    final Widget cleanPlayerWidget = CleanEmbeddedPlayer(
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
      onExpandPressed: _toggleFullscreen,
      onNextEpisode: effectiveOnNext,
      onPreviousEpisode: effectiveOnPrevious,
      hasPrevious: hasPrevious,
      hasNext: hasNext,
      episodeLabel: realEpLabel,
      isTheaterMode: _isTheaterMode,
      onTheaterModeToggle: () =>
          setState(() => _isTheaterMode = !_isTheaterMode),
      isAmbientLightingEnabled: _isAmbientLightingEnabled,
      cinematicAmbient: _isFullscreen,
      onAmbientLightingToggle: (val) =>
          setState(() => _isAmbientLightingEnabled = val),
      onBack: _isFullscreen ? _toggleFullscreen : _handleBackToContent,
      showBackButton: _isFullscreen ? true : null,
      video720: widget.video720,
      video1080: widget.video1080,
    );

    return Stack(
      children: [
        // WatchScreenBase se mantiene montado para que su dispose no detenga
        // el motor de reproducción al entrar/salir de pantalla completa.
        WatchScreenBase(
      isAmbientGlowEnabled: _isAmbientLightingEnabled,
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
      totalEpisodes: isTheme ? 1 : widget.totalEpisodes,
      skipResume: widget.skipResume,
      isLive: widget.isLive,
      playlistEpisodes: isTheme ? const [] : widget.playlistEpisodes,
      playlistIndex: widget.playlistIndex,
      synopsis: widget.synopsis,
      showPlaylistSidebar: !isTheme,
      onNextEpisode: effectiveOnNext,
      onPreviousEpisode: effectiveOnPrevious,
      onEpisodeSelected: effectiveOnSelected,
      onBack: _handleBackToContent,
      isTheaterMode: _isTheaterMode,
      // En pantalla completa el player se dibuja en un layer propio encima del
      // layout, para no desmontar WatchScreenBase.
      playerWidget: _isFullscreen ? const SizedBox.shrink() : cleanPlayerWidget,
        ),

        // Modo pantalla completa: sólo el reproductor. Se envuelve en Scaffold
        // para que el player tenga ancestro Material (textos, iconos, Slider y
        // ripple se renderizan igual que en el embedded normal).
        if (_isFullscreen)
          Positioned.fill(
            child: Scaffold(
              backgroundColor: Colors.black,
              body: cleanPlayerWidget,
            ),
          ),
      ],
    );
  }

  void _handleBackToContent() {
    if (UrlUtils.lastContentUri != null && UrlUtils.lastContentUri!.isNotEmpty) {
      context.go(UrlUtils.lastContentUri!, extra: UrlUtils.lastContentExtra);
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
      video720: widget.video720,
      video1080: widget.video1080,
      skipResume: widget.skipResume,
      isLive: widget.isLive,
    );
    context.pushReplacement(uri);
  }

  /// Alterna el modo pantalla completa del reproductor.
  ///
  /// En Web entra/sale del fullscreen del navegador y colapsa la pantalla al
  /// reproductor. En nativo (Windows/Linux/macOS) conserva el comportamiento
  /// anterior: abrir el reproductor dedicado.
  void _toggleFullscreen() {
    if (kIsWeb) {
      final bool next = !_isFullscreen;
      setState(() => _isFullscreen = next);
      setAppFullscreen(next);
      return;
    }

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
