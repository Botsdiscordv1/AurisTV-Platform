import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:auris_core/auris_core.dart';

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
  });

  final String sourceUrl;
  final String source;
  final String? category;
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

  @override
  ConsumerState<CleanEmbeddedPlayer> createState() => _CleanEmbeddedPlayerState();
}

class _CleanEmbeddedPlayerState extends ConsumerState<CleanEmbeddedPlayer> {
  Player? _player;
  VideoController? _videoController;
  Timer? _hideControlsTimer;

  bool _showControls = false;
  bool _isPlaying = false;
  bool _isBuffering = true;
  bool _hasLoadedFirstFrame = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  double _volume = 100.0;
  bool _isVolumeHovered = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _player = Player();
    _videoController = VideoController(_player!);

    _setupListeners();
    _loadSource();
  }

  void _setupListeners() {
    _player?.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing) _hasLoadedFirstFrame = true;
        });
      }
    });

    _player?.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _player?.stream.position.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
          if (pos.inMilliseconds > 0) _hasLoadedFirstFrame = true;
        });
      }
    });

    _player?.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _player?.stream.completed.listen((completed) {
      if (completed && widget.onEpisodeEnd != null) {
        widget.onEpisodeEnd!();
      }
    });
  }

  void _loadSource() {
    if (widget.sourceUrl.isNotEmpty) {
      _player?.open(Media(widget.sourceUrl));
    }
  }

  @override
  void didUpdateWidget(CleanEmbeddedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourceUrl != oldWidget.sourceUrl) {
      _loadSource();
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
      _player?.setVolume(val);
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isInitialLoading = !_hasLoadedFirstFrame && !_isPlaying && _position.inMilliseconds == 0;

    return MouseRegion(
      onHover: (_) {
        if (!_showControls) _toggleControls();
      },
      child: GestureDetector(
        onTap: () {
          if (!isInitialLoading) {
            if (_isPlaying) {
              _player?.pause();
            } else {
              _player?.play();
            }
            _toggleControls();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Capa de Video real
            if (_videoController != null)
              Video(
                controller: _videoController!,
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
                                  _player?.seek(Duration(seconds: value.toInt()));
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
                                      // Play / Pause
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            if (_isPlaying) {
                                              _player?.pause();
                                            } else {
                                              _player?.play();
                                            }
                                            _startHideTimer();
                                          },
                                          borderRadius: BorderRadius.circular(18),
                                          hoverColor: Colors.white.withOpacity(0.15),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.08),
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
                                      const SizedBox(width: 6),

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
                                      const SizedBox(width: 4),

                                      // Volume pill (hover expandable)
                                      MouseRegion(
                                        onEnter: (_) => setState(() => _isVolumeHovered = true),
                                        onExit: (_) => setState(() => _isVolumeHovered = false),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          height: 34,
                                          width: _isVolumeHovered ? 130 : 34,
                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(17),
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

                                      // Time Duration Badge
                                      Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.35),
                                          borderRadius: BorderRadius.circular(16),
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
                                        onTap: widget.onQualityPressed,
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
                                              const Icon(
                                                Icons.settings_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
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
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
