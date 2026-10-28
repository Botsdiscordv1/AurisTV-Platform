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

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/utils/youtube_resolver.dart';

import '../../auris_core.dart';
import 'nav_arrow.dart';

final activeHeroIndexProvider = StateProvider.family<int, String>((ref, category) => 0);

enum HeroBannerLayout { mobile, cinematic }

class HeroBanner extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item)? onPlay;
  final void Function(MediaItem item) onDetails;
  final dynamic Function(MediaItem item)? onTrailer;
  final bool autofocus;
  final String currentCategory;
  final HeroBannerLayout? layout;

  const HeroBanner({
    super.key,
    required this.items,
    this.onPlay,
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
  bool _wasEverVisible = false;
  int _lastRenderedBgIndex = -1;

  final FocusNode _playButtonFocusNode = FocusNode(); 
  final FocusNode _favButtonFocusNode = FocusNode();
  final FocusNode _trailerButtonFocusNode = FocusNode();
  final FocusNode _muteButtonFocusNode = FocusNode();
  final FocusNode _prevButtonFocusNode = FocusNode();
  final FocusNode _nextButtonFocusNode = FocusNode();

  yt.YoutubePlayerController? _ytController;
  StreamSubscription? _ytSubscription;

  Player? _nativePlayer;
  VideoController? _nativeVideoController;
  StreamSubscription? _nativeSubscription;
  StreamSubscription? _nativePositionSubscription;

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
        ref.read(activeHeroIndexProvider(widget.currentCategory).notifier).state = 0;
        _startCycle(delay: const Duration(milliseconds: 800));
        _precacheNextImage();
      }
    });
  }

  void _handlePlay(MediaItem item) {
    if (widget.onPlay != null) {
      widget.onPlay!(item);
    } else {
      _handleDetails(item);
    }
  }

  void _handleDetails(MediaItem item) {
    if (item.source == 'ppv' || item.source == 'sport' || item.source == 'live' || (item.channels != null && item.channels!.isNotEmpty)) {
      debugPrint('[HeroBanner] Intercepted sports item -> Opening ContentSportScreen for: "${item.title}"');
      final sportsEvent = ContentSports(
        id: item.id,
        title: item.title,
        posterUrl: item.posterUrl,
        bannerUrl: item.bannerUrl ?? item.posterUrl,
        channels: item.channels ?? [],
        source: item.source.isNotEmpty ? item.source : 'ppv',
        league: item.subtitle,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ContentSportScreen(event: sportsEvent),
        ),
      );
      return;
    }
    widget.onDetails(item);
  }

  int _bgMemCacheWidth() {
    final mq = MediaQuery.of(context);
    return (mq.size.width * mq.devicePixelRatio).round().clamp(640, 1920);
  }

  void _precacheNextImage() {
    if (widget.items.length < 2) return;
    final nextIndex = (_backgroundIndex + 1) % widget.items.length;
    final nextItem = widget.items[nextIndex];

    final imageUrl = _heroBackgroundUrl(nextItem);
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

  String _heroBackgroundUrl(MediaItem item) {
    if (_resolvedLayout == HeroBannerLayout.mobile) {
      return item.posterUrl;
    } else {
      return item.bannerUrl ?? item.posterUrl;
    }
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
      if (mounted) {
        setState(() => _backgroundIndex = nextIndex);
        ref.read(activeHeroIndexProvider(widget.currentCategory).notifier).state = nextIndex % widget.items.length;
      }
      
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
          enableCaption: false,
          captionLanguage: '',
          userAgent: 'Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0',
        ),
      );
      ctrl.loadVideoById(videoId: key);
      ctrl.listen((state) {
        if (state.playerState == yt.PlayerState.cued && mounted) ctrl.playVideo();
        if (state.playerState == yt.PlayerState.playing && mounted) {
          try {
            ctrl.webViewController.runJavaScript("try { if(window.player){ window.player.unloadModule('captions'); window.player.unloadModule('cc'); } } catch(e){}");
          } catch (_) {}
          if (!_videoReady) {
            Future.delayed(const Duration(milliseconds: 400), () { 
              if (mounted) setState(() => _videoReady = true); 
            });
          }
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

      _nativePositionSubscription = player.stream.position.listen((pos) {
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
    _nativePositionSubscription?.cancel();
    _nativePositionSubscription = null;
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

  HeroBannerLayout get _resolvedLayout {
    if (context.useMobileLayout) {
      return widget.layout ?? HeroBannerLayout.mobile;
    }
    return widget.layout ?? HeroBannerLayout.cinematic;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final double screenWidth = MediaQuery.of(context).size.width;
    final HeroBannerLayout layout = _resolvedLayout;

    return VisibilityDetector(
      key: ValueKey('hero_visibility_${widget.currentCategory}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0.1;
        if (visible != _isVisible && mounted) {
          setState(() => _isVisible = visible);
          if (!_isVisible) {
            _stopAutoPlay();
            _stopCycle();
          } else if (_isAppActive) {
            _startAutoPlay();
            if (!_wasEverVisible) {
              _wasEverVisible = true;
              _startCycle(delay: const Duration(seconds: 1));
            }
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
                _previousPage();
              } else if (details.primaryVelocity! < 0) {
                _nextPage();
              }
            },
            onTap: () {
              final item = _currentContentItem;
              if (item != null) {
                SafeTap.run(() => _handleDetails(item));
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
        clipBehavior: Clip.none,
        children: [
          _buildBackgroundLayer(bgItem),
          _buildMobileGradients(), 
          Positioned(
            left: 16, right: 0, bottom: 35,
            child: contentItem != null 
                ? _buildMobileContent(contentItem)
                : const SizedBox.shrink(),
          ),
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
              clipBehavior: Clip.none,
              children: [
                _buildBackgroundLayer(bgItem),
                if (_ytController != null && _showTrailerLayer)
                  _buildTrailerLayer(screenWidth),
                if (_nativeVideoController != null && _showTrailerLayer)
                  _buildTrailerLayer(screenWidth),
                _buildCinematicGradients(),
                Positioned(
                  left: 40, bottom: 32, top: 0,
                  right: 20,
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
                _buildDotsIndicator(20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundLayer(MediaItem item) {
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
        key: ValueKey('bg_${item.id}_$_lastRenderedBgIndex'),
        imageUrl: _heroBackgroundUrl(item),
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
    const darkBg = Color(0xFF000000);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: darkBg.withOpacity(0.15)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [darkBg.withOpacity(0.5), Colors.transparent],
              stops: const [0.0, 0.3],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                darkBg,
                darkBg.withOpacity(0.95),
                darkBg.withOpacity(0.6),
                darkBg.withOpacity(0.2),
                Colors.transparent,
              ],
              stops: const [0.0, 0.2, 0.5, 0.75, 1.0],
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
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Colors.transparent],
              stops: [0.0, 0.22],
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: showTrailer ? 0.0 : 1.0,
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
                      Color(0xF2000000),
                      Color(0xB3000000),
                      Color(0x33000000),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.28, 0.48, 0.70, 0.95],
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

  Widget _buildMobileContent(MediaItem item) {
    return _buildCinematicContent(item, MediaQuery.of(context).size.width);
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
    final titleFontSize = ResponsiveUtils.heroTitleFontSize(context);
    final bool isInicio = widget.currentCategory.toLowerCase() == 'inicio';
    
    return Column(
      key: ValueKey('content_col_tv_${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isInicio) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/icons/auris-tv-icon.svg',
                height: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _formatMediaType(item),
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.2,
                ),
              ),
              if (item.rating != null && item.rating! >= 7.0) ...[
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    'TOP 10',
                    style: TextStyle(
                      fontFamily: 'NetflixSans',
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'N.º 1 en ${_formatMediaTypePlural(item)} hoy',
                  style: const TextStyle(
                    fontFamily: 'NetflixSans',
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],

        if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
          Builder(builder: (context) {
            final dpr = MediaQuery.of(context).devicePixelRatio;
            final logoWidth = MediaQuery.of(context).size.width * 0.40;
            final logoUrl = ApiEndpoints.proxyImage(item.logoUrl);
            return SizedBox(
              height: ResponsiveUtils.heroLogoHeight(context),
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
                    height: ResponsiveUtils.heroLogoHeight(context),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'NetflixSans',
              fontSize: context.useMobileLayout ? 24.0 : titleFontSize, 
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

        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '98% para ti',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Color(0xFF46D369),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
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

        SizedBox(
          width: context.useMobileLayout ? (screenWidth - 48) : (screenWidth * 0.46),
          child: Text(
            item.synopsis ?? '', 
            maxLines: 3, 
            overflow: TextOverflow.ellipsis, 
            style: TextStyle(
              fontFamily: 'NetflixSans',
              color: const Color(0xFFE5E5E5), 
              fontSize: context.useMobileLayout ? 12.5 : ResponsiveUtils.heroSynopsisFontSize(context), 
              height: 1.38, 
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(0, 1), blurRadius: 4),
              ],
            )
          ),
        ),

        const SizedBox(height: 18),
        
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(right: 80),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NetflixHeroButton(
                focusNode: _playButtonFocusNode,
                onPressed: () => SafeTap.run(() => _handlePlay(item)),
                icon: AurisIcons.play,
                label: 'Reproducir',
                isPrimary: true,
                autofocus: widget.autofocus,
              ),
              const SizedBox(width: 10),
              Builder(builder: (context) {
                final favorites = ref.watch(favoritesProvider);
                final String favId = item.id.isNotEmpty ? item.id : item.title;
                final isFav = favorites.any((f) => f.id == favId);
                return _NetflixHeroButton(
                  focusNode: _favButtonFocusNode,
                  icon: isFav ? AurisIcons.bookmarkFilled : AurisIcons.add,
                  label: isFav ? 'En mi lista' : 'Mi lista',
                  onPressed: () {
                    final user = ref.read(authProvider);
                    final favItem = FavoriteItem(
                      id: favId,
                      title: item.title,
                      posterUrl: item.posterUrl,
                      bannerUrl: item.bannerUrl ?? item.posterUrl,
                      category: widget.currentCategory,
                      source: item.source,
                      url: item.detailUrl ?? '',
                      addedAt: DateTime.now(),
                      kind: item.kind,
                      year: item.year,
                      type: item.card?.type ?? item.type.name,
                      profileId: user?.activeProfileId ?? 'guest_profile',
                    );
                    ref.read(favoritesProvider.notifier).toggleFavorite(favItem);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isFav ? 'Quitado de Mi lista' : 'Añadido a Mi lista')),
                    );
                  },
                );
              }),
              if (item.trailerKey != null) ...[
                const SizedBox(width: 10),
                _NetflixHeroButton(
                  focusNode: _trailerButtonFocusNode,
                  icon: (kIsWeb && _showTrailerLayer) ? AurisIcons.close : AurisIcons.trailer,
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
                const SizedBox(width: 10),
                Consumer(builder: (context, ref, _) {
                  final isMuted = ref.watch(heroBannerMutedProvider);
                  return _NetflixHeroIconButton(
                    focusNode: _muteButtonFocusNode,
                    icon: isMuted ? AurisIcons.volumeMute : AurisIcons.volumeUp,
                    label: isMuted ? 'Activar audio' : 'Silenciar',
                    onPressed: () => ref.read(heroBannerMutedProvider.notifier).state = !isMuted,
                  );
                }),
              ],
              if (!context.useMobileLayout && widget.items.length > 1) ...[
                const SizedBox(width: 10),
                _NetflixHeroIconButton(
                  focusNode: _prevButtonFocusNode,
                  icon: AurisIcons.arrowLeft2,
                  label: 'Anterior',
                  onPressed: () {
                    _previousPage();
                    _startAutoPlay();
                  },
                ),
                const SizedBox(width: 8),
                _NetflixHeroIconButton(
                  focusNode: _nextButtonFocusNode,
                  icon: AurisIcons.arrowRight2,
                  label: 'Siguiente',
                  onPressed: () {
                    _nextPage();
                    _startAutoPlay();
                  },
                ),
              ],
              const SizedBox(width: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavArrows() {
    return const SizedBox.shrink();
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
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool activeWhite = widget.isPrimary || _isHovered || _isFocused;
    final Color bgColor = activeWhite ? Colors.white : const Color(0x80545454);
    final Color textColor = activeWhite ? Colors.black : Colors.white;

    final String effectiveIcon = ((_isHovered || _isFocused) && (widget.icon == AurisIcons.play || widget.icon == AurisIcons.playFilled))
        ? AurisIcons.playFilled
        : widget.icon;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _isFocused = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: (_isHovered || _isFocused) ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: (_isHovered || _isFocused)
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
              borderRadius: BorderRadius.circular(4),
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
                        color: textColor,
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
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _hovered || _focused;
    final Color bgColor = active ? Colors.white : const Color(0x66000000);
    final Color fgColor = active ? Colors.black : Colors.white;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Tooltip(
          message: widget.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? Colors.white : Colors.white54,
                width: 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                customBorder: const CircleBorder(),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: widget.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fgColor,
                          ),
                        )
                      : AurisIcon(
                          widget.icon,
                          size: 20,
                          color: fgColor,
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
