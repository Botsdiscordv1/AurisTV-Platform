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

enum HeroBannerLayout { mobile, cinematic }

class HeroBanner extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onPlay;
  final void Function(MediaItem item) onDetails;
  final dynamic Function(MediaItem item)? onTrailer;
  final bool autofocus;
  final String currentCategory;
  final VoidCallback? onFocused; // Callback para notificar enfoque al padre

  const HeroBanner({
    super.key,
    required this.items,
    required this.onPlay,
    required this.onDetails,
    this.onTrailer,
    this.autofocus = false,
    this.currentCategory = 'inicio',
    this.onFocused,
    dynamic layout,
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

  bool _isFocused = false; 

  final FocusNode _playButtonFocusNode = FocusNode(); 

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

  void _precacheNextImage() {
    if (widget.items.length < 2) return;
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
    _playButtonFocusNode.dispose();
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
        if (mounted) setState(() => _contentIndex = nextIndex);

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
      if (!_isHovered && !_showTrailerLayer && mounted) _nextPage();
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
            _startCycle(delay: const Duration(seconds: 1));
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

              // Si el contenedor capturó el foco primario, lo delegamos al botón de reproducir
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _isFocused && !_playButtonFocusNode.hasFocus) {
                  _playButtonFocusNode.requestFocus();
                }
              });
            } else {
              _startAutoPlay();
              if (mounted) setState(() => _isFocused = false);
            }
          },
          onKeyEvent: (node, event) {
            return KeyEventResult.ignored; // Desactivado cambio manual para no interferir con botones
          },
          child: GestureDetector(
            onTap: () {
              final item = _currentContentItem;
              if (item != null) widget.onDetails(item);
            },
            child: AspectRatio(
              aspectRatio: TVResponsiveUtils.heroAspectRatio(context),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12), // Usamos el nuevo padding base alineado
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0D),
          borderRadius: BorderRadius.circular(24),
          // Senior Fix: Borde estático original solo cuando tiene el foco
          border: _isFocused 
              ? Border.all(color: Colors.white.withOpacity(0.15), width: 2.0)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              _buildBackgroundLayer(bgItem),
              // Trailer
              if (_ytController != null && _showTrailerLayer)
                _buildTrailerLayer(screenWidth),
              if (_nativeVideoController != null && _showTrailerLayer)
                _buildTrailerLayer(screenWidth),
              
              // Gradient Scrim
              _buildCinematicGradients(),

              // Content Overlay
              Positioned(
                left: 0, bottom: 0, top: 0,
                child: Container(
                  width: screenWidth * 0.6,
                  padding: const EdgeInsets.only(left: 20, bottom: 10), // Reducido de 20 a 10 para bajar la cabecera
                  alignment: Alignment.bottomLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
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
              _buildDotsIndicator(15),
            ],
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
          fit: StackFit.expand,
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
        filterQuality: FilterQuality.high,
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

        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: showTrailer ? 0.0 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black.withOpacity(0.15)),
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

        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: showTrailer ? 1.0 : 0.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
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

  Widget _buildCinematicContent(MediaItem item, double screenWidth) {
    final titleFontSize = TVResponsiveUtils.heroTitleFontSize(context);
    
    return Column(
      key: ValueKey('content_col_tv_${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Icono + Categoría (Label superior)
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/auris-tv-icon.svg', 
              height: 18, 
              colorFilter: const ColorFilter.mode(Color(0xFFEF7A1E), BlendMode.srcIn)
            ),
            const SizedBox(width: 8),
            Text(
              item.type.name.toUpperCase(), 
              style: TextStyle(
                color: Colors.white, 
                fontSize: TVResponsiveUtils.sp(context, 9), 
                fontWeight: FontWeight.w900, 
                letterSpacing: 2.0
              )
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Logo / Título
        if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
          CachedNetworkImage(
            key: ValueKey('logo_tv_${item.id}'),
            imageUrl: item.logoUrl!, 
            height: TVResponsiveUtils.heroLogoHeight(context),
            fit: BoxFit.contain, 
            alignment: Alignment.bottomLeft,
            fadeInDuration: const Duration(milliseconds: 100),
          )
        else
          Text(
            item.title.toUpperCase(), 
            style: TextStyle(
              fontSize: titleFontSize, 
              fontWeight: FontWeight.w900, 
              color: Colors.white, 
              height: 0.9,
              letterSpacing: -1,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(0, 4), blurRadius: 10)
              ]
            )
          ),
        
        const SizedBox(height: 12),

        // 3. Metadata (Episodio, Rating, Géneros)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (item.type == MediaType.anime && item.episode != null) ...[
              Text(
                'NUEVO EPISODIO ${item.episode}', 
                style: const TextStyle(
                  color: Color(0xFFEF7A1E), 
                  fontSize: 12, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 0.5
                )
              ),
              const SizedBox(width: 12),
              Container(width: 1.2, height: 12, color: Colors.white30),
              const SizedBox(width: 12),
            ],
            
            if (item.rating != null && item.rating! > 0) ...[
              const Icon(Icons.star_rounded, color: Color(0xFFEF7A1E), size: 16),
              const SizedBox(width: 4),
              Text(
                item.rating!.toStringAsFixed(1), 
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w900
                )
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
                    fontSize: 12, 
                    fontWeight: FontWeight.w600
                  )
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1.2, height: 12, color: Colors.white30),
              const SizedBox(width: 12),
            ],

            if (item.certification != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38), 
                  borderRadius: BorderRadius.circular(2)
                ),
                child: Text(
                  item.certification!, 
                  style: const TextStyle(
                    color: Colors.white70, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
            ],
          ],
        ),

        // BLOQUE DINÁMICO (Sinopsis y Botones)
        // Senior Fix: Usamos AnimatedSwitcher con SizeTransition para el efecto de "empuje" hacia arriba
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutQuart,
          switchOutCurve: Curves.easeInQuart,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1.0, // Hace que crezca hacia arriba desde la base
                child: child,
              ),
            );
          },
          child: _isFocused 
            ? Column(
                key: const ValueKey('expanded_hero_content'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  // 4. Sinopsis
                  SizedBox(
                    width: screenWidth * 0.44,
                    child: Text(
                      item.synopsis ?? '', 
                      maxLines: 3, 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: TVResponsiveUtils.heroSynopsisFontSize(context), 
                        height: 1.4, 
                        fontWeight: FontWeight.w400
                      )
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 5. Botones de Acción
                  Row(
                    children: [
                      _BannerButton(
                        focusNode: _playButtonFocusNode, // Asignamos el nodo para la captura de foco
                        onPressed: () => widget.onPlay(item), 
                        icon: Icons.play_arrow, 
                        label: 'Reproducir', 
                        isPrimary: true,
                        autofocus: widget.autofocus, // Senior Fix: Autofocus inicial para TV
                      ),
                      const SizedBox(width: 12),
                      _BannerIconButton(icon: Icons.add, label: 'Mi lista', onPressed: () {}),
                      const SizedBox(width: 12),
                      _BannerIconButton(icon: Icons.info_outline, label: 'Detalles', onPressed: () => widget.onDetails(item)),
                      if (item.trailerKey != null) ...[
                        const SizedBox(width: 12),
                        _BannerIconButton(
                          icon: (kIsWeb && _showTrailerLayer) ? Icons.videocam_off_outlined : Icons.movie_outlined,
                          label: 'Tráiler',
                          isLoading: _isTrailerLoading,
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
                            onPressed: () => ref.read(heroBannerMutedProvider.notifier).state = !isMuted,
                          );
                        }),
                      ],
                    ],
                  ),
                ],
              )
            : const SizedBox(key: ValueKey('collapsed_hero_content')),
        ),
      ],
    );
  }

  Widget _buildNavArrows() {
    return const SizedBox.shrink(); // Desactivadas flechas en TV para evitar trampas de foco
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
  final bool autofocus;
  final FocusNode? focusNode; // Añadido soporte para FocusNode
  const _BannerButton({
    required this.onPressed, 
    required this.icon, 
    required this.label, 
    this.isPrimary = false,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      autofocus: autofocus,
      focusNode: focusNode, // Vinculamos el nodo
      icon: Icon(icon, size: 20), // Reducido de 24
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), // Reducido de 15
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? Colors.white : Colors.white10,
        foregroundColor: isPrimary ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), // Reducido de 20x12
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

class _BannerIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  const _BannerIconButton({
    required this.icon, 
    required this.label, 
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton.filledTonal(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading 
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Icon(icon, size: 18), // Reducido de 22
        style: IconButton.styleFrom(
          backgroundColor: Colors.white10, 
          foregroundColor: Colors.white, 
          padding: const EdgeInsets.all(7) // Reducido de 10
        ),
      ),
    );
  }
}
