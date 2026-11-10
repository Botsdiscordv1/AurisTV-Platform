import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:auris_core/auris_core.dart';
import 'package:auris_core/presentation/watch/adaptive_watch_layout.dart';
import 'package:auris_core/presentation/watch/widgets/watch_episode_metadata.dart';
import 'package:auris_core/presentation/watch/widgets/watch_action_bar.dart';
import 'package:auris_core/presentation/watch/widgets/watch_synopsis.dart';
import 'package:auris_core/presentation/watch/widgets/watch_nav_card.dart';
import 'package:auris_core/presentation/watch/widgets/watch_playlist_sidebar.dart';

/// Pantalla WatchScreen (Previa al Player Fullscreen - Crunchyroll Style).
///
/// Muestra:
/// - Reproductor embebido funcional en contenedor 16:9 con mini controles y botón de Pantalla Completa.
/// - Metadatos completos del episodio (Título, Badges, Favoritos).
/// - Barra de Reacciones (Me gusta, No me gusta, Compartir).
/// - Sinopsis expandible con "VER MÁS" (solo cuando supera 4 líneas).
/// - Tarjetas de Navegación "SIGUIENTE EPISODIO" y "EPISODIO ANTERIOR".
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
    this.startPosition,
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
  final int? startPosition;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  Player? _player;
  VideoController? _videoController;
  Timer? _hideControlsTimer;
  String _lastOpenedUrl = '';

  bool _showControls = false;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _hasLoadedFirstFrame = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 20412;
  int _dislikeCount = 142;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player = Player();

    // Configuración MPV de Alto Rendimiento para HLS en Android (Aceleración HW + Cache de lectura previa)
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final platform = _player!.platform as dynamic;
        platform.setProperty('ao', 'audiotrack');
        platform.setProperty('hwdec', 'auto-safe');
        platform.setProperty('vo', 'gpu');
        platform.setProperty('cache', 'yes');
        platform.setProperty('demuxer-readahead-secs', '20');
        platform.setProperty('hr-seek', 'yes');
        platform.setProperty('hr-seek-demuxer-offset', '0');
        platform.setProperty('video-sync', 'display-resample');
        platform.setProperty('audio-buffer', '0.2');
      }
    } catch (_) {}

    _videoController = VideoController(
      _player!,
      configuration: const VideoControllerConfiguration(
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );

    if (widget.sourceUrl.isNotEmpty) {
      _player?.open(Media(widget.sourceUrl));
    }

    _player?.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing && _position.inMilliseconds > 0) {
            _hasLoadedFirstFrame = true;
          }
        });
      }
    });

    _player?.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() => _isBuffering = buffering);
      }
    });

    _player?.stream.position.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
          if (pos.inMilliseconds > 0 && _isPlaying) {
            _hasLoadedFirstFrame = true;
          }
        });

        // Guardar progreso en el historial cada 5 segundos de reproducción
        if (pos.inSeconds > 0 && pos.inSeconds % 5 == 0 && _duration.inSeconds > 0) {
          _updateHistory(pos.inMilliseconds, _duration.inMilliseconds);
        }
      }
    });

    _player?.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _startHideTimer();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  bool _isFullscreen = false;

  Future<void> _toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
      _showControls = true;
    });

    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _player?.dispose();
    super.dispose();
  }

  void _navigateToFullscreen() {
    final int currentPosMs = _player?.state.position.inMilliseconds ?? 0;
    _player?.pause();

    final queryParams = <String, String>{
      if (widget.sourceUrl.isNotEmpty) 'url': widget.sourceUrl,
      if (widget.source.isNotEmpty) 'source': widget.source,
      if (widget.episode != null) 'episode': widget.episode!,
      if (widget.season != null) 'season': widget.season.toString(),
      if (widget.serverName != null) 'serverName': widget.serverName!,
      if (widget.category != null) 'category': widget.category!,
      if (widget.title != null) 'title': widget.title!,
      if (widget.metadataTitle != null) 'metadataTitle': widget.metadataTitle!,
      if (widget.episodeTitle != null) 'episodeTitle': widget.episodeTitle!,
      if (widget.posterUrl != null) 'posterUrl': widget.posterUrl!,
      if (widget.bannerUrl != null) 'bannerUrl': widget.bannerUrl!,
      if (widget.logoUrl != null) 'logoUrl': widget.logoUrl!,
      if (widget.certification != null) 'certification': widget.certification!,
      'startPosition': currentPosMs.toString(),
    };

    final uri = Uri(
      path: '/player/${widget.contentId}',
      queryParameters: queryParams,
    );

    context.push(uri.toString());
  }

  Future<void> _cargarEpisodioHlsSeguro(String urlStream, Map<String, String> headers) async {
    try {
      await _player?.stop();

      // Consultar historial para reanudación inteligente de progreso
      final String seriesTitle = widget.title ?? widget.metadataTitle ?? widget.contentId;
      final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(
        seriesTitle,
        widget.season ?? 1,
        widget.episode ?? '1',
      );
      final int resumeMs = widget.startPosition ?? (hist?.positionInMilliseconds ?? 0);
      final bool shouldResume = resumeMs > 3000 && !(hist?.isCompleted ?? false);
      final Duration startDur = shouldResume ? Duration(milliseconds: resumeMs) : Duration.zero;

      if (shouldResume) {
        debugPrint('[WatchScreen] Reanudando progreso guardado en ${resumeMs ~/ 1000}s para "$seriesTitle" E${widget.episode}');
      }

      // Abrir en modo pausado para permitir que la textura de Flutter (1920x1080) se estabilice
      await _player?.open(
        Media(urlStream, httpHeaders: headers, start: startDur),
        play: false,
      );

      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (shouldResume) {
          await _player?.seek(startDur);
        } else {
          await _player?.seek(Duration.zero);
        }
      }

      await _player?.play();
    } catch (e) {
      debugPrint('[WatchScreen] Error al cargar HLS seguro: $e');
    }
  }

  void _updateHistory(int posMs, int durMs) {
    if (posMs <= 0 || durMs <= 0) return;
    final String seriesTitle = widget.title ?? widget.metadataTitle ?? widget.contentId;
    ref.read(playbackHistoryStateProvider.notifier).updatePosition(
      contentId: seriesTitle,
      season: widget.season,
      episode: widget.episode,
      positionMs: posMs,
      durationMs: durMs,
      title: seriesTitle,
      posterUrl: widget.posterUrl,
      bannerUrl: widget.bannerUrl,
      category: widget.category,
      source: widget.source,
      url: widget.sourceUrl,
      episodeTitle: widget.episodeTitle,
    );
  }



  void _switchEpisode(EpisodeInfo ep) {
    final String targetUrl = ep.url.isNotEmpty ? ep.url : widget.sourceUrl;
    final queryParams = <String, String>{
      'url': targetUrl,
      'source': widget.source,
      'episode': ep.number.toString(),
      if (widget.season != null) 'season': widget.season.toString(),
      if (widget.serverName != null) 'serverName': widget.serverName!,
      if (widget.category != null) 'category': widget.category!,
      if (widget.title != null) 'title': widget.title!,
      if (widget.metadataTitle != null) 'metadataTitle': widget.metadataTitle!,
      if (ep.title != null && ep.title!.isNotEmpty) 'episodeTitle': ep.title!,
      if (ep.thumbnail != null) 'posterUrl': ep.thumbnail!,
      if (widget.bannerUrl != null) 'bannerUrl': widget.bannerUrl!,
      if (widget.logoUrl != null) 'logoUrl': widget.logoUrl!,
      if (widget.certification != null) 'certification': widget.certification!,
      if (widget.year != null) 'year': widget.year.toString(),
    };

    final uri = Uri(
      path: '/watch/${widget.contentId}',
      queryParameters: queryParams,
    );

    context.pushReplacement(uri.toString());
  }

  String _formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _rewind10() {
    final target = _position - const Duration(seconds: 10);
    final clamped = target < Duration.zero ? Duration.zero : target;
    setState(() => _position = clamped); // UI optimista en 0ms
    _player?.seek(clamped);
    _startHideTimer();
  }

  void _fastForward10() {
    final target = _position + const Duration(seconds: 10);
    final maxDur = _duration > Duration.zero ? _duration : const Duration(hours: 10);
    final clamped = target > maxDur ? maxDur : target;
    setState(() => _position = clamped); // UI optimista en 0ms
    _player?.seek(clamped);
    _startHideTimer();
  }

  Widget _buildEmbeddedPlayer() {
    final bool isInitialLoading = !_hasLoadedFirstFrame;

    return GestureDetector(
      onTap: () {
        if (!isInitialLoading) {
          _toggleControls();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Capa de Video real
          if (_videoController != null)
            Video(
              controller: _videoController!,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            )
          else
            Container(color: Colors.black),

          // 1. Fase de Carga Inicial Única (Solo antes de reproducir el primer frame del episodio)
          if (isInitialLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
              ),
            ),

          // 2. Overlay de Controles (Disponible cuando el primer frame ya cargó)
          AnimatedOpacity(
            opacity: (_showControls && !isInitialLoading) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !(_showControls && !isInitialLoading),
              child: Container(
                color: Colors.black38,
                child: Stack(
                  children: [
                    // Botones Centrales: Retroceder 10s, Play/Pausa, Adelantar 10s
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 32,
                            icon: const Icon(Icons.replay_10, color: Colors.white),
                            onPressed: _rewind10,
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 38,
                            icon: AurisIcon(
                              _isPlaying ? AurisIcons.pauseFilled : AurisIcons.playFilled,
                              color: const Color(0xFFEF7A1E),
                              size: 38,
                            ),
                            onPressed: () {
                              if (_isPlaying) {
                                _player?.pause();
                              } else {
                                _player?.play();
                              }
                              _startHideTimer();
                            },
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 32,
                            icon: const Icon(Icons.forward_10, color: Colors.white),
                            onPressed: _fastForward10,
                          ),
                        ],
                      ),
                    ),

                    // Cabecera Fullscreen (Título y Botón Salir)
                    if (_isFullscreen)
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            IconButton(
                              icon: AurisIcon(AurisIcons.arrowLeft, color: Colors.white, size: 24),
                              onPressed: _toggleFullscreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${widget.title ?? widget.metadataTitle ?? "AurisTV"} - ${widget.episodeTitle ?? "Episodio ${widget.episode ?? "1"}"}',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Botón Circular de Pantalla Completa (Navega a PlayerScreen con todos los controles completos)
                    Positioned(
                      right: 12,
                      bottom: 46,
                      child: InkWell(
                        onTap: _navigateToFullscreen,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AurisIcon(
                              AurisIcons.expand,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Barra Inferior: Tiempo y Slider de Progreso
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 2),
                            child: Text(
                              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SliderTheme(
                            data: const SliderThemeData(
                              trackHeight: 3,
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                              activeTrackColor: Color(0xFFEF7A1E),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Color(0xFFEF7A1E),
                            ),
                            child: Slider(
                              value: _position.inSeconds.toDouble().clamp(0, (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble()),
                              max: (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble(),
                              onChanged: (value) {
                                final targetSec = value.toInt();
                                if (targetSec >= 0) {
                                  final target = Duration(seconds: targetSec);
                                  setState(() => _position = target); // UI optimista en 0ms
                                  _player?.seek(target);
                                  _startHideTimer();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String seriesTitle = widget.title ?? widget.metadataTitle ?? 'AurisTV Content';
    final int currentEpNum = int.tryParse(widget.episode ?? '1') ?? 1;
    final String epNumStr = widget.episode != null ? 'E${widget.episode}' : 'E$currentEpNum';

    // Extracción y resolución automática del stream HLS/MP4
    final extractAsync = ref.watch(extractStreamProvider(ExtractParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
    )));

    extractAsync.whenData((extractRes) {
      final String resolvedUrl = extractRes.url.isNotEmpty
          ? extractRes.url
          : (extractRes.tracks.firstOrNull?.url ?? widget.sourceUrl);
      final Map<String, String> resolvedHeaders = extractRes.headers.isNotEmpty
          ? extractRes.headers
          : (extractRes.tracks.firstOrNull?.headers ?? const {});

      if (resolvedUrl.isNotEmpty && _lastOpenedUrl != resolvedUrl) {
        _lastOpenedUrl = resolvedUrl;
        setState(() {
          _hasLoadedFirstFrame = false;
          _isBuffering = true;
          _showControls = false;
          _position = Duration.zero;
        });
        final bool isHls = resolvedUrl.contains('.m3u8') || resolvedUrl.contains('/hls/');
        debugPrint('====================================================');
        debugPrint('[WatchScreen STREAM LOG] Fuente/Servidor: ${widget.source} (${widget.serverName ?? ""})');
        debugPrint('[WatchScreen STREAM LOG] URL Stream: $resolvedUrl');
        debugPrint('[WatchScreen STREAM LOG] HLS = $isHls');
        debugPrint('====================================================');

        _cargarEpisodioHlsSeguro(resolvedUrl, resolvedHeaders);
      }
    });

    // Consultar lista de episodios de la serie desde el provider de datos reales
    final episodesData = ref.watch(episodesProvider(EpisodesParams(
      url: widget.sourceUrl,
      source: widget.source,
      title: seriesTitle,
      season: widget.season,
    ))).valueOrNull;

    final List<EpisodeInfo> epList = episodesData?.episodes ?? [];
    final EpisodeInfo? currentEp = epList.firstWhereOrNull((ep) => ep.number == currentEpNum);

    // Metadata Real del Episodio Activo
    final String realEpTitle = (currentEp?.title != null && currentEp!.title!.isNotEmpty)
        ? currentEp.title!
        : (widget.episodeTitle ?? 'Episodio $currentEpNum');

    final String realSynopsis = (currentEp?.description != null && currentEp!.description!.isNotEmpty)
        ? currentEp.description!
        : 'Sigue las aventuras de $seriesTitle en este episodio $realEpTitle con la mejor calidad en AurisTV.';

    final String rawDate = (currentEp?.airDate != null && currentEp!.airDate!.isNotEmpty)
        ? currentEp.airDate!
        : (episodesData?.seasonAirDate ?? episodesData?.releaseDate ?? (widget.year != null ? widget.year.toString() : ''));

    final String realReleaseDate = formatDisplayDate(rawDate);

    final String realBadges = (currentEp?.quality != null && currentEp!.quality!.isNotEmpty)
        ? currentEp.quality!
        : 'Sub | Dob';

    final String realCertification = (widget.certification != null &&
            widget.certification!.isNotEmpty &&
            widget.certification != 'NR')
        ? widget.certification!.toUpperCase()
        : '16+';

    final bool isBookmarked = ref.watch(favoritesProvider).any((f) => f.id == widget.contentId || f.title == seriesTitle);

    // Calcular episodio siguiente y anterior con metadatos reales
    EpisodeInfo? nextEp;
    EpisodeInfo? prevEp;

    for (final ep in epList) {
      if (ep.number == currentEpNum + 1) nextEp = ep;
      if (ep.number == currentEpNum - 1) prevEp = ep;
    }

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullscreen) {
          _toggleFullscreen();
        }
      },
      child: _isFullscreen
          ? Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  _buildEmbeddedPlayer(),
                ],
              ),
            )
          : Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  seriesTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              body: AdaptiveWatchLayout(
                // Reproductor embebido 16:9 real
                playerWidget: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildEmbeddedPlayer(),
                ),

                // Metadatos Reales
                metadataWidget: WatchEpisodeMetadata(
                  seriesTitle: seriesTitle,
                  episodeTitle: realEpTitle,
                  episodeNumber: epNumStr,
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

                // Reacciones
                actionBarWidget: WatchActionBar(
                  likeCount: '${(_likeCount / 1000).toStringAsFixed(1)}K',
                  dislikeCount: '$_dislikeCount',
                  isLiked: _isLiked,
                  isDisliked: _isDisliked,
                  onLikePressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      if (_isLiked) {
                        _likeCount++;
                        if (_isDisliked) {
                          _isDisliked = false;
                          _dislikeCount--;
                        }
                      } else {
                        _likeCount--;
                      }
                    });
                  },
                  onDislikePressed: () {
                    setState(() {
                      _isDisliked = !_isDisliked;
                      if (_isDisliked) {
                        _dislikeCount++;
                        if (_isLiked) {
                          _isLiked = false;
                          _likeCount--;
                        }
                      } else {
                        _dislikeCount--;
                      }
                    });
                  },
                  onSharePressed: () {},
                ),

                // Sinopsis Real
                synopsisWidget: WatchSynopsis(
                  synopsis: realSynopsis,
                ),

                // Siguiente Episodio Real
                nextEpisodeWidget: nextEp != null
                    ? WatchNavCard(
                        sectionLabel: 'Siguiente Episodio',
                        episodeNumber: 'E${nextEp.number}',
                        episodeTitle: (nextEp.title != null && nextEp.title!.isNotEmpty) ? nextEp.title! : 'Episodio ${nextEp.number}',
                        thumbnailUrl: nextEp.thumbnail ?? widget.bannerUrl,
                        duration: nextEp.duration ?? (nextEp.runtime != null ? '${nextEp.runtime}m' : '24m'),
                        audioSubsBadge: nextEp.quality ?? 'Sub | Dob',
                        onTap: () => _switchEpisode(nextEp!),
                      )
                    : const SizedBox.shrink(),

                // Episodio Anterior Real
                previousEpisodeWidget: prevEp != null
                    ? WatchNavCard(
                        sectionLabel: 'Episodio Anterior',
                        episodeNumber: 'E${prevEp.number}',
                        episodeTitle: (prevEp.title != null && prevEp.title!.isNotEmpty) ? prevEp.title! : 'Episodio ${prevEp.number}',
                        thumbnailUrl: prevEp.thumbnail ?? widget.bannerUrl,
                        duration: prevEp.duration ?? (prevEp.runtime != null ? '${prevEp.runtime}m' : '24m'),
                        audioSubsBadge: prevEp.quality ?? 'Sub | Dob',
                        onTap: () => _switchEpisode(prevEp!),
                      )
                    : const SizedBox.shrink(),

                // Cola lateral para Web/Tablet
                playlistSidebarWidget: epList.isNotEmpty
                    ? WatchPlaylistSidebar(
                        episodes: epList,
                        activeEpisode: widget.episode ?? '1',
                        onEpisodeSelected: (ep) => _switchEpisode(ep),
                      )
                    : null,
              ),
            ),
    );
  }
}
