import 'dart:async';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../player/presentation/youtube_trailer_player.dart';
import 'package:flutter/foundation.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart' hide FocusablePosterCard, FocusableWideCard;
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../../shared/widgets/focusable_wide_card.dart';
import '../../../shared/widgets/full_screen_viewer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tv_responsive_utils.dart';
import '../../home/widgets/wide_content_row.dart';
import 'content_details_screen.dart';
import 'episodes_detail_overlay.dart';

// --- Galería Local Helpers ---
String _getWarningText(String? certification) => getWarningText(certification);

String? _pickDisplayDate(String? primary, String? fallback) {
  if (primary != null && primary.isNotEmpty) return primary;
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return null;
}

String _episodeUrlFor(EpisodeInfo? ep, String baseUrl, String source, int epNum) {
  if (ep != null && ep.url.isNotEmpty) return ep.url;
  return buildEpisodeUrl(baseUrl, source, epNum);
}

bool _isMovieLikeTitle(String title) {
  return RegExp(r'\b(movie|film)\b|pel[\u00EDi]culas?', caseSensitive: false).hasMatch(title);
}

bool _isMovieContent(dynamic detail) {
  if (detail is AnimeDetail) {
    final f = detail.format?.toLowerCase() ?? '';
    return f == 'movie' || f == 'película' || f == 'ova' || f == 'ona' || f == 'special';
  }
  if (detail is MovieDetail) return detail.isMovie;
  return false;
}

int? _getRuntime(dynamic detail) {
  if (detail is AnimeDetail) return detail.duration;
  if (detail is MovieDetail) return detail.runtime;
  return null;
}

int? _getEpisodeCount(dynamic detail) {
  if (detail is AnimeDetail) return detail.episodes;
  if (detail is MovieDetail) return detail.totalEpisodes;
  return null;
}

String _formatRuntime(int? minutes) {
  if (minutes == null || minutes == 0) return 'N/A';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '$h h';
  return '$h h $m min';
}

Widget _buildBadge(BuildContext context, String? text, {bool small = false}) {
  if (text == null || text.isEmpty) return const SizedBox.shrink();
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: ResponsiveUtils.sp(context, small ? 6 : 10), 
      vertical: ResponsiveUtils.sp(context, small ? 2 : 4)
    ),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.3),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.5), 
        width: 1.5
      ),
      borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, 3)),
    ),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        color: Colors.white, 
        fontSize: small ? 11 : 14, 
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );
}

Widget _buildAgeBadge(BuildContext context, String? text, {bool small = false}) {
  if (text == null || text.isEmpty) return const SizedBox.shrink();
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: ResponsiveUtils.sp(context, small ? 4 : 6), 
      vertical: ResponsiveUtils.sp(context, small ? 1 : 2)
    ),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      border: Border.all(
        color: Colors.white10, 
        width: 1.0
      ),
      borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, 3)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white, 
        fontSize: small ? 9 : 11, 
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

String _formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    final date = DateTime.parse(dateStr);
    final months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  } catch (_) {
    return dateStr ?? '';
  }
}

class _RatingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final bool mobile;
  const _RatingSkeleton({required this.width, required this.height, this.mobile = false});
  @override
  Widget build(BuildContext context) {
    final base = mobile ? 18.0 : 24.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: mobile ? value : value * 0.85,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(base / 2),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const _SkeletonBox({required this.width, required this.height, this.borderRadius = 4});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class _ContentHeader extends ConsumerStatefulWidget {
  final String title; 
  final String source; 
  final String url; 
  final String category;
  final String? poster; 
  final String? banner; 
  final AsyncValue<ContentDetailResponse?> detailAsync; 
  final SearchResult? currentSource; 
  final List<SearchResult> sources; 
  final Function(int) onSourceSelected; 
  final VoidCallback onPlay; 
  final double? sourceRating; 
  final bool showRatingSkeleton;
  final bool isLoadingSources;
  final int totalSeasons; 
  final bool isMovieish;
  final int currentSeason; 
  final String? inferredSeasonAirDate;
  final PlaybackHistory? latestHistory;
  final Set<String>? unavailableSources;
  final int? season;
  final String? kind;
  final int? year;
  final String? type;
  final VoidCallback? onShowEpisodes;
  final AsyncValue<Map<String, List<RelatedInfo>>> relations;
  final UnifiedDetailParams detailParams;
  final String? metadataTitle;

  const _ContentHeader({
    required this.title, 
    required this.source, 
    required this.url, 
    required this.category,
    this.poster, 
    this.banner, 
    required this.detailAsync, 
    this.currentSource, 
    required this.sources, 
    required this.onSourceSelected, 
    required this.onPlay, 
    this.sourceRating, 
    this.showRatingSkeleton = false,
    this.isLoadingSources = false,
    required this.totalSeasons, 
    this.isMovieish = false,
    required this.currentSeason, 
    this.inferredSeasonAirDate,
    this.latestHistory,
    this.unavailableSources,
    this.season,
    this.kind,
    this.year,
    this.type,
    this.onShowEpisodes,
    required this.relations,
    required this.detailParams,
    this.metadataTitle,
  });

  @override ConsumerState<_ContentHeader> createState() => _ContentHeaderState();
}

enum _ContentSection { header, episodes, related, openings, endings }

class _ContentHeaderState extends ConsumerState<_ContentHeader> {
  YouTubeTrailerPlayerController? _trailerController; Timer? _fadeTimer; String? _lastTrailerKey; bool _isMuted = true; bool _showPlayer = false; bool _isPlayedOnce = false; Timer? _delayTimer;
  bool _showTitle = true; Timer? _titleHideTimer;
  bool _revealed = false;
  Timer? _revealTimeout;
  final FocusNode _actionsRowFirstNode = FocusNode();
  final ScrollController _mainScrollController = ScrollController();
  final GlobalKey _episodesSectionKey = GlobalKey();
  final FocusNode _seasonSelectorFocusNode = FocusNode(debugLabel: 'season_selector');
  final FocusNode _sourceSelectorFocusNode = FocusNode(debugLabel: 'source_selector');
  EpisodeInfo? _focusedEpisode;
  int? _lastSeenSeason;
  // Memoria de scroll de las filas horizontales (como las filas del Home).
  final ScrollController _episodesScrollController = ScrollController();
  // Nodo único que intercepta el D-PAD de toda la fila de episodios
  // (mismo patrón cursor-fijo que WideContentRow).
  final FocusNode _episodeRowFocusNode = FocusNode(debugLabel: 'EpisodesRow');
  /// Nodos dummy por episodio: skipTraversal + !canRequestFocus.
  List<FocusNode> _episodeDummyNodes = [];
  /// Índice lógico actualmente seleccionado en la fila de episodios.
  int? _focusedEpisodeIndex;

  // Sección activa para opacidad cinematográfica estilo Prime Video
  _ContentSection _activeSection = _ContentSection.header;
  bool get _isScrolled => _activeSection != _ContentSection.header || _scrollOffset > 30;

  // Memoria y navegación vertical entre secciones (patrón Home)
  int _lastFocusedActionIndex = 0;
  final List<FocusNode> _actionFocusNodes = [];
  int _lastFocusedSelector = 0; // 0 = temporada, 1 = fuente
  int? _lastFocusedEpisodeIndex;
  final GlobalKey<_RelatedCarouselState> _relatedCarouselKey = GlobalKey<_RelatedCarouselState>();
  final GlobalKey<WideContentRowState> _openingsRowKey = GlobalKey<WideContentRowState>();
  final GlobalKey<WideContentRowState> _endingsRowKey = GlobalKey<WideContentRowState>();

  void _syncActionFocusNodes(int count) {
    while (_actionFocusNodes.length < count) {
      final idx = _actionFocusNodes.length;
      final node = FocusNode(debugLabel: 'action_$idx');
      node.addListener(() {
        if (node.hasFocus) {
          _lastFocusedActionIndex = idx;
          if (_activeSection != _ContentSection.header && mounted) {
            setState(() => _activeSection = _ContentSection.header);
          }
        }
      });
      _actionFocusNodes.add(node);
    }
    while (_actionFocusNodes.length > count) {
      _actionFocusNodes.removeLast().dispose();
    }
  }

  /// Sincroniza los nodos dummy para la fila de episodios.
  void _syncEpisodeDummyNodes(int count) {
    if (_episodeDummyNodes.length == count) return;
    for (final n in _episodeDummyNodes) {
      n.dispose();
    }
    _episodeDummyNodes = List.generate(
      count,
      (_) => FocusNode(skipTraversal: true, canRequestFocus: false),
    );
  }

  bool get _hasSeasonOrSourceSelectors =>
      !widget.isMovieish && (widget.totalSeasons > 1 || widget.sources.isNotEmpty);

  bool _focusRememberedAction() {
    if (_mainScrollController.hasClients) {
      _mainScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
    if (_actionFocusNodes.isEmpty) return false;
    final idx = _lastFocusedActionIndex.clamp(0, _actionFocusNodes.length - 1);
    if (idx < _actionFocusNodes.length && _actionFocusNodes[idx].canRequestFocus) {
      _actionFocusNodes[idx].requestFocus();
      return true;
    }
    if (_actionsRowFirstNode.canRequestFocus) {
      _actionsRowFirstNode.requestFocus();
      return true;
    }
    return false;
  }

  bool _focusRememberedSelector() {
    _scrollToEpisodesSection();
    if (_lastFocusedSelector == 1 && widget.sources.isNotEmpty && _sourceSelectorFocusNode.canRequestFocus) {
      _sourceSelectorFocusNode.requestFocus();
      return true;
    }
    if (widget.totalSeasons > 1 && _seasonSelectorFocusNode.canRequestFocus) {
      _seasonSelectorFocusNode.requestFocus();
      return true;
    }
    if (widget.sources.isNotEmpty && _sourceSelectorFocusNode.canRequestFocus) {
      _sourceSelectorFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  bool _focusRememberedEpisode() {
    if (_episodeDummyNodes.isEmpty) return false;
    _scrollToEpisodesSection();
    final idx = (_lastFocusedEpisodeIndex ?? 0).clamp(0, _episodeDummyNodes.length - 1);
    _episodeRowFocusNode.requestFocus();
    _setEpisodeFocusedIndex(idx);
    return true;
  }

  bool _focusBelowActions() {
    if (_hasSeasonOrSourceSelectors && _focusRememberedSelector()) return true;
    if (_focusRememberedEpisode()) return true;
    if (_relatedCarouselKey.currentState?.focusRememberedCard() == true) return true;
    if (_openingsRowKey.currentState?.focusRememberedCard() == true) return true;
    if (_endingsRowKey.currentState?.focusRememberedCard() == true) return true;
    return false;
  }

  bool _focusBelowEpisodes() {
    if (_relatedCarouselKey.currentState?.focusRememberedCard() == true) return true;
    if (_openingsRowKey.currentState?.focusRememberedCard() == true) return true;
    if (_endingsRowKey.currentState?.focusRememberedCard() == true) return true;
    return false;
  }

  bool _focusAboveRelated() {
    if (_focusRememberedEpisode()) return true;
    if (_hasSeasonOrSourceSelectors && _focusRememberedSelector()) return true;
    if (_focusRememberedAction()) return true;
    return false;
  }

  bool _focusBelowRelated() {
    if (_openingsRowKey.currentState?.focusRememberedCard() == true) return true;
    if (_endingsRowKey.currentState?.focusRememberedCard() == true) return true;
    return false;
  }

  bool _focusAboveOpenings() {
    if (_relatedCarouselKey.currentState?.focusRememberedCard() == true) return true;
    if (_focusRememberedEpisode()) return true;
    if (_hasSeasonOrSourceSelectors && _focusRememberedSelector()) return true;
    if (_focusRememberedAction()) return true;
    return false;
  }

  void _scrollToEpisodesSection() {
    if (!_mainScrollController.hasClients) return;
    final ctx = _episodesSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    }
  }

  void _scrollToEpisodeIndex(int index, double cardWidth) {
    if (!_episodesScrollController.hasClients) return;
    const double spacing = 14.0;
    final double targetOffset = index * (cardWidth + spacing);
    final double maxScroll = _episodesScrollController.position.maxScrollExtent;
    _episodesScrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// Actualiza el índice de episodio seleccionado, refresca la info superior
  /// y ancla la tarjeta bajo el cursor fijo (idéntico a Prime Video y WideContentRow).
  void _setEpisodeFocusedIndex(int index, [EpisodeInfo? episode]) {
    if (!mounted) return;
    setState(() {
      _focusedEpisodeIndex = index;
      _lastFocusedEpisodeIndex = index;
      _activeSection = _ContentSection.episodes;
      if (episode != null) {
        _focusedEpisode = episode;
      }
    });
    final cardWidth = TVResponsiveUtils.bannerWidth(context);
    _scrollToEpisodeIndex(index, cardWidth);
  }

  void _startTitleHideTimer() {
    _titleHideTimer?.cancel();
    if (_showPlayer) {
      _titleHideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _showPlayer && _showTitle) {
          setState(() => _showTitle = false);
        }
      });
    }
  }

  void _handleInteraction() {
    if (!mounted) return;
    if (!_showTitle) {
      setState(() => _showTitle = true);
    }
    _startTitleHideTimer();
  }
  @override void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndInitTrailer();
    // Primer build ya con datos (revelado temprano del screen): sin esto el
    // header mostraba skeletons hasta el siguiente update.
    if (!_revealed &&
        (widget.detailAsync.valueOrNull != null || widget.detailAsync.hasValue)) {
      _revealed = true;
    }
  }
  @override void didUpdateWidget(covariant _ContentHeader oldWidget) { 
    super.didUpdateWidget(oldWidget); 
    _checkAndInitTrailer(); 

    final hasRealData = widget.detailAsync.valueOrNull != null;
    if (!_revealed && (hasRealData || widget.detailAsync.hasValue)) {
      setState(() => _revealed = true);
    }
  }

  void _checkAndInitTrailer() {
    final d = widget.detailAsync.valueOrNull?.main;
    final k = (d is AnimeDetail) ? d.trailerKey : (d is MovieDetail ? d.trailerKey : null);
    if (k != null && k.isNotEmpty) { if (k != _lastTrailerKey) { _lastTrailerKey = k; } } else if (_lastTrailerKey != null) { _lastTrailerKey = null; _disposeController(); }
  }

  void _initTrailer(String key, {bool immediate = false}) {
    _delayTimer?.cancel();
    void start() {
      if (!mounted || key != _lastTrailerKey) return;
      if (_trailerController != null && _trailerController!.isReady) {
        _fadeTimer?.cancel(); _trailerController!.pauseVideo(); _trailerController!.seekTo(0);
        if (!_isMuted) { _trailerController!.unmute(); _trailerController!.setVolume(100); } else { _trailerController!.mute(); }
        _trailerController!.playVideo();
        setState(() { _showPlayer = false; _isPlayedOnce = false; _showTitle = true; });
        _titleHideTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 600), () { 
          if (mounted && !_showPlayer) {
            setState(() { _showPlayer = true; _showTitle = true; }); 
            _startTitleHideTimer();
          }
        });
        return;
      }
      _trailerController = YouTubeTrailerPlayerController();
      _trailerController!.addListener(() {
        if (_trailerController!.isReady && mounted && !_showPlayer) {
          setState(() { _showPlayer = true; _showTitle = true; }); 
          _startTitleHideTimer();
        }
      });
      if (mounted) {
        setState(() { _showPlayer = false; _isPlayedOnce = false; _showTitle = true; _lastTrailerKey = key; });
        _titleHideTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 400), () { 
          if (mounted) { 
            _trailerController!.playVideo(); 
            Future.delayed(const Duration(milliseconds: 1100), () { 
              if (mounted && !_showPlayer) {
                setState(() { _showPlayer = true; _showTitle = true; }); 
                _startTitleHideTimer();
              }
            }); 
          } 
        });
      }
    }
    if (immediate) start(); else _delayTimer = Timer(const Duration(seconds: 3), start);
  }

  void _disposeController() { _delayTimer?.cancel(); _fadeTimer?.cancel(); _titleHideTimer?.cancel(); _trailerController?.dispose(); _trailerController = null; }
  
  double _scrollOffset = 0.0;

  @override void initState() {
    super.initState();
    _revealTimeout = Timer(ApiEndpoints.detailRevealTimeout, () {
      if (mounted && !_revealed) setState(() => _revealed = true);
    });
    _mainScrollController.addListener(() {
      if (mounted) {
        final offset = _mainScrollController.hasClients ? _mainScrollController.offset : 0.0;
        if ((offset > 20) != (_scrollOffset > 20)) {
          setState(() => _scrollOffset = offset);
        }
      }
    });

    _actionsRowFirstNode.addListener(() {
      if (_actionsRowFirstNode.hasFocus) {
        if (_activeSection != _ContentSection.header && mounted) {
          setState(() => _activeSection = _ContentSection.header);
        }
        if (_mainScrollController.hasClients && _mainScrollController.offset > 0.0) {
          _mainScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  @override void dispose() { 
    _revealTimeout?.cancel();
    for (final n in _actionFocusNodes) {
      n.dispose();
    }
    for (final n in _episodeDummyNodes) {
      n.dispose();
    }
    _actionsRowFirstNode.dispose();
    _episodeRowFocusNode.dispose();
    _seasonSelectorFocusNode.dispose();
    _sourceSelectorFocusNode.dispose();
    _mainScrollController.dispose();
    _episodesScrollController.dispose();
    _disposeController(); 
    super.dispose(); 
  }

  @override Widget build(BuildContext context) {
    ref.listen(unifiedContentProvider(widget.detailParams).select((s) => s.episodes), (prev, next) {
      next.whenData((result) {
        final eps = result?.response.episodes ?? [];
        if (eps.isNotEmpty) {
          if (_focusedEpisode == null || _lastSeenSeason != widget.currentSeason) {
            _lastSeenSeason = widget.currentSeason;
            if (mounted) {
              setState(() {
                _focusedEpisode = eps.first;
              });
            }
          }
        }
      });
    });

    final d = widget.detailAsync.valueOrNull?.main;
    // Mientras la respuesta de metadatos del servidor NO haya llegado, ocultamos
    // tanto el título (texto) como la imagen de fondo: el nombre/póster/banner
    // de la tarjeta solo valen como FALLBACK una vez resuelto el detalle. Antes
    // de eso mostramos skeletons, para no "adelantar" datos que luego cambian.
    final bool metaPending =
        widget.detailAsync.isLoading && widget.detailAsync.valueOrNull == null;
    final logoReady = !metaPending;
    final b = metaPending
        ? null
        : DetailBackdropResolver.resolve(
            detail: d,
            bannerParam: widget.banner,
            poster: widget.poster,
            season: widget.currentSeason,
          );
    final heroTitle = widget.title;
    final width = MediaQuery.sizeOf(context).width;
    final heroBanner = ApiEndpoints.proxyImage(DetailBackdropResolver.resolve(detail: d, bannerParam: widget.banner, sourceBanner: widget.sources.isNotEmpty ? widget.sources.first.banner : null, season: widget.currentSeason), highQuality: true);

    return MouseRegion(
      onHover: (_) => _handleInteraction(),
      child: Listener(
        onPointerDown: (_) => _handleInteraction(),
        onPointerMove: (_) => _handleInteraction(),
        onPointerHover: (_) => _handleInteraction(),
        child: Stack(
          children: [
            // Backdrop cinematográfico estático fijo en la pantalla (patrón Prime Video)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa 1: Fondo y backdrop fotográfico fijado
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xFF000000),
                      child: b != null && b.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: b,
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                              memCacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.of(context).devicePixelRatio).round().clamp(1, 1920),
                              fadeInDuration: AurisImageConfig.defaultFadeInDuration,
                              fadeOutDuration: AurisImageConfig.defaultFadeOutDuration,
                              cacheManager: AurisImageCacheManager.instance,
                              errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF000000)),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  // Capa 2: Gradiente horizontal inicial (izquierda sólida a derecha transparente)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFF000000),
                            const Color(0xFF000000).withOpacity(0.95),
                            const Color(0xFF000000).withOpacity(0.85),
                            const Color(0xFF000000).withOpacity(0.40),
                            const Color(0xFF000000).withOpacity(0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.20, 0.35, 0.55, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Capa 3: Gradiente vertical inicial (fading inferior hacia oscuro)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF000000).withOpacity(0.45),
                            Colors.transparent,
                            Colors.transparent,
                            const Color(0xFF000000).withOpacity(0.80),
                            const Color(0xFF000000),
                          ],
                          stops: const [0.0, 0.15, 0.60, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Capa 4: Scrim de transición animada al hacer scroll o enfocar secciones inferiores
                  // Oscurece uniformemente el backdrop manteniendo el mismo fondo estático
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      opacity: _isScrolled ? 0.75 : 0.0,
                      child: const ColoredBox(color: Color(0xFF000000)),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              controller: _mainScrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.sizeOf(context).height * 0.90,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final h = constraints.maxHeight; 
                      final ph = h; 
                      final pw = MediaQuery.sizeOf(context).width;
                      return Stack(fit: StackFit.expand, clipBehavior: Clip.hardEdge, children: [
                        Container(color: Colors.transparent),
                        if (_trailerController != null && _lastTrailerKey != null)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 500),
                              opacity: _showPlayer ? 1.0 : 0.0,
                              child: PointerInterceptor(
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: ClipRect(
                                    child: OverflowBox(
                                      alignment: Alignment.center,
                                      minWidth: pw,
                                      maxWidth: pw,
                                      minHeight: ph,
                                      maxHeight: ph,
                                      child: YouTubeTrailerPlayer(
                                        key: ValueKey(_lastTrailerKey),
                                        controller: _trailerController!,
                                        videoId: _lastTrailerKey!,
                                        autoPlay: true,
                                        mute: true,
                                        aspectRatio: 16 / 9,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: TVResponsiveUtils.horizontalPadding(context), 
                          top: h * 0.06,
                          bottom: 4,
                          child: SizedBox(
                            width: width - 2 * TVResponsiveUtils.horizontalPadding(context),
                            child: _buildNetflixContentColumn(context, d, width, heroTitle, logoReady, metaPending),
                          ),
                        ),
                      ]);
                    }),
                  ),
                  const SizedBox(height: 6),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    opacity: (_activeSection == _ContentSection.episodes || _activeSection == _ContentSection.header) ? 1.0 : 0.45,
                    child: _buildIntegratedEpisodesSection(context, d, widget.detailParams, widget.currentSource, heroBanner),
                  ),
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    opacity: _activeSection == _ContentSection.related ? 1.0 : 0.45,
                    child: _buildRelatedCarousel(),
                  ),
                  const SizedBox(height: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    opacity: (_activeSection == _ContentSection.openings || _activeSection == _ContentSection.endings) ? 1.0 : 0.45,
                    child: _buildThemesSection(),
                  ),
                ],
              ),
            ),
            Positioned.fill(child: _buildUpperButtons(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegratedEpisodesSection(BuildContext context, dynamic d, UnifiedDetailParams detailParams, SearchResult? currentSource, String? heroBanner) {
    if (widget.isMovieish) return const SizedBox.shrink();

    final episodesAsync = ref.watch(unifiedContentProvider(detailParams)).episodes;

    return episodesAsync.when(
      data: (result) {
        final eps = result?.response.episodes ?? [];
        if (eps.isEmpty) return const SizedBox.shrink();
        _syncEpisodeDummyNodes(eps.length);

        if (_lastSeenSeason != widget.currentSeason || _focusedEpisode == null) {
          _lastSeenSeason = widget.currentSeason;
          _lastFocusedEpisodeIndex = 0;
          _focusedEpisodeIndex = null;
          if (eps.isNotEmpty) {
            _focusedEpisode = eps.first;
          }
        }

        // El episodio seleccionado puede haber llegado primero con datos
        // parciales y luego actualizarse con metadata completa. Se busca por
        // número en la lista actual para no quedarse con el objeto viejo.
        final int selectedNumber = _focusedEpisode?.number ?? 1;
        final displayEpisode = eps.firstWhereOrNull((e) => e.number == selectedNumber) ?? eps.first;

        final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);

        return Container(
          key: _episodesSectionKey,
          width: double.infinity,
          padding: const EdgeInsets.only(
            top: 12,
            bottom: 10,
          ),
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isMovieish && (widget.totalSeasons > 1 || widget.sources.isNotEmpty)) ...[
                Padding(
                  padding: EdgeInsets.only(left: horizontalPadding),
                  child: _buildSeasonAndSourceSelectors(context, detailParams, currentSource),
                ),
                const SizedBox(height: 16),
              ],
              Padding(
                padding: EdgeInsets.only(left: horizontalPadding),
                child: SizedBox(
                  height: 105,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(
                      key: ValueKey(displayEpisode.number),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayEpisode.title != null && displayEpisode.title!.isNotEmpty
                                ? '${displayEpisode.number}. ${displayEpisode.title}'
                                : '${displayEpisode.number}. Episodio ${displayEpisode.number}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (displayEpisode.description != null && displayEpisode.description!.isNotEmpty)
                            SizedBox(
                              width: MediaQuery.sizeOf(context).width * 0.55,
                              height: 32,
                              child: Text(
                                displayEpisode.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                              ),
                            )
                          else
                            const SizedBox(height: 32),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildAgeBadge(context, (d is MovieDetail ? d.certification : (d is AnimeDetail ? d.certification : null)) ?? '13+', small: true),
                              const SizedBox(width: 8),
                              Text(displayEpisode.duration ?? '24 min', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                              if (_pickDisplayDate(displayEpisode.airDate, widget.year?.toString()) != null) ...[
                                const SizedBox(width: 8),
                                Text(_formatDate(_pickDisplayDate(displayEpisode.airDate, widget.year?.toString())), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // --- Fila de episodios con cursor fijo (mismo patrón que WideContentRow y Prime Video) ---
              Builder(builder: (context) {
                final cardWidth = TVResponsiveUtils.bannerWidth(context);
                final cardHeight = TVResponsiveUtils.bannerHeight(context);

                return SizedBox(
                  height: cardHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Focus(
                        focusNode: _episodeRowFocusNode,
                        onFocusChange: (focused) {
                          if (!mounted) return;
                          if (focused) {
                            // Al entrar: restaurar el último episodio visto y marcar sección activa
                            final idx = (_lastFocusedEpisodeIndex ?? 0)
                                .clamp(0, eps.length - 1);
                            setState(() {
                              _activeSection = _ContentSection.episodes;
                              if (_focusedEpisodeIndex == null) {
                                _focusedEpisodeIndex = idx;
                                _focusedEpisode = eps[idx];
                              }
                            });
                            _scrollToEpisodeIndex(idx, cardWidth);
                            _scrollToEpisodesSection();
                          } else {
                            // Al salir: guardar memoria, quitar cursor
                            if (_focusedEpisodeIndex != null) {
                              _lastFocusedEpisodeIndex = _focusedEpisodeIndex;
                            }
                            setState(() => _focusedEpisodeIndex = null);
                          }
                        },
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                            return KeyEventResult.ignored;
                          }
                          final key = event.logicalKey;
                          final current = _focusedEpisodeIndex ?? 0;
                          final last = eps.length - 1;

                          if (key == LogicalKeyboardKey.arrowRight) {
                            if (current < last) {
                              _setEpisodeFocusedIndex(current + 1, eps[current + 1]);
                            }
                            // En el último: no escapar (blocked)
                            return KeyEventResult.handled;
                          } else if (key == LogicalKeyboardKey.arrowLeft) {
                            if (current > 0) {
                              _setEpisodeFocusedIndex(current - 1, eps[current - 1]);
                            }
                            // En el primero: no escapar (blocked)
                            return KeyEventResult.handled;
                          } else if (key == LogicalKeyboardKey.arrowUp) {
                            if (_hasSeasonOrSourceSelectors && _focusRememberedSelector()) {
                              return KeyEventResult.handled;
                            }
                            if (_focusRememberedAction()) return KeyEventResult.handled;
                            return KeyEventResult.handled;
                          } else if (key == LogicalKeyboardKey.arrowDown) {
                            if (_focusBelowEpisodes()) return KeyEventResult.handled;
                            return KeyEventResult.handled;
                          } else if (key == LogicalKeyboardKey.enter ||
                              key == LogicalKeyboardKey.select ||
                              key == LogicalKeyboardKey.space) {
                            if (_focusedEpisodeIndex != null && _focusedEpisodeIndex! < eps.length) {
                              final ep = eps[_focusedEpisodeIndex!];
                              final epSrc = result?.sourceForNumber(ep.number) ?? currentSource;
                              SafeTap.run(() => _playEpisode(ep, epSrc, eps.length, detailParams, currentSource, heroBanner, widget.category, widget.kind, d));
                            }
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: ListView.separated(
                          key: const PageStorageKey('content-episodes-row'),
                          controller: _episodesScrollController,
                          // NeverScrollableScrollPhysics: scroll únicamente programático
                          // (_scrollToEpisodeIndex). El cursor blanco queda fijo y las
                          // tarjetas se deslizan debajo con animación fluida.
                          physics: const NeverScrollableScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          itemCount: eps.length,
                          padding: EdgeInsets.only(
                            left: horizontalPadding,
                            right: (MediaQuery.sizeOf(context).width - cardWidth - horizontalPadding).clamp(horizontalPadding, 2000.0),
                            top: 0,
                            bottom: 0,
                          ),
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final ep = eps[index];
                            final epSrc = result?.sourceForNumber(ep.number) ?? currentSource;
                            final thumbUrl = (ep.thumbnail?.isNotEmpty ?? false)
                                ? ep.thumbnail!
                                : (epSrc?.thumbnail ?? currentSource?.thumbnail ?? '');
                            // isSelected: reservado para uso futuro (no genera translucidez intra-fila)
                            return GestureDetector(
                              onTap: () => _playEpisode(ep, epSrc, eps.length, detailParams,
                                  currentSource, heroBanner, widget.category, widget.kind, d),
                              child: SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: ApiEndpoints.proxyImage(thumbUrl),
                                        fit: BoxFit.cover,
                                        memCacheWidth: (cardWidth * MediaQuery.of(context).devicePixelRatio).round().clamp(1, 640),
                                        memCacheHeight: (cardHeight * MediaQuery.of(context).devicePixelRatio).round().clamp(1, 400),
                                        fadeInDuration: AurisImageConfig.defaultFadeInDuration,
                                        fadeOutDuration: AurisImageConfig.defaultFadeOutDuration,
                                        cacheManager: AurisImageCacheManager.instance,
                                        errorWidget: (_, __, ___) => Container(color: Colors.white10),
                                      ),
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.75),
                                                ],
                                                stops: const [0.48, 1.0],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.65),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.white.withOpacity(0.20), width: 1.0),
                                          ),
                                          child: Text(
                                            'E${ep.number}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (widget.latestHistory != null &&
                                          int.tryParse(widget.latestHistory!.episode ?? '') == ep.number &&
                                          widget.latestHistory!.progress > 0)
                                        Positioned(
                                          bottom: 0,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 3,
                                            color: Colors.white24,
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: widget.latestHistory!.progress.clamp(0.0, 1.0),
                                              child: Container(
                                                color: const Color(0xFFEF7A1E),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Borde blanco FIJO anclado en el padding izquierdo (estilo Prime Video).
                      // El cursor no se mueve; las tarjetas se deslizan debajo.
                      Positioned(
                        left: horizontalPadding,
                        top: 0,
                        width: cardWidth,
                        height: cardHeight,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _focusedEpisodeIndex != null ? 1.0 : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.white24))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _playEpisode(EpisodeInfo ep, SearchResult? epSource, int total, UnifiedDetailParams detailParams, SearchResult? currentSource, String? heroBanner, String playCategory, String? playKind, dynamic detailData) {
    final epNum = ep.number;
    final effectiveSrc = epSource?.source ?? widget.source;
    final playEpisodesUrl = epSource?.url ?? widget.url;
    final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, widget.currentSeason, epNum.toString());
    final epThumb = (ep.thumbnail?.isNotEmpty ?? false) ? ep.thumbnail! : (epSource?.thumbnail ?? currentSource?.thumbnail ?? '');
    
    context.push('/player/${Uri.encodeComponent(widget.title)}?source=${effectiveSrc}&url=${_episodeUrlFor(ep, playEpisodesUrl, effectiveSrc, epNum)}&episode=$epNum&season=${widget.currentSeason}&serverName=${simplifySourceName(effectiveSrc)}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=$playCategory&totalEpisodes=$total${widget.metadataTitle != null && widget.metadataTitle!.isNotEmpty ? '&metadataTitle=${Uri.encodeComponent(widget.metadataTitle!)}' : ''}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}&logoUrl=${Uri.encodeComponent(detailData?.logo ?? '')}${playKind != null && playKind.isNotEmpty ? '&kind=${Uri.encodeComponent(playKind)}' : ''}${widget.year != null ? '&year=${widget.year}' : ''}');
  }

  Widget _buildNetflixContentColumn(BuildContext context, dynamic d, double width, String heroTitle, bool logoReady, bool metaPending) {
    final titleSize = ResponsiveUtils.sp(context, width < 1050 ? 22.0 : 36.0);
    // Con logo presente la identidad ya la da el propio logo: el título
    // original bajo él sobra (HeroTitle solo pinta logo o texto, nunca ambos).
    final dynamic logo = d?.logo;
    final bool hasLogo = logo is String && logo.isNotEmpty;

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 1200), 
            curve: Curves.easeInOut, 
            opacity: (_showPlayer && !_showTitle) ? 0.0 : 1.0, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metaPending)
                  _SkeletonBox(
                    width: width * 0.4,
                    height: 80,
                    borderRadius: 8,
                  )
                else
                  HeroTitle(
                    title: heroTitle,
                    logo: d?.logo,
                    logoReady: logoReady,
                    maxWidth: width * 0.4,
                    maxHeight: 80,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize * 1.5,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: 1.5,
                      shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 8)]
                    ),
                  ),
                if (d is MovieDetail && !hasLogo && d.originalTitle != null && d.originalTitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    d.originalTitle!,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: titleSize * 0.65,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. Izquierda: Fila de botones de acción exclusivamente
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _buildCircularActions(context, d),
                ),
              ),
              const SizedBox(width: 24),

              // 2. Medio: Sinopsis reservada (3 líneas con botón Más) + Meta line reservada (1 línea)
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 58,
                      child: _buildSynopsisWithMoreButton(d, d),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 24,
                      child: _buildMiddleMetaLine(d),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // 3. Derecha: Cast reservado (hasta 3 líneas) + Etiqueta de edad
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 48,
                      width: 200,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: _buildCastInfo(d),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: _buildRightMetaAndBadge(d),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleMetaLine(dynamic detail) {
    final rawDate = (detail is AnimeDetail) ? detail.firstAirDate : (detail is MovieDetail ? detail.releaseDate : null);
    final d = _pickDisplayDate(rawDate, widget.inferredSeasonAirDate); 
    final List<String> genres = (detail?.genres as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Row(
      children: [
        if (genres.isNotEmpty) ...[
          Text(genres.take(4).join(' • '), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
        ],
        if (d != null && d.length >= 4)
          Text(d.length > 4 ? d : d.substring(0, 4), style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildRightMetaAndBadge(dynamic detail) {
    final r = (detail?.rating ?? widget.sourceRating) as double?;
    final cert = (detail is MovieDetail ? detail.certification : (detail is AnimeDetail ? detail.certification : null)) ?? '13+';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r != null && r > 0) ...[
          Text(
            'IMDb ${formatRating(r) ?? 'N/A'}/10',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 10),
        ],
        _buildAgeBadge(context, cert, small: false),
      ],
    );
  }

  Widget _buildCircularActions(BuildContext context, dynamic d) {
    final size = ResponsiveUtils.sp(context, 40.0); 
    final iconSize = ResponsiveUtils.sp(context, 20.0); 
    final spacing = ResponsiveUtils.sp(context, 6.0);
    final String currentId = widget.url.isNotEmpty ? widget.url : widget.title;
    final bool isFav = ref.watch(favoritesProvider).any((f) => f.id == currentId);
    final latestHistory = ref.watch(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title);
    final bool hasSources = widget.currentSource != null;

    final rawButtons = <_DetailIconButton>[
      _DetailIconButton(
        icon: AurisIcons.play,
        label: (latestHistory != null && !latestHistory.isFinished) ? 'Reanudar' : 'Reproducir',
        autofocus: true,
        focusNode: _actionsRowFirstNode,
        onPressed: widget.onPlay,
        size: size,
        iconSize: iconSize,
      ),
      _DetailIconButton(
        icon: isFav ? AurisIcons.bookmarkMinusFilled : AurisIcons.addCircleOutline,
        label: isFav ? 'En mi lista' : 'Añadir a mi lista',
        onPressed: () {
          final user = ref.read(authProvider);
          final item = FavoriteItem(
            id: currentId,
            title: widget.title,
            posterUrl: widget.poster ?? '',
            bannerUrl: widget.banner ?? '',
            category: widget.category,
            source: widget.source,
            url: widget.url,
            addedAt: DateTime.now(),
            profileId: user?.activeProfileId ?? 'guest_profile',
            kind: widget.kind,
            year: widget.year,
            type: widget.type,
            season: widget.season,
            sources: flattenSources(
                ref.read(activeContentSourcesProvider)),
          );
          ref.read(favoritesProvider.notifier).toggleFavorite(item);
        },
        size: size,
        iconSize: iconSize,
      ),
      if (_lastTrailerKey != null)
        _DetailIconButton(
          icon: AurisIcons.trailer,
          label: 'Ver tráiler',
          onPressed: () => _initTrailer(_lastTrailerKey!, immediate: true),
          size: size,
          iconSize: iconSize,
        ),
      if (_trailerController != null && _showPlayer)
        _DetailIconButton(
          icon: _isMuted ? AurisIcons.volumeMute : AurisIcons.volumeUp, 
          label: _isMuted ? 'Activar audio' : 'Silenciar', 
          onPressed: () { 
            setState(() { 
              _isMuted = !_isMuted; 
              if (_isMuted) _trailerController?.mute(); 
              else { _trailerController?.unmute(); _trailerController!.setVolume(100); } 
            }); 
          }, 
          size: size, 
          iconSize: iconSize,
        ),
    ];

    final int totalCount = rawButtons.length;
    _syncActionFocusNodes(totalCount);
    final buttonWidgets = <Widget>[];

    for (int idx = 0; idx < totalCount; idx++) {
      if (idx > 0) buttonWidgets.add(SizedBox(width: spacing));
      final btn = rawButtons[idx];
      buttonWidgets.add(
        _DetailIconButton(
          key: btn.key,
          icon: btn.icon,
          filledIcon: btn.filledIcon,
          onPressed: btn.onPressed,
          label: btn.label,
          size: btn.size,
          iconSize: btn.iconSize,
          color: btn.color,
          autofocus: btn.autofocus,
          focusNode: _actionFocusNodes[idx],
          onArrowDown: () => _focusBelowActions(),
          isFirst: idx == 0,
          isLast: idx == totalCount - 1 && !hasSources,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cápsula contenedora SOLO para los botones de acción (íconos)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(100),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: buttonWidgets,
            ),
          ),
        ],
      ),
    );
  }

  /// Pantalla fullscreen de detalles: fondo con el backdrop del contenido y
  /// sinopsis completa (país y reparto incluidos).
  void _openFullscreenDetails(dynamic d) {
    final raw = DetailBackdropResolver.resolve(
      detail: d,
      bannerParam: widget.banner,
      poster: widget.poster,
      season: widget.currentSeason,
    );
    final background = raw != null ? ApiEndpoints.proxyImage(raw, highQuality: true) : null;
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => ContentDetailsScreen(
        title: widget.title,
        detailData: d,
        backgroundUrl: background,
      ),
    ));
  }

  Widget _buildNetflixMetaRow(dynamic detail) {
    final r = (detail?.rating ?? widget.sourceRating) as double?;
    final rawDate = (detail is AnimeDetail) ? detail.firstAirDate : (detail is MovieDetail ? detail.releaseDate : null);
    final d = _pickDisplayDate(rawDate, widget.inferredSeasonAirDate); 
    final cert = (detail is MovieDetail ? detail.certification : (detail is AnimeDetail ? detail.certification : null)) ?? 'NR';
    final runtime = _getRuntime(detail);
    final isMovie = _isMovieContent(detail);
    final episodeCount = _getEpisodeCount(detail);
    final List<String> genres = (detail?.genres as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              if (!_revealed) ...[
                _SkeletonBox(width: ResponsiveUtils.sp(context, 50), height: ResponsiveUtils.sp(context, 20)),
                _SkeletonBox(width: ResponsiveUtils.sp(context, 80), height: ResponsiveUtils.sp(context, 20)),
              ] else ...[
                if (d != null && d.length >= 4) Text(isMovie && d.length > 4 ? d : d.substring(0, 4)),
                if (isMovie) ...[ if (runtime != null) Text(_formatRuntime(runtime)) ] 
                else if (widget.totalSeasons > 1) ...[ Text('${widget.totalSeasons} Temporadas') ] 
                else if (episodeCount != null && episodeCount > 0) ...[ Text('$episodeCount Episodios') ],
                if (genres.isNotEmpty) ...genres.take(2).map((g) => _buildBadge(context, g.toUpperCase(), small: true)),
                if (r != null && r > 0) Row(mainAxisSize: MainAxisSize.min, children: [AurisIcon(AurisIcons.star, color: Colors.amber, size: 16), const SizedBox(width: 4), Text(formatRating(r) ?? 'N/A')]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (!_revealed) _SkeletonBox(width: ResponsiveUtils.sp(context, 200), height: ResponsiveUtils.sp(context, 16))
        else Row(children: [_buildAgeBadge(context, cert, small: true), const SizedBox(width: 12), Expanded(child: Text(_getWarningText(cert), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: const Color(0xFFA5A5AA), fontSize: 11, fontWeight: FontWeight.w500)))]),
      ],
    );
  }

  Widget _buildCastInfo(dynamic d) {
    String castText = '';
    if (d is AnimeDetail) castText = d.characters.take(3).map((c) => c.name).join(', ');
    else if (d is MovieDetail) castText = d.cast.take(3).map((c) => c.name).join(', ');
    if (castText.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: RichText(
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        text: TextSpan(
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          children: [
            const TextSpan(text: 'Cast: ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            TextSpan(text: castText),
          ],
        ),
      ),
    );
  }

  String _resolveRelationTitle(dynamic detail) {
    final bool isMovie = (detail is MovieDetail) ||
        (detail is AnimeDetail && detail.kind == 'movie') ||
        (widget.kind != null && widget.kind!.toLowerCase().contains('movie')) ||
        (widget.category.toLowerCase().contains('movie'));

    final bool isAnime = (detail is AnimeDetail) ||
        (widget.kind != null && widget.kind!.toLowerCase().contains('anime')) ||
        (widget.category.toLowerCase().contains('anime'));

    final bool isDorama = (widget.kind != null && (widget.kind!.toLowerCase().contains('dorama') || widget.kind!.toLowerCase().contains('kdrama') || widget.kind!.toLowerCase().contains('c_drama'))) ||
        (widget.category.toLowerCase().contains('dorama') || widget.category.toLowerCase().contains('kdrama'));

    if (isMovie) {
      return 'Los clientes que vieron esta película también vieron';
    } else if (isAnime) {
      return 'Los clientes que vieron este anime también vieron';
    } else if (isDorama) {
      return 'Los clientes que vieron este dorama también vieron';
    } else {
      return 'Los clientes que vieron este producto también vieron';
    }
  }

  Widget _buildRelatedCarousel() {
    return widget.relations.when(
      data: (relations) {
        final List<RelatedInfo> all = [
          ...?relations['franchise'],
          ...?relations['recommended'],
          ...?relations['similar'],
        ];
        if (all.isEmpty) return const SizedBox.shrink();

        String normalize(String t) => t
            .replaceAll(RegExp(r'\s*\([Ss]erie\)'), '')
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '');

        final Map<String, RelatedInfo> unique = {};
        for (final r in all) {
          final key = normalize(r.title);
          if (key.isNotEmpty && !unique.containsKey(key)) unique[key] = r;
        }
        final items = unique.values.toList();
        if (items.isEmpty) return const SizedBox.shrink();

        final detailData = widget.detailAsync.valueOrNull?.main;
        final title = _resolveRelationTitle(detailData);
        final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 4),
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            Focus(
              canRequestFocus: false,
              onFocusChange: (f) {
                if (f && mounted) {
                  setState(() => _activeSection = _ContentSection.related);
                }
              },
              child: _RelatedCarousel(
                key: _relatedCarouselKey,
                items: items,
                category: widget.category,
                sourceFallback: widget.currentSource?.source ?? widget.source,
                onArrowUpToPrev: _focusAboveRelated,
                onArrowDownToNext: _focusBelowRelated,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSynopsisWithMoreButton(dynamic detail, dynamic d) {
    final text = detail?.overview ?? '';
    if (!_revealed && text.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: ResponsiveUtils.sp(context, 400), height: ResponsiveUtils.sp(context, 16)),
          const SizedBox(height: 8),
          _SkeletonBox(width: ResponsiveUtils.sp(context, 380), height: ResponsiveUtils.sp(context, 16)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _MoreButton(
          onPressed: () => _openFullscreenDetails(d),
          onArrowLeft: () => _focusRememberedAction(),
          onArrowDown: () => _focusBelowActions(),
        ),
      ],
    );
  }

  Widget _buildThemesSection() {
    final themesAsync = ref.watch(unifiedContentProvider(widget.detailParams)).themes;
    return themesAsync.when(
      data: (themesData) {
        final openings = themesData.openings;
        final endings = themesData.endings;
        if (openings.isEmpty && endings.isEmpty) return const SizedBox.shrink();

        // Adapta AnimeThemeInfo → WideContentItem para reutilizar WideContentRow
        // con exactamente el mismo diseño, foco y animación de cursor fijo que Home.
        WideContentItem themeToItem(AnimeThemeInfo th, int idx, bool isOP) {
          return WideContentItem(
            id: th.videoUrl.isNotEmpty ? th.videoUrl : '${isOP ? 'op' : 'ed'}_$idx',
            title: th.title,
            imageUrl: th.imageUrl ?? '',
            subtitle: th.artist.isNotEmpty ? th.artist : 'Artista desconocido',
            originalItem: th,
          );
        }

        final openingItems = [
          for (int i = 0; i < openings.length; i++) themeToItem(openings[i], i, true)
        ];
        final endingItems = [
          for (int i = 0; i < endings.length; i++) themeToItem(endings[i], i, false)
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (openingItems.isNotEmpty)
              Focus(
                canRequestFocus: false,
                onFocusChange: (f) {
                  if (f && mounted) {
                    setState(() => _activeSection = _ContentSection.openings);
                  }
                },
                child: WideContentRow(
                  key: _openingsRowKey,
                  title: 'Openings',
                  items: openingItems,
                  onItemTap: (item) => _playTheme(item.originalItem as AnimeThemeInfo, true),
                  onArrowUpToPrev: _focusAboveOpenings,
                  onArrowDownToNext: endingItems.isNotEmpty
                      ? () => _endingsRowKey.currentState?.focusRememberedCard() == true
                      : null,
                ),
              ),
            if (endingItems.isNotEmpty)
              Focus(
                canRequestFocus: false,
                onFocusChange: (f) {
                  if (f && mounted) {
                    setState(() => _activeSection = _ContentSection.endings);
                  }
                },
                child: WideContentRow(
                  key: _endingsRowKey,
                  title: 'Endings',
                  items: endingItems,
                  onItemTap: (item) => _playTheme(item.originalItem as AnimeThemeInfo, false),
                  onArrowUpToPrev: openingItems.isNotEmpty
                      ? () => _openingsRowKey.currentState?.focusRememberedCard() == true
                      : _focusAboveOpenings,
                  onArrowDownToNext: null,
                ),
              ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _playTheme(AnimeThemeInfo theme, bool isOP) {
    final titleParam = '&title=${Uri.encodeComponent(widget.title)}&episodeTitle=${Uri.encodeComponent(theme.title)}';
    String url = theme.videoUrl;
    if (theme.video1080 != null && theme.video1080!.isNotEmpty) {
      url = theme.video1080!;
    } else if (theme.video720 != null && theme.video720!.isNotEmpty) {
      url = theme.video720!;
    }
    final v720 = (theme.video720?.isNotEmpty ?? false) ? '&video720=${Uri.encodeComponent(theme.video720!)}' : '';
    final v1080 = (theme.video1080?.isNotEmpty ?? false) ? '&video1080=${Uri.encodeComponent(theme.video1080!)}' : '';
    context.push('/player/${Uri.encodeComponent(theme.title)}?source=&url=${Uri.encodeComponent(url)}&episode=${isOP ? 'OP' : 'ED'}&season=${widget.currentSeason}&category=anime$titleParam$v720$v1080&posterUrl=${Uri.encodeComponent(theme.imageUrl ?? '')}');
  }

  Widget _buildSeasonAndSourceSelectors(BuildContext context, UnifiedDetailParams detailParams, SearchResult? currentSource) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.totalSeasons > 1) ...[
          Focus(
            focusNode: _seasonSelectorFocusNode,
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                _lastFocusedSelector = 0;
                if (_activeSection != _ContentSection.header && mounted) {
                  _activeSection = _ContentSection.header;
                }
                _scrollToEpisodesSection();
              }
              setState(() {});
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (widget.sources.isNotEmpty &&
                      _sourceSelectorFocusNode.canRequestFocus) {
                    _sourceSelectorFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _focusRememberedAction();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  if (_focusRememberedEpisode()) return KeyEventResult.handled;
                  if (_focusBelowEpisodes()) return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: _seasonSelectorFocusNode.hasFocus ? Colors.white : const Color(0xFF22252A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _seasonSelectorFocusNode.hasFocus ? Colors.white : Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: widget.currentSeason,
                  dropdownColor: const Color(0xFF1E2229),
                  isDense: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _seasonSelectorFocusNode.hasFocus ? Colors.black : Colors.white,
                  ),
                  style: TextStyle(
                    color: _seasonSelectorFocusNode.hasFocus ? Colors.black : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  items: [
                    for (int s = 1; s <= widget.totalSeasons; s++)
                      DropdownMenuItem(
                        value: s,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Temporada $s',
                            style: TextStyle(
                              color: _seasonSelectorFocusNode.hasFocus ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                  onChanged: (seasonNum) {
                    if (seasonNum != null) {
                      ref.setSeason(detailParams, seasonNum);
                    }
                  },
                ),
              ),
            ),
          ),
          if (widget.sources.isNotEmpty) const SizedBox(width: 12),
        ],
        if (widget.sources.isNotEmpty) ...[
          Focus(
            focusNode: _sourceSelectorFocusNode,
            onFocusChange: (hasFocus) {
              if (hasFocus) {
                _lastFocusedSelector = 1;
                if (_activeSection != _ContentSection.header && mounted) {
                  _activeSection = _ContentSection.header;
                }
                _scrollToEpisodesSection();
              }
              setState(() {});
            },
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  if (widget.totalSeasons > 1 &&
                      _seasonSelectorFocusNode.canRequestFocus) {
                    _seasonSelectorFocusNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _focusRememberedAction();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  if (_focusRememberedEpisode()) return KeyEventResult.handled;
                  if (_focusBelowEpisodes()) return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: _sourceSelectorFocusNode.hasFocus ? Colors.white : const Color(0xFF22252A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _sourceSelectorFocusNode.hasFocus ? Colors.white : Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SearchResult>(
                  value: currentSource,
                  dropdownColor: const Color(0xFF1E2229),
                  isDense: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _sourceSelectorFocusNode.hasFocus ? Colors.black : Colors.white,
                  ),
                  style: TextStyle(
                    color: _sourceSelectorFocusNode.hasFocus ? Colors.black : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  items: [
                    for (int i = 0; i < widget.sources.length; i++)
                      DropdownMenuItem(
                        value: widget.sources[i],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            simplifySourceName(widget.sources[i].source),
                            style: TextStyle(
                              color: _sourceSelectorFocusNode.hasFocus ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                  onChanged: (src) {
                    if (src != null) {
                      final idx = widget.sources.indexOf(src);
                      if (idx != -1) {
                        widget.onSourceSelected(idx);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUpperButtons(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _MoreButton extends StatefulWidget {
  final VoidCallback onPressed;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowDown;

  const _MoreButton({
    required this.onPressed,
    this.onArrowLeft,
    this.onArrowDown,
  });

  @override
  State<_MoreButton> createState() => _MoreButtonState();
}

class _MoreButtonState extends State<_MoreButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (widget.onArrowLeft != null) {
              widget.onArrowLeft!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (widget.onArrowDown != null) {
              widget.onArrowDown!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _focused ? Colors.white : const Color(0xFF2A2E35),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Más',
            style: GoogleFonts.poppins(
              color: _focused ? Colors.black : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailIconButton extends StatefulWidget {
  final Object icon;
  final Object? filledIcon;
  final VoidCallback onPressed;
  final String label;
  final double? size;
  final double? iconSize;
  final Color? color;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onArrowDown;

  const _DetailIconButton({
    super.key,
    required this.icon,
    this.filledIcon,
    required this.onPressed,
    required this.label,
    this.size,
    this.iconSize,
    this.color,
    this.autofocus = false,
    this.focusNode,
    this.isFirst = false,
    this.isLast = false,
    this.onArrowDown,
  });

  @override
  State<_DetailIconButton> createState() => _DetailIconButtonState();
}

class _DetailIconButtonState extends State<_DetailIconButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isFocused;
    final Object displayIcon = widget.icon;
    final Color iconColor = widget.color ?? (isActive ? Colors.black : Colors.white);
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
          if (widget.isLast && event.logicalKey == LogicalKeyboardKey.arrowRight) {
            return KeyEventResult.handled;
          }
          if (widget.isFirst && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown && widget.onArrowDown != null) {
            widget.onArrowDown!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: _FocusTooltip(
          show: isActive,
          label: widget.label,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: displayIcon is String
                  ? AurisIcon(displayIcon as String, color: iconColor, size: widget.iconSize ?? ResponsiveUtils.sp(context, 24))
                  : Icon(displayIcon as IconData?, color: iconColor, size: widget.iconSize ?? ResponsiveUtils.sp(context, 24)),
              onPressed: widget.onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _NetflixListButton extends StatefulWidget {
  final Object icon; final String label; final VoidCallback onPressed; final double? progress; final bool isPrimary; final bool autofocus; final VoidCallback? onNavigateUp;
  const _NetflixListButton({required this.icon, required this.label, required this.onPressed, this.progress, this.isPrimary = false, this.autofocus = false, this.onNavigateUp});
  @override State<_NetflixListButton> createState() => _NetflixListButtonState();
}

class _NetflixListButtonState extends State<_NetflixListButton> {
  bool _focused = false; bool _hovered = false;
  @override void initState() { super.initState(); _focused = widget.autofocus; }
  @override Widget build(BuildContext context) {
    final bool isActive = _focused || _hovered;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      // TV: OK explícito (InkWell no siempre activa con select en todos los firmwares).
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp && widget.onNavigateUp != null) {
          widget.onNavigateUp!();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed(); return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          width: ResponsiveUtils.sp(context, 280),
          height: ResponsiveUtils.sp(context, 30),
          decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Stack(alignment: Alignment.centerLeft, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    widget.icon is String
                        ? AurisIcon(widget.icon as String, color: isActive ? Colors.black : const Color(0xFFC8C8CE), size: 20)
                        : Icon(widget.icon as IconData?, color: isActive ? Colors.black : const Color(0xFFC8C8CE), size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isActive ? Colors.black : const Color(0xFFC8C8CE),
                          fontSize: 13,
                          fontWeight: FontWeight.w500
                        )
                      )
                    )
                  ]
                )
              ),
              if (widget.progress != null && widget.progress! > 0 && isActive)
                Positioned(right: 16, child: Container(width: 70, height: 5, decoration: BoxDecoration(color: isActive ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: widget.progress!.clamp(0.0, 1.0), child: Container(color: AppTheme.brand)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class ContentScreen extends ConsumerStatefulWidget {
  final String title; final String source; final String url; final String? quality; final String? type; final String? metadataTitle; final String? banner; final String category; final int? year; final int? season; final String? kind; final int? totalSeasons; final String? sectionId; final SearchResult? result;
  const ContentScreen({super.key, required this.title, required this.source, required this.url, this.quality, this.type, this.metadataTitle, this.banner, this.category = 'all', this.year, this.season, this.kind, this.totalSeasons, this.sectionId, this.result});
  @override ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showContent = false; Timer? _loadTimer;
  @override void initState() { super.initState(); _loadTimer = Timer(ApiEndpoints.pageLoadTimeout, () { if (mounted) setState(() => _showContent = true); }); }
  @override void dispose() { _loadTimer?.cancel(); _scrollController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final detailParams = UnifiedDetailParams(
      title: widget.title,
      metadataTitle: widget.metadataTitle,
      category: widget.category,
      kind: widget.kind ?? widget.result?.kind,
      year: widget.year ?? widget.result?.year,
      season: widget.season ?? widget.result?.season,
      source: widget.source,
      url: widget.url,
      type: widget.result?.type ?? widget.type,
      sectionId: widget.sectionId,
      initialSources: widget.result != null ? List.unmodifiable([widget.result!]) : null,
    );
    final detailState = ref.watch(unifiedContentProvider(detailParams));
    
    // [Intelligence] Tracking de personalización al entrar a la pantalla
    ref.watch(detailViewTrackerProvider(detailParams));

    // El detalle puede resolver una película de anime (movie_anime) aunque el
    // card llegue con kind/type 'anime' (datos del server). Propagar esa
    // naturaleza al player y al historial: sin esto el player mostraba
    // episodios y al reabrir se pedía /detail/anime en vez de /detail/movie.
    final bool _animeCtx = widget.category == 'anime' ||
        widget.category == 'movie_anime' ||
        widget.kind == 'movie_anime' ||
        widget.result?.kind == 'movie_anime' ||
        widget.result?.type == 'movie_anime' ||
        widget.type == 'movie_anime' ||
        widget.type == 'anime';
    final String playCategory = detailState.isMovieish
        ? (_animeCtx ? 'movie_anime' : 'movie')
        : (widget.category ?? 'anime');
    final String? playKind = detailState.isMovieish
        ? (_animeCtx ? 'movie_anime' : 'movie')
        : (widget.kind ?? widget.result?.kind);

    // Senior Sync Fix: Sincronizar fuentes con el player de forma segura (sin microtasks)
    ref.listen<UnifiedContentState>(unifiedContentProvider(detailParams), (prev, next) {
      if (next.allSources.isNotEmpty) {
        final currentInPlayer = ref.read(activeContentSourcesProvider);
        if (!const ListEquality().equals(currentInPlayer, next.allSources)) {
          ref.read(activeContentSourcesProvider.notifier).state = next.allSources;
        }
      }
    });

    // Revelado temprano (paridad con Móvil): en cuanto hay detalle o fuentes
    // se muestra la pantalla con botones de acción; solo lo pendiente usa
    // skeleton. Sin esto se esperaba el pageLoadTimeout completo (20s).
    final dataReady =
        detailState.detail.hasValue || detailState.allSources.isNotEmpty;
    if (dataReady && !_showContent) {
      _loadTimer?.cancel();
      _loadTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showContent = true);
      });
    }

    if (!_showContent) return Scaffold(backgroundColor: const Color(0xFF000000), body: _buildPageSkeleton(context));

    final detailData = detailState.detail.valueOrNull?.main;
    final currentSource = detailState.selectedSource;
    final history = ref.watch(playbackHistoryStateProvider).valueOrNull ?? [];

    // Senior Pre-fetch Strategy:
    // Al abrir detalles, disparamos la extracción de la fuente seleccionada en segundo plano
    // (ya sea película o el episodio a reanudar). Así, al pulsar "Reproducir", 
    // el stream ya estará caliente en el caché de Riverpod.
    if (currentSource != null && _showContent) {
      String? prefetchUrl;
      if (detailState.isMovieish) {
        prefetchUrl = currentSource.url;
      } else {
        // Episodio a prefetch: sin historial → E1; con progreso a medias →
        // ese episodio; terminado → el siguiente (clamp al total).
        final latest = history.where((h) => h.contentId == widget.title).firstOrNull;
        int epNum = 1;
        final latestEp = latest != null ? int.tryParse(latest.episode ?? '') : null;
        if (latestEp != null && latestEp > 0) {
          epNum = (latest?.isCompleted ?? false) ? latestEp + 1 : latestEp;
        }
        final epData = detailState.episodes.valueOrNull?.response;
        final totalEps = epData?.total ?? 0;
        if (totalEps > 0) epNum = epNum.clamp(1, totalEps);
        final epSource = detailState.episodes.valueOrNull?.sourceForNumber(epNum) ?? currentSource;
        final ep = epData?.episodes.firstWhereOrNull((e) => e.number == epNum);
        prefetchUrl = _episodeUrlFor(ep, epSource.url, epSource.source, epNum);
      }

      if (prefetchUrl.isNotEmpty) {
        ref.watch(extractProvider(ExtractParams(
          url: prefetchUrl,
          source: currentSource.source,
          category: widget.category,
        )));
      }
    }

    final heroBanner = ApiEndpoints.proxyImage(DetailBackdropResolver.resolve(detail: detailData, bannerParam: widget.banner, sourceBanner: detailState.allSources.isNotEmpty ? detailState.allSources.first.banner : null, season: detailState.currentSeason), highQuality: true);

    return Scaffold(
      backgroundColor: const Color(0xFF000000), 
      body: _ContentHeader(
        title: widget.title, source: widget.source, url: widget.url, category: widget.category, poster: ApiEndpoints.proxyImage(currentSource?.thumbnail), banner: heroBanner, detailAsync: detailState.detail, currentSource: currentSource, sources: detailState.allSources, totalSeasons: detailState.totalSeasons, isMovieish: detailState.isMovieish, currentSeason: detailState.currentSeason, onSourceSelected: (index) => ref.setSource(detailParams, detailState.allSources[index]), 
        kind: widget.kind ?? widget.result?.kind, year: widget.year, type: widget.result?.type ?? widget.type, season: widget.season ?? widget.result?.season,
        relations: detailState.relations,
        detailParams: detailParams,
        metadataTitle: widget.metadataTitle,
        inferredSeasonAirDate: detailState.episodes.valueOrNull?.response.seasonAirDate, 
        latestHistory: ref.watch(playbackHistoryStateProvider).valueOrNull?.where((h) => h.contentId == widget.title).firstOrNull, 
        onPlay: () {
          SearchResult? playSource = currentSource;
          final effectiveSrc = playSource?.source ?? widget.source;
          final playEpisodesUrl = playSource?.url ?? widget.url;
          if (detailState.isMovieish) {
            final ep = EpisodeInfo(number: 1, id: 0, url: playEpisodesUrl, title: 'Película', thumbnail: ApiEndpoints.proxyImage(playSource?.thumbnail));
            context.push('/player/${Uri.encodeComponent(widget.title)}?source=${effectiveSrc}&url=${_episodeUrlFor(ep, playEpisodesUrl, effectiveSrc, 1)}&episode=1&serverName=${simplifySourceName(effectiveSrc)}&startPosition=&category=$playCategory&totalEpisodes=1${widget.metadataTitle != null && widget.metadataTitle!.isNotEmpty ? '&metadataTitle=${Uri.encodeComponent(widget.metadataTitle!)}' : ''}&posterUrl=${Uri.encodeComponent(playSource?.thumbnail ?? '')}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}&logoUrl=${Uri.encodeComponent(detailData?.logo ?? '')}${playKind != null && playKind.isNotEmpty ? '&kind=${Uri.encodeComponent(playKind)}' : ''}${widget.year != null ? '&year=${widget.year}' : ''}');
            return;
          }
          final latest = ref.read(playbackHistoryStateProvider).valueOrNull?.where((h) => h.contentId == widget.title).firstOrNull;
          int epNum = latest != null ? int.tryParse(latest.episode ?? '1') ?? 1 : 1;
          final epData = detailState.episodes.valueOrNull?.response;
          final epSource = detailState.episodes.valueOrNull?.sourceForNumber(epNum) ?? currentSource;
          final ep = epData?.episodes.firstWhereOrNull((e) => e.number == epNum);
          final epThumb = ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? '';
          context.push('/player/${Uri.encodeComponent(widget.title)}?source=${epSource?.source ?? effectiveSrc}&url=${_episodeUrlFor(ep, epSource?.url ?? widget.url, epSource?.source ?? effectiveSrc, epNum)}&episode=$epNum&season=${latest?.season ?? detailState.currentSeason}&serverName=${simplifySourceName(epSource?.source ?? effectiveSrc)}&startPosition=${latest?.positionInMilliseconds ?? ''}&category=$playCategory&totalEpisodes=${epData?.total ?? 0}${widget.metadataTitle != null && widget.metadataTitle!.isNotEmpty ? '&metadataTitle=${Uri.encodeComponent(widget.metadataTitle!)}' : ''}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}&logoUrl=${Uri.encodeComponent(detailData?.logo ?? '')}${playKind != null && playKind.isNotEmpty ? '&kind=${Uri.encodeComponent(playKind)}' : ''}${widget.year != null ? '&year=${widget.year}' : ''}');
        }
      ),
    );
  }

  Widget _buildPageSkeleton(BuildContext context) {
    return Stack(clipBehavior: Clip.hardEdge, children: [
      AspectRatio(aspectRatio: 3.2 / 1, child: Container(color: const Color(0xFF000000))),
      Positioned(left: 40, right: 40, bottom: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const _SkeletonBox(width: 400, height: 80), const SizedBox(height: 24), Row(mainAxisSize: MainAxisSize.min, children: [const _SkeletonBox(width: 64, height: 56, borderRadius: 28), const SizedBox(width: 16), const _SkeletonBox(width: 64, height: 56, borderRadius: 28)]), const SizedBox(height: 24), Container(width: 220, height: 56, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)))]))
    ]);
  }
}

/// Carrusel horizontal D-pad de contenido relacionado (sin cabecera).
/// Combina franquicia + recomendados + similares en una sola fila compacta
/// por debajo de las píldoras de fuente.
class _RelatedCarousel extends StatefulWidget {
  final List<RelatedInfo> items;
  final String category;
  final String sourceFallback;
  final bool Function()? onArrowUpToPrev;
  final bool Function()? onArrowDownToNext;

  const _RelatedCarousel({
    super.key,
    required this.items,
    required this.category,
    required this.sourceFallback,
    this.onArrowUpToPrev,
    this.onArrowDownToNext,
  });

  @override
  State<_RelatedCarousel> createState() => _RelatedCarouselState();
}

class _RelatedCarouselState extends State<_RelatedCarousel> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  int? _lastFocusedIndex;
  List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _initFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void didUpdateWidget(covariant _RelatedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _initFocusNodes();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  void _initFocusNodes() {
    for (final n in _focusNodes) {
      n.dispose();
    }
    _focusNodes = List.generate(widget.items.length, (i) {
      final n = FocusNode(debugLabel: 'related_$i');
      n.addListener(() {
        if (n.hasFocus) {
          _lastFocusedIndex = i;
        }
      });
      return n;
    });
  }

  bool focusRememberedCard() {
    if (widget.items.isEmpty) return false;
    _ensureRowVisible();
    final idx = (_lastFocusedIndex ?? 0).clamp(0, widget.items.length - 1);
    if (idx < _focusNodes.length && _focusNodes[idx].canRequestFocus) {
      _focusNodes[idx].requestFocus();
      return true;
    }
    return false;
  }

  void _ensureRowVisible() {
    if (mounted) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 5;
    final canRight = maxScroll > currentScroll + 5;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = (_scrollController.offset + offset).clamp(0.0, maxScroll);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 800), curve: Curves.easeOutQuart);
  }

  @override
  void dispose() {
    for (final n in _focusNodes) {
      n.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _openRelated(RelatedInfo r) {
    final sName = r.source ?? widget.sourceFallback;
    final result = SearchResult(
      title: r.title,
      url: r.url,
      source: sName,
      quality: 'HD',
      thumbnail: r.cover,
      slug: r.slug,
      metadataTitle: r.title,
      kind: r.kind,
      type: r.type,
      year: r.year,
      sources: [SourceItem(source: sName, url: r.url, quality: 'HD', slug: r.slug)],
    );
    final openCategory = inferOpenCategory(result, widget.category);
    final uri = '/content/${Uri.encodeComponent(r.title)}'
        '?source=${Uri.encodeComponent(sName)}'
        '&category=${Uri.encodeComponent(openCategory)}'
        '&url=${Uri.encodeComponent(r.url)}'
        '&metadataTitle=${Uri.encodeComponent(r.title)}'
        '${r.kind != null && r.kind!.isNotEmpty ? '&kind=${Uri.encodeComponent(r.kind!)}' : ''}'
        '${r.type != null && r.type!.isNotEmpty ? '&type=${Uri.encodeComponent(r.type!)}' : ''}'
        '${r.year != null ? '&year=${r.year}' : ''}';
    context.push(uri, extra: result);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    final double rowHeight = TVResponsiveUtils.rowHeight(context, hasInfo: true);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: rowHeight,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  _updateScrollIndicators();
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 8 columnas en el ancho disponible: se reduce el ancho de la
                    // tarjeta lo justo para que quepan las 8 (antes cabían 7).
                    const int columns = 8;
                    const double gap = 14;
                    final double available =
                        (constraints.maxWidth - 2 * horizontalPadding)
                            .clamp(0.0, double.infinity);
                    final double cardWidth =
                        ((available - (columns - 1) * gap) / columns)
                            .clamp(60.0, TVResponsiveUtils.posterWidth(context));
                    return SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      clipBehavior: Clip.none,
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: available),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            for (int index = 0; index < widget.items.length; index++) ...[
                              if (index > 0) const SizedBox(width: gap),
                              SizedBox(
                                width: cardWidth,
                                child: FocusablePosterCard(
                                  key: ValueKey(widget.items[index].url),
                                  focusNode: index < _focusNodes.length ? _focusNodes[index] : null,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent) {
                                      if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                                          index == widget.items.length - 1) {
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                                          index == 0) {
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                        if (widget.onArrowDownToNext?.call() == true) {
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                        if (widget.onArrowUpToPrev?.call() == true) {
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  title: widget.items[index].title,
                                  posterUrl: widget.items[index].cover,
                                  showInfo: true,
                                  onTap: () => _openRelated(widget.items[index]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              left: horizontalPadding - 25,
              top: 10,
              bottom: 60,
              child: ExcludeFocus(
                excluding: !(_isHovered && _canScrollLeft),
                child: AnimatedOpacity(
                  opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !(_isHovered && _canScrollLeft),
                    child: Center(
                      child: NavArrow(
                        icon: Icons.arrow_back_ios_new,
                        useBackground: true,
                        enableScale: false,
                        onTap: () => _scroll(-600),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: horizontalPadding - 25,
              top: 10,
              bottom: 60,
              child: ExcludeFocus(
                excluding: !(_isHovered && _canScrollRight),
                child: AnimatedOpacity(
                  opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !(_isHovered && _canScrollRight),
                    child: Center(
                      child: NavArrow(
                        icon: Icons.arrow_forward_ios,
                        useBackground: true,
                        enableScale: false,
                        onTap: () => _scroll(600),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila horizontal de temas (Openings o Endings) con memoria de foco vertical (estilo Home).
class _ThemeRow extends StatefulWidget {
  final String title;
  final List<AnimeThemeInfo> items;
  final ScrollController scrollController;
  final ValueChanged<AnimeThemeInfo> onPlayTheme;
  final bool Function()? onArrowUpToPrev;
  final bool Function()? onArrowDownToNext;

  const _ThemeRow({
    super.key,
    required this.title,
    required this.items,
    required this.scrollController,
    required this.onPlayTheme,
    this.onArrowUpToPrev,
    this.onArrowDownToNext,
  });

  @override
  State<_ThemeRow> createState() => _ThemeRowState();
}

class _ThemeRowState extends State<_ThemeRow> {
  int? _focusedIndex;
  int? _lastFocusedIndex;
  final FocusNode _rowFocusNode = FocusNode(debugLabel: 'ThemeRow');
  late List<FocusNode> _dummyNodes;

  List<FocusNode> _buildDummyNodes(int count) => List.generate(
        count,
        (_) => FocusNode(skipTraversal: true, canRequestFocus: false),
      );

  @override
  void initState() {
    super.initState();
    _dummyNodes = _buildDummyNodes(widget.items.length);
  }

  @override
  void didUpdateWidget(covariant _ThemeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      if (_lastFocusedIndex != null &&
          _lastFocusedIndex! >= widget.items.length) {
        _lastFocusedIndex = null;
      }
      if (_focusedIndex != null && _focusedIndex! >= widget.items.length) {
        setState(() => _focusedIndex = null);
      }
      for (final n in _dummyNodes) {
        n.dispose();
      }
      _dummyNodes = _buildDummyNodes(widget.items.length);
    }
  }

  @override
  void dispose() {
    for (final n in _dummyNodes) {
      n.dispose();
    }
    _rowFocusNode.dispose();
    super.dispose();
  }

  bool focusRememberedCard() {
    if (widget.items.isEmpty) return false;
    _ensureRowVisible();
    final int idx = (_lastFocusedIndex ?? 0).clamp(0, widget.items.length - 1);
    _rowFocusNode.requestFocus();
    _setFocusedIndex(idx);
    return true;
  }

  void _ensureRowVisible() {
    if (mounted) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _scrollToIndex(int index, double cardWidth) {
    if (!widget.scrollController.hasClients) return;
    const double spacing = 16.0;
    final double targetOffset = index * (cardWidth + spacing);
    final double maxScroll = widget.scrollController.position.maxScrollExtent;
    final double clampedOffset = targetOffset.clamp(0.0, maxScroll);
    widget.scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _setFocusedIndex(int index) {
    if (!mounted) return;
    setState(() => _focusedIndex = index);
    _lastFocusedIndex = index;
    _scrollToIndex(index, 280.0);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final current = _focusedIndex ?? 0;
    final last = widget.items.length - 1;

    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < last) {
        _setFocusedIndex(current + 1);
        return KeyEventResult.handled;
      } else {
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (current > 0) {
        _setFocusedIndex(current - 1);
        return KeyEventResult.handled;
      } else {
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.onArrowDownToNext?.call() == true) return KeyEventResult.handled;
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.onArrowUpToPrev?.call() == true) return KeyEventResult.handled;
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      if (_focusedIndex != null && _focusedIndex! < widget.items.length) {
        widget.onPlayTheme(widget.items[_focusedIndex!]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    return Focus(
      focusNode: _rowFocusNode,
      onFocusChange: (focused) {
        setState(() {
          if (focused) {
            final idx =
                (_lastFocusedIndex ?? 0).clamp(0, widget.items.length - 1);
            _focusedIndex = idx;
            _scrollToIndex(idx, 280.0);
          } else {
            _focusedIndex = null;
          }
        });
      },
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 8),
            child: Text(
              widget.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 200,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.separated(
                  key: PageStorageKey('content-${widget.title.toLowerCase()}-row'),
                  controller: widget.scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final th = widget.items[index];
                    final bool isSelected = _focusedIndex == index;
                    return FocusableWideCard(
                      key: ValueKey(th.videoUrl.isNotEmpty
                          ? th.videoUrl
                          : '${widget.title}_$index'),
                      focusNode: _dummyNodes[index],
                      disableAutoEnsureVisible: true,
                      forceSelected: isSelected,
                      showBorder: true,
                      title: th.title,
                      imageUrl: th.imageUrl ?? '',
                      subtitle: th.artist.isNotEmpty
                          ? th.artist
                          : 'Artista desconocido',
                      width: 280,
                      height: 158,
                      onTap: () {
                        _setFocusedIndex(index);
                        widget.onPlayTheme(th);
                      },
                    );
                  },
                ),
                // El anillo de foco lo dibuja la propia tarjeta
                // (DisneyFocusShell): outline-4/outline-offset-4 en #FAFAFA a
                // 300ms que viaja con el tile en vez del marco fijo Prime.
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tooltip que se muestra cuando el widget hijo tiene foco/hover (D-pad TV),
/// en lugar del long-press del Tooltip nativo. Ubicado encima del botón.
class _FocusTooltip extends StatelessWidget {
  final bool show;
  final String label;
  final Widget child;
  const _FocusTooltip({required this.show, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        child,
        Positioned(
          bottom: 42,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: show ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
