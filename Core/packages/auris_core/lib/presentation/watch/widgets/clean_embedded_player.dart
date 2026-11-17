import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:auris_core/auris_core.dart';

import 'ambient_glow.dart';
import '../ambient_video_provider.dart';
import '../../../core/utils/video_ambient.dart';
import 'package:auris_core/core/config/brand_colors.dart';

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
    this.cinematicAmbient = false,
    this.onBack,
    this.showBackButton,
    this.video720,
    this.video1080,
  });

  final VoidCallback? onBack;
  final bool? showBackButton;
  final String? video720;
  final String? video1080;

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

  /// Activa la variante "cinemática" del modo ambiente, la que YouTube usa en
  /// pantalla completa: el arte difuminado rellena todo el escenario (barras
  /// negras incluidas) al 40 % de opacidad. Si es `false` se usa la variante
  /// del player embebido, más tenue y solo en los bordes.
  final bool cinematicAmbient;

  @override
  ConsumerState<CleanEmbeddedPlayer> createState() => _CleanEmbeddedPlayerState();
}

class _CleanEmbeddedPlayerState extends ConsumerState<CleanEmbeddedPlayer> {
  Timer? _hideControlsTimer;
  StreamSubscription? _posSub;
  StreamSubscription? _playSub;
  StreamSubscription? _bufSub;
  StreamSubscription? _bufferProgressSub;
  StreamSubscription? _durSub;
  StreamSubscription? _compSub;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  int? _videoWidth;
  int? _videoHeight;

  bool _showControls = false;
  bool _isPlaying = false;
  bool _isCompleted = false;
  bool _isBuffering = false;
  bool _isDraggingSlider = false;
  double _dragPositionSeconds = 0.0;
  bool _hasLoadedFirstFrame = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _bufferProgress = Duration.zero;

  // --- Resume state ---
  int _pendingResumeMs = 0;
  bool _resumeApplied = false;

  double _volume = 100.0;
  double _lastNonZeroVolume = 100.0;
  bool _isVolumeHovered = false;
  bool _isVolumeDragging = false;
  bool _isTimeHovered = false;
  bool _showRemainingTime = false;

  // --- Floating Settings Panel State ---
  bool _showSettingsPanel = false;
  SettingsView _settingsView = SettingsView.main;
  late bool _isAmbientLightingEnabled;
  double _playbackSpeed = 1.0;
  Timer? _sleepTimer;
  Timer? _ambientTimer;
  int _ambientSequence = 0;
  int _sleepTimerMinutes = 0;
  String _sleepTimerLabel = 'No';

  // --- 2x Speed Hold & Skip OP/ED State ---
  bool _isHolding2x = false;
  double _preHoldSpeed = 1.0;
  bool _wasPlayingBeforeHold = false;
  Timer? _holdTimer;
  bool _isSkipOpEdHovered = false;

  // --- Focus Node para atajos de teclado Web Desktop ---
  final FocusNode _focusNode = FocusNode();

  // --- Quality options state ---
  List<QualityOption> _discoveredQualities = [];
  String _currentSelectedQuality = 'auto';
  String? _masterStreamUrl;

  @override
  void initState() {
    super.initState();
    _isAmbientLightingEnabled = widget.isAmbientLightingEnabled;
    if (kIsWeb) {
      // Modo ambiente con los colores del video que se está reproduciendo.
      // YouTube refresca cada ~5,05 s, pero con su canvas de 2× de alto el atraso
      // no se nota. Acá el halo es fino y 5 s de atraso se leía como una imagen
      // fija, así que se refresca cada 2 s.
      _ambientTimer = Timer.periodic(
        const Duration(milliseconds: 2000),
        (_) => _sampleAmbient(),
      );
      // Primera muestra apenas haya frame, sin esperar el primer tick.
      Timer(const Duration(milliseconds: 1200), _sampleAmbient);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
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
          _bufferProgress = player.state.buffer;
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

  void _handlePlayReplay(Player? player) {
    if (_isCompleted) {
      player?.seek(Duration.zero);
      player?.play();
      setState(() => _isCompleted = false);
    } else if (_isPlaying) {
      player?.pause();
    } else {
      player?.play();
    }
    _startHideTimer();
  }

  void _setupListeners(Player player) {
    _playSub?.cancel();
    _playSub = player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
          if (playing) {
            _hasLoadedFirstFrame = true;
            _isCompleted = false;
          }
        });
      }
    });

    _bufSub?.cancel();
    _bufSub = player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _bufferProgressSub?.cancel();
    _bufferProgressSub = player.stream.buffer.listen((buf) {
      if (mounted) setState(() => _bufferProgress = buf);
    });

    _posSub?.cancel();
    _posSub = player.stream.position.listen((pos) {
      if (!mounted) return;
      if (!_isDraggingSlider) {
        setState(() {
          _position = pos;
          if (pos.inMilliseconds > 0) _hasLoadedFirstFrame = true;

          if (_duration > Duration.zero) {
            if (pos >= _duration - const Duration(milliseconds: 500)) {
              _isCompleted = true;
            } else if (pos < _duration - const Duration(seconds: 1) && _isCompleted) {
              _isCompleted = false;
            }
          }
        });
      }

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
      if (mounted) setState(() => _isCompleted = completed);
      if (completed && widget.onEpisodeEnd != null) {
        widget.onEpisodeEnd!();
      }
    });

    // Dimensiones reales del video: definen dónde quedan las barras negras y,
    // por lo tanto, dónde puede vivir la iluminación cinematográfica.
    _widthSub?.cancel();
    _widthSub = player.stream.width.listen((w) {
      if (!mounted || w == null || w <= 0 || w == _videoWidth) return;
      setState(() => _videoWidth = w);
    });
    _heightSub?.cancel();
    _heightSub = player.stream.height.listen((h) {
      if (!mounted || h == null || h <= 0 || h == _videoHeight) return;
      setState(() => _videoHeight = h);
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
    final bool isOpEd = widget.source == 'Themes' || widget.sourceUrl.contains('animethemes.moe') || widget.video720 != null || widget.video1080 != null;
    if (isOpEd) {
      final List<QualityOption> opEdQualities = [];
      if (widget.video1080 != null && widget.video1080!.isNotEmpty) {
        opEdQualities.add(QualityOption(key: '1080', label: '1080p FHD', url: widget.video1080!));
      }
      if (widget.video720 != null && widget.video720!.isNotEmpty) {
        opEdQualities.add(QualityOption(key: '720', label: '720p HD', url: widget.video720!));
      }
      if (mounted) {
        setState(() {
          _discoveredQualities = opEdQualities;
        });
      }
    } else {
      _parseHlsVariantsIfNeeded(widget.sourceUrl, widget.headers);
    }

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

    final bool isOpEd = widget.source == 'Themes' || widget.sourceUrl.contains('animethemes.moe') || widget.video720 != null || widget.video1080 != null;

    if (qualityKey == 'auto') {
      targetUrl = _masterStreamUrl ?? widget.sourceUrl;
    } else if (isOpEd) {
      targetUrl = qualityKey == '720' ? widget.video720 : qualityKey == '1080' ? widget.video1080 : null;
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
      _volume = val.clamp(0.0, 100.0);
      if (_volume > 0) {
        _lastNonZeroVolume = _volume;
      }
      ref.read(activePlayerProvider).player?.setVolume(_volume);
    });
  }

  void _toggleMute() {
    if (_volume > 0) {
      _setVolume(0);
    } else {
      _setVolume(_lastNonZeroVolume > 0 ? _lastNonZeroVolume : 100);
    }
    _startHideTimer();
  }

  void _skipOpEd() {
    final player = ref.read(activePlayerProvider).player;
    if (player == null) return;
    final current = player.state.position;
    final duration = player.state.duration;
    final target = current + const Duration(seconds: 85);
    if (duration > Duration.zero && target > duration) {
      player.seek(duration);
    } else {
      player.seek(target);
    }
    _startHideTimer();
  }

  void _setHold2x(bool holding) {
    if (_isHolding2x == holding) return;
    final player = ref.read(activePlayerProvider).player;
    if (mounted) {
      setState(() {
        _isHolding2x = holding;
        if (holding) {
          _wasPlayingBeforeHold = player?.state.playing ?? false;
          // Guardar la velocidad real del player (no solo la del selector) para restaurarla al soltar.
          _preHoldSpeed = player?.state.rate ?? _playbackSpeed;
          if (!_wasPlayingBeforeHold) {
            player?.play();
          }
          player?.setRate(2.0);
        } else {
          player?.setRate(_preHoldSpeed);
          if (!_wasPlayingBeforeHold) {
            player?.pause();
          }
        }
      });
    }
  }

  void _seekToPercent(double percent) {
    final player = ref.read(activePlayerProvider).player;
    if (_duration.inMilliseconds > 0) {
      final targetMs = (_duration.inMilliseconds * percent).toInt();
      player?.seek(Duration(milliseconds: targetMs));
      _startHideTimer();
      _toggleControls();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final player = ref.read(activePlayerProvider).player;

    if (key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        _holdTimer?.cancel();
        _holdTimer = Timer(const Duration(milliseconds: 250), () {
          _setHold2x(true);
        });
        return KeyEventResult.handled;
      } else if (event is KeyRepeatEvent) {
        if (!_isHolding2x) {
          _setHold2x(true);
        }
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        _holdTimer?.cancel();
        if (_isHolding2x) {
          _setHold2x(false);
        } else {
          if (_isPlaying) {
            player?.pause();
          } else {
            player?.play();
          }
          _toggleControls();
        }
        return KeyEventResult.handled;
      }
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.keyK) {
      if (_isPlaying) {
        player?.pause();
      } else {
        player?.play();
      }
      _toggleControls();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyF) {
      widget.onExpandPressed?.call();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyT) {
      widget.onTheaterModeToggle?.call();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      final newSec = (_position.inSeconds - 10).clamp(0, _duration.inSeconds);
      player?.seek(Duration(seconds: newSec));
      _startHideTimer();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
      final newSec = (_position.inSeconds + 10).clamp(0, _duration.inSeconds);
      player?.seek(Duration(seconds: newSec));
      _startHideTimer();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _setVolume((_volume + 10).clamp(0, 100));
      _startHideTimer();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _setVolume((_volume - 10).clamp(0, 100));
      _startHideTimer();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyN) {
      if (widget.hasNext || widget.onNextEpisode != null) {
        widget.onNextEpisode?.call();
        _startHideTimer();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyP) {
      if (widget.hasPrevious || widget.onPreviousEpisode != null) {
        widget.onPreviousEpisode?.call();
        _startHideTimer();
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      player?.seek(Duration.zero);
      _startHideTimer();
      _toggleControls();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _seekToPercent(0.1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _seekToPercent(0.2);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _seekToPercent(0.3);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _seekToPercent(0.4);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      _seekToPercent(0.5);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      _seekToPercent(0.6);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      _seekToPercent(0.7);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      _seekToPercent(0.8);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      _seekToPercent(0.9);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Muestrea el frame actual del `<video>` y publica la paleta para las capas
  /// del modo ambiente (watch, embebido, teatro y fullscreen).
  void _sampleAmbient() {
    // Sin depender de `_isPlaying`: si el video está pausado (o el autoplay
    // quedó bloqueado) igual hay un frame en el `<video>` y el modo ambiente debe
    // mostrar ese frame, no el póster del episodio.
    if (!mounted) return;
    final bytes = sampleVideoAmbientFrame();
    if (bytes == null || bytes.isEmpty) return;

    _ambientSequence++;
    ref.read(ambientVideoProvider.notifier).state = AmbientFrame(
      bytes: bytes,
      sequence: _ambientSequence,
    );
  }

  @override
  void dispose() {
    _ambientTimer?.cancel();
    _holdTimer?.cancel();
    _focusNode.dispose();
    _sleepTimer?.cancel();
    _hideControlsTimer?.cancel();
    _posSub?.cancel();
    _playSub?.cancel();
    _bufSub?.cancel();
    _bufferProgressSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
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
    final bool isTabletOrDesktop = MediaQuery.sizeOf(context).width >= 768;
    final bool shouldShowEmbedBack = widget.onBack != null &&
        (widget.showBackButton ?? !isTabletOrDesktop);
    final bool isTheme = widget.source == 'Themes' ||
        widget.source == 'YouTube' ||
        widget.sourceUrl.contains('animethemes.moe');
    final bool isTabletOrMobile = MediaQuery.sizeOf(context).width < 1024;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(node, event),
      child: MouseRegion(
        onHover: (_) {
          if (!_showControls) _toggleControls();
        },
        child: GestureDetector(
          onTap: () {
            if (_isHolding2x) return;
            if (!isInitialLoading) {
              _handlePlayReplay(player);
              _toggleControls();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 0. Resplandor de Luz Ambiental (Ambilight)
              _buildAmbientLightingOverlay(),

              // 1. Capa de Video real
              controller != null
                  ? Positioned.fill(
                      // El video se ajusta a su relación de aspecto real: así el
                      // `<video>` nunca queda con barras negras propias y el
                      // espacio sobrante de la tarjeta lo rellena la capa
                      // ambiente.
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _videoAspect,
                          child: Video(
                            controller: controller,
                            controls: NoVideoControls,
                            fit: BoxFit.contain,
                            // `fill` pinta TODO el viewport (negro por defecto en
                            // media_kit) y tapaba la capa ambiente en las barras.
                            // Transparente deja ver el arte difuminado detrás.
                            fill: Colors.transparent,
                          ),
                        ),
                      ),
                    )
                  : const Positioned.fill(
                      child: ColoredBox(color: Colors.black),
                    ),

              // 2. Fase de Carga Inicial
              isInitialLoading
                  ? Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(color: AurisPalette.brand),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),

              // 3. Overlay de Controles Rediseñado para Web Desktop
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: (_showControls && !isInitialLoading) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !(_showControls && !isInitialLoading),
                    child: Stack(
                      fit: StackFit.expand,
                      children  : [
                      // Botón Back superior izquierdo (sólo si no hay WatchTopBar activo)
                      if (shouldShowEmbedBack)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onBack,
                              borderRadius: BorderRadius.circular(20),
                              hoverColor: Colors.white.withValues(alpha: 0.08),
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
                      // Gradiente Superior sutil (sólo si el botón back embebido está activo)
                      if (shouldShowEmbedBack)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 72,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.60),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // --- Center Play/Pause & Seek -10s / +10s Controls (Mobile / Tablet) ---
                      if (isTabletOrMobile)
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // -10s Button
                              IconButton(
                                onPressed: () {
                                  final newSec = (_position.inSeconds - 10).clamp(0, _duration.inSeconds);
                                  player?.seek(Duration(seconds: newSec));
                                  _startHideTimer();
                                },
                                icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.50),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(width: 24),

                              // Play / Pause Button
                              IconButton(
                                onPressed: () {
                                  _handlePlayReplay(player);
                                },
                                icon: AurisIcon(
                                  _isCompleted ? AurisIcons.ytReplay : (_isPlaying ? AurisIcons.pause : AurisIcons.play),
                                  color: Colors.white,
                                  size: _isCompleted ? 52 : 38,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.50),
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(width: 24),

                              // +10s Button
                              IconButton(
                                onPressed: () {
                                  final newSec = (_position.inSeconds + 10).clamp(0, _duration.inSeconds);
                                  player?.seek(Duration(seconds: newSec));
                                  _startHideTimer();
                                },
                                icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.50),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                        ),

                    // =====================================================================
                    // YouTube Web Desktop Official Chrome Controls (.ytp-chrome-controls)
                    // Con Cápsulas Delhi Modern Frosted Glass (ytp-delhi-modern)
                    // =====================================================================
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- 1. ytp-progress-bar-container (Timeline Slider con _YouTubeSliderTrackShape) ---
                          Padding(
                            // 8 px entre el timeline y las cápsulas (referencia de
                            // YouTube en el watch: unified_seek_player_edge_padding).
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                            child: _HoverableTimeline(
                              sliderTheme: const SliderThemeData(
                                trackHeight: 4.5,
                                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8.0),
                                overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
                                activeTrackColor: AurisPalette.brand,
                                inactiveTrackColor: Colors.transparent,
                                thumbColor: AurisPalette.brand,
                                overlayColor: Colors.transparent,
                              ),
                              value: _isDraggingSlider
                                  ? _dragPositionSeconds.clamp(0.0, (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble())
                                  : _position.inSeconds.toDouble().clamp(
                                        0.0,
                                        (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble(),
                                      ),
                              max: (_duration.inSeconds > 0 ? _duration.inSeconds : 1).toDouble(),
                              buffer: _bufferProgress,
                              duration: _duration,
                              onChangeStart: (value) {
                                setState(() {
                                  _isDraggingSlider = true;
                                  _dragPositionSeconds = value;
                                });
                              },
                              onChanged: (value) {
                                setState(() {
                                  _dragPositionSeconds = value;
                                });
                                _startHideTimer();
                              },
                              onChangeEnd: (value) {
                                player?.seek(Duration(seconds: value.toInt()));
                                setState(() {
                                  _isDraggingSlider = false;
                                });
                                _startHideTimer();
                              },
                            ),
                          ),
                          

                          // --- 2. ytp-chrome-controls (Height 64px, Web Desktop Proporciones Ampliadas) ---
                          SizedBox(
                            height: 56,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // =========================================================
                                // ytp-left-controls (Play Circle Pill, Nav Pill, Time Pill)
                                // =========================================================
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1. ytp-play-button (Circular 40px Frosted Glass Capsule)
                                    if (!isTabletOrMobile)
                                      ClipOval(
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: const BoxDecoration(
                                            color: Color(0x4D000000),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Material(
                                            color: Colors.transparent,
                                            shape: const CircleBorder(),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () {
                                                _handlePlayReplay(player);
                                              },
                                              hoverColor: Colors.white.withValues(alpha: 0.08),
                                              child: SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: Center(
                                                  child: AurisIcon(
                                                    _isCompleted ? AurisIcons.ytReplay : (_isPlaying ? AurisIcons.pause : AurisIcons.play),
                                                    color: Colors.white,
                                                    size: _isCompleted ? 30 : 22,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (isTabletOrDesktop)
                                      const SizedBox(width: 8),

                                    // 2. ytp-prev-button & ytp-next-button (Navigation Frosted Glass Pill 46px)
                                    if (isTabletOrDesktop) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          height: 40,
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0x4D000000),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Previous Button
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                                                style: IconButton.styleFrom(
                                                  hoverColor: Colors.white.withValues(alpha: 0.08),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                ),
                                                icon: AurisIcon(
                                                  AurisIcons.backwardStep,
                                                  color: (widget.hasPrevious || widget.onPreviousEpisode != null)
                                                      ? Colors.white
                                                      : Colors.white30,
                                                  size: 22,
                                                ),
                                                onPressed: (widget.hasPrevious || widget.onPreviousEpisode != null)
                                                    ? () {
                                                        widget.onPreviousEpisode?.call();
                                                        _startHideTimer();
                                                      }
                                                    : null,
                                                tooltip: 'Anterior',
                                              ),
                                              const SizedBox(width: 2),

                                              // Next Button
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                                                style: IconButton.styleFrom(
                                                  hoverColor: Colors.white.withValues(alpha: 0.08),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                ),
                                                icon: AurisIcon(
                                                  AurisIcons.forwardStep,
                                                  color: (widget.hasNext || widget.onNextEpisode != null)
                                                      ? Colors.white
                                                      : Colors.white30,
                                                  size: 22,
                                                ),
                                                onPressed: (widget.hasNext || widget.onNextEpisode != null)
                                                    ? () {
                                                        widget.onNextEpisode?.call();
                                                        _startHideTimer();
                                                      }
                                                    : null,
                                                tooltip: 'Siguiente',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],

                                    // 3. ytp-volume-area (Official YouTube Standalone Volume Capsule 40px)
                                    if (!isTabletOrMobile) ...[
                                      MouseRegion(
                                        onEnter: (_) => setState(() => _isVolumeHovered = true),
                                        onExit: (_) => setState(() => _isVolumeHovered = false),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween<double>(
                                              begin: 40.0,
                                              end: (_isVolumeHovered || _isVolumeDragging) ? 122.0 : 40.0,
                                            ),
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeInOutCubic,
                                            builder: (context, width, _) {
                                            return ClipRect(
                                              child: Container(
                                                width: width,
                                                height: 40.0,
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0x4D000000),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: OverflowBox(
                                                  minWidth: 0,
                                                  maxWidth: 114.0,
                                                  alignment: Alignment.centerLeft,
                                                  child: Stack(
                                                    alignment: Alignment.centerLeft,
                                                    children: [
                                                      if (_isVolumeHovered || _isVolumeDragging)
                                                        Positioned.fill(
                                                          child: Center(
                                                            child: Container(
                                                              height: 32,
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withValues(alpha: 0.08),
                                                                borderRadius: BorderRadius.circular(16),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          // Botón de mute con icono oficial de YouTube
                                                          IconButton(
                                                            padding: EdgeInsets.zero,
                                                            constraints: const BoxConstraints(minWidth: 38, minHeight: 32),
                                                            hoverColor: Colors.transparent,
                                                            splashColor: Colors.transparent,
                                                            highlightColor: Colors.transparent,
                                                            icon: _YouTubeVolumeIcon(
                                                              volume: _volume,
                                                              size: 23,
                                                            ),
                                                            onPressed: () {
                                                              _toggleMute();
                                                              _startHideTimer();
                                                            },
                                                            tooltip: _volume == 0 ? 'Activar sonido (m)' : 'Silenciar (m)',
                                                          ),

                                                          // Slider de volumen horizontal con ancho animado y Fade In/Out
                                                          AnimatedContainer(
                                                            duration: const Duration(milliseconds: 250),
                                                            curve: Curves.easeInOutCubic,
                                                            width: (_isVolumeHovered || _isVolumeDragging) ? 76.0 : 0.0,
                                                            child: AnimatedOpacity(
                                                              opacity: (_isVolumeHovered || _isVolumeDragging) ? 1.0 : 0.0,
                                                              duration: const Duration(milliseconds: 200),
                                                              child: SizedBox(
                                                                width: 76.0,
                                                                child: (_isVolumeHovered || _isVolumeDragging)
                                                                    ? _YouTubeVolumeSlider(
                                                                        volume: _volume,
                                                                        onVolumeChanged: (val) {
                                                                          _setVolume(val);
                                                                          _startHideTimer();
                                                                        },
                                                                        onDragStateChanged: (dragging) {
                                                                          setState(() => _isVolumeDragging = dragging);
                                                                          if (!dragging) _startHideTimer();
                                                                        },
                                                                      )
                                                                    : const SizedBox.shrink(),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    ],
                                    const SizedBox(width: 8),

                                    // 4. ytp-time-display (Official ytp-time-wrapper-delhi Frosted Glass Capsule 46px)
                                    MouseRegion(
                                      onEnter: (_) => setState(() => _isTimeHovered = true),
                                      onExit: (_) => setState(() => _isTimeHovered = false),
                                      cursor: SystemMouseCursors.click,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => _showRemainingTime = !_showRemainingTime);
                                            _startHideTimer();
                                          },
                                          child: Container(
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0x4D000000),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            alignment: Alignment.center,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                if (_isTimeHovered)
                                                  Positioned.fill(
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.white.withValues(alpha: 0.08),
                                                          borderRadius: BorderRadius.circular(19),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                                  child: Center(
                                                    child: RichText(
                                                      text: TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: _showRemainingTime
                                                                ? '-${_formatDuration(_duration > _position ? _duration - _position : Duration.zero)}'
                                                                : _formatDuration(_position),
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 13.0,
                                                              fontWeight: FontWeight.w600,
                                                              letterSpacing: 0.2,
                                                              shadows: [
                                                                Shadow(
                                                                  offset: Offset(0, 0),
                                                                  blurRadius: 2,
                                                                  color: Colors.black,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const TextSpan(
                                                            text: ' / ',
                                                            style: TextStyle(
                                                              color: Colors.white70,
                                                              fontSize: 13.0,
                                                              fontWeight: FontWeight.normal,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: _formatDuration(_duration),
                                                            style: const TextStyle(
                                                              color: Colors.white70,
                                                              fontSize: 13.0,
                                                              fontWeight: FontWeight.normal,
                                                              letterSpacing: 0.2,
                                                              shadows: [
                                                                Shadow(
                                                                  offset: Offset(0, 0),
                                                                  blurRadius: 2,
                                                                  color: Colors.black,
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
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // =========================================================
                                // ytp-right-controls Group (Saltar OP/ED Capsule + Controls Capsule)
                                // =========================================================
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 1. "Saltar OP/ED" Standalone Frosted Glass Capsule (46px)
                                    if (!isTheme && widget.category != 'movie') ...[
                                      MouseRegion(
                                        onEnter: (_) => setState(() => _isSkipOpEdHovered = true),
                                        onExit: (_) => setState(() => _isSkipOpEdHovered = false),
                                        cursor: SystemMouseCursors.click,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: GestureDetector(
                                            onTap: _skipOpEd,
                                            child: Container(
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0x4D000000),
                                                borderRadius: const BorderRadius.all(Radius.circular(20)),
                                              ),
                                              alignment: Alignment.center,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  if (_isSkipOpEdHovered)
                                                    Positioned.fill(
                                                      child: Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.white.withValues(alpha: 0.08),
                                                            borderRadius: BorderRadius.circular(16),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                                    child: Center(
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          AurisIcon(
                                                            AurisIcons.fastForward,
                                                            color: Colors.white,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          const Text(
                                                            'Saltar OP/ED',
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 13.0,
                                                              fontWeight: FontWeight.bold,
                                                              letterSpacing: 0.3,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],

                                    // 2. Right Controls Capsule (CC, Settings, Episodes, Theater, Fullscreen)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0x4D000000),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // 1. ytp-settings-button (Settings Gear with HD Badge)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                                          style: IconButton.styleFrom(
                                            hoverColor: Colors.white.withValues(alpha: 0.08),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          icon: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: Alignment.center,
                                            children: [
                                              AurisIcon(
                                                AurisIcons.settings,
                                                color: Colors.white,
                                                size: 23,
                                              ),
                                              if (widget.hasQualityOptions)
                                                Positioned(
                                                  top: -2,
                                                  right: -4,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                                                    decoration: BoxDecoration(
                                                      color: AurisPalette.brand,
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                    child: const Text(
                                                      'HD',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 7.5,
                                                        fontWeight: FontWeight.w900,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _showSettingsPanel = !_showSettingsPanel;
                                              _settingsView = SettingsView.main;
                                            });
                                            _startHideTimer();
                                          },
                                          tooltip: 'Configuración',
                                        ),
                                        const SizedBox(width: 2),

                                        // 4. ytp-size-button (Modo cine / Teatro)
                                        if (!isTheme && !isTabletOrMobile && widget.onTheaterModeToggle != null) ...[
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                                            style: IconButton.styleFrom(
                                              hoverColor: Colors.white.withValues(alpha: 0.08),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            ),
                                            icon: AurisIcon(
                                              AurisIcons.theaterMode,
                                              color: Colors.white,
                                              size: 23,
                                            ),
                                            onPressed: widget.onTheaterModeToggle,
                                            tooltip: widget.isTheaterMode ? 'Restaurar tamaño (t)' : 'Modo cine (t)',
                                          ),
                                          const SizedBox(width: 2),
                                        ],

                                        // 5. ytp-fullscreen-button (Pantalla completa)
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                                          style: IconButton.styleFrom(
                                            hoverColor: Colors.white.withValues(alpha: 0.08),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          icon: AurisIcon(
                                            AurisIcons.expand,
                                            color: Colors.white,
                                            size: 23,
                                          ),
                                          onPressed: widget.onExpandPressed,
                                          tooltip: 'Pantalla completa (f)',
                                        ),
                                      ],
                                    ),
                                  ),
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
              ),

              // Panel Flotante de Configuración (Settings Popover)
              _buildFloatingSettingsPanel(),

              // 4. Cápsula Flotante "2x" al mantener presionado (Standard Delhi Frosted Glass)
              if (_isHolding2x)
                Positioned(
                  top: 28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0x4D000000), // Exacto YouTube: rgba(0, 0, 0, 0.3)
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '2x',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              AurisIcon(
                                AurisIcons.fastForwardFilled,
                                color: AurisPalette.brand,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Arte que alimenta el modo ambiente (banner del episodio o, en su defecto,
  /// el póster del contenido).
  String? get _ambientArtUrl {
    final banner = widget.bannerUrl?.trim();
    if (banner != null && banner.isNotEmpty) return banner;
    final poster = widget.posterUrl?.trim();
    if (poster != null && poster.isNotEmpty) return poster;
    return null;
  }

  /// Modo ambiente / iluminación cinematográfica.
  ///
  /// YouTube lo implementa con un `<canvas>` que copia el frame del `<video>` a
  /// ~15 fps y lo pinta con `filter: blur(40px)` a 0.4 de opacidad
  /// (`cinematic_watch_css_filter_blur_strength: 40`,
  /// `cinematic_watch_effect_opacity: 0.4`,
  /// `cinematic_watch_effect_letterbox_opacity: 0.4`). Aquí no hay acceso a los
  /// píxeles del video de media_kit, así que la fuente del resplandor es el arte
  /// del contenido, con los mismos parámetros ópticos.
  ///
  /// Dos variantes, igual que en YouTube:
  ///  * embebido / modo teatro: la luz vive **solo en las barras laterales**, a la
  ///    altura exacta del video. Nunca se escapa por arriba ni por abajo del
  ///    cuadro, igual que en el watch de YouTube.
  ///  * pantalla completa (`cinematicAmbient: true`): relleno difuminado de todo
  ///    el escenario (letterbox incluido) a 0.40.
  Widget _buildAmbientLightingOverlay() {
    if (!_isAmbientLightingEnabled) return const SizedBox.shrink();
    final String? art = _ambientArtUrl;
    if (art == null) return const SizedBox.shrink();

    final bool cinematic = widget.cinematicAmbient;
    final AmbientFrame? ambientFrame = ref.watch(ambientVideoProvider);

    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Widget light = AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              // El frame del video ya trae la máscara radial y el buffer diminuto
              // de YouTube, así que no necesita el atenuado del arte de respaldo.
              opacity: ambientFrame != null
                  ? (cinematic ? 0.85 : 0.72)
                  : (cinematic ? 0.40 : (_isPlaying ? 0.32 : 0.16)),
              // Con frame disponible se usan los colores del video; si no, el
              // arte del contenido difuminado.
              child: ambientFrame != null
                  ? AmbientVideoLayer(frame: ambientFrame)
                  : ClipRect(
                      child: AmbientArtImage(
                        imageUrl: art,
                        sigma: cinematic ? 40 : 32,
                        scale: cinematic ? 1.06 : 1.18,
                      ),
                    ),
            );

            // Fullscreen y tarjeta 16:9: la luz puede llenar el marco porque el
            // video (con `fill` transparente) solo deja ver las barras.
            if (cinematic || !widget.isTheaterMode) return light;

            // Embebido / teatro: una franja a la altura del video, de lado a
            // lado, que solo asoma donde el video no llega (las barras).
            final Rect video = _videoRect(constraints.biggest);
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: video.top,
                  height: video.height,
                  child: light,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Relación de aspecto del video actual; 16:9 hasta que el motor reporta las
  /// dimensiones reales del stream.
  double get _videoAspect {
    final int? w = _videoWidth;
    final int? h = _videoHeight;
    if (w == null || h == null || w <= 0 || h <= 0) return 16 / 9;
    return w / h;
  }

  /// Rectángulo que ocupa el video dentro del escenario con `BoxFit.contain`.
  /// Sirve para ubicar las barras negras y limitar la luz a esa zona.
  Rect _videoRect(Size stage) {
    final double aspect = _videoAspect;
    double w = stage.width;
    double h = w / aspect;
    if (h > stage.height) {
      h = stage.height;
      w = h * aspect;
    }
    return Rect.fromLTWH((stage.width - w) / 2, (stage.height - h) / 2, w, h);
  }

  Widget _buildFloatingSettingsPanel() {
    if (!_showSettingsPanel) return const SizedBox.shrink();

    return Positioned(
      bottom: widget.isTheaterMode ? 72 : 68,
      right: widget.isTheaterMode ? 28 : 16,
      width: 310,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xE61C1C1C), // Official YouTube Popover Background rgba(28,28,28,0.90)
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_settingsView == SettingsView.main) ...[
                  // 1. Iluminación cinematográfica (Modo Ambiente YouTube)
                  _buildSettingsTile(
                    customSvgIcon: AurisIcons.ambientMode,
                    title: 'Iluminación cinematográfica',
                    trailing: SizedBox(
                      height: 24,
                      child: Transform.scale(
                        scale: 0.75,
                        child: Switch.adaptive(
                          value: _isAmbientLightingEnabled,
                          activeColor: AurisPalette.brand,
                          onChanged: (val) {
                            setState(() => _isAmbientLightingEnabled = val);
                            widget.onAmbientLightingToggle?.call(val);
                          },
                        ),
                      ),
                    ),
                  ),

              // 2. Subtítulos
              _buildSettingsTile(
                customSvgIcon: AurisIcons.subtitles,
                title: 'Subtítulos',
                trailingText: widget.currentSubtitleLabel ?? 'Español - es',
                onTap: () {
                  setState(() => _showSettingsPanel = false);
                  widget.onSubtitlesPressed?.call();
                },
              ),

              // 3. Temporizador de apagado (YouTube Sleep Timer)
              _buildSettingsTile(
                customSvgIcon: AurisIcons.sleepTimer,
                title: 'Temporizador de apagado',
                trailingText: _sleepTimerLabel,
                onTap: () {
                  setState(() => _settingsView = SettingsView.sleepTimer);
                },
              ),

              // 4. Velocidad de reproducción (YouTube Speed)
              _buildSettingsTile(
                customSvgIcon: AurisIcons.playbackSpeed,
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
    IconData? icon,
    String? customSvgIcon,
    required String title,
    Widget? trailing,
    String? trailingText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.08),
      splashColor: Colors.white.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (customSvgIcon != null)
              AurisIcon(customSvgIcon, color: Colors.white, size: 20)
            else if (icon != null)
              Icon(icon, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
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
      hoverColor: Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AurisPalette.brand : Colors.white,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AurisPalette.brand, size: 18),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// YOUTUBE VOLUME COMPONENTES OFICIALES (Icono Vectorial Multi-Capa + Slider)
// =============================================================================

/// Icono oficial de volumen de YouTube con transición fluida de ondas sonoras:
/// - Speaker base constante
/// - Onda pequeña (small-ripple) activa si volumen > 0 con fade/scale
/// - Onda grande (big-ripple) activa si volumen >= 50 con fade/scale
/// - Cruz de mute activa si volumen == 0
class _YouTubeVolumeIcon extends StatelessWidget {
  final double volume;
  final double size;

  const _YouTubeVolumeIcon({
    required this.volume,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMuted = volume == 0;
    final bool showSmallRipple = volume > 0;
    final bool showBigRipple = volume >= 50;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Speaker base
          AurisIcon(
            r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path d="''' +
                AurisIcons.ytVolumeSpeakerPath +
                r'''" fill="white"/></svg>''',
            size: size,
            color: Colors.white,
          ),

          // 2. Small ripple (onda baja)
          AnimatedOpacity(
            opacity: showSmallRipple ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: showSmallRipple ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              alignment: const Alignment(0.5, 0.0), // punto de pivote (18, 12)
              child: AurisIcon(
                r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path d="''' +
                    AurisIcons.ytVolumeSmallRipplePath +
                    r'''" fill="white"/></svg>''',
                size: size,
                color: Colors.white,
              ),
            ),
          ),

          // 3. Big ripple (onda alta)
          AnimatedOpacity(
            opacity: showBigRipple ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: showBigRipple ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              alignment: const Alignment(0.83, 0.0), // punto de pivote (22, 12)
              child: AurisIcon(
                r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path d="''' +
                    AurisIcons.ytVolumeBigRipplePath +
                    r'''" fill="white"/></svg>''',
                size: size,
                color: Colors.white,
              ),
            ),
          ),

          // 4. Mute cross (cruz cuando está silenciado)
          AnimatedOpacity(
            opacity: isMuted ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: isMuted ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: AurisIcon(
                r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><path d="''' +
                    AurisIcons.ytVolumeMuteCrossPath +
                    r'''" fill="white"/></svg>''',
                size: size,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider horizontal idéntico al reproductor web de YouTube (`ytp-volume-slider`):
/// - Track de 2px de altura (blanco activo, rgba(255, 255, 255, 0.20) inactivo)
/// - Handle circular de 12px blanco limpio con sombra suave
/// - Arrastre y clic fluido continuo (touch-action: none)
class _YouTubeVolumeSlider extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<bool> onDragStateChanged;

  const _YouTubeVolumeSlider({
    required this.volume,
    required this.onVolumeChanged,
    required this.onDragStateChanged,
  });

  @override
  State<_YouTubeVolumeSlider> createState() => _YouTubeVolumeSliderState();
}

class _YouTubeVolumeSliderState extends State<_YouTubeVolumeSlider> {
  static const double _trackWidth = 56.0;
  static const double _handleSize = 12.0;

  void _updateVolumeFromOffset(double localDx) {
    final double fraction = (localDx / _trackWidth).clamp(0.0, 1.0);
    widget.onVolumeChanged(fraction * 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final double fraction = (widget.volume / 100.0).clamp(0.0, 1.0);
    final double handleLeft = (fraction * _trackWidth) - (_handleSize / 2.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          widget.onDragStateChanged(true);
          _updateVolumeFromOffset(details.localPosition.dx);
        },
        onTapUp: (_) => widget.onDragStateChanged(false),
        onTapCancel: () => widget.onDragStateChanged(false),
        onHorizontalDragStart: (details) {
          widget.onDragStateChanged(true);
          _updateVolumeFromOffset(details.localPosition.dx);
        },
        onHorizontalDragUpdate: (details) {
          _updateVolumeFromOffset(details.localPosition.dx);
        },
        onHorizontalDragEnd: (_) => widget.onDragStateChanged(false),
        onHorizontalDragCancel: () => widget.onDragStateChanged(false),
        child: Container(
          width: _trackWidth + 12.0, // margen derecho para respirar en la cápsula
          height: 40,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(right: 12.0),
          child: SizedBox(
            width: _trackWidth,
            height: _handleSize,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // 1. Inactive track (YouTube: rgba(255, 255, 255, 0.20))
                Container(
                  width: _trackWidth,
                  height: 2.0,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(1.0),
                  ),
                ),

                // 2. Active track (YouTube: #fff)
                Container(
                  width: _trackWidth * fraction,
                  height: 2.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(1.0),
                  ),
                ),

                // 3. Handle dot (YouTube: 12px círculo blanco limpio con sombra ligera)
                Positioned(
                  left: handleLeft.clamp(-_handleSize / 2.0, _trackWidth - (_handleSize / 2.0)),
                  child: Container(
                    width: _handleSize,
                    height: _handleSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.80),
                          blurRadius: 1.0,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
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

class _YouTubeSliderTrackShape extends RoundedRectSliderTrackShape {
  final Duration buffer;
  final Duration duration;
  final double? hoverFraction;

  _YouTubeSliderTrackShape({
    required this.buffer,
    required this.duration,
    this.hoverFraction,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.5;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 2.0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint basePaint = Paint()
      ..color = const Color(0xFF282828).withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    final Paint bufferPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? AurisPalette.brand
      ..style = PaintingStyle.fill;

    final double trackHeight = sliderTheme.trackHeight ?? 4.5;
    final Radius radius = Radius.circular(trackHeight / 2);

    // 1. Base track
    final Rect baseRect = Rect.fromLTWH(
      trackRect.left,
      trackRect.top + (trackRect.height - trackHeight) / 2,
      trackRect.width,
      trackHeight,
    );
    context.canvas.drawRRect(RRect.fromRectAndRadius(baseRect, radius), basePaint);

    // 2. Buffer track
    final double durationSec = duration.inSeconds > 0 ? duration.inSeconds.toDouble() : 1.0;
    final double bufferSec = buffer.inSeconds.toDouble().clamp(0.0, durationSec);
    final double bufferWidth = trackRect.width * (bufferSec / durationSec);
    if (bufferWidth > 0) {
      final Rect bufferRect = Rect.fromLTWH(
        trackRect.left,
        trackRect.top + (trackRect.height - trackHeight) / 2,
        bufferWidth,
        trackHeight,
      );
      context.canvas.drawRRect(RRect.fromRectAndRadius(bufferRect, radius), bufferPaint);
    }

    // 3. Active (played) track
    final double activeWidth = thumbCenter.dx - trackRect.left;
    if (activeWidth > 0) {
      final Rect activeRect = Rect.fromLTWH(
        trackRect.left,
        trackRect.top + (trackRect.height - trackHeight) / 2,
        activeWidth.clamp(0.0, trackRect.width),
        trackHeight,
      );
      context.canvas.drawRRect(RRect.fromRectAndRadius(activeRect, radius), activePaint);
    }

    // 4. Hover Preview track (painted after active track up to mouse cursor)
    if (hoverFraction != null) {
      final double hoverWidth = trackRect.width * hoverFraction!;
      if (hoverWidth > activeWidth) {
        final Paint previewPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.60)
          ..style = PaintingStyle.fill;
        final Rect previewRect = Rect.fromLTWH(
          trackRect.left + activeWidth,
          trackRect.top + (trackRect.height - trackHeight) / 2,
          (hoverWidth - activeWidth).clamp(0.0, trackRect.width - activeWidth),
          trackHeight,
        );
        context.canvas.drawRRect(RRect.fromRectAndRadius(previewRect, radius), previewPaint);
      }
    }
  }
}

class _HoverableTimeline extends StatefulWidget {
  final SliderThemeData sliderTheme;
  final double value;
  final double max;
  final Duration buffer;
  final Duration duration;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChangeEnd;

  const _HoverableTimeline({
    required this.sliderTheme,
    required this.value,
    required this.max,
    required this.buffer,
    required this.duration,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  @override
  State<_HoverableTimeline> createState() => _HoverableTimelineState();
}

class _HoverableTimelineState extends State<_HoverableTimeline> {
  double? _hoverFraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onHover: (event) {
            final double localX = event.localPosition.dx;
            final double width = constraints.maxWidth;
            if (width > 0) {
              setState(() {
                _hoverFraction = (localX / width).clamp(0.0, 1.0);
              });
            }
          },
          onExit: (_) {
            setState(() {
              _hoverFraction = null;
            });
          },
          child: SliderTheme(
            data: widget.sliderTheme.copyWith(
              trackShape: _YouTubeSliderTrackShape(
                buffer: widget.buffer,
                duration: widget.duration,
                hoverFraction: _hoverFraction,
              ),
            ),
            child: Slider(
              value: widget.value,
              max: widget.max,
              onChangeStart: widget.onChangeStart,
              onChanged: widget.onChanged,
              onChangeEnd: widget.onChangeEnd,
            ),
          ),
        );
      },
    );
  }
}
