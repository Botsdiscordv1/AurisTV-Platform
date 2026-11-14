import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/foundation.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/pip_service.dart';
import '../../cast/presentation/widgets/cast_picker_sheet.dart';
import '../../player/presentation/mobile_video_surface.dart';

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
    this.synopsis,
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
  final String? synopsis;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  Timer? _hideControlsTimer;
  String _lastOpenedUrl = '';
  StreamSubscription? _posSubscription;
  StreamSubscription? _playSubscription;
  StreamSubscription? _bufSubscription;
  StreamSubscription? _durSubscription;
  StreamSubscription? _completedSub;

  bool _showControls = false;
  bool _isPlaying = false;
  bool _isCompleted = false;
  // ignore: unused_field
  bool _isBuffering = true;
  bool _hasLoadedFirstFrame = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // --- Resume state ---
  int _pendingResumeMs = 0;
  bool _resumeApplied = false;

  // --- Seek stabilization (Bug 2) ---
  bool _isSeeking = false;
  Timer? _seekTimeoutTimer;

  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 20412;
  int _dislikeCount = 142;

  // Ajustes Estilo YouTube (Modo Ambiente, Temporizador, Velocidad, Calidad)
  final GlobalKey _embeddedVideoKey = GlobalKey();
  int _sleepTimerMinutes = 0;
  Timer? _sleepTimer;
  bool _isMinimizing = false;
  int _visibleEpisodesLimit = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final active = ref.read(activePlayerProvider);
      ref.read(activePlayerProvider.notifier).initPlayerIfNeeded();
      ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.full);
      _setupPlayerListeners();

      // Si venimos del MiniPlayer para el mismo contenido/episodio, recuperar el estado
      final bool isSameContent = active.currentItem?.id == widget.contentId ||
          active.currentItem?.title == (widget.title ?? widget.metadataTitle);
      final bool isSameEp = active.episode == widget.episode;
      if (isSameContent && isSameEp && active.player != null) {
        final pos = active.player!.state.position;
        final dur = active.player!.state.duration;
        final playing = active.player!.state.playing;
        setState(() {
          _position = pos;
          if (dur > Duration.zero) _duration = dur;
          _isPlaying = playing;
          if (pos.inMilliseconds > 0 || playing) {
            _hasLoadedFirstFrame = true;
          }
        });
      }
    });
  }

  void _setupPlayerListeners() {
    final active = ref.read(activePlayerProvider);
    final player = active.player;
    if (player == null) return;

    _playSubscription?.cancel();
    _playSubscription = player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing) {
            _hasLoadedFirstFrame = true;
          }
        });
      }
    });

    _bufSubscription?.cancel();
    _bufSubscription = player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      // Bug 2 fix: si estamos en medio de un seek manual, NO mostramos el
      // spinner de buffering; el _seekTimeoutTimer lo limpiará en 2.5 s.
      if (_isSeeking) return;
      setState(() => _isBuffering = buffering);
    });

    _posSubscription?.cancel();
    _posSubscription = player.stream.position.listen((pos) {
      if (!mounted) return;

      // Bug 2 fix: cuando la posición avanza después de un seek, apagamos el
      // flag de seek y cancelamos el timeout de seguridad.
      if (_isSeeking && pos.inMilliseconds > 0) {
        _seekTimeoutTimer?.cancel();
        _isSeeking = false;
        if (mounted) setState(() => _isBuffering = false);
      }

      setState(() {
        if (!_isSeeking) _position = pos;
        if (pos.inMilliseconds > 0) _hasLoadedFirstFrame = true;
      });

      // Bug 1 fix: aplicar resume pendiente en cuanto el demuxer reporta
      // duración > 0 (pipeline lista). Solo se aplica una vez por carga.
      if (!_resumeApplied && _pendingResumeMs > 3000) {
        final dur = player.state.duration;
        if (dur > Duration.zero) {
          _resumeApplied = true;
          final target = Duration(milliseconds: _pendingResumeMs);
          debugPrint('[WatchScreen] Resume seek → ${_pendingResumeMs}ms (dur=${dur.inSeconds}s)');
          player.seek(target);
        }
      }

      // Guardar progreso en el historial cada 5 segundos de reproducción
      if (pos.inSeconds > 0 && pos.inSeconds % 5 == 0 && _duration.inSeconds > 0) {
        _updateHistory(pos.inMilliseconds, _duration.inMilliseconds);
      }
    });

    _durSubscription?.cancel();
    if (player.state.duration > Duration.zero) {
      _duration = player.state.duration;
    }
    _durSubscription = player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);

      // Bug 1 fix: en cuanto llega la duración real (demuxer listo), aplicamos
      // el resume pendiente si aún no se aplicó desde el listener de posición.
      if (!_resumeApplied && _pendingResumeMs > 3000 && dur > Duration.zero) {
        _resumeApplied = true;
        final target = Duration(milliseconds: _pendingResumeMs);
        debugPrint('[WatchScreen] Resume seek (dur trigger) → ${_pendingResumeMs}ms');
        player.seek(target);
      }
    });

    _completedSub?.cancel();
    _completedSub = player.stream.completed.listen((completed) {
      if (!mounted) return;
      setState(() {
        _isCompleted = completed;
        if (completed) {
          _isPlaying = false;
          _showControls = true;
        }
      });
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

  void _skipOpEd() {
    final active = ref.read(activePlayerProvider);
    final current = active.player?.state.position ?? _position;
    final target = current + const Duration(seconds: 85);
    active.player?.seek(target);
    _startHideTimer();
    _updateHistory(
      target.inMilliseconds,
      active.player?.state.duration.inMilliseconds ?? _duration.inMilliseconds,
    );
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
        DeviceOrientation.portraitUp,
      ]);
    }
    _startHideTimer();
  }

  void _navigateToFullscreen() {
    final active = ref.read(activePlayerProvider);
    final int currentPosMs = active.player?.state.position.inMilliseconds ?? _position.inMilliseconds;

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

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _seekTimeoutTimer?.cancel();
    _posSubscription?.cancel();
    _playSubscription?.cancel();
    _bufSubscription?.cancel();
    _durSubscription?.cancel();
    _completedSub?.cancel();
    _sleepTimer?.cancel();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }

    // Si el usuario eligió minimizar explícitamente, pasar a miniplayer.
    // De lo contrario (Back normal), detener y cerrar el reproductor completamente.
    try {
      final active = ref.read(activePlayerProvider);
      final bool inPip = PipService.isPipMode.value;
      if (_isMinimizing || inPip) {
        if (active.player?.state.playing == true) {
          ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.mini);
        }
      } else {
        if (!inPip) {
          ref.read(activePlayerProvider.notifier).stop();
        }
      }
    } catch (_) {}

    super.dispose();
  }

  /// Minimiza el reproductor hacia el MiniPlayer global voluntariamente y vuelve atrás.
  void _minimizeToMiniPlayer() {
    _isMinimizing = true;
    try {
      ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.mini);
    } catch (_) {}
    if (mounted) {
      context.pop();
    }
  }

  Future<void> _cargarEpisodioHlsSeguro(String urlStream, Map<String, String> headers) async {
    try {
      final notifier = ref.read(activePlayerProvider.notifier);
      notifier.initPlayerIfNeeded();

      final String seriesTitle = widget.title ?? widget.metadataTitle ?? widget.contentId;
      final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(
        seriesTitle,
        widget.season ?? 1,
        widget.episode ?? '1',
      );
      final int resumeMs = widget.startPosition ?? (hist?.positionInMilliseconds ?? 0);
      final bool shouldResume = resumeMs > 3000 && !(hist?.isCompleted ?? false);

      // Bug 1 fix: guardamos la posición pendiente ANTES de llamar a play().
      // Los listeners en _setupPlayerListeners() aplicarán el seek en cuanto
      // el demuxer reporte duration > 0 (pipeline lista). Así nunca se hace
      // un seek a ciegas sobre un pipeline sin inicializar.
      if (shouldResume) {
        _pendingResumeMs = resumeMs;
        _resumeApplied = false;
      } else {
        _pendingResumeMs = 0;
        _resumeApplied = true; // nada que aplicar
      }

      // Inyección automática de cabeceras de seguridad Referer / User-Agent para Streamtape, Voe, etc.
      final Map<String, String> effectiveHeaders = Map.from(headers);
      if (urlStream.contains('streamtape.com')) {
        effectiveHeaders['Referer'] = 'https://streamtape.com/';
        effectiveHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      } else if (urlStream.contains('voe.sx')) {
        effectiveHeaders['Referer'] = 'https://voe.sx/';
        effectiveHeaders['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      }

      await notifier.play(
        item: MediaItem(
          id: seriesTitle,
          title: seriesTitle,
          posterUrl: widget.posterUrl ?? widget.bannerUrl ?? '',
          bannerUrl: widget.bannerUrl,
          detailUrl: widget.sourceUrl,
          type: widget.category == 'movie' ? MediaType.movie : MediaType.series,
        ),
        url: urlStream,
        episode: widget.episode ?? '1',
        season: widget.season ?? 1,
        source: widget.source,
        episodeTitle: widget.episodeTitle,
        headers: effectiveHeaders,
      );

      _setupPlayerListeners();

      // Ya no llamamos seek aquí; lo hace _setupPlayerListeners cuando el
      // stream de duration/position emite su primer valor real.
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
    final String targetUrl = ep.url.isNotEmpty
        ? ep.url
        : buildEpisodeUrl(widget.sourceUrl, widget.source, ep.number);

    setState(() {
      _hasLoadedFirstFrame = false;
      _showControls = false;
      _lastOpenedUrl = '';
      _position = Duration.zero;
      _pendingResumeMs = 0;
      _resumeApplied = false;
    });

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
    final active = ref.read(activePlayerProvider);
    final target = _position - const Duration(seconds: 10);
    final clamped = target < Duration.zero ? Duration.zero : target;
    _performSeek(active, clamped);
  }

  void _fastForward10() {
    final active = ref.read(activePlayerProvider);
    final target = _position + const Duration(seconds: 10);
    final maxDur = _duration > Duration.zero ? _duration : const Duration(hours: 10);
    final clamped = target > maxDur ? maxDur : target;
    _performSeek(active, clamped);
  }

  /// Bug 2 fix: seek robusto compartido por slider, +10/-10 y drag.
  /// - Actualiza la UI de forma optimista.
  /// - Activa _isSeeking para silenciar el spinner de buffering durante el seek.
  /// - Arranca un timeout de seguridad de 2.5 s por si el stream de position
  ///   no llega (HLS: algunos segments tardan más).
  void _performSeek(dynamic active, Duration target) {
    setState(() {
      _position = target;
      _isSeeking = true;
      _isBuffering = false; // no mostrar spinner mientras esperamos
    });
    active.player?.seek(target);
    _seekTimeoutTimer?.cancel();
    _seekTimeoutTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() { _isSeeking = false; _isBuffering = false; });
    });
    _startHideTimer();
  }

  void _showSettingsSheet() {
    final active = ref.read(activePlayerProvider);
    final String currentSpeedLabel = '${(active.player?.state.rate ?? 1.0)}x';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF212121),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Pill Handle (YouTube Style)
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ajustes de Reproducción',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // 1. Velocidad de Reproducción
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.speed_outlined, color: Colors.white, size: 22),
                      title: const Text('Velocidad de reproducción', style: TextStyle(color: Colors.white, fontSize: 15)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(currentSpeedLabel, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _showSpeedSheet();
                      },
                    ),

                    // 2. Modo Ambiente (Switch sincronizado con settingsProvider)
                    SwitchListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      secondary: const Icon(Icons.vignette_outlined, color: Colors.white, size: 22),
                      title: const Text('Modo ambiente', style: TextStyle(color: Colors.white, fontSize: 15)),
                      activeThumbColor: const Color(0xFFEF7A1E),
                      activeTrackColor: const Color(0xFFEF7A1E).withValues(alpha: 0.5),
                      value: ref.watch(settingsProvider.select((s) => s.ambientModeEnabled)),
                      onChanged: (val) {
                        setSheetState(() {});
                        ref.read(settingsProvider.notifier).setAmbientModeEnabled(val);
                      },
                    ),

                    // 3. Temporizador de Apagado
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.bedtime_outlined, color: Colors.white, size: 22),
                      title: const Text('Temporizador de apagado', style: TextStyle(color: Colors.white, fontSize: 15)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sleepTimerMinutes > 0 ? '${_sleepTimerMinutes}m' : 'Desactivado',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(bottomSheetContext);
                        _showSleepTimerSheet();
                      },
                    ),

                    const Divider(color: Colors.white12, height: 1),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: Text(
                        'AurisTV Player Engine',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSpeedSheet() {
    final active = ref.read(activePlayerProvider);
    final presetRows = [
      [0.25, 0.5, 0.75, 1.0, 1.25],
      [1.5, 1.75, 2.0, 2.5, 3.0],
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF212121),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSpeedState) {
            final double currentRate = active.player?.state.rate ?? 1.0;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.speed_outlined, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${currentRate.toStringAsFixed(currentRate % 1 == 0 ? 1 : 2)}x',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...presetRows.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: row.map((r) {
                            final bool isSel = (currentRate - r).abs() < 0.01;
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                active.player?.setRate(r);
                                setSpeedState(() {});
                                setState(() {});
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFEF7A1E) : Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${r}x',
                                  style: TextStyle(
                                    color: isSel ? Colors.black : Colors.white,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSleepTimerSheet() {
    final options = [
      {'minutes': 0, 'label': 'Desactivado'},
      {'minutes': 15, 'label': '15 minutos'},
      {'minutes': 30, 'label': '30 minutos'},
      {'minutes': 45, 'label': '45 minutos'},
      {'minutes': 60, 'label': '60 minutos'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF212121),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Temporizador de Apagado', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...options.map((opt) {
                  final int mins = opt['minutes'] as int;
                  final String label = opt['label'] as String;
                  final bool isSelected = _sleepTimerMinutes == mins;

                  return ListTile(
                    leading: SizedBox(
                      width: 24,
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                    title: Text(label, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    onTap: () {
                      _sleepTimer?.cancel();
                      setState(() => _sleepTimerMinutes = mins);
                      if (mins > 0) {
                        _sleepTimer = Timer(Duration(minutes: mins), () {
                          final active = ref.read(activePlayerProvider);
                          active.player?.pause();
                          if (mounted) setState(() => _sleepTimerMinutes = 0);
                        });
                      }
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmbeddedPlayer() {
    final active = ref.watch(activePlayerProvider);
    final String currentSourceLower = (widget.source.toLowerCase()) + (widget.serverName?.toLowerCase() ?? '');
    final bool isZillaHls = currentSourceLower.contains('zilla') &&
        (_lastOpenedUrl.contains('.m3u8') || _lastOpenedUrl.contains('/hls/'));

    final bool useSurface = VideoSurfaceConfig.nativeAndroidSurface &&
        isZillaHls &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android;

    final controller = useSurface
        ? null
        : (active.controller ??
            (active.player != null
                ? VideoController(
                    active.player!,
                    configuration: const VideoControllerConfiguration(
                      androidAttachSurfaceAfterVideoParameters: false,
                    ),
                  )
                : null));

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
          // Capa de Video real: SurfaceView exclusivo para ZILLA HLS, Textura para todo lo demás
          if (useSurface && active.player != null)
            RepaintBoundary(
              key: _embeddedVideoKey,
              child: FittedMobileVideoSurface(
                player: active.player!,
                onSurface: (viewId, wid, width, height) {
                  unawaited(NativeVideoSurfaceBinder.attach(
                    player: active.player!,
                    viewId: viewId,
                    wid: wid,
                    width: width,
                    height: height,
                  ));
                },
                onSurfaceDestroyed: (viewId, wid) {
                  unawaited(NativeVideoSurfaceBinder.detach(
                    active.player!,
                    viewId: viewId,
                    wid: wid,
                  ));
                },
              ),
            )
          else if (controller != null)
            RepaintBoundary(
              key: _embeddedVideoKey,
              child: Video(
                controller: controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
            )
          else
            Container(color: Colors.black),

          // 1. Fase de Carga Inicial Única (Spinner sobre el video)
          if (isInitialLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
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
                              _isCompleted
                                  ? AurisIcons.restart
                                  : (_isPlaying ? AurisIcons.pauseFilled : AurisIcons.playFilled),
                              color: const Color(0xFFEF7A1E),
                              size: 38,
                            ),
                            onPressed: () {
                              final active = ref.read(activePlayerProvider);
                              if (_isCompleted) {
                                setState(() {
                                  _isCompleted = false;
                                  _position = Duration.zero;
                                  _isPlaying = true;
                                });
                                active.player?.seek(Duration.zero);
                                active.player?.play();
                              } else if (_isPlaying) {
                                active.player?.pause();
                              } else {
                                active.player?.play();
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

                    // Botón Atrás en la esquina superior izquierda (Dentro del Reproductor)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            onPressed: () {
                              if (_isFullscreen) {
                                _toggleFullscreen();
                              } else {
                                context.pop();
                              }
                            },
                          ),
                          if (_isFullscreen) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${widget.title ?? widget.metadataTitle ?? "AurisTV"} - ${widget.episodeTitle ?? "Episodio ${widget.episode ?? "1"}"}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Botones Cast, Miniplayer y Ajustes en la Esquina Superior Derecha
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Botón MiniPlayer / Picture-in-Picture voluntario
                          if (!_isFullscreen)
                            IconButton(
                              icon: const Icon(Icons.picture_in_picture_alt_outlined, color: Colors.white, size: 22),
                              tooltip: 'Minimizar',
                              onPressed: _minimizeToMiniPlayer,
                            ),
                          IconButton(
                            icon: AurisIcon(AurisIcons.cast, color: Colors.white, size: 22),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => const CastPickerSheet(),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                            onPressed: _showSettingsSheet,
                          ),
                        ],
                      ),
                    ),

                    // Cápsula "Saltar OP/ED" (Fondo negro con opacidad 20% y bordes redondeados)
                    Positioned(
                      left: 12,
                      bottom: 30,
                      child: InkWell(
                        onTap: _skipOpEd,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AurisIcon(
                                AurisIcons.fastForward,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Saltar OP/ED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Botón Circular de Pantalla Completa (Navega a PlayerScreen)
                    Positioned(
                      right: 12,
                      bottom: 30,
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

                    // Barra Inferior: Tiempo y Slider de Progreso Pegados al Borde
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 0),
                            child: Text(
                              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SliderTheme(
                            data: const SliderThemeData(
                              trackHeight: 2,
                              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4.5),
                              overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                              activeTrackColor: Color(0xFFEF7A1E),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Color(0xFFEF7A1E),
                            ),
                            child: Slider(
                              value: _position.inSeconds.toDouble().clamp(0, (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble()),
                              max: (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble(),
                              onChangeStart: (_) {
                                // Iniciar modo seek: silencia el buffering listener durante el arrastre
                                setState(() => _isSeeking = true);
                                _seekTimeoutTimer?.cancel();
                              },
                              onChanged: (value) {
                                // Solo actualizar UI (preview optimista), sin llamar seek()
                                final target = Duration(seconds: value.toInt());
                                setState(() => _position = target);
                                _startHideTimer();
                              },
                              onChangeEnd: (value) {
                                // Seek real solo al soltar el slider
                                final target = Duration(seconds: value.toInt());
                                final active = ref.read(activePlayerProvider);
                                _performSeek(active, target);
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
          : (extractRes.tracks.firstOrNull?.url ?? '');
      final Map<String, String> resolvedHeaders = extractRes.headers.isNotEmpty
          ? extractRes.headers
          : (extractRes.tracks.firstOrNull?.headers ?? const {});

      if (resolvedUrl.isNotEmpty && _lastOpenedUrl != resolvedUrl) {
        _lastOpenedUrl = resolvedUrl;

        // Si el player ya está activo reproduciendo esta misma URL (ej: venimos del MiniPlayer)
        final active = ref.read(activePlayerProvider);
        final bool isAlreadyPlayingThisStream = active.url == resolvedUrl &&
            active.player != null &&
            (active.player!.state.playing || active.player!.state.position.inMilliseconds > 0);

        if (isAlreadyPlayingThisStream) {
          final activeDur = active.player!.state.duration;
          setState(() {
            _hasLoadedFirstFrame = true;
            _position = active.player!.state.position;
            if (activeDur > Duration.zero) _duration = activeDur;
            _isPlaying = active.player!.state.playing;
          });
          return;
        }

        setState(() {
          _hasLoadedFirstFrame = false;
          _showControls = false;
          _position = Duration.zero;
        });
        final bool isHls = resolvedUrl.contains('.m3u8') || resolvedUrl.contains('/hls/');
        debugPrint('====================================================');
        debugPrint('[WatchScreen STREAM LOG] Fuente/Servidor: ${widget.source} (${widget.serverName ?? ""})');
        debugPrint('[WatchScreen STREAM LOG] URL Stream: $resolvedUrl');
        debugPrint('[WatchScreen STREAM LOG] HLS = $isHls');
        debugPrint('====================================================');

        // Senior Fix (Riverpod 2.x): modificar providers dentro de build() está prohibido.
        // Usar Future.microtask para retrasar la carga después de que el árbol de widgets
        // termine de construirse.
        Future.microtask(() {
          if (!mounted) return;
          _cargarEpisodioHlsSeguro(resolvedUrl, resolvedHeaders);
        });
      }
    });

    // Senior Fix (SSE): ref.listen para capturar CADA evento SSE del StreamProvider
    // y actualizar activePlayerProvider con los tracks acumulados. Sin esto, cuando
    // llegan más streams después del primero, los tracks se ignoran y el reproductor
    // fullscreen no los ve.
    ref.listen(extractStreamProvider(ExtractParams(
      url: widget.sourceUrl,
      source: widget.source,
      category: widget.category,
    )), (prev, next) {
      if (!mounted) return;
      next.whenData((result) {
        final playableTracks = result.tracks.where((t) => !t.isDownload).toList();
        final prevCount = prev?.value?.tracks.where((t) => !t.isDownload).length ?? 0;
        if (playableTracks.length > prevCount) {
          debugPrint('[WatchScreen SSE] Tracks actualizados: $prevCount → ${playableTracks.length}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(activePlayerProvider.notifier).updateSession(tracks: playableTracks);
          });
        }
      });
    });

    final bool isMovie = isMovieLike(widget.category, seriesTitle);

    // Consultar lista de episodios de la serie desde el provider de datos reales (solo para series)
    final EpisodesResponse? episodesData = isMovie
        ? null
        : ref.watch(episodesProvider(EpisodesParams(
            url: widget.sourceUrl,
            source: widget.source,
            category: widget.category,
            title: seriesTitle,
            season: widget.season,
          ))).valueOrNull;

    final List<EpisodeInfo> epList = isMovie ? const [] : (episodesData?.episodes ?? []);
    final EpisodeInfo? currentEp = isMovie ? null : epList.firstWhereOrNull((ep) => ep.number == currentEpNum);

    // Metadata Real del Episodio/Película Activo
    final String realEpTitle = isMovie
        ? (widget.episodeTitle ?? seriesTitle)
        : ((currentEp?.title != null && currentEp!.title!.isNotEmpty)
            ? currentEp.title!
            : (widget.episodeTitle ?? 'Episodio $currentEpNum'));

    final String realSynopsis = isMovie
        ? (widget.synopsis ?? 'Disfruta de $seriesTitle con la mejor calidad en AurisTV.')
        : ((currentEp?.description != null && currentEp!.description!.isNotEmpty)
            ? currentEp.description!
            : 'Sigue las aventuras de $seriesTitle en este episodio $realEpTitle con la mejor calidad en AurisTV.');

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

    // Calcular episodio siguiente con metadatos reales (solo para series)
    EpisodeInfo? nextEp;

    if (!isMovie) {
      for (final ep in epList) {
        if (ep.number == currentEpNum + 1) nextEp = ep;
      }
    }

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isFullscreen) {
          _toggleFullscreen();
        } else if (didPop) {
          try {
            if (_isMinimizing) {
              final active = ref.read(activePlayerProvider);
              if (active.player?.state.playing == true) {
                Future.microtask(() {
                  ref.read(activePlayerProvider.notifier).setUiState(PlayerUIState.mini);
                });
              }
            } else {
              ref.read(activePlayerProvider.notifier).stop();
            }
          } catch (_) {}
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
              body: SafeArea(
                bottom: false,
                // Modo Ambiente: CinematicAmbientLighting envuelve TODO el body
                // para que el glow se proyecte sobre el fondo negro de la pantalla
                // sin ser clippeado por el AspectRatio del reproductor.
                child: Builder(builder: (context) {
                  final layout = AdaptiveWatchLayout(
                    playerWidget: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildEmbeddedPlayer(),
                    ),
                    metadataWidget: WatchEpisodeMetadata(
                      seriesTitle: seriesTitle,
                      episodeTitle: realEpTitle,
                      episodeNumber: isMovie ? 'Película' : epNumStr,
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
                    synopsisWidget: WatchSynopsis(
                      synopsis: realSynopsis,
                    ),
                    nextEpisodeWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ocultar Siguiente Episodio si la lista in-line fue desplegada (_visibleEpisodesLimit > 0)
                        if (nextEp != null && _visibleEpisodesLimit == 0)
                          WatchNavCard(
                            sectionLabel: 'Siguiente Episodio',
                            episodeNumber: 'E${nextEp.number}',
                            episodeTitle: (nextEp.title != null && nextEp.title!.isNotEmpty) ? nextEp.title! : 'Episodio ${nextEp.number}',
                            thumbnailUrl: nextEp.thumbnail ?? widget.bannerUrl,
                            duration: nextEp.duration ?? (nextEp.runtime != null ? '${nextEp.runtime}m' : '24m'),
                            audioSubsBadge: nextEp.quality ?? 'Sub | Dob',
                            onTap: () => _switchEpisode(nextEp!),
                          ),

                        // Lista In-Line de Episodios Paginada de 28 en 28
                        if (_visibleEpisodesLimit > 0 && epList.isNotEmpty) ...[
                          Padding(
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: AurisIcon(
                                      AurisIcons.chevronUp,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...epList.take(_visibleEpisodesLimit).map((ep) {
                            final bool isCurrent = ep.number.toString() == widget.episode;
                            final String epTitle = (ep.title != null && ep.title!.isNotEmpty) ? ep.title! : 'Episodio ${ep.number}';
                            final String durationStr = ep.duration ?? (ep.runtime != null ? '${ep.runtime}m' : '24m');
                            final String qualityStr = ep.quality ?? 'Sub | Dob';
                            final String thumbUrl = ep.thumbnail ?? widget.bannerUrl ?? widget.posterUrl ?? '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _switchEpisode(ep),
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
                                            border: Border.all(color: Colors.white12, width: 0.5),
                                            image: thumbUrl.isNotEmpty
                                                ? DecorationImage(image: NetworkImage(thumbUrl), fit: BoxFit.cover)
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
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFEF7A1E),
                                                      borderRadius: BorderRadius.circular(3),
                                                    ),
                                                    child: const Text(
                                                      'REPRODUCIENDO',
                                                      style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                                                    ),
                                                  ),
                                                ),
                                              Positioned(
                                                right: 6,
                                                bottom: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black87,
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                  child: Text(
                                                    durationStr,
                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                                            'E${ep.number} - $epTitle',
                                            style: TextStyle(
                                              color: isCurrent ? const Color(0xFFEF7A1E) : Colors.white,
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
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
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

                        // Botón VER MÁS EPISODIOS (Suma 28 episodios a la lista in-line cada vez)
                        if (_visibleEpisodesLimit < epList.length) ...[
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
                                  _visibleEpisodesLimit == 0 ? 'VER MÁS EPISODIOS' : 'VER MÁS EPISODIOS (${epList.length - _visibleEpisodesLimit})',
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
                    ),
                    previousEpisodeWidget: const SizedBox.shrink(),
                    playlistSidebarWidget: epList.isNotEmpty
                        ? WatchPlaylistSidebar(
                            episodes: epList,
                            activeEpisode: widget.episode ?? '1',
                            onEpisodeSelected: (ep) => _switchEpisode(ep),
                          )
                        : null,
                  );

                  final bool isAmbientEnabled = ref.watch(settingsProvider.select((s) => s.ambientModeEnabled));
                  if (isAmbientEnabled) {
                    final Color posterColor = extractAmbientColorFromTitle(
                      widget.title ?? widget.metadataTitle ?? widget.contentId,
                    );
                    return CinematicAmbientLighting(
                      player: ref.watch(activePlayerProvider).player,
                      posterColor: posterColor,
                      heightMultiplier: 1.0,
                      percentageFromTop: 0.15,
                      intensity: 0.65,
                      child: layout,
                    );
                  }
                  return layout;
                }),
              ),
            ),
    );
  }
}
