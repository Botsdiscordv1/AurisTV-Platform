import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../../core/utils/responsive_utils.dart';
import '../../../core/router/app_router.dart';
import 'package:auris_core/auris_core.dart';
import '../../../shared/widgets/nav_arrow.dart';
import '../presentation/providers/home_provider.dart';

class HeroBanner extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onPlay;
  final void Function(MediaItem item) onDetails;
  final bool autofocus;
  final String currentCategory;

  const HeroBanner({
    super.key,
    required this.items,
    required this.onPlay,
    required this.onDetails,
    this.autofocus = false,
    this.currentCategory = 'inicio',
  });

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> with RouteAware, WidgetsBindingObserver {
  int _backgroundIndex = 0;
  int _contentIndex = 0;
  double _overlayOpacity = 0.65;
  bool _isHovered = false;
  Timer? _autoPlayTimer;
  bool _isFocused = false;
  bool _showTrailerLayer = false;
  bool _videoReady = false;
  bool _isAppActive = true;


  // Player state
  YoutubePlayerController? _ytController;
  StreamSubscription? _ytSubscription;
  Timer? _fadeTimer;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoPlay();
    // Senior Fix: Usamos addPostFrameCallback para evitar el error de MediaQuery
    // antes de que el initState termine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startCycle(delay: const Duration(milliseconds: 800));
      }
    });
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant HeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isEmpty) return;
    
    final oldItem = oldWidget.items.isNotEmpty ? oldWidget.items[_backgroundIndex % oldWidget.items.length] : null;
    final newItem = widget.items[_backgroundIndex % widget.items.length];
    
    if (oldItem?.trailerKey != newItem.trailerKey) {
      _startCycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _stopAutoPlay();
    _stopCycle();
    super.dispose();
  }

  @override
  void didPushNext() {
    // Senior Nuke: Destruir el controlador inmediatamente al navegar a cualquier otra pantalla
    debugPrint('[HeroBanner] Destruyendo trailer por navegación...');
    _stopCycle();
    _disposeController();
    setState(() {
      _showTrailerLayer = false;
      _videoReady = false;
    });
  }

  @override
  void didPopNext() {
    // Re-iniciar solo si regresamos
    _startAutoPlay();
    _startCycle(delay: const Duration(seconds: 3));
  }

  MediaItem get _currentBackgroundItem {
    if (widget.items.isEmpty) return const MediaItem(id: '', title: '', posterUrl: '', type: MediaType.anime);
    return widget.items[_backgroundIndex % widget.items.length];
  }

  MediaItem get _currentContentItem {
    if (widget.items.isEmpty) return const MediaItem(id: '', title: '', posterUrl: '', type: MediaType.anime);
    return widget.items[_contentIndex % widget.items.length];
  }

  void _nextPage() {
    final nextIdx = (_backgroundIndex + 1) % widget.items.length;
    _runCinematicSequence(nextIdx);
  }

  void _previousPage() {
    final prevIdx = (_backgroundIndex - 1 + widget.items.length) % widget.items.length;
    _runCinematicSequence(prevIdx);
  }

  void _runCinematicSequence(int nextIndex) {
    if (widget.items.isEmpty || !_isAppActive) return;

    // Senior Flow: Eliminamos el parpadeo de opacidad (oscurecimiento)
    // El cambio ahora es un flujo continuo de imagen y texto.
    setState(() {
      _contentIndex = -1; // Desvanecemos el texto primero
    });

    // Pequeño delay para que el texto salga antes de que la imagen cambie
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || !_isAppActive) return;
      setState(() {
        _backgroundIndex = nextIndex;
      });
      
      _delayTimer?.cancel();
      _fadeTimer?.cancel();
      _disposeController();
      setState(() {
        _showTrailerLayer = false;
        _videoReady = false;
      });
    });

    // Entrada del nuevo texto con la nueva imagen ya en proceso de fundido
    Future.delayed(const Duration(milliseconds: 550), () {
      if (!mounted || !_isAppActive) return;
      setState(() {
        _contentIndex = nextIndex;
      });
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || !_isAppActive) return;
      _startCycle(delay: const Duration(seconds: 1));
    });
  }

  void _startCycle({Duration delay = const Duration(seconds: 2)}) {
    if (!_isAppActive) return;
    
    setState(() {
      _showTrailerLayer = false;
      _videoReady = false;
    });

    // Senior Mobile Shield: Bloqueo TOTAL de trailers en móvil
    // Google bloquea iframes en móviles vía 152-4 y consume demasiada CPU.
    final isMobile = ResponsiveUtils.isMobile(context);
    if (isMobile) {
      _disposeController();
      return;
    }

    // Senior Autoplay Policy: Solo en categorías específicas para escritorio
    final cat = widget.currentCategory.toLowerCase();
    final bool allowAutoplay = cat == 'animes' || cat == 'películas' || cat == 'series';
    
    if (!allowAutoplay) {
      _disposeController();
      return;
    }
    
    final key = _currentBackgroundItem.trailerKey;
    if (key != null && key.isNotEmpty) {
      _delayTimer?.cancel();
      _delayTimer = Timer(delay, () {
        if (mounted && _isAppActive) _initController();
      });
    } else {
      _disposeController();
    }
  }

  void _stopCycle() {
    _delayTimer?.cancel();
    _disposeController();
    setState(() {
      _showTrailerLayer = false;
      _videoReady = false;
    });
  }

  void _initController() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) return;
    final key = _currentBackgroundItem.trailerKey;
    if (key == null || key.isEmpty) return;

    _disposeController();

    final ctrl = YoutubePlayerController(
      params: YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: ref.read(heroBannerMutedProvider),
        loop: false,
        showVideoAnnotations: false,
        playsInline: true,
        strictRelatedVideos: true,
        enableKeyboard: false,
        // Senior Fix Final: Definir el origen como el dominio de YouTube y usar un UserAgent
        // de navegador móvil para evitar el bloqueo 152-4 por parte de Google.
        origin: 'https://www.youtube.com',
        userAgent: 'Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0',
      ),
    );

    // Cargamos el video por ID de forma limpia
    ctrl.loadVideoById(videoId: key);

    ctrl.listen((state) {
      // Intentamos reproducir siempre que esté listo
      if (state.playerState == PlayerState.cued && mounted) {
        ctrl.playVideo();
      }
      
      // Si el video está reproduciéndose, lo preparamos para mostrarlo
      if (state.playerState == PlayerState.playing && mounted && !_videoReady) {
        // Un pequeño delay para saltar el frame inicial/logo
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() => _videoReady = true);
          }
        });
      }

      if (state.playerState == PlayerState.ended && mounted) {
        setState(() {
          _showTrailerLayer = false;
          _videoReady = false;
        });
      }
    });

    _ytSubscription = ctrl.videoStateStream.listen((state) {
      final duration = ctrl.value.metaData.duration.inSeconds;
      final position = state.position.inSeconds;
      
      // Si detectamos progreso real, el video DEFINITIVAMENTE está listo
      if (position > 0.5 && !_videoReady && mounted) {
        setState(() => _videoReady = true);
      }

      if (position > 5 && duration > 30 && (duration - position) < 12) {
        if (_showTrailerLayer && mounted) {
          setState(() {
            _showTrailerLayer = false;
            _videoReady = false;
          });
          _fadeOutAudio(ctrl);
        }
      }
    });

    if (mounted) {
      setState(() {
        _ytController = ctrl;
        _showTrailerLayer = true; 
      });
      
      // Refuerzo de reproducción para navegadores
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          ctrl.playVideo();
          // Fallback final: si en 3 segundos no ha cargado pero el usuario está activo, mostramos igual
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && !_videoReady && _showTrailerLayer && _isAppActive) {
              setState(() => _videoReady = true);
            }
          });
        }
      });
    }
  }

  void _fadeOutAudio(YoutubePlayerController ctrl) {
    if (ref.read(heroBannerMutedProvider)) return;
    _fadeTimer?.cancel();
    int volume = 100;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      volume -= 10;
      if (volume <= 0) {
        ctrl.mute();
        timer.cancel();
      } else {
        ctrl.setVolume(volume);
      }
    });
  }

  void _disposeController() {
    _fadeTimer?.cancel();
    _ytSubscription?.cancel();
    _ytSubscription = null;
    _ytController?.close();
    _ytController = null;
  }

  void _syncMute(bool isMuted) {
    if (_ytController != null) {
      if (isMuted) _ytController!.mute();
      else { _ytController!.unMute(); _ytController!.setVolume(100); }
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!_isHovered && !_showTrailerLayer && mounted) {
        _nextPage();
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  Widget _buildTextTransition(Widget child, Animation<double> animation) {
    // Definimos el movimiento de +12px (hacia abajo) a 0.
    // Usamos un valor relativo pequeño (0.05) que en un contenedor de ~240px son ~12px.
    final offsetAnimation = animation.drive(
      Tween<Offset>(
        begin: const Offset(0.0, 0.05), 
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: offsetAnimation,
        child: child,
      ),
    );
  }

  Widget _buildBackgroundTransition(Widget child, Animation<double> animation) {
    // Senior UI Architecture: Técnica de "Capa Sólida".
    // El widget que entra (child) se desvanece.
    // El widget que sale (oldChild) se mantiene estático debajo para evitar el parpadeo gris.
    final bool isIncoming = child.key is ValueKey && 
        (child.key as ValueKey).value.toString().startsWith('bg_');

    if (isIncoming) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    } else {
      // El widget saliente se mantiene sólido y estático para servir de base
      return child;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);

    // Senior: Synchronize player mute state with global provider
    ref.listen(heroBannerMutedProvider, (_, next) => _syncMute(next));

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (focused) {
          setState(() {
            _isFocused = focused;
            if (focused) _stopAutoPlay();
            else _startAutoPlay();
          });
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final isBannerPrimary = node.hasPrimaryFocus;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && isBannerPrimary) {
              _previousPage();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight && isBannerPrimary) {
              _nextPage();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: isMobile 
              ? EdgeInsets.zero 
              : EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 48), // Senior: Alineado con carruseles
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                _previousPage();
              } else if (details.primaryVelocity! < 0) {
                _nextPage();
              }
            },
            onTap: () => widget.onDetails(_currentContentItem),
            child: Container(
              color: isMobile ? null : const Color(0xFF0B0B0D), // Senior: Fondo sólido tras la transparencia del borde
              foregroundDecoration: isMobile ? null : BoxDecoration(
                borderRadius: BorderRadius.circular(24), 
                border: Border.all(
                  color: Colors.white.withOpacity(0.15), 
                  width: 2.0, 
                ),
              ),
              child: Padding(
                padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(2.0), // Senior: Evita que la imagen sangre tras el grosor
                child: ClipRRect(
                  borderRadius: isMobile 
                    ? BorderRadius.zero 
                    : BorderRadius.circular(22), // Radio ajustado al grosor (24 - 2)
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: AspectRatio(
                    aspectRatio: isMobile ? 16 / 11 : 2.8 / 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;
                        final playerHeight = height * 1.35;
                        final playerWidth = playerHeight * (16 / 9);
                        final bgItem = _currentBackgroundItem;
                        final contentItem = _currentContentItem;
                        // Senior: Ajustado a un padding interno moderado
                        final internalPadding = isMobile ? horizontalPadding : 80.0;

                        return Stack(
                          children: [
                            // CAPA 1: Background con Sangrado Total
                            Positioned(
                              top: 0, left: 0, right: 0, bottom: 0, // Senior Fix: Ajustado a 0 para evitar fugas bajo el borde
                              child: Container(
                                color: const Color(0xFF0B0B0D), 
                                child: AnimatedOpacity(
                                  // Senior: Ocultamos el banner por completo cuando el trailer está listo
                                  opacity: (_showTrailerLayer && _videoReady) ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 800),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 800),
                                    transitionBuilder: _buildBackgroundTransition,
                                    layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: <Widget>[
                                          ...previousChildren,
                                          if (currentChild != null) currentChild,
                                        ],
                                      );
                                    },
                                    child: _BannerContent(
                                      key: ValueKey('bg_${bgItem.id}'),
                                      item: bgItem,
                                      showTrailer: _showTrailerLayer && _videoReady,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // CAPA 2: Trailer overlay
                            if (_ytController != null && _showTrailerLayer)
                              Positioned(
                                top: 0, bottom: 0, right: 0, // Senior Fix: Alineado al fondo para consistencia con el fondo
                                width: isMobile ? width : width * 0.72,
                                child: AnimatedOpacity(
                                  opacity: (_showTrailerLayer && _videoReady) ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 600),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      IgnorePointer(
                                        ignoring: true,
                                        child: ClipRect(
                                          child: OverflowBox(
                                            alignment: Alignment.center,
                                            minWidth: isMobile ? playerWidth : width * 0.72,
                                            maxWidth: isMobile ? playerWidth : width * 0.72,
                                            minHeight: playerHeight,
                                            maxHeight: playerHeight,
                                            child: YoutubePlayer(
                                              key: ValueKey('yt_${bgItem.trailerKey}'),
                                              controller: _ytController!,
                                              aspectRatio: 16 / 9,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // CAPA 3: UI overlay (gradientes + texto con coreografía)
                            PointerInterceptor(
                              intercepting: _showTrailerLayer && _videoReady,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildGradients(isMobile),
                                  
                                  // Senior Fix: El sello hermético ahora va DETRÁS del texto
                                  _buildHermeticSeal(isMobile),

                                  // Posicionamiento adaptativo
                                  Positioned(
                                    left: internalPadding,
                                    bottom: isMobile ? 25 : 45, // Senior: Bajado de 80 a 45 para mejor peso visual
                                    right: internalPadding,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 600),
                                      transitionBuilder: _buildTextTransition,
                                      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                        return Stack(
                                          alignment: Alignment.bottomLeft, 
                                          children: [
                                            ...previousChildren,
                                            if (currentChild != null) currentChild,
                                          ],
                                        );
                                      },
                                      child: _contentIndex == -1 
                                        ? SizedBox(key: const ValueKey('empty'), width: width - (internalPadding * 2)) 
                                        : _buildContentOverlay(_currentContentItem, isMobile, width - (internalPadding * 2), key: ValueKey('content_${_currentContentItem.id}')),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // CAPA 4: Flechas de navegación (Ocultas en móvil)
                            if (!isMobile) ...[
                              Positioned(
                                left: 10, top: 0, bottom: 0,
                                child: AnimatedOpacity(
                                  opacity: _isHovered ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: IgnorePointer(
                                    ignoring: !_isHovered,
                                    child: Center(
                                      child: NavArrow(
                                        icon: Icons.arrow_back_ios_new,
                                        useBackground: false,
                                        enableScale: true,
                                        onTap: _previousPage,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 10, top: 0, bottom: 0,
                                child: AnimatedOpacity(
                                  opacity: _isHovered ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: IgnorePointer(
                                    ignoring: !_isHovered,
                                    child: Center(
                                      child: NavArrow(
                                        icon: Icons.arrow_forward_ios,
                                        useBackground: false,
                                        enableScale: true,
                                        onTap: _nextPage,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // CAPA 5: Dots indicator
                            Positioned(
                              bottom: isMobile ? 15 : 25, 
                              left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.items.length,
                                  (index) {
                                    final isCurrent = (_backgroundIndex % widget.items.length) == index;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      width: isCurrent ? (isMobile ? 10 : 12) : (isMobile ? 5 : 7),
                                      height: isMobile ? 5 : 7,
                                      decoration: BoxDecoration(
                                        color: isCurrent ? Colors.white : Colors.white38,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradients(bool isMobile) {
    final bool showTrailer = !isMobile && _showTrailerLayer && _videoReady;
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Stack(
        key: ValueKey('${_overlayOpacity}_$showTrailer'),
        fit: StackFit.expand,
        children: [
          // 1. FUNDACIÓN DE LEGIBILIDAD (Side Scrim Potenciado estilo Netflix)
          // Senior Refinement: Gradiente más concentrado a la izquierda para no oscurecer el centro del arte
          if (!isMobile)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF0B0B0D).withOpacity(0.98), 
                    const Color(0xFF0B0B0D).withOpacity(0.7),
                    const Color(0xFF0B0B0D).withOpacity(0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.5, 0.65],
                ),
              ),
            ),

          // 2. MÁSCARA CINEMATOGRÁFICA (Fusión con el Trailer)
          if (showTrailer)
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

          // 3. PROTECCIÓN DE INTERFAZ (Top Scrim para legibilidad de TopBar)
          if (!isMobile)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0B0B0D).withOpacity(0.6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3], // Solo oscurecemos la parte superior
                ),
              ),
            ),

        ],
      ),
    );
}

  String _getMediaLabel(MediaType type) {
    switch (type) {
      case MediaType.anime:
        return 'ANIME';
      case MediaType.movie:
        return 'PELÍCULA';
      case MediaType.kdrama:
        return 'K-DRAMA';
      case MediaType.series:
        return 'SERIE';
      default:
        return 'SERIE';
    }
  }

  Widget _heroTitleWidget(MediaItem item, bool isMobile, double titleFontSize, double maxTitleWidth, {bool isLarge = false}) {
    final TextStyle textStyle = isMobile
        ? const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 4),
              Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 10),
            ],
          )
        : TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Colors.white,
            height: 0.95,
            shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 8)],
          );
    if (item.logoUrl != null && item.logoUrl!.isNotEmpty) {
      // Senior: Altura dinámica. Si no hay sinopsis larga, el logo crece de 140 a 200px
      final double h = isMobile 
          ? 80 
          : (titleFontSize * (isLarge ? 4.8 : 3.4)).clamp(0.0, isLarge ? 200.0 : 140.0);
      final double logoMaxWidth = isMobile ? maxTitleWidth : (maxTitleWidth * 0.8).clamp(400.0, 800.0);
      
      return Container(
        width: logoMaxWidth, // Senior Shield: Ancho determinista para el área del logo
        height: h,
        alignment: Alignment.bottomLeft,
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Capa de Sombra Dinámica (Drop Shadow)
            Align(
              alignment: Alignment.bottomLeft,
              child: Transform.translate(
                offset: const Offset(2, 2),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.7),
                      BlendMode.srcIn,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: item.logoUrl!,
                      height: h,
                      width: logoMaxWidth, // Senior Fix: Forzar ancho para que no colapse al centro
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                      alignment: Alignment.bottomLeft,
                      fadeInDuration: Duration.zero,
                    ),
                  ),
                ),
              ),
            ),
            // Logo Original
            Align(
              alignment: Alignment.bottomLeft,
              child: CachedNetworkImage(
                imageUrl: item.logoUrl!,
                height: h,
                width: logoMaxWidth, // Senior Fix: Consistencia total de ancho
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                alignment: Alignment.bottomLeft,
                fadeInDuration: const Duration(milliseconds: 300),
                placeholder: (context, url) => SizedBox(height: h, width: logoMaxWidth),
                errorWidget: (_, __, ___) => Text(item.title.toUpperCase(), style: textStyle),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: isMobile ? double.infinity : maxTitleWidth,
      child: Text(
        item.title.toUpperCase(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );
  }

  Widget _buildContentOverlay(MediaItem item, bool isMobile, double constraintsWidth, {Key? key}) {
    final width = constraintsWidth;
    final titleFontSize = isMobile ? 14.0 : (width < 1100 ? 38.0 : 54.0);
    final spacing = isMobile ? 8.0 : (width < 1100 ? 12.0 : 20.0);
    final maxTitleWidth = isMobile ? width * 0.85 : (width * 0.7).clamp(400.0, 900.0);

    // Senior UI Logic: Detectamos si la sinopsis es corta (1 línea) para priorizar el Logo
    bool isShortSynopsis = false;
    if (!isMobile && item.synopsis != null && item.synopsis!.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: item.synopsis,
          style: TextStyle(
            fontSize: width < 1100 ? 16 : 18,
            height: 1.4,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: maxTitleWidth * 0.9);
      
      // Si el texto no excede las líneas máximas y solo ocupa una métrica de línea, es "corta"
      isShortSynopsis = textPainter.computeLineMetrics().length <= 1;
    }

    return SizedBox(
      width: width,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _heroTitleWidget(item, isMobile, titleFontSize, maxTitleWidth, isLarge: isShortSynopsis),
          if (!isMobile) ...[
            const SizedBox(height: 16),
            _buildMetadataCapsules(item),
          ],
          SizedBox(height: spacing),
          if (isMobile) ...[
            // ... resto del código sin cambios
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    'RECOMENDADO',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${item.year ?? "2024"} • #1 en Tendencias',
                  style: const TextStyle(
                    color: Color(0xFFEF7A1E), 
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else ...[
            if (item.synopsis != null && item.synopsis!.isNotEmpty && !isShortSynopsis) ...[
              SizedBox(
                width: maxTitleWidth * 0.9,
                child: Text(
                  item.synopsis!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width < 1100 ? 16 : 18,
                    height: 1.4,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _BannerButton(
                  onPressed: () => widget.onPlay(item),
                  icon: Icons.play_arrow, // Senior: Icono más afilado y preciso
                  label: 'Reproducir',
                  isPrimary: true,
                  compact: width < 1100,
                ),
                _BannerIconButton(
                  icon: Icons.add,
                  label: 'Mi lista',
                  onPressed: () {},
                  compact: width < 1100,
                ),
                _BannerIconButton(
                  icon: Icons.info_outline,
                  label: 'Detalles',
                  onPressed: () => widget.onDetails(item),
                  compact: width < 1100,
                ),
                if (item.trailerKey != null && item.trailerKey!.isNotEmpty)
                  _BannerIconButton(
                    icon: _showTrailerLayer ? Icons.videocam_off_outlined : Icons.movie_outlined,
                    label: _showTrailerLayer ? 'Quitar tráiler' : 'Ver tráiler',
                    isLoading: _showTrailerLayer && !_videoReady,
                    onPressed: () {
                      if (_showTrailerLayer) {
                        _stopCycle();
                      } else {
                        _initController();
                      }
                    },
                    compact: width < 1100,
                  ),
                AnimatedOpacity(
                  opacity: (_showTrailerLayer && _videoReady) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final isMuted = ref.watch(heroBannerMutedProvider);
                      return IgnorePointer(
                        ignoring: !(_showTrailerLayer && _videoReady),
                        child: _BannerIconButton(
                          icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          label: isMuted ? 'Activar audio' : 'Silenciar',
                          onPressed: () => ref.read(heroBannerMutedProvider.notifier).state = !isMuted,
                          compact: width < 1100,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '•',
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildMetadataCapsules(MediaItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Identidad y Categoría
        SvgPicture.asset(
          'assets/icons/auris-tv-icon.svg',
          height: 16,
          colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn),
        ),
        const SizedBox(width: 8),
        Text(
          _getMediaLabel(item.type),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        if (item.rating != null || item.year != null) ...[
          _buildMetadataSeparator(),
          if (item.rating != null) ...[
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Text(
              formatRating(item.rating) ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (item.year != null) ...[
            _buildMetadataSeparator(),
            Text(
              '${item.year}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildHermeticSeal(bool isMobile) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF0B0B0D).withOpacity(isMobile ? 0.95 : 1.0), 
            const Color(0xFF0B0B0D).withOpacity(0.4),
            const Color(0xFF0B0B0D).withOpacity(0.0),
          ],
          stops: const [0.0, 0.2, 0.5], // Bajado el alcance para no tapar los rostros
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final MediaItem item;
  final bool showTrailer;

  const _BannerContent({super.key, required this.item, required this.showTrailer});

  @override
  Widget build(BuildContext context) {
    return _buildBackdrop();
  }

  Widget _buildBackdrop() {
    final hasBanner = item.bannerUrl != null && item.bannerUrl!.isNotEmpty;
    final double overlayOpacity = showTrailer ? 0.45 : 0.0;

    if (hasBanner) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        foregroundDecoration: BoxDecoration(
          color: Colors.black.withOpacity(overlayOpacity),
        ),
        child: CachedNetworkImage(
          imageUrl: item.bannerUrl!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          alignment: Alignment.topCenter,
          placeholder: (context, url) => Container(color: Colors.black12),
          errorWidget: (context, url, error) => Container(color: Colors.black),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: item.posterUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          alignment: Alignment.topCenter,
          placeholder: (context, url) => Container(color: Colors.white10),
          errorWidget: (context, url, error) => Container(color: Colors.black26),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          color: Colors.black.withOpacity(showTrailer ? 0.75 : 0.55),
        ),
      ],
    );
  }
}

class _MuteButton extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onTap;

  const _MuteButton({required this.isMuted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black45,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(
          isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _BannerButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool compact;

  const _BannerButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.compact = false,
  });

  @override
  State<_BannerButton> createState() => _BannerButtonState();
}

class _BannerButtonState extends State<_BannerButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = _focused || _hovered;
    final Color bgColor = widget.isPrimary 
        ? (isSelected ? Colors.white.withOpacity(0.85) : Colors.white)
        : (isSelected ? Colors.grey.withOpacity(0.5) : const Color(0xFF6D6D6EB3));
    final Color fgColor = widget.isPrimary ? Colors.black : Colors.white;

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.compact ? 44 : 56, // Senior: Unificado a 56px para alinear con botones circulares
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30), 
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(30), 
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.compact ? 20 : 28), // Senior: Más aire lateral
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon, 
                      color: fgColor, 
                      size: widget.compact ? 24 : 34 // Senior: Proporción perfecta
                    ),
                    const SizedBox(width: 6), // Senior: Espaciado más ajustado al icono
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: widget.compact ? 16 : 19, // Senior: Ligeramente más grande
                        fontWeight: FontWeight.w800, // Senior: Más peso visual
                        letterSpacing: 0.2,
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

class _BannerIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String label;
  final bool compact;
  final bool isLoading;

  const _BannerIconButton({
    required this.icon, 
    required this.onPressed,
    required this.label,
    this.compact = false,
    this.isLoading = false,
  });

  @override
  State<_BannerIconButton> createState() => _BannerIconButtonState();
}

class _BannerIconButtonState extends State<_BannerIconButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = _focused || _hovered;
    final size = widget.compact ? 44.0 : 56.0;
    
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
        child: Tooltip(
          message: widget.label,
          preferBelow: false,
          verticalOffset: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          child: AnimatedScale(
            scale: _hovered ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white10,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24, 
                  width: isSelected ? 2 : 1
                ),
                boxShadow: _focused ? [
                  BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 12, spreadRadius: 1)
                ] : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onPressed,
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: widget.isLoading 
                      ? SizedBox(
                          width: widget.compact ? 16 : 20,
                          height: widget.compact ? 16 : 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        )
                      : Icon(
                          widget.icon, 
                          color: isSelected ? Colors.black : Colors.white, 
                          size: widget.compact ? 22 : 28
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
