import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt; // Senior Fix: Alias para evitar colisión de PlayerState
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Senior Fix: Importaciones para el reproductor nativo (Mobile/TV)
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/utils/youtube_resolver.dart';

import '../../auris_core.dart';
import 'nav_arrow.dart';

enum HeroBannerLayout { mobile, cinematic }

class HeroBanner extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onPlay;
  final void Function(MediaItem item) onDetails;
  final dynamic Function(MediaItem item)? onTrailer; // Senior Fix: dynamic para soportar callbacks async
  final bool autofocus;
  final String currentCategory;
  final HeroBannerLayout? layout;

  const HeroBanner({
    super.key,
    required this.items,
    required this.onPlay,
    required this.onDetails,
    this.onTrailer,
    this.autofocus = false,
    this.currentCategory = 'inicio',
    this.layout,
  });

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> with WidgetsBindingObserver {
  int _backgroundIndex = 0;
  int _contentIndex = 0;
  bool _isHovered = false;
  Timer? _autoPlayTimer;
  bool _showTrailerLayer = false;
  bool _videoReady = false;
  bool _isAppActive = true;
  bool _isVisible = true;

  yt.YoutubePlayerController? _ytController;
  StreamSubscription? _ytSubscription;

  // Senior Fix: Estado para el reproductor nativo (media_kit)
  Player? _nativePlayer;
  VideoController? _nativeVideoController;
  StreamSubscription? _nativeSubscription;

  Timer? _fadeTimer;
  Timer? _delayTimer;
  bool _isTrailerLoading = false;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoPlay();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startCycle(delay: const Duration(milliseconds: 800));
        _precacheNextImage();
      }
    });
  }

  void _precacheNextImage() {
    if (widget.items.length < 2) return;
    // Precargamos la imagen del siguiente banner para una transición suave (Zero-Lag)
    final nextIndex = (_backgroundIndex + 1) % widget.items.length;
    final nextItem = widget.items[nextIndex];
    
    final imageUrl = ApiEndpoints.proxyImage(nextItem.bannerUrl ?? nextItem.posterUrl, highQuality: true);
    if (imageUrl.isNotEmpty) {
      precacheImage(CachedNetworkImageProvider(imageUrl), context);
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
    _stopAutoPlay();
    _stopCycle();
    super.dispose();
  }

  MediaItem get _currentBackgroundItem => widget.items[_backgroundIndex % widget.items.length];
  MediaItem? get _currentContentItem {
    if (_contentIndex == -1) return null;
    return widget.items[_contentIndex % widget.items.length];
  }

  void _nextPage() => _runCinematicSequence((_backgroundIndex + 1) % widget.items.length);
  void _previousPage() => _runCinematicSequence((_backgroundIndex - 1 + widget.items.length) % widget.items.length);

  void _runCinematicSequence(int nextIndex) {
    if (widget.items.isEmpty || !_isAppActive) return;

    // Senior Strategy: Aseguramos la limpieza total y cancelación de hilos previos
    _delayTimer?.cancel();
    _fadeTimer?.cancel();
    _disposeController();

    // 1. OCULTAR TODO EL CONTENIDO
    if (mounted) {
      setState(() {
        _contentIndex = -1;
        _showTrailerLayer = false;
        _videoReady = false;
      });
    }

    // 2. CAMBIAR FONDO (Tras 400ms de desvanecimiento)
    _delayTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_isAppActive) return;
      if (mounted) setState(() => _backgroundIndex = nextIndex);
      
      // Senior Fix: Precargar el siguiente incluso antes de que llegue su turno
      _precacheNextImage();
      
      // 3. MOSTRAR NUEVO CONTENIDO (Damos 350ms para que la imagen cargue)
      _delayTimer = Timer(const Duration(milliseconds: 350), () {
        if (!mounted || !_isAppActive) return;
        if (mounted) setState(() => _contentIndex = nextIndex);

        // 4. REINICIAR TRAILER
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
    
    // Senior Fix: Respetar la preferencia de Autoplay de Trailers del usuario
    final settings = ref.read(settingsProvider);
    if (!settings.autoPlayTrailers) { _disposeController(); return; }

    // Senior Fix: Restauramos la restricción en móvil para evitar autoplay de trailers.
    final bool isMobile = context.isMobile;
    if (isMobile) { _disposeController(); return; }

    final cat = widget.currentCategory.toLowerCase();
    final bool allowAutoplay = cat == 'inicio' || cat == 'animes' || cat == 'películas' || cat == 'series' || cat == 'kdrama' || cat == 'kdramas';
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
    // Senior Fix: Evitar setState durante dispose/finalizeTree (lifecycle defunct)
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
      // MANTENEMOS IFRAME PARA WEB (Mejor compatibilidad con browsers)
      final ctrl = yt.YoutubePlayerController(
        params: yt.YoutubePlayerParams(
          showControls: false, showFullscreenButton: false, mute: ref.read(heroBannerMutedProvider),
          loop: false, showVideoAnnotations: false, playsInline: true, strictRelatedVideos: true, enableKeyboard: false,
          origin: 'https://www.youtube.com',
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
      // SENIOR FIX: REPRODUCTOR NATIVO PARA MOBILE/TV (Evita errores 150/152)
      final directUrl = await YoutubeResolver.getDirectStreamUrl(key);
      if (directUrl == null || !mounted) return;

      final player = Player();
      final controller = VideoController(player);

      // Senior Tuning: Optimizamos el motor para carga estable de trailers
      try {
        final platform = player.platform as dynamic;
        platform.setProperty('hwdec', 'auto-safe');
        platform.setProperty('audio-buffer', '0.5'); // Buffer mínimo de seguridad para evitar jitter
      } catch (_) {}

      await player.setVolume(ref.read(heroBannerMutedProvider) ? 0 : 100);
      await player.open(Media(directUrl), play: false);

      _nativeSubscription = player.stream.completed.listen((completed) {
        if (completed && mounted) {
          setState(() { _showTrailerLayer = false; _videoReady = false; });
        }
      });

      // Monitoreo de posición para fade out al final
      player.stream.position.listen((pos) {
        if (!mounted) return;
        final duration = player.state.duration.inSeconds;
        final position = pos.inSeconds;
        
        // Cuando el video realmente ha comenzado a emitir frames, mostramos la capa
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

    // Limpieza de reproductor nativo
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
    _nativePlayer?.dispose();
    _nativePlayer = null;
    _nativeVideoController = null;
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!_isHovered && !_showTrailerLayer && mounted) _nextPage();
    });
  }

  void _stopAutoPlay() => _autoPlayTimer?.cancel();

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Senior Strategy: Dispositivos con ancho > 600 (como Z Fold desplegado) 
    // usan el Layout "Cápsula" (cinematic) para optimizar el espacio vertical.
    final bool useMobileLayout = context.breakpoint < Breakpoint.sm || 
                                (context.breakpoint < Breakpoint.lg && screenWidth < 600);
    
    final HeroBannerLayout layout = widget.layout ?? (useMobileLayout ? HeroBannerLayout.mobile : HeroBannerLayout.cinematic);

    return VisibilityDetector(
      key: ValueKey('hero_visibility_${widget.currentCategory}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.1; // Senior Fix: 10% de visibilidad para considerar activo
        if (visible != _isVisible && mounted) {
          setState(() => _isVisible = visible);
          if (!_isVisible) {
            _stopAutoPlay();
            _stopCycle();
          } else if (_isAppActive) {
            _startAutoPlay();
            _startCycle(delay: const Duration(seconds: 1));
          }
        }
      },
      child: MouseRegion(
        onEnter: (_) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }); },
        onExit: (_) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }); },
        child: Focus(
          autofocus: widget.autofocus,
          onFocusChange: (focused) {
            if (mounted) setState(() { if (focused) _stopAutoPlay(); else _startAutoPlay(); });
          },
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft && node.hasPrimaryFocus) { _previousPage(); return KeyEventResult.handled; }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight && node.hasPrimaryFocus) { _nextPage(); return KeyEventResult.handled; }
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                _previousPage(); // Swipe Derecha -> Anterior
              } else if (details.primaryVelocity! < 0) {
                _nextPage(); // Swipe Izquierda -> Siguiente
              }
            },
            onTap: () {
              final item = _currentContentItem;
              if (item != null) {
                SafeTap.run(() => widget.onDetails(item));
              }
            },
            child: _buildAdaptiveLayout(layout, screenWidth),
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveLayout(HeroBannerLayout layout, double screenWidth) {
    if (layout == HeroBannerLayout.mobile) {
      return _buildMobileLayout(screenWidth);
    } else {
      return _buildCinematicLayout(screenWidth);
    }
  }

  Widget _buildMobileLayout(double screenWidth) {
    final bgItem = _currentBackgroundItem;
    final contentItem = _currentContentItem;
    
    return AspectRatio(
      aspectRatio: ResponsiveUtils.heroAspectRatio(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          _buildBackgroundLayer(bgItem),
          // Gradient Scrim (Senior Strategy: Unificamos protección superior e inferior)
          _buildMobileGradients(), 
          // Content Overlay
          Positioned(
            left: 20, right: 20, bottom: 35,
            child: contentItem != null 
                ? _buildMobileContent(contentItem)
                : const SizedBox.shrink(),
          ),
          // Dots
          _buildDotsIndicator(15),
        ],
      ),
    );
  }

  Widget _buildCinematicLayout(double screenWidth) {
    final double horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final bgItem = _currentBackgroundItem;
    final contentItem = _currentContentItem;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 2.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: ResponsiveUtils.heroAspectRatio(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background
                _buildBackgroundLayer(bgItem),
                // Trailer
                if (_ytController != null && _showTrailerLayer)
                  _buildTrailerLayer(screenWidth),
                // Gradient Scrim
                _buildCinematicGradients(),
                Positioned(
                  left: 0, bottom: 0, top: 0, // Senior Fix: Anclamos el Positioned a los bordes izquierdos
                  child: Container(
                    width: screenWidth * 0.6,
                    padding: EdgeInsets.only(
                      left: context.breakpoint <= Breakpoint.xl ? 30 : 40, 
                      bottom: context.breakpoint <= Breakpoint.xl ? 25 : 45
                    ),
                    alignment: Alignment.bottomLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.bottomLeft, // Senior Fix: Alineación interna inamovible
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: anim.drive(Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero)),
                          child: child,
                        ),
                      ),
                      child: contentItem == null 
                          ? const SizedBox(key: ValueKey('hiding'), width: 1, height: 1) 
                          : _buildCinematicContent(contentItem, screenWidth),
                    ),
                  ),
                ),
                // Nav Arrows
                _buildNavArrows(),
                // Dots
                _buildDotsIndicator(25),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundLayer(MediaItem item) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          fit: StackFit.expand, // Senior Fix: Forzar a que las capas de transición ocupen todo el espacio
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: CachedNetworkImage(
        key: ValueKey('bg_${item.id}'),
        imageUrl: item.bannerUrl ?? item.posterUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high, // Senior Fix: Máxima fidelidad para banners 4K/Desktop
      ),
    );
  }

  Widget _buildTrailerLayer(double screenWidth) {
    // Senior UI Strategy: Super-Zoom al 165% para garantizar que los controles centrales 
    // de YouTube (Play/Pause icons) queden fuera del área visible del banner.
    final double height = MediaQuery.of(context).size.width / (2.8);
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
        controls: NoVideoControls, // Sin controles para el banner
      );
    }

    return Positioned(
      top: 0, bottom: 0, right: 0,
      width: screenWidth * 0.8, // Ocupamos el 80% derecho para el video
      child: AnimatedOpacity(
        opacity: _videoReady ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 800),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // El Video (Blindado)
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
            // Senior Fix Web: Escudo transparente con PointerInterceptor para "matar"
            // los clics antes de que lleguen al iframe de YouTube.
            // Solo se monta cuando el video ya es visible: un PointerInterceptor
            // crea un DIV HTML que bloquea mouse/scroll aunque el AnimatedOpacity
            // este en 0 o haya un IgnorePointer encima.
            if (kIsWeb && _videoReady && _showTrailerLayer)
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

  Widget _buildMobileGradients() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. DIMMING: Opacado general para quitar el brillo (Senior Strategy)
        Container(color: Colors.black.withOpacity(0.2)),

        // 2. PROTECCIÓN SUPERIOR (Para la TopBar)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3],
            ),
          ),
        ),

        // 3. PROTECCIÓN INFERIOR (Para el contenido y botones)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFF0B0B0D),
                const Color(0xFF0B0B0D).withOpacity(0.9),
                const Color(0xFF0B0B0D).withOpacity(0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.15, 0.4, 0.8],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCinematicGradients() {
    final bool showTrailer = _showTrailerLayer && _videoReady;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. PROTECCIÓN DE INTERFAZ SUPERIOR (Top Scrim)
        // Siempre activa para asegurar legibilidad de la TopBar en fondos claros.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0B0B0D).withOpacity(0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.25],
            ),
          ),
        ),

        // 2. MÁSCARA BASE (Backdrop Strategy con Dimming y Fusión Inferior)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: showTrailer ? 0.0 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // DIMMING: Opacado general de la imagen para evitar brillos blancos
              Container(color: Colors.black.withOpacity(0.15)),

              // Fusión Lateral Original
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF0B0B0D).withOpacity(0.85), 
                      const Color(0xFF0B0B0D).withOpacity(0.4),
                      const Color(0xFF0B0B0D).withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.5, 0.8],
                  ),
                ),
              ),

              // Fusión Inferior Original (Backdrop)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF0B0B0D).withOpacity(0.8),
                      const Color(0xFF0B0B0D).withOpacity(0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.5],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. MÁSCARA DE TRAILER (Original Trailer Strategy)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: showTrailer ? 1.0 : 0.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fusión Lateral Pro (Trailer)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF0B0B0D),
                      const Color(0xFF0B0B0D),
                      const Color(0xFF0B0B0D).withOpacity(0.9),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.38, 0.45, 1.0],
                  ),
                ),
              ),
              // Fundido inferior (Trailer)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF0B0B0D),
                      const Color(0xFF0B0B0D).withOpacity(0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.4],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildMobileContent(MediaItem item) {
    return Column(
      key: ValueKey('content_mob_${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Bloque Superior: Logo y Metadata Primaria (Año/Rating)
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Logo o Título (Lado Izquierdo)
            Expanded(
              child: item.logoUrl != null && item.logoUrl!.isNotEmpty
                  ? Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                        maxHeight: ResponsiveUtils.heroLogoHeight(context),
                      ),
                      child: CachedNetworkImage(
                        key: ValueKey('logo_mob_${item.id}'),
                        imageUrl: item.logoUrl!, 
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomLeft,
                        fadeInDuration: const Duration(milliseconds: 200),
                      ),
                    )
                  : Text(
                      item.title.toUpperCase(), 
                      style: TextStyle(
                        fontSize: ResponsiveUtils.sp(context, context.breakpoint < Breakpoint.sm ? 22 : 26), 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white, 
                        height: 1.1
                      )
                    ),
            ),
            const SizedBox(width: 12),
            // Metadata Primaria (Lado Derecho - Alineada a la base del logo)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.certification != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54, width: 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(item.certification!, style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.sp(context, 10), fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (item.rating != null && item.rating! > 0) ...[
                      const Icon(Icons.star_rounded, color: Color(0xFFEF7A1E), size: 14),
                      const SizedBox(width: 2),
                      Text(item.rating!.toStringAsFixed(1), style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.sp(context, 12), fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                const SizedBox(height: 2), // Senior Fix: Metadata bajada al máximo hacia la base
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 6), // Senior Fix: Reducido gap entre bloques para compactar la UI

        // 2. Bloque Inferior: Línea de Base Unificada (Estado y Géneros)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Estado dinámico (Alineado a la izquierda)
            if (!item.available)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                  child: Text('PRÓXIMAMENTE', style: TextStyle(color: Colors.white60, fontSize: ResponsiveUtils.sp(context, 10), fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              )
            else if (item.episode != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'NUEVO EPISODIO ${item.episode}', 
                  style: TextStyle(color: const Color(0xFFEF7A1E), fontSize: ResponsiveUtils.sp(context, 11), fontWeight: FontWeight.w900, letterSpacing: 0.5)
                ),
              )
            else
              const SizedBox.shrink(),

            // Géneros en MAYÚSCULAS (Lista completa alineada al estado)
            if (item.genres.isNotEmpty)
              Flexible(
                child: Text(
                  item.genres.join(' • ').toUpperCase(), 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: ResponsiveUtils.sp(context, 11), fontWeight: FontWeight.w500)
                ),
              ),
          ],
        ),
        
        if (!context.isMobile) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              _BannerButton(
                onPressed: () => SafeTap.run(() => widget.onPlay(item)),
                icon: Icons.play_arrow,
                label: 'Reproducir',
                isPrimary: true,
                isCompact: true,
              ),
              const SizedBox(width: 10),
              _BannerIconButton(
                icon: Icons.info_outline,
                label: 'Info',
                onPressed: () => SafeTap.run(() => widget.onDetails(item)),
                isCompact: true,
              ),
              if (item.trailerKey != null) ...[
                const SizedBox(width: 10),
                _BannerIconButton(
                  icon: Icons.movie_outlined,
                  label: 'Tráiler',
                  onPressed: () async {
                    if (_isTrailerLoading) return;
                    setState(() => _isTrailerLoading = true);
                    try {
                      final result = widget.onTrailer?.call(item);
                      if (result is Future) await result;
                    } finally {
                      if (mounted) setState(() => _isTrailerLoading = false);
                    }
                  },
                  isLoading: _isTrailerLoading,
                  isCompact: true,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }



  Widget _buildCinematicContent(MediaItem item, double screenWidth) {
    final b = context.breakpoint;
    final bool isIntermediate = b <= Breakpoint.xl; // iPad Pro (V/H) y Laptops
    final titleFontSize = ResponsiveUtils.heroTitleFontSize(context);
    
    return Column(
      key: ValueKey('content_col_${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. ICONO + CATEGORÍA
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/auris-tv-icon.svg', 
              height: isIntermediate ? 16 : 18, 
              colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn)
            ),
            const SizedBox(width: 10),
            Text(
              item.type.name.toUpperCase(), 
              style: TextStyle(
                color: Colors.white, 
                fontSize: ResponsiveUtils.sp(context, isIntermediate ? 11 : 13), 
                fontWeight: FontWeight.w900, 
                letterSpacing: 1.5
              )
            ),
          ],
        ),
        SizedBox(height: isIntermediate ? 10 : 16),

        // 2. EL LOGO / TÍTULO
        if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
          Container(
            constraints: BoxConstraints(
              // Senior Fix: Limitamos el ancho máximo del logo para evitar que títulos 
              // panorámicos (ej: Spider-Man) dominen demasiado la pantalla.
              maxWidth: screenWidth * (isIntermediate ? 0.35 : 0.38),
              maxHeight: ResponsiveUtils.heroLogoHeight(context) * (isIntermediate ? 1.1 : 1.35),
            ),
            child: CachedNetworkImage(
              key: ValueKey('logo_${item.id}'),
              imageUrl: item.logoUrl!, 
              fit: BoxFit.contain, 
              alignment: Alignment.bottomLeft,
              fadeInDuration: const Duration(milliseconds: 100),
            ),
          )
        else
          Text(
            item.title.toUpperCase(), 
            style: TextStyle(
              fontSize: titleFontSize * (isIntermediate ? 1.0 : 1.2), 
              fontWeight: FontWeight.w900, 
              color: Colors.white, 
              height: 0.9,
              letterSpacing: -1,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(0, 4), blurRadius: 10)
              ]
            )
          ),
        
        SizedBox(height: isIntermediate ? 10 : 16),

        // 3. METADATA
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (item.type == MediaType.anime && item.episode != null) ...[
              Text(
                'NUEVO EPISODIO ${item.episode}', 
                style: TextStyle(
                  color: const Color(0xFFEF7A1E), 
                  fontSize: ResponsiveUtils.sp(context, isIntermediate ? 11 : 13), 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 0.5
                )
              ),
              const SizedBox(width: 12),
              Container(width: 1.2, height: 12, color: Colors.white30),
              const SizedBox(width: 12),
            ],
            
            if (item.rating != null && item.rating! > 0) ...[
              Icon(Icons.star_rounded, color: const Color(0xFFEF7A1E), size: isIntermediate ? 14 : 18),
              const SizedBox(width: 4),
              Text(
                item.rating!.toStringAsFixed(1), 
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: ResponsiveUtils.sp(context, isIntermediate ? 12 : 14), 
                  fontWeight: FontWeight.w900
                )
              ),
              const SizedBox(width: 12),
              Container(width: 1.2, height: 12, color: Colors.white30),
              const SizedBox(width: 12),
            ],

            if (item.certification != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(2)),
                child: Text(
                  item.certification!, 
                  style: TextStyle(color: Colors.white70, fontSize: ResponsiveUtils.sp(context, 9), fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1.2, height: 12, color: Colors.white30),
              const SizedBox(width: 12),
            ],

            if (item.genres.isNotEmpty) ...[
              Flexible(
                child: Text(
                  item.genres.join('  •  '), 
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6), 
                    fontSize: ResponsiveUtils.sp(context, isIntermediate ? 11 : 13), 
                    fontWeight: FontWeight.w600
                  )
                ),
              ),
            ],
          ],
        ),
        
        SizedBox(height: isIntermediate ? 16 : 20),

        // 4. SINOPSIS
        SizedBox(
          width: screenWidth * (isIntermediate ? 0.55 : 0.44),
          child: Text(
            item.synopsis ?? '', 
            maxLines: isIntermediate ? 2 : 3, 
            overflow: TextOverflow.ellipsis, 
            style: TextStyle(
              color: Colors.white, 
              fontSize: ResponsiveUtils.heroSynopsisFontSize(context), 
              height: 1.4, 
              fontWeight: FontWeight.w400
            )
          ),
        ),
        SizedBox(height: isIntermediate ? 18 : 32),
        
        // 5. ACCIONES
        Row(
          children: [
            _BannerButton(
              onPressed: () => SafeTap.run(() => widget.onPlay(item)), 
              icon: Icons.play_arrow, 
              label: 'Reproducir', 
              isPrimary: true,
              isCompact: isIntermediate,
            ),
            const SizedBox(width: 12),
            _BannerIconButton(
              icon: Icons.add, 
              label: 'Mi lista', 
              onPressed: () {},
              isCompact: isIntermediate,
            ),
            const SizedBox(width: 12),
            _BannerIconButton(
              icon: Icons.info_outline, 
              label: 'Detalles', 
              onPressed: () => SafeTap.run(() => widget.onDetails(item)),
              isCompact: isIntermediate,
            ),
            if (item.trailerKey != null) ...[
              const SizedBox(width: 12),
              _BannerIconButton(
                icon: (kIsWeb && _showTrailerLayer) ? Icons.videocam_off_outlined : Icons.movie_outlined,
                label: 'Tráiler',
                isLoading: _isTrailerLoading,
                isCompact: isIntermediate,
                onPressed: () async {
                  if (_isTrailerLoading) return;
                  if (kIsWeb && _showTrailerLayer) {
                    _stopCycle();
                    return;
                  }
                  
                  if (kIsWeb) {
                    _initController();
                  } else {
                    setState(() => _isTrailerLoading = true);
                    try {
                      final result = widget.onTrailer?.call(item);
                      if (result is Future) await result;
                    } finally {
                      if (mounted) setState(() => _isTrailerLoading = false);
                    }
                  }
                },
              ),
            ],
            if (_showTrailerLayer && _videoReady) ...[
              const SizedBox(width: 12),
              Consumer(builder: (context, ref, _) {
                final isMuted = ref.watch(heroBannerMutedProvider);
                return _BannerIconButton(
                  icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  label: isMuted ? 'Activar audio' : 'Silenciar',
                  isCompact: isIntermediate,
                  onPressed: () => ref.read(heroBannerMutedProvider.notifier).state = !isMuted,
                );
              }),
            ],
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildNavArrows() {
    return Stack(
      children: [
        Positioned(left: 10, top: 0, bottom: 0, child: AnimatedOpacity(opacity: _isHovered ? 1.0 : 0.0, duration: const Duration(milliseconds: 300), child: NavArrow(icon: Icons.arrow_back_ios_new, useBackground: false, onTap: _previousPage))),
        Positioned(right: 10, top: 0, bottom: 0, child: AnimatedOpacity(opacity: _isHovered ? 1.0 : 0.0, duration: const Duration(milliseconds: 300), child: NavArrow(icon: Icons.arrow_forward_ios, useBackground: false, onTap: _nextPage))),
      ],
    );
  }

  Widget _buildDotsIndicator(double bottom) {
    return Positioned(
      bottom: bottom, left: 0, right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.items.length, (index) {
          final isCurrent = (_backgroundIndex % widget.items.length) == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isCurrent ? 12 : 7, height: 7,
            decoration: BoxDecoration(color: isCurrent ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(4)),
          );
        }),
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isCompact;
  const _BannerButton({
    required this.onPressed, 
    required this.icon, 
    required this.label, 
    this.isPrimary = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double height = isCompact ? 44 : 54;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isCompact ? 24 : 32, color: isPrimary ? Colors.black : Colors.white),
      label: Text(
        label, 
        style: TextStyle(
          fontWeight: FontWeight.w800, 
          fontSize: isCompact ? 16 : 20,
          letterSpacing: -0.5,
        )
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.1),
        foregroundColor: isPrimary ? Colors.black : Colors.white,
        elevation: 0,
        fixedSize: Size.fromHeight(height), 
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20 : 28, 
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height)),
      ),
    );
  }
}

class _BannerIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isCompact;
  final bool isLoading;
  const _BannerIconButton({
    required this.icon, 
    required this.label, 
    required this.onPressed,
    this.isCompact = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final double size = isCompact ? 44 : 54;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            child: isLoading 
              ? SizedBox(
                  width: isCompact ? 20 : 24, 
                  height: isCompact ? 20 : 24, 
                  child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white)
                )
              : Icon(icon, size: isCompact ? 22 : 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
