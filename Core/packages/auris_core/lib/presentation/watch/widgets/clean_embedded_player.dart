import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:auris_core/auris_core.dart';

enum SettingsView { main, speed, sleepTimer, quality }

/// Reproductor de Video Embebido para WatchScreen en Web Desktop.
/// 
/// Controles rediseñados en cápsula flotante:
/// - Play/Pausa, Anterior/Siguiente episodio, Control de volumen hover.
/// - Badge de tiempo transcurrido / total y cápsula "En este video >".
/// - Botones de Subtítulos, Calidad con badge HD, Lista de Episodios y Pantalla Completa.
class CleanEmbeddedPlayer extends ConsumerStatefulWidget {
  const CleanEmbeddedPlayer({
    super.key,
    required this.sourceUrl,
    required this.source,
    this.category,
    this.headers = const {},
    this.contentId,
    this.title,
    this.episode,
    this.season,
    this.posterUrl,
    this.bannerUrl,
    this.detailUrl,
    this.episodeTitle,
    this.startPosition,
    this.onExpandPressed,
    this.onEpisodeEnd,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.hasPrevious = false,
    this.hasNext = false,
    this.episodeLabel,
    this.onEpisodesPressed,
    this.onQualityPressed,
    this.onSubtitlesPressed,
    this.isTheaterMode = false,
    this.onTheaterModeToggle,
    this.isAmbientLightingEnabled = true,
    this.onAmbientLightingToggle,
    this.currentQualityLabel,
    this.currentSubtitleLabel,
    this.hasQualityOptions = true,
    this.onBack,
  });

  final VoidCallback? onBack;

  final String sourceUrl;
  final String source;
  final String? category;
  final Map<String, String> headers;
  final String? contentId;
  final String? title;
  final String? episode;
  final int? season;
  final String? posterUrl;
  final String? bannerUrl;
  final String? detailUrl;
  final String? episodeTitle;
  final int? startPosition;
  final VoidCallback? onExpandPressed;
  final VoidCallback? onEpisodeEnd;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final bool hasPrevious;
  final bool hasNext;
  final String? episodeLabel;
  final VoidCallback? onEpisodesPressed;
  final VoidCallback? onQualityPressed;
  final VoidCallback? onSubtitlesPressed;
  final bool isTheaterMode;
  final VoidCallback? onTheaterModeToggle;
  final bool isAmbientLightingEnabled;
  final ValueChanged<bool>? onAmbientLightingToggle;
  final String? currentQualityLabel;
  final String? currentSubtitleLabel;
  final bool hasQualityOptions;

  @override
  ConsumerState<CleanEmbeddedPlayer> createState() => _CleanEmbeddedPlayerState();
}

class _CleanEmbeddedPlayerState extends ConsumerState<CleanEmbeddedPlayer> {
  Timer? _hideControlsTimer;
  StreamSubscription? _posSub;
  StreamSubscription? _playSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _durSub;
  StreamSubscription? _compSub;

  bool _showControls = false;
  bool _isPlaying = false;
  // ignore: unused_field
  bool _isBuffering = true;
  bool _hasLoadedFirstFrame = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // --- Resume state ---
  int _pendingResumeMs = 0;
  bool _resumeApplied = false;

  double _volume = 100.0;
  bool _isVolumeHovered = false;

  // --- Floating Settings Panel State ---
  bool _showSettingsPanel = false;
  SettingsView _settingsView = SettingsView.main;
  late bool _isAmbientLightingEnabled;
  double _playbackSpeed = 1.0;
  Timer? _sleepTimer;
  int _sleepTimerMinutes = 0;
  String _sleepTimerLabel = 'No';

  // --- Quality options state ---
  List<QualityOption> _discoveredQualities = [];
  String _currentSelectedQuality = 'auto';
  String? _masterStreamUrl;

  @override
  void initState() {
    super.initState();
    _isAmbientLightingEnabled = widget.isAmbientLightingEnabled;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initPlayerAndSource();
    });
  }

  void _initPlayerAndSource() {
    final notifier = ref.read(activePlayerProvider.notifier);
    notifier.initPlayerIfNeeded();
    notifier.setUiState(PlayerUIState.full);

    final active = ref.read(activePlayerProvider);
    final player = active.player;

    if (player != null) {
      // Comparar tanto el episodio como la serie y la URL para decidir si reutilizar.
      // Si el episodio es distinto al que tiene el active player, NO se reutiliza (es un cambio de episodio)
      final bool isSameContent = active.currentItem?.id == (widget.contentId ?? widget.title) ||
          active.currentItem?.title == widget.title;
      final bool isSameEp = active.episode == widget.episode;
      final bool isActivelyPlaying = player.state.playing || 
          player.state.position.inMilliseconds > 0;
      
      final bool isSameStream = active.url == widget.sourceUrl && isActivelyPlaying;
      
      if (isSameContent && isSameEp && (isSameStream || isActivelyPlaying)) {
        setState(() {
          _position = player.state.position;
          if (player.state.duration > Duration.zero) {
            _duration = player.state.duration;
          }
          _isPlaying = player.state.playing;
          if (_position.inMilliseconds > 0 || _isPlaying) {
            _hasLoadedFirstFrame = true;
          }
        });
        _setupListeners(player);
        return;
      }
    }

    _loadSource();
  }

  void _setupListeners(Player player) {
    _playSub?.cancel();
    _playSub = player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing) _hasLoadedFirstFrame = true;
        });
      }
    });

    _bufSub?.cancel();
    _bufSub = player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _posSub?.cancel();
    _posSub = player.stream.position.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        if (pos.inMilliseconds > 0) _hasLoadedFirstFrame = true;
      });

      if (!_resumeApplied && _pendingResumeMs > 3000) {
        final dur = player.state.duration;
        if (dur > Duration.zero) {
          _resumeApplied = true;
          player.seek(Duration(milliseconds: _pendingResumeMs));
        }
      }

      if (pos.inSeconds > 0 && pos.inSeconds % 5 == 0 && _duration.inSeconds > 0) {
        _updateHistory(pos.inMilliseconds, _duration.inMilliseconds);
      }
    });

    _durSub?.cancel();
    if (player.state.duration > Duration.zero) {
      _duration = player.state.duration;
    }
    _durSub = player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);

      if (!_resumeApplied && _pendingResumeMs > 3000 && dur > Duration.zero) {
        _resumeApplied = true;
        player.seek(Duration(milliseconds: _pendingResumeMs));
      }
    });

    _compSub?.cancel();
    _compSub = player.stream.completed.listen((completed) {
      if (completed && widget.onEpisodeEnd != null) {
        widget.onEpisodeEnd!();
      }
    });
  }

  Future<void> _loadSource() async {
    if (widget.sourceUrl.isEmpty) return;

    final notifier = ref.read(activePlayerProvider.notifier);
    notifier.initPlayerIfNeeded();

    final String seriesTitle = widget.title ?? widget.contentId ?? 'AurisTV Content';
    final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(
          seriesTitle,
          widget.season ?? 1,
          widget.episode ?? '1',
        );
    final int resumeMs = widget.startPosition ?? (hist?.positionInMilliseconds ?? 0);
    final bool shouldResume = resumeMs > 3000 && !(hist?.isCompleted ?? false);

    if (shouldResume) {
      _pendingResumeMs = resumeMs;
      _resumeApplied = false;
    } else {
      _pendingResumeMs = 0;
      _resumeApplied = true;
    }

    setState(() {
      _hasLoadedFirstFrame = false;
      _position = Duration.zero;
    });

    _masterStreamUrl = widget.sourceUrl;
    _parseHlsVariantsIfNeeded(widget.sourceUrl, widget.headers);

    await notifier.play(
      item: MediaItem(
        id: seriesTitle,
        title: seriesTitle,
        posterUrl: widget.posterUrl ?? widget.bannerUrl ?? '',
        bannerUrl: widget.bannerUrl,
        detailUrl: widget.detailUrl ?? widget.sourceUrl,
        type: widget.category == 'movie' ? MediaType.movie : MediaType.series,
      ),
      url: widget.sourceUrl,
      episode: widget.episode ?? '1',
      season: widget.season ?? 1,
      source: widget.source,
      episodeTitle: widget.episodeTitle,
      headers: widget.headers,
    );

    final player = ref.read(activePlayerProvider).player;
    if (player != null) {
      _setupListeners(player);
    }
  }

  void _updateHistory(int posMs, int durMs) {
    if (posMs <= 0 || durMs <= 0) return;
    final String seriesTitle = widget.title ?? widget.contentId ?? 'AurisTV Content';
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
          url: widget.detailUrl ?? widget.sourceUrl,
          episodeTitle: widget.episodeTitle,
        );
  }

  @override
  void didUpdateWidget(CleanEmbeddedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourceUrl != oldWidget.sourceUrl) {
      _loadSource();
    }
  }

  Future<void> _parseHlsVariantsIfNeeded(String url, Map<String, String> headers) async {
    if (!HlsVariantParser.isHlsUrl(url)) {
      if (mounted) {
        setState(() {
          _discoveredQualities = [];
          _currentSelectedQuality = 'auto';
        });
      }
      return;
    }

    try {
      final qualities = await HlsVariantParser.parseFromUrl(url, headers: headers);
      if (mounted) {
        setState(() {
          _discoveredQualities = qualities;
        });
      }
    } catch (_) {}
  }

  Future<void> _changeQuality(String qualityKey) async {
    if (_currentSelectedQuality == qualityKey) return;

    final player = ref.read(activePlayerProvider).player;
    if (player == null) return;

    String? targetUrl;
    Map<String, String> targetHeaders = widget.headers;

    if (qualityKey == 'auto') {
      targetUrl = _masterStreamUrl ?? widget.sourceUrl;
    } else {
      final match = _discoveredQualities.firstWhereOrNull((q) => q.key == qualityKey);
      if (match != null) {
        targetUrl = match.url;
        if (match.headers.isNotEmpty) {
          targetHeaders = match.headers;
        }
      }
    }

    if (targetUrl == null || targetUrl.isEmpty) return;

    final currentPosition = player.state.position;
    setState(() {
      _currentSelectedQuality = qualityKey;
      _showSettingsPanel = false;
      _settingsView = SettingsView.main;
    });

    try {
      await player.open(Media(targetUrl, httpHeaders: targetHeaders));
      if (currentPosition > Duration.zero) {
        await player.seek(currentPosition);
      }
      await player.play();
    } catch (e) {
      debugPrint('[CleanEmbeddedPlayer] _changeQuality error: $e');
    }
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

  void _setVolume(double val) {
    setState(() {
      _volume = val;
      ref.read(activePlayerProvider).player?.setVolume(val);
    });
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _hideControlsTimer?.cancel();
    _posSub?.cancel();
    _playSub?.cancel();
    _bufSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activePlayerProvider);
    final player = active.player;
    final controller = active.controller ??
        (player != null
            ? VideoController(
                player,
                configuration: const VideoControllerConfiguration(
                  androidAttachSurfaceAfterVideoParameters: false,
                ),
              )
            : null);

    final bool isInitialLoading = !_hasLoadedFirstFrame && !_isPlaying && _position.inMilliseconds == 0;

    return MouseRegion(
      onHover: (_) {
        if (!_showControls) _toggleControls();
      },
      child: GestureDetector(
        onTap: () {
          if (!isInitialLoading) {
            if (_isPlaying) {
              player?.pause();
            } else {
              player?.play();
            }
            _toggleControls();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Capa de Video real
            if (controller != null)
              Video(
                controller: controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              )
            else
              Container(color: Colors.black),

            // 2. Fase de Carga Inicial
            if (isInitialLoading)
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
                ),
              ),

            // 3. Overlay de Controles Rediseñado para Web Desktop
            AnimatedOpacity(
              opacity: (_showControls && !isInitialLoading) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !(_showControls && !isInitialLoading),
                child: Stack(
                  children: [
                    // Botón Back superior izquierdo si está provisto (espejo de móvil)
                    if (widget.onBack != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onBack,
                            borderRadius: BorderRadius.circular(20),
                            hoverColor: Colors.white.withValues(alpha: 0.15),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.40),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Gradiente sutil únicamente en la parte inferior tras los controles
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.65),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Barra Inferior de Controles Completa (Estilo Web Desktop)
                    Positioned(
                      left: widget.isTheaterMode ? 28 : 16,
                      right: widget.isTheaterMode ? 28 : 16,
                      bottom: widget.isTheaterMode ? 14 : 12,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Slider de Tiempo
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
                                  player?.seek(Duration(seconds: value.toInt()));
                                  _startHideTimer();
                                },
                              ),
                            ),
                            const SizedBox(height: 4),

                            // 2. Fila de Controles (Play, Prev, Next, Volume, Time, Chapter | CC, Settings HD, List, Fullscreen)
                            SizedBox(
                              height: 48,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // GRUPO IZQUIERDO
                                  Row(
                                    children: [
                                      // 1. Cápsula Play / Pause
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            if (_isPlaying) {
                                              player?.pause();
                                            } else {
                                              player?.play();
                                            }
                                            _startHideTimer();
                                          },
                                          borderRadius: BorderRadius.circular(18),
                                          hoverColor: Colors.white.withValues(alpha: 0.15),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.20),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: AurisIcon(
                                                _isPlaying ? AurisIcons.customPause : AurisIcons.customPlay,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // 2. Cápsula Prev / Next
                                      Container(
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.20),
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Previous Episode
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              icon: AurisIcon(
                                                AurisIcons.customPrev,
                                                color: (widget.hasPrevious || widget.onPreviousEpisode != null) ? Colors.white : Colors.white30,
                                                size: 20,
                                              ),
                                              onPressed: (widget.hasPrevious || widget.onPreviousEpisode != null)
                                                  ? () {
                                                      widget.onPreviousEpisode?.call();
                                                      _startHideTimer();
                                                    }
                                                  : null,
                                            ),
                                            const SizedBox(width: 2),
                                            // Next Episode
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                              icon: AurisIcon(
                                                AurisIcons.customNext,
                                                color: (widget.hasNext || widget.onNextEpisode != null) ? Colors.white : Colors.white30,
                                                size: 20,
                                              ),
                                              onPressed: (widget.hasNext || widget.onNextEpisode != null)
                                                  ? () {
                                                      widget.onNextEpisode?.call();
                                                      _startHideTimer();
                                                    }
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // 3. Cápsula Volume (hover expandable)
                                      MouseRegion(
                                        onEnter: (_) => setState(() => _isVolumeHovered = true),
                                        onExit: (_) => setState(() => _isVolumeHovered = false),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          height: 36,
                                          width: _isVolumeHovered ? 130 : 36,
                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.20),
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: Row(
                                            children: [
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                                icon: AurisIcon(
                                                  AurisIcons.customVolume,
                                                  color: _volume == 0 ? Colors.white38 : Colors.white,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  if (_volume > 0) {
                                                    _setVolume(0);
                                                  } else {
                                                    _setVolume(100);
                                                  }
                                                },
                                              ),
                                              if (_isVolumeHovered)
                                                Expanded(
                                                  child: SliderTheme(
                                                    data: const SliderThemeData(
                                                      trackHeight: 2.5,
                                                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4),
                                                      activeTrackColor: Color(0xFFEF7A1E),
                                                      inactiveTrackColor: Colors.white24,
                                                      thumbColor: Color(0xFFEF7A1E),
                                                    ),
                                                    child: Slider(
                                                      value: _volume,
                                                      min: 0,
                                                      max: 100,
                                                      onChanged: (val) => _setVolume(val),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // 4. Cápsula Time Duration Badge
                                      Container(
                                        height: 36,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.20),
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // GRUPO DERECHO
                                  Row(
                                    children: [
                                      // Subtitles / CC
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(
                                          Icons.subtitles_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: widget.onSubtitlesPressed,
                                        tooltip: 'Subtítulos',
                                      ),
                                      const SizedBox(width: 4),

                                      // Settings Gear with HD Badge
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            _showSettingsPanel = !_showSettingsPanel;
                                            _settingsView = SettingsView.main;
                                          });
                                          _startHideTimer();
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        hoverColor: Colors.white.withOpacity(0.12),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            clipBehavior: Clip.none,
                                            children: [
                                              Icon(
                                                Icons.settings_rounded,
                                                color: _showSettingsPanel ? const Color(0xFFEF7A1E) : Colors.white,
                                                size: 20,
                                              ),
                                              if (widget.hasQualityOptions)
                                                Positioned(
                                                  top: -2,
                                                  right: -4,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE50914),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'HD',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 7,
                                                        fontWeight: FontWeight.w900,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),

                                      // Episodes Drawer button
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(
                                          Icons.format_list_bulleted_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: widget.onEpisodesPressed,
                                        tooltip: 'Episodios',
                                      ),
                                      const SizedBox(width: 4),

                                      // Modo Teatro / Expandir
                                      if (widget.onTheaterModeToggle != null) ...[
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: AurisIcon(
                                            AurisIcons.expandir,
                                            color: widget.isTheaterMode ? const Color(0xFFEF7A1E) : Colors.white,
                                            size: 20,
                                          ),
                                          onPressed: widget.onTheaterModeToggle,
                                          tooltip: widget.isTheaterMode ? 'Restaurar tamaño' : 'Modo Teatro (Expandir)',
                                        ),
                                        const SizedBox(width: 4),
                                      ],

                                      // Fullscreen Expand
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: AurisIcon(
                                          AurisIcons.customFullscreen,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        onPressed: widget.onExpandPressed,
                                        tooltip: 'Pantalla Completa',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Panel Flotante de Configuración (Settings Popover)
                      _buildFloatingSettingsPanel(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSettingsPanel() {
    if (!_showSettingsPanel) return const SizedBox.shrink();

    return Positioned(
      bottom: widget.isTheaterMode ? 72 : 68,
      right: widget.isTheaterMode ? 28 : 16,
      width: 310,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_settingsView == SettingsView.main) ...[
                // 1. Iluminación cinematográfica
                _buildSettingsTile(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Iluminación cinematográfica',
                  trailing: SizedBox(
                    height: 24,
                    child: Switch.adaptive(
                      value: _isAmbientLightingEnabled,
                      activeColor: const Color(0xFFEF7A1E),
                      onChanged: (val) {
                        setState(() => _isAmbientLightingEnabled = val);
                        widget.onAmbientLightingToggle?.call(val);
                      },
                    ),
                  ),
                ),

                // 2. Subtítulos
                _buildSettingsTile(
                  icon: Icons.subtitles_outlined,
                  title: 'Subtítulos',
                  trailingText: widget.currentSubtitleLabel ?? 'Español - es',
                  onTap: () {
                    setState(() => _showSettingsPanel = false);
                    widget.onSubtitlesPressed?.call();
                  },
                ),

                // 3. Temporizador de apagado
                _buildSettingsTile(
                  icon: Icons.nights_stay_outlined,
                  title: 'Temporizador de apagado',
                  trailingText: _sleepTimerLabel,
                  onTap: () {
                    setState(() => _settingsView = SettingsView.sleepTimer);
                  },
                ),

                // 4. Velocidad de reproducción
                _buildSettingsTile(
                  icon: Icons.speed_rounded,
                  title: 'Velocidad de reproducción',
                  trailingText: _playbackSpeed == 1.0 ? 'Normal' : '${_playbackSpeed}x',
                  onTap: () {
                    setState(() => _settingsView = SettingsView.speed);
                  },
                ),

                // 5. Calidad (si está habilitado o se detectaron variantes HLS)
                if (widget.hasQualityOptions || _discoveredQualities.isNotEmpty)
                  _buildSettingsTile(
                    icon: Icons.tune_rounded,
                    title: 'Calidad',
                    trailingText: _currentSelectedQuality == 'auto'
                        ? 'Automática'
                        : (_discoveredQualities.firstWhereOrNull((q) => q.key == _currentSelectedQuality)?.label ?? _currentSelectedQuality),
                    onTap: () {
                      if (_discoveredQualities.isNotEmpty) {
                        setState(() => _settingsView = SettingsView.quality);
                      } else {
                        setState(() => _showSettingsPanel = false);
                        widget.onQualityPressed?.call();
                      }
                    },
                  ),
              ] else if (_settingsView == SettingsView.quality) ...[
                _buildSubMenuHeader(
                  title: 'Calidad de video',
                  onBack: () => setState(() => _settingsView = SettingsView.main),
                ),
                _buildSubMenuOption(
                  label: 'Automática (Recomendada)',
                  isSelected: _currentSelectedQuality == 'auto',
                  onTap: () => _changeQuality('auto'),
                ),
                ..._discoveredQualities.map((quality) {
                  final bool isSelected = _currentSelectedQuality == quality.key;
                  final String sub = quality.bandwidth != null ? ' (${(quality.bandwidth! / 1000).round()} kbps)' : '';
                  return _buildSubMenuOption(
                    label: '${quality.label}$sub',
                    isSelected: isSelected,
                    onTap: () => _changeQuality(quality.key),
                  );
                }),
              ] else if (_settingsView == SettingsView.speed) ...[
                _buildSubMenuHeader(
                  title: 'Velocidad de reproducción',
                  onBack: () => setState(() => _settingsView = SettingsView.main),
                ),
                ...[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                  final bool isSelected = _playbackSpeed == speed;
                  return _buildSubMenuOption(
                    label: speed == 1.0 ? 'Normal' : '${speed}x',
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _playbackSpeed = speed;
                        _settingsView = SettingsView.main;
                      });
                      final player = ref.read(activePlayerProvider).player;
                      player?.setRate(speed);
                    },
                  );
                }),
              ] else if (_settingsView == SettingsView.sleepTimer) ...[
                _buildSubMenuHeader(
                  title: 'Temporizador de apagado',
                  onBack: () => setState(() => _settingsView = SettingsView.main),
                ),
                ...[
                  {'label': 'Desactivado', 'minutes': 0},
                  {'label': '10 minutos', 'minutes': 10},
                  {'label': '15 minutos', 'minutes': 15},
                  {'label': '30 minutos', 'minutes': 30},
                  {'label': '45 minutos', 'minutes': 45},
                  {'label': '60 minutos', 'minutes': 60},
                ].map((item) {
                  final String label = item['label'] as String;
                  final int minutes = item['minutes'] as int;
                  final bool isSelected = _sleepTimerMinutes == minutes;

                  return _buildSubMenuOption(
                    label: label,
                    isSelected: isSelected,
                    onTap: () {
                      _setSleepTimer(minutes, label);
                    },
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _setSleepTimer(int minutes, String label) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerMinutes = minutes;
      _sleepTimerLabel = minutes == 0 ? 'No' : label;
      _settingsView = SettingsView.main;
    });

    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        if (mounted) {
          final player = ref.read(activePlayerProvider).player;
          player?.pause();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Temporizador de apagado finalizado. Reproducción pausada.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.08),
      splashColor: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else if (trailingText != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailingText,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 18,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMenuHeader({
    required String title,
    required VoidCallback onBack,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(color: Colors.white.withOpacity(0.1), height: 12),
      ],
    );
  }

  Widget _buildSubMenuOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFEF7A1E) : Colors.white,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: Color(0xFFEF7A1E), size: 18),
          ],
        ),
      ),
    );
  }
}
