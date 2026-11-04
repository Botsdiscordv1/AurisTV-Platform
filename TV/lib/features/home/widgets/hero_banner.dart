import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Media Kit para reproducción nativa en TV
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/tv_responsive_utils.dart';
import '../../../shared/widgets/tv_focus_wrapper.dart';

enum HeroBannerLayout { mobile, cinematic }

class HeroBanner extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onDetails;
  final dynamic Function(MediaItem item)? onTrailer;
  final bool autofocus;
  final String currentCategory;
  final VoidCallback? onFocused; // Callback para notificar enfoque al padre
  /// Nodo de la cápsula activa del topbar: D-pad arriba desde el hero salta
  /// directo a ella (Inicio en Inicio, Anime en Anime, ...).
  final FocusNode? pillFocusNode;
  /// D-pad abajo desde el hero: enfoca la PRIMERA tarjeta de la primera sección
  /// (determinista vía las GlobalKey del home). Si es null, usa el salto genérico.
  final bool Function()? onArrowDown;
  final VoidCallback? onArrowLeft;
  final bool isCompact;
  const HeroBanner({
    super.key,
    required this.items,
    required this.onDetails,
    this.onTrailer,
    this.autofocus = false,
    this.currentCategory = 'inicio',
    this.onFocused,
    this.pillFocusNode,
    this.onArrowDown,
    this.onArrowLeft,
    this.isCompact = false,
    dynamic layout,
  });

  @override
  ConsumerState<HeroBanner> createState() => HeroBannerState();
}

class HeroBannerState extends ConsumerState<HeroBanner> with WidgetsBindingObserver {
  int _backgroundIndex = 0;
  int _contentIndex = 0;
  bool _isHovered = false;
  Timer? _autoPlayTimer;
  bool _showTrailerLayer = false;
  bool _videoReady = false;
  bool _isAppActive = true;
  bool _isVisible = true;
  // Senior Fix: evita que al regresar de Content → Home el banner
  // reinicie la secuencia cinemática y recargue visualmente las imágenes.
  bool _wasEverVisible = false;
  // Guard para que _buildBackgroundLayer no cambie la key del
  // AnimatedSwitcher cuando el índice no ha cambiado realmente.
  int _lastRenderedBgIndex = -1;

  bool _isFocused = false; 
  bool _isTransitioning = false;

  final FocusNode _playButtonFocusNode = FocusNode(); 
  final FocusNode _favButtonFocusNode = FocusNode();
  final FocusNode _trailerButtonFocusNode = FocusNode();
  final FocusNode _muteButtonFocusNode = FocusNode();
  final FocusNode _prevButtonFocusNode = FocusNode();
  final FocusNode _nextButtonFocusNode = FocusNode();

  bool _pendingPlayFocus = false;

  @override
  void didUpdateWidget(covariant HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCompact && !widget.isCompact && _pendingPlayFocus) {
      _pendingPlayFocus = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) requestPlayFocus();
      });
    }
  }

  void requestPlayFocus() {
    if (_playButtonFocusNode.canRequestFocus) {
      _playButtonFocusNode.requestFocus();
    }
  }

  void focusPlayButton() {
    if (widget.isCompact) {
      _pendingPlayFocus = true;
      return;
    }
    _lastNavButton = null;
    requestPlayFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) requestPlayFocus();
    });
  }

  yt.YoutubePlayerController? _ytController;
  StreamSubscription? _ytSubscription;

  Player? _nativePlayer;
  VideoController? _nativeVideoController;
  StreamSubscription? _nativeSubscription;

  Timer? _fadeTimer;
  Timer? _delayTimer;
  bool _isTrailerLoading = false;
  bool _isDisposing = false;// Senior Fix: Nodo para redirección de foco

  @override
  void initState() {
    super.initState();
    _isFocused = widget.autofocus; 
    WidgetsBinding.instance.addObserver(this);
    _startAutoPlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startCycle(delay: const Duration(milliseconds: 800));
        _precacheNextImage();
      }
    });
  }

  String? _formatMovieDuration(String? durationStr, int? runtimeMin) {
    int? totalMins = runtimeMin;
    if ((totalMins == null || totalMins <= 0) && durationStr != null && durationStr.isNotEmpty) {
      totalMins = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    if (totalMins == null || totalMins <= 0) {
      return durationStr;
    }
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    if (hours > 0 && mins > 0) {
      return '$hours h $mins min';
    } else if (hours > 0) {
      return '$hours h';
    } else {
      return '$mins min';
    }
  }

  int _bgMemCacheWidth() {
    final mq = MediaQuery.of(context);
    // Senior 1GB TV Box Tuning: Banner con tope de 1280px en RAM (720p/1080p downscaled)
    // Reduce el consumo de 8.5MB a 3.5MB por fondo de banner
    return (mq.size.width * mq.devicePixelRatio).round().clamp(640, 1280);
  }

  void _precacheNextImage() {
    if (widget.items.length < 2) return;
    final nextIndex = (_backgroundIndex + 1) % widget.items.length;
    final nextItem = widget.items[nextIndex];

    final imageUrl = nextItem.bannerUrl ?? nextItem.posterUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      precacheImage(
        ResizeImage(
          CachedNetworkImageProvider(imageUrl, cacheManager: AurisImageCacheManager.instance),
          width: _bgMemCacheWidth(),
        ),
        context,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _isAppActive = false;
      _stopAutoPlay();
      _stopCycle();
    } else if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
      _startAutoPlay();
      _startCycle(delay: const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _playButtonFocusNode.dispose();
    _favButtonFocusNode.dispose();
    _trailerButtonFocusNode.dispose();
    _muteButtonFocusNode.dispose();
    _prevButtonFocusNode.dispose();
    _nextButtonFocusNode.dispose();
    _stopAutoPlay();
    _stopCycle();
    super.dispose();
  }

  MediaItem get _currentBackgroundItem => widget.items[_backgroundIndex % widget.items.length];
  MediaItem? get _currentContentItem {
    if (_contentIndex == -1) return null;
    return widget.items[_contentIndex % widget.items.length];
  }

  List<FocusNode> _getActiveActionFocusNodes(MediaItem item) {
    final nodes = <FocusNode>[_playButtonFocusNode, _favButtonFocusNode];
    if (widget.items.length > 1) {
      nodes.add(_prevButtonFocusNode);
      nodes.add(_nextButtonFocusNode);
    }
    return nodes;
  }

  String? _lastNavButton; // 'prev', 'next', o null

  void _nextPage() => _runCinematicSequence((_backgroundIndex + 1) % widget.items.length);
  void _previousPage() => _runCinematicSequence((_backgroundIndex - 1 + widget.items.length) % widget.items.length);

  void _manualNextPage() {
    _lastNavButton = 'next';
    _nextPage();
  }

  void _manualPreviousPage() {
    _lastNavButton = 'prev';
    _previousPage();
  }

  void _autoNextPage() {
    _lastNavButton = null;
    _nextPage();
  }

  void _runCinematicSequence(int nextIndex) {
    if (widget.items.isEmpty || !_isAppActive) return;

    _isTransitioning = true;
    _delayTimer?.cancel();
    _fadeTimer?.cancel();
    _disposeController();

    if (mounted) {
      setState(() {
        _contentIndex = -1;
        _showTrailerLayer = false;
        _videoReady = false;
      });
    }

    _delayTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_isAppActive) return;
      if (mounted) setState(() => _backgroundIndex = nextIndex);
      _precacheNextImage();
      
      _delayTimer = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || !_isAppActive) return;
        if (mounted) setState(() {
          _contentIndex = nextIndex;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _isTransitioning = false;
          if (_isFocused) {
            if (_lastNavButton == 'prev' && _prevButtonFocusNode.canRequestFocus) {
              _prevButtonFocusNode.requestFocus();
            } else if (_lastNavButton == 'next' && _nextButtonFocusNode.canRequestFocus) {
              _nextButtonFocusNode.requestFocus();
            } else if (!_playButtonFocusNode.hasFocus) {
              _playButtonFocusNode.requestFocus();
            }
          }
          _lastNavButton = null;
        });

        _delayTimer = Timer(const Duration(seconds: 1), () {
          if (!mounted || !_isAppActive) return;
          _startCycle();
        });
      });
    });
  }

  void _startCycle({Duration delay = const Duration(seconds: 2)}) {
    if (!_isAppActive) return;
    if (mounted) {
      setState(() { _showTrailerLayer = false; _videoReady = false; });
    }
    
    final settings = ref.read(settingsProvider);
    if (!settings.autoPlayTrailers) { _disposeController(); return; }

    const bool isMobile = false; // TV siempre es desktop/cinemático
    if (isMobile) { _disposeController(); return; }

    final cat = widget.currentCategory.toLowerCase();
    final bool allowAutoplay = cat == 'animes' || cat == 'películas' || cat == 'series' || cat == 'kdrama';
    if (!allowAutoplay) { _disposeController(); return; }
    
    final key = _currentBackgroundItem.trailerKey;
    if (key != null && key.isNotEmpty) {
      _delayTimer?.cancel();
      _delayTimer = Timer(delay, () { if (mounted && _isAppActive) _initController(); });
    } else { _disposeController(); }
  }

  void _stopCycle() {
    _delayTimer?.cancel();
    _disposeController();
    if (_isDisposing) {
      _showTrailerLayer = false;
      _videoReady = false;
      return;
    }
    if (mounted) {
      setState(() { _showTrailerLayer = false; _videoReady = false; });
    }
  }

  void _initController() async {
    final key = _currentBackgroundItem.trailerKey;
    if (key == null || key.isEmpty) return;

    _disposeController();

    if (kIsWeb) {
      final ctrl = yt.YoutubePlayerController(
        params: yt.YoutubePlayerParams(
          showControls: false, showFullscreenButton: false, mute: ref.read(heroBannerMutedProvider),
          loop: false, showVideoAnnotations: false, playsInline: true, strictRelatedVideos: true, enableKeyboard: false,
          userAgent: 'Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0',
        ),
      );
      ctrl.loadVideoById(videoId: key);
      ctrl.listen((state) {
        if (state.playerState == yt.PlayerState.cued && mounted) ctrl.playVideo();
        if (state.playerState == yt.PlayerState.playing && mounted && !_videoReady) {
          Future.delayed(const Duration(milliseconds: 400), () { 
            if (mounted) setState(() => _videoReady = true); 
          });
        }
        if (state.playerState == yt.PlayerState.ended && mounted) { 
          setState(() { _showTrailerLayer = false; _videoReady = false; }); 
        }
      });
      _ytSubscription = ctrl.videoStateStream.listen((state) {
        if (!mounted) return;
        final duration = ctrl.value.metaData.duration.inSeconds;
        final position = state.position.inSeconds;
        if (position > 0.5 && !_videoReady && mounted) setState(() => _videoReady = true);
        if (position > 5 && duration > 30 && (duration - position) < 12) {
          if (_showTrailerLayer && mounted) { 
            setState(() { _showTrailerLayer = false; _videoReady = false; }); 
            _fadeOutAudio(ctrl); 
          }
        }
      });
      if (mounted) {
        setState(() { _ytController = ctrl; _showTrailerLayer = true; });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            ctrl.playVideo();
            Future.delayed(const Duration(seconds: 3), () { if (mounted && !_videoReady && _showTrailerLayer && _isAppActive) setState(() => _videoReady = true); });
          }
        });
      }
    } else {
      final directUrl = await YoutubeResolver.getDirectStreamUrl(key);
      if (directUrl == null || !mounted) return;

      final player = Player();
      final controller = VideoController(player);

      try {
        final platform = player.platform as dynamic;
        platform.setProperty('hwdec', 'auto-safe');
        platform.setProperty('audio-buffer', '0.5'); 
      } catch (_) {}

      await player.setVolume(ref.read(heroBannerMutedProvider) ? 0 : 100);
      await player.open(Media(directUrl), play: false);

      _nativeSubscription = player.stream.completed.listen((completed) {
        if (completed && mounted) {
          setState(() { _showTrailerLayer = false; _videoReady = false; });
        }
      });

      player.stream.position.listen((pos) {
        if (!mounted) return;
        final duration = player.state.duration.inSeconds;
        final position = pos.inSeconds;
        
        if (pos.inMilliseconds > 400 && !_videoReady) {
           if (mounted) setState(() => _videoReady = true);
        }

        if (position > 5 && duration > 30 && (duration - position) < 12) {
          if (_showTrailerLayer && mounted) { 
            setState(() { _showTrailerLayer = false; _videoReady = false; }); 
            _fadeOutAudio(player); 
          }
        }
      });

      if (mounted) {
        setState(() {
          _nativePlayer = player;
          _nativeVideoController = controller;
          _showTrailerLayer = true;
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            player.play();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && !_videoReady && _showTrailerLayer && _isAppActive) setState(() => _videoReady = true);
            });
          }
        });
      }
    }
  }

  void _fadeOutAudio(dynamic ctrl) {
    if (ref.read(heroBannerMutedProvider)) return;
    _fadeTimer?.cancel();
    int volume = 100;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      volume -= 10;
      if (volume <= 0) {
        if (ctrl is yt.YoutubePlayerController) ctrl.mute();
        if (ctrl is Player) ctrl.setVolume(0);
        timer.cancel();
      } else {
        if (ctrl is yt.YoutubePlayerController) ctrl.setVolume(volume);
        if (ctrl is Player) ctrl.setVolume(volume.toDouble());
      }
    });
  }

  void _disposeController() {
    _fadeTimer?.cancel();
    _ytSubscription?.cancel();
    _ytSubscription = null;
    _ytController?.close();
    _ytController = null;

    _nativeSubscription?.cancel();
    _nativeSubscription = null;
    _nativePlayer?.dispose();
    _nativePlayer = null;
    _nativeVideoController = null;
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!_isHovered && !_showTrailerLayer && mounted) _autoNextPage();
    });
  }

  void _stopAutoPlay() => _autoPlayTimer?.cancel();

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final double screenWidth = MediaQuery.of(context).size.width;



    return VisibilityDetector(
      key: ValueKey('hero_visibility_tv_${widget.currentCategory}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.1;
        if (visible != _isVisible) {
          setState(() => _isVisible = visible);
          if (!_isVisible) {
            _stopAutoPlay();
            _stopCycle();
          } else if (_isAppActive) {
            _startAutoPlay();
            // Senior Fix: Si el banner ya fue visible antes (vuelta de navegación),
            // NO reiniciamos la secuencia cinemática — solo reanudamos el autoplay.
            // Esto evita el flash/recarga de imagen al volver de Content → Home.
            if (!_wasEverVisible) {
              _wasEverVisible = true;
              _startCycle(delay: const Duration(seconds: 1));
            }
            // En regresos normales, simplemente reiniciamos el timer de rotación
            // sin tocar _backgroundIndex ni _contentIndex.
          }
        }
      },
      child: MouseRegion(
        onEnter: (_) { if (mounted) setState(() => _isHovered = true); },
        onExit: (_) { if (mounted) setState(() => _isHovered = false); },
        child: Focus(
          autofocus: widget.autofocus,
          canRequestFocus: true, // Senior Fix: El contenedor ahora atrapa el foco para evitar saltos al TopBar
          onFocusChange: (focused) {
            if (focused) {
              _stopAutoPlay();
              if (mounted) setState(() => _isFocused = true);
              if (widget.onFocused != null) widget.onFocused!();

              // Si el contenedor capturó el foco primario, respetamos el botón manual si fue usado recientemente, sino vamos a reproducir
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_isFocused) return;
                // Si el foco ya está dentro de un botón del hero, no lo robamos.
                final item = _currentContentItem ?? (widget.items.isNotEmpty ? widget.items.first : null);
                if (item != null && _getActiveActionFocusNodes(item).any((n) => n.hasFocus)) {
                  return;
                }
                if (_lastNavButton == 'prev' && _prevButtonFocusNode.canRequestFocus) {
                  _prevButtonFocusNode.requestFocus();
                } else if (_lastNavButton == 'next' && _nextButtonFocusNode.canRequestFocus) {
                  _nextButtonFocusNode.requestFocus();
                } else if (!_playButtonFocusNode.hasFocus) {
                  _playButtonFocusNode.requestFocus();
                }
              });
            } else {
              if (!_isTransitioning) {
                _startAutoPlay();
                if (mounted) setState(() => _isFocused = false);
              }
            }
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                final target = widget.pillFocusNode;
                if (target != null && target.canRequestFocus) {
                  target.requestFocus();
                  return KeyEventResult.handled;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (widget.onArrowDown?.call() == true) {
                  return KeyEventResult.handled;
                }
                if (TvDirectionalFocus.focusFirstBelow(preserveColumn: false)) {
                  return KeyEventResult.handled;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (_playButtonFocusNode.hasFocus) {
                  if (widget.onArrowLeft != null) {
                    widget.onArrowLeft!();
                    return KeyEventResult.handled;
                  }
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () {
              final item = _currentContentItem;
              if (item != null) widget.onDetails(item);
            },
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.80,
              width: screenWidth,
              child: _buildCinematicLayout(screenWidth),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCinematicLayout(double screenWidth) {
    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    final bgItem = _currentBackgroundItem;
    final contentItem = _currentContentItem;

    return Container(
      color: const Color(0xFF000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fondo de imagen con crossfade cinemático
          _buildBackgroundLayer(bgItem),

          // 2. Capa de tráiler si está activo
          if (_ytController != null && _showTrailerLayer)
            _buildTrailerLayer(screenWidth),
          if (_nativeVideoController != null && _showTrailerLayer)
            _buildTrailerLayer(screenWidth),
          
          // 3. Gradientes cinematográficos idénticos a Netflix TV
          _buildCinematicGradients(),

          // 4. Contenido superpuesto (Logo, Badges, Sinopsis y Botones)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: horizontalPadding,
            top: null,
            bottom: widget.isCompact
                ? MediaQuery.of(context).size.height * 0.35
                : 110,
            right: horizontalPadding,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: Alignment.bottomLeft,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: anim.drive(
                    Tween<Offset>(begin: const Offset(0.015, 0), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.easeOutCubic)),
                  ),
                  child: child,
                ),
              ),
              child: contentItem == null 
                  ? const SizedBox(key: ValueKey('hiding'), width: 1, height: 1) 
                  : _buildCinematicContent(contentItem, screenWidth),
            ),
          ),
        ),

          // 5. Controles de navegación y estado
          _buildNavArrows(),
          _buildDotsIndicator(20),
        ],
      ),
    );
  }

  Widget _buildBackgroundLayer(MediaItem item) {
    // Senior Fix: Actualizamos el guard solo cuando el índice cambia de verdad.
    // Si setState se dispara por razones ajenas (foco, hover, visibilidad al volver),
    // la key del AnimatedSwitcher NO cambia → no hay fade-in innecesario.
    if (_backgroundIndex != _lastRenderedBgIndex) {
      _lastRenderedBgIndex = _backgroundIndex;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: CachedNetworkImage(
        // La key usa _lastRenderedBgIndex en lugar de _backgroundIndex directo,
        // lo que garantiza que el AnimatedSwitcher solo recrea el widget
        // cuando el fondo realmente cambia, no en rebuilds por otros motivos.
        key: ValueKey('bg_${item.id}_$_lastRenderedBgIndex'),
        imageUrl: item.bannerUrl ?? item.posterUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.topCenter,
        memCacheWidth: _bgMemCacheWidth(),
        fadeInDuration: AurisImageConfig.defaultFadeInDuration,
        fadeOutDuration: AurisImageConfig.defaultFadeOutDuration,
        cacheManager: AurisImageCacheManager.instance,
        filterQuality: MediaQuery.of(context).size.width < 1600
            ? FilterQuality.medium
            : FilterQuality.high,
      ),
    );
  }

  Widget _buildTrailerLayer(double screenWidth) {
    final double height = MediaQuery.of(context).size.width / 2.1;
    final double playerHeight = height * 1.65; 
    final double playerWidth = playerHeight * (16 / 9);

    Widget playerWidget;
    if (kIsWeb) {
      playerWidget = yt.YoutubePlayer(
        key: ValueKey('yt_${_currentBackgroundItem.trailerKey}'),
        controller: _ytController!,
        aspectRatio: 16 / 9,
      );
    } else {
      playerWidget = Video(
        key: ValueKey('native_${_currentBackgroundItem.trailerKey}'),
        controller: _nativeVideoController!,
        fill: Colors.transparent,
        controls: NoVideoControls,
      );
    }

    return Positioned(
      top: 0, bottom: 0, right: 0,
      width: screenWidth * 0.8,
      child: AnimatedOpacity(
        opacity: _videoReady ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: true,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.center,
                  minWidth: playerWidth,
                  maxWidth: playerWidth,
                  minHeight: playerHeight,
                  maxHeight: playerHeight,
                  child: playerWidget,
                ),
              ),
            ),
            if (kIsWeb)
              Positioned.fill(
                child: PointerInterceptor(
                  intercepting: true,
                  child: Container(color: Colors.transparent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCinematicGradients() {
    final bool showTrailer = _showTrailerLayer && _videoReady;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Viñeta superior sutil para legibilidad del TopBar
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99000000),
                Colors.transparent,
              ],
              stops: [0.0, 0.22],
            ),
          ),
        ),

        // 2. Gradientes cuando se muestra imagen estática
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: showTrailer ? 0.0 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Viñeta horizontal de izquierda a derecha (estilo Netflix)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF000000),
                      Color(0xF2000000),
                      Color(0xB3000000),
                      Color(0x33000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.28, 0.48, 0.70, 0.95],
                  ),
                ),
              ),
              // Viñeta vertical inferior (comienza en la parte baja del hero)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF000000),
                      Color(0x99000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.15, 0.35],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Gradientes cuando se reproduce el video de fondo
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: showTrailer ? 1.0 : 0.0,
          child: const Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color(0xCC000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.35, 0.52, 1.0],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF000000),
                      Color(0x99000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.15, 0.35],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  String _formatMediaTypeClean(MediaItem item) {
    final kind = item.kind?.toLowerCase();
    if (kind == 'anime' || item.type == MediaType.anime) {
      return 'ANIME';
    } else if (kind == 'kdrama' || item.type == MediaType.kdrama) {
      return 'K-DRAMA';
    } else if (kind == 'movie' || item.type == MediaType.movie) {
      return 'PELÍCULA';
    } else {
      return 'SERIE';
    }
  }

  String _formatMediaType(MediaItem item) {
    final kind = item.kind?.toLowerCase();
    if (kind == 'anime' || item.type == MediaType.anime) {
      return 'A N I M E';
    } else if (kind == 'kdrama' || item.type == MediaType.kdrama) {
      return 'K D R A M A';
    } else if (kind == 'movie' || item.type == MediaType.movie) {
      return 'P E L Í C U L A';
    } else {
      return 'S E R I E';
    }
  }

  String _formatMediaTypePlural(MediaItem item) {
    final kind = item.kind?.toLowerCase();
    if (kind == 'anime' || item.type == MediaType.anime) {
      return 'animes';
    } else if (kind == 'kdrama' || item.type == MediaType.kdrama) {
      return 'k-dramas';
    } else if (kind == 'movie' || item.type == MediaType.movie) {
      return 'películas';
    } else {
      return 'series';
    }
  }

  Widget _buildCinematicContent(MediaItem item, double screenWidth) {
    final titleFontSize = TVResponsiveUtils.heroTitleFontSize(context);
    
    return Column(
      key: ValueKey('content_col_tv_${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [


        // 2. Logo / Título
        if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
          Builder(builder: (context) {
            final dpr = MediaQuery.of(context).devicePixelRatio;
            final logoWidth = MediaQuery.of(context).size.width * 0.40;
            final logoUrl = ApiEndpoints.proxyImage(item.logoUrl);
            return SizedBox(
              height: TVResponsiveUtils.heroLogoHeight(context),
              width: logoWidth,
              child: LogoToneFilter(
                imageUrl: logoUrl,
                child: CachedNetworkImage(
                  key: ValueKey('logo_tv_${item.id}'),
                  imageUrl: logoUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                  fadeInDuration: const Duration(milliseconds: 100),
                  memCacheWidth: (logoWidth * dpr).round().clamp(320, 1280),
                  placeholder: (context, url) => SizedBox(
                    height: TVResponsiveUtils.heroLogoHeight(context),
                    width: logoWidth,
                  ),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            );
          })
        else
          Text(
            item.title.toUpperCase(), 
            style: TextStyle(
              fontFamily: 'NetflixSans',
              fontSize: titleFontSize, 
              fontWeight: FontWeight.w900, 
              color: Colors.white, 
              height: 0.95,
              letterSpacing: -0.8,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.6), offset: const Offset(0, 4), blurRadius: 10)
              ]
            )
          ),
        
        const SizedBox(height: 12),

        // 3. Metadata idéntica a Netflix TV (Coincidencia verde, Año, Clasificación, Duración, Badges Ultra HD)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Coincidencia verde de Netflix
            const Text(
              '98% para ti',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Color(0xFF46D369), // Verde Netflix exacto
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            if (widget.currentCategory.toLowerCase() == 'inicio') ...[
              Text(
                _formatMediaTypeClean(item),
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 10),
            ],
            // Año
            Text(
              item.year != null ? '${item.year}' : '2024',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Colors.white.withOpacity(0.85),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            // Clasificación por edad (Cajita delimitada)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1.0),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                item.certification ?? '16+',
                style: const TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Duración o Temporadas de forma null-safe
            if ((item.duration != null && item.duration!.isNotEmpty) || (item.runtime != null && item.runtime! > 0)) ...[
              Text(
                _formatMovieDuration(item.duration, item.runtime) ?? '',
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (item.totalSeasons != null && item.totalSeasons! > 0) ...[
              Text(
                item.totalSeasons == 1 ? '1 temporada' : '${item.totalSeasons} temporadas',
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
            ] else if (item.episode != null && item.episode! > 0) ...[
              Text(
                'Episodio ${item.episode}',
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
            ],
            // Calidad Ultra HD
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1.0),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'Ultra HD',
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white70,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1.0),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Text(
                'HDR',
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white70,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 4. Sinopsis (limpia, siempre legible estilo Netflix)
        SizedBox(
          width: screenWidth * 0.46,
          child: Text(
            item.synopsis ?? '', 
            maxLines: 3, 
            overflow: TextOverflow.ellipsis, 
            style: TextStyle(
              fontFamily: 'NetflixSans',
              color: const Color(0xFFE5E5E5), 
              fontSize: TVResponsiveUtils.heroSynopsisFontSize(context), 
              height: 1.38, 
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(0, 1), blurRadius: 4),
              ],
            )
          ),
        ),

        if (!widget.isCompact) ...[
          const SizedBox(height: 18),
          
          // 5. Botones de Acción (Reproducir y secundarios al lado)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NetflixHeroButton(
                focusNode: _playButtonFocusNode,
                onPressed: () => widget.onDetails(item),
                icon: AurisIcons.play,
                label: 'Reproducir',
                isPrimary: true,
                autofocus: widget.autofocus,
              ),
              const SizedBox(width: 12),
              Builder(builder: (context) {
                final isFav = ref.watch(favoritesProvider).any((f) => f.id == item.id);
                return _NetflixHeroIconButton(
                  focusNode: _favButtonFocusNode,
                  icon: isFav ? AurisIcons.bookmarkFilled : AurisIcons.add,
                  label: isFav ? 'En mi lista' : 'Mi lista',
                  onPressed: () {
                    final user = ref.read(authProvider);
                    ref.read(favoritesProvider.notifier).toggleFavorite(
                      favoriteFromMedia(item, user?.activeProfileId ?? 'guest_profile'),
                    );
                  },
                );
              }),
              if (widget.items.length > 1) ...[
                const SizedBox(width: 12),
                _NetflixHeroIconButton(
                  focusNode: _prevButtonFocusNode,
                  icon: AurisIcons.arrowLeft2,
                  label: 'Anterior',
                  onPressed: () {
                    _manualPreviousPage();
                    _startAutoPlay();
                  },
                ),
                const SizedBox(width: 12),
                _NetflixHeroIconButton(
                  focusNode: _nextButtonFocusNode,
                  icon: AurisIcons.arrowRight2,
                  label: 'Siguiente',
                  onPressed: () {
                    _manualNextPage();
                    _startAutoPlay();
                  },
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNavArrows() {
    return const SizedBox.shrink(); // Desactivadas flechas táctiles en TV
  }

  Widget _buildDotsIndicator(double bottom) {
    return Positioned(
      bottom: bottom, left: 0, right: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: List.generate(widget.items.length, (index) {
          final isCurrent = (_backgroundIndex % widget.items.length) == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: isCurrent ? 14 : 6, 
            height: 3.5,
            decoration: BoxDecoration(
              color: isCurrent ? Colors.white : Colors.white24, 
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

/// Botón rectangular de acción para el Hero con la firma visual de Netflix TV:
/// - Esquinas cuadradas ligeramente redondeadas (BorderRadius 4px).
/// - El botón primario es blanco con texto negro siempre.
/// - Los botones secundarios son grises translúcidos con texto blanco; pero al
///   recibir el foco del control remoto, SE CONVIERTEN EN BLANCO SÓLIDO CON TEXTO
///   E ICONO NEGRO y se escalan un 6% con transición suave.
class _NetflixHeroButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String icon;
  final String label;
  final bool isPrimary;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool isLoading;

  const _NetflixHeroButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.autofocus = false,
    this.focusNode,
    this.isLoading = false,
  });

  @override
  State<_NetflixHeroButton> createState() => _NetflixHeroButtonState();
}

class _NetflixHeroButtonState extends State<_NetflixHeroButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isPlayButton = widget.icon == AurisIcons.play || widget.icon == AurisIcons.playFilled;
    
    final Color bgColor = isPlayButton 
        ? Colors.white 
        : (_isFocused ? Colors.white : Colors.white.withValues(alpha: 0.15));
    final Color textColor = isPlayButton ? Colors.black : (_isFocused ? Colors.black : Colors.white);
    
    final String effectiveIcon = isPlayButton ? AurisIcons.playFilled : widget.icon;
    final Color iconColor = isPlayButton ? Colors.black : textColor;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !widget.isLoading) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30), // Cápsula (pill shape)
            // Borde siempre presente con ancho fijo para evitar que el cambio de
            // tamaño al enfocar cause un relayout que sacuda el header.
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.isLoading ? null : widget.onPressed,
              borderRadius: BorderRadius.circular(30),
              // Netflix TV no tiene tinte de splash — eliminamos el color del tema.
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isLoading)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: textColor,
                        ),
                      )
                    else
                      AurisIcon(
                        effectiveIcon,
                        size: 20,
                        color: iconColor,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón circular para acciones complementarias del Hero (Audio, Navegación de carrusel)
/// con retroalimentación inmediata en foco estilo Netflix.
class _NetflixHeroIconButton extends StatefulWidget {
  final String icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final FocusNode? focusNode;

  const _NetflixHeroIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.focusNode,
  });

  @override
  State<_NetflixHeroIconButton> createState() => _NetflixHeroIconButtonState();
}

class _NetflixHeroIconButtonState extends State<_NetflixHeroIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _focused ? Colors.white : Colors.white.withValues(alpha: 0.15);
    final Color iconColor = _focused ? Colors.black : Colors.white;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !widget.isLoading) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Tooltip(
        message: widget.label,
        child: AnimatedScale(
          scale: _focused ? 1.0 : 0.95,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              // Ancho fijo (2px) para que el botón circular no cambie de tamaño
              // al enfocar, evitando temblor del header.
              border: Border.all(
                color: _focused ? Colors.white : Colors.white38,
                width: 2.0,
              ),
            ),
            child: widget.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: iconColor,
                    ),
                  )
                : AurisIcon(widget.icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
