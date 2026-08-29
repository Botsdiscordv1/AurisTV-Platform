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

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../../shared/widgets/nav_arrow.dart';
import '../../../shared/widgets/full_screen_viewer.dart';
import 'episodes_detail_overlay.dart';

// --- Galería Local Helpers ---
final _galleryLocalProvider = FutureProvider.family<GalleryResponse, GalleryParams>((ref, params) async {
  return ref.watch(galleryProvider(params).future);
});

String _getWarningText(String? certification) => getWarningText(certification);

String? _pickDisplayDate(String? primary, String? fallback) {
  if (primary != null && primary.isNotEmpty) return primary;
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return null;
}

/// Fuentes como JKAnime devuelven episodios sin `url` (string vacía),
/// así que hay que reconstruirla desde la URL base del anime.
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
    return f == 'movie' || f == 'pel\u00EDcula' || f == 'ova' || f == 'ona' || f == 'special';
  }
  if (detail is MovieDetail) return detail.isMovie;
  return false;
}

int? _getRuntime(dynamic detail) {
  if (detail is AnimeDetail) return detail.duration;
  if (detail is MovieDetail) return detail.runtime;
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
        fontSize: ResponsiveUtils.sp(context, small ? 11 : 14), 
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
      horizontal: ResponsiveUtils.sp(context, small ? 5 : 8), 
      vertical: ResponsiveUtils.sp(context, small ? 1.5 : 3)
    ),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      border: Border.all(
        color: Colors.white10, 
        width: 1.0
      ),
      borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, small ? 3 : 4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white, 
        fontSize: ResponsiveUtils.sp(context, small ? 10 : 13), 
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

Widget _buildDotSeparator() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
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
  final AsyncValue<dynamic> animeDetailAsync; 
  final AsyncValue<dynamic> movieDetailAsync; 
  final SearchResult? currentSource; 
  final List<SearchResult> sources; 
  final Function(int) onSourceSelected; 
  final VoidCallback onPlay; 
  final double? sourceRating; 
  final bool showRatingSkeleton;
  final bool isLoadingSources;
  final int totalSeasons; 
  final int currentSeason; 
  final ValueChanged<int> onSeasonSelected;
  final String? inferredSeasonAirDate;
  final PlaybackHistory? latestHistory;
  final Set<String>? unavailableSources;
  final int? season;
  final VoidCallback? onShowEpisodes;

  const _ContentHeader({
    required this.title, 
    required this.source, 
    required this.url, 
    required this.category,
    this.poster, 
    this.banner, 
    required this.animeDetailAsync, 
    required this.movieDetailAsync, 
    this.currentSource, 
    required this.sources, 
    required this.onSourceSelected, 
    required this.onPlay, 
    this.sourceRating, 
    this.showRatingSkeleton = false,
    this.isLoadingSources = false,
    required this.totalSeasons, 
    required this.currentSeason, 
    required this.onSeasonSelected,
    this.inferredSeasonAirDate,
    this.latestHistory,
    this.unavailableSources,
    this.season,
    this.onShowEpisodes,
  });

  @override ConsumerState<_ContentHeader> createState() => _ContentHeaderState();
}

class _ContentHeaderState extends ConsumerState<_ContentHeader> {
  YouTubeTrailerPlayerController? _trailerController; Timer? _fadeTimer; String? _lastTrailerKey; bool _isMuted = true; bool _showPlayer = false; bool _isPlayedOnce = false; Timer? _delayTimer;
  bool _showTitle = true; Timer? _titleHideTimer;

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
  @override void didChangeDependencies() { super.didChangeDependencies(); _checkAndInitTrailer(); }
  @override void didUpdateWidget(covariant _ContentHeader oldWidget) { super.didUpdateWidget(oldWidget); _checkAndInitTrailer(); }
  void _checkAndInitTrailer() {
    final d = widget.category == 'movie_anime'
        ? (widget.movieDetailAsync.valueOrNull ?? widget.animeDetailAsync.valueOrNull)
        : (widget.animeDetailAsync.valueOrNull ?? widget.movieDetailAsync.valueOrNull);
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
  void _fadeOutAudio(YouTubeTrailerPlayerController ctrl) {
    _fadeTimer?.cancel(); 
    if (_isMuted) { 
      ctrl.pauseVideo(); 
      return; 
    }
    ctrl.setVolume(50);
    _fadeTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      ctrl.setVolume(0);
      _fadeTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        ctrl.mute();
        ctrl.pauseVideo();
      });
    });
  }
  void _disposeController() { _delayTimer?.cancel(); _fadeTimer?.cancel(); _titleHideTimer?.cancel(); _trailerController?.dispose(); _trailerController = null; }
  @override void dispose() { _disposeController(); super.dispose(); }

@override Widget build(BuildContext context) {
    final d = widget.category == 'movie_anime'
        ? (widget.movieDetailAsync.valueOrNull ?? widget.animeDetailAsync.valueOrNull)
        : (widget.animeDetailAsync.valueOrNull ?? widget.movieDetailAsync.valueOrNull);
    final logoReady = widget.animeDetailAsync.hasValue || widget.movieDetailAsync.hasValue;
    final b = (widget.banner?.isNotEmpty == true)
        ? widget.banner!
        : (d?.backdrop?.isNotEmpty == true ? d!.backdrop! : widget.poster);
    final heroTitle = stripSeasonSuffix(widget.title ?? '');
    final width = MediaQuery.sizeOf(context).width;

    return MouseRegion(
      onHover: (_) => _handleInteraction(),
      child: Listener(
        onPointerDown: (_) => _handleInteraction(),
        onPointerMove: (_) => _handleInteraction(),
        onPointerHover: (_) => _handleInteraction(),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          // FONDO INMERSIVO (Netflix Style) - Define el tamaño del Header
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(builder: (context, constraints) {
              final h = constraints.maxHeight; 
              final ph = h; 
              final pw = ph * (16 / 9);
              return Stack(fit: StackFit.expand, clipBehavior: Clip.hardEdge, children: [
                Container(color: const Color(0xFF0B0B0D)),
                if (b != null) Positioned(top: 0, left: 0, right: 0, bottom: 0, child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.black, Colors.black54, Colors.transparent],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800), 
                    tween: Tween<double>(begin: 0.0, end: _showPlayer ? 4.0 : 0.0), 
                    builder: (context, blur, child) => ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), 
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800), 
                        foregroundDecoration: BoxDecoration(color: Colors.black.withOpacity(_showPlayer ? 0.45 : 0.0)), 
                        child: CachedNetworkImage(imageUrl: b, fit: BoxFit.cover, alignment: Alignment.centerRight, fadeInDuration: const Duration(milliseconds: 300), errorWidget: (_, __, ___) => Container(color: Colors.black12))
                      )
                    )
                  ),
                )),
                if (_trailerController != null && _lastTrailerKey != null) Positioned(top: 0, left: 0, right: 0, bottom: 0, child: AnimatedOpacity(duration: const Duration(milliseconds: 500), opacity: _showPlayer ? 1.0 : 0.0, child: PointerInterceptor(child: IgnorePointer(ignoring: true, child: ClipRect(child: OverflowBox(alignment: Alignment.center, minWidth: pw, maxWidth: pw, minHeight: ph, maxHeight: ph, child: YouTubeTrailerPlayer(key: ValueKey(_lastTrailerKey), controller: _trailerController!, videoId: _lastTrailerKey!, autoPlay: true, mute: true, aspectRatio: 16 / 9))))))),
                
                // GRADIENTE LATERAL REFORZADO PARA TEXTO (Integrado aquí)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF0B0B0D).withOpacity(0.98),
                        const Color(0xFF0B0B0D).withOpacity(0.90),
                        const Color(0xFF0B0B0D).withOpacity(0.40),
                        const Color(0xFF0B0B0D).withOpacity(0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.25, 0.45, 0.65, 1.0],
                    ),
                  ),
                ),
                
                // BLOQUE DE CONTENIDO VERTICAL
                Positioned(
                  left: ResponsiveUtils.horizontalPadding(context), 
                  top: h * 0.12,
                  bottom: 20, 
                  child: SizedBox(
                    width: 520 * (width / 1600.0).clamp(0.8, 1.2),
                    child: _buildNetflixContentColumn(context, d, width, heroTitle, logoReady),
                  ),
                ),

                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [const Color(0xFF0B0B0D).withOpacity(0.5), Colors.transparent], stops: const [0.0, 0.4]))),
              ]);
            }),
          ),
          Positioned.fill(child: _buildUpperButtons(context)),
        ]),
      ),
    );
  }

  Widget _buildNetflixContentColumn(BuildContext context, dynamic d, double width, String heroTitle, bool logoReady) {
    final isUltraCompact = width < 1050; final isCompact = width >= 1050 && width < 1250;
    final titleSize = ResponsiveUtils.sp(context, isUltraCompact ? 22.0 : (isCompact ? 28.0 : 36.0)); 
    final contentSpacing = ResponsiveUtils.sp(context, 14.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        // 1. TÍTULO / LOGO
        AnimatedOpacity(
          duration: const Duration(milliseconds: 1200), 
          curve: Curves.easeInOut, 
          opacity: (_showPlayer && !_showTitle) ? 0.0 : 1.0, 
          child: HeroTitle(
            title: heroTitle,
            logo: d?.logo,
            logoReady: logoReady,
            maxWidth: isUltraCompact ? width * 0.45 : 500.0,
            maxHeight: titleSize * 2.2,
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize * 1.5,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: isUltraCompact ? 0.5 : 1.5,
              shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 8)]
            ),
          )
        ),
        SizedBox(height: contentSpacing * 1.5),

        // 2. METADATOS (Año, Rating, Duración)
        _buildNetflixMetaRow(d),
        SizedBox(height: contentSpacing),

        // 3. SINOPSIS
        _buildSynopsis(d, isCompact: false),
        SizedBox(height: contentSpacing),

        // 4. CAST (REPARTO)
        _buildCastInfo(d),
        SizedBox(height: contentSpacing * 1.5),

        // 5. ACCIONES RÁPIDAS (Pequeñas)
        _buildCircularActions(context, isCompact: true),
        SizedBox(height: contentSpacing * 2),

        // 6. LISTA DE ACCIONES VERTICALES (Estilo Netflix)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNetflixActionList(context),
                if (widget.totalSeasons > 1) ...[
                  SizedBox(height: contentSpacing),
                  _SeasonSelector(title: widget.title, currentSeason: widget.currentSeason, totalSeasons: widget.totalSeasons, onSeasonSelected: widget.onSeasonSelected, compact: false),
                ],
                if (widget.currentSource != null) ...[
                  SizedBox(height: contentSpacing),
                  SourceChipsBar(sources: widget.sources, currentSource: widget.currentSource, onSourceSelected: widget.onSourceSelected, unavailableSources: widget.unavailableSources, season: widget.season),
                ],
              ],
            ),
          ),
        ),
      ]
    );
  }

  Widget _buildCircularActions(BuildContext context, {bool isCompact = false}) {
    final size = ResponsiveUtils.sp(context, isCompact ? 42.0 : 48.0); 
    final iconSize = ResponsiveUtils.sp(context, isCompact ? 20.0 : 24.0); 
    final spacing = ResponsiveUtils.sp(context, isCompact ? 10.0 : 14.0);
    
    return Padding(
      padding: const EdgeInsets.only(left: 0), // Sin padding externo, controlaremos el inicio con el widget interno
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailIconButton(
            icon: Icons.thumb_down_off_alt, 
            label: 'No es para m\u00ED', 
            onPressed: () {
              // TODO: Lógica de No me gusta
            },
            size: size, 
            iconSize: iconSize
          ), 
          SizedBox(width: spacing),
          _DetailIconButton(
            icon: Icons.thumb_up_off_alt, 
            label: 'Me gusta', 
            onPressed: () {
              // TODO: Lógica de Like
            },
            size: size, 
            iconSize: iconSize
          ), 
          SizedBox(width: spacing),
          _DetailIconButton(
            icon: Icons.heart_broken_outlined, // Simulación de "Me encanta" (Double Like en la captura)
            label: 'Me encanta', 
            onPressed: () {
              // TODO: Lógica de Love
            },
            size: size, 
            iconSize: iconSize
          ),
        if (_trailerController != null && _showPlayer) ...[
          SizedBox(width: spacing),
          _DetailIconButton(
            icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, 
            label: _isMuted ? 'Activar audio' : 'Silenciar', 
            onPressed: () { 
              setState(() { 
                _isMuted = !_isMuted; 
                if (_isMuted) _trailerController?.mute(); 
                else { _trailerController?.unmute(); _trailerController!.setVolume(100); } 
              }); 
            }, 
            size: size, 
            iconSize: iconSize
          )
        ],
      ],
    ),
  );
}


  Widget _buildNetflixMetaRow(dynamic detail) {
    final r = (detail?.rating ?? widget.sourceRating) as double?;
    final rawDate = (detail is AnimeDetail) ? detail.firstAirDate : (detail is MovieDetail ? detail.releaseDate : null);
    final d = _pickDisplayDate(rawDate, widget.inferredSeasonAirDate); 
    final cert = (detail is MovieDetail ? detail.certification : (detail is AnimeDetail ? detail.certification : null)) ?? 'NR';
    final runtime = _getRuntime(detail);
    final isMovie = _isMovieContent(detail);

    final List<String> genres = (detail?.genres as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DefaultTextStyle(
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: ResponsiveUtils.sp(context, 17),
            fontWeight: FontWeight.w600,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              if (d != null && d.length >= 4) Text(d.substring(0, 4)),
              if (isMovie) ...[
                if (runtime != null) Text(_formatRuntime(runtime)),
              ] else if (widget.totalSeasons > 1) ...[
                Text('${widget.totalSeasons} Temporadas'),
              ] else if (detail?.episodes != null) ...[
                Text('${detail.episodes} Episodios'),
              ],
              if (genres.isNotEmpty) ...[
                ...genres.take(2).map((g) => _buildBadge(context, g.toUpperCase(), small: true)),
              ],
              if (r != null && r > 0) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: ResponsiveUtils.sp(context, 20)),
                    const SizedBox(width: 4),
                    Text(formatRating(r) ?? 'N/A'),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAgeBadge(context, cert, small: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getWarningText(cert),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFA5A5AA),
                  fontSize: ResponsiveUtils.sp(context, 14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCastInfo(dynamic d) {
    String castText = '';
    if (d is AnimeDetail) {
      castText = d.characters.take(3).map((c) => c.name).join(', ');
    } else if (d is MovieDetail) {
      castText = d.cast.take(3).map((c) => c.name).join(', ');
    }

    if (castText.isEmpty) return const SizedBox.shrink();

    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: ResponsiveUtils.sp(context, 16),
          fontWeight: FontWeight.w500,
        ),
        children: [
          const TextSpan(text: 'Cast: ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          TextSpan(text: castText),
        ],
      ),
    );
  }

  Widget _buildNetflixActionList(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('playback_history').listenable(), 
      builder: (ctx, box, _) {
        return Consumer(builder: (context, ref, child) {
          final historyManager = ref.watch(playbackHistoryStateProvider.notifier);
          final latestHistory = historyManager.getLatestWatched(widget.title);
          
          final favorites = ref.watch(favoritesProvider);
          final String currentId = widget.url.isNotEmpty ? widget.url : widget.title;
          final bool isFav = favorites.any((f) => f.id == currentId);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. REANUDAR (Con barra de progreso)
              if (latestHistory != null && !latestHistory.isFinished)
                _NetflixListButton(
                  icon: Icons.play_arrow,
                  label: latestHistory.season != null 
                    ? 'Reanudar T${latestHistory.season}:EP ${latestHistory.episode}' 
                    : 'Reanudar Episodio ${latestHistory.episode}',
                  progress: latestHistory.progress,
                  isPrimary: true,
                  autofocus: true,
                  onPressed: widget.onPlay,
                )
              else
                _NetflixListButton(
                  icon: Icons.play_arrow,
                  label: 'Reproducir',
                  isPrimary: true,
                  autofocus: true,
                  onPressed: widget.onPlay,
                ),
              
              const SizedBox(height: 10),

              // 2. REPRODUCIR DESDE EL INICIO
              _NetflixListButton(
                icon: Icons.replay,
                label: 'Reproducir desde el inicio',
                onPressed: () {
                  // TODO: Lógica para forzar inicio desde 0
                  widget.onPlay();
                },
              ),

              const SizedBox(height: 10),

              // 3. TRÁILER
              if (_lastTrailerKey != null)
                _NetflixListButton(
                  icon: Icons.movie_outlined,
                  label: 'Ver tráiler',
                  onPressed: () => _initTrailer(_lastTrailerKey!, immediate: true),
                ),

              const SizedBox(height: 10),

              // 4. EPISODIOS Y MÁS
              if (widget.totalSeasons > 1 || (widget.category != 'movie' && widget.category != 'movie_anime'))
                _NetflixListButton(
                  icon: Icons.layers_outlined,
                  label: 'Episodios y m\u00E1s',
                  onPressed: () => widget.onShowEpisodes?.call(),
                ),

              const SizedBox(height: 10),

              // 5. MI LISTA
              _NetflixListButton(
                icon: isFav ? Icons.check : Icons.add,
                label: isFav ? 'En mi lista' : 'Añadir a mi lista',
                onPressed: () {
                  final user = ref.read(authProvider);
                  final profileId = user?.activeProfileId ?? 'guest_profile';
                  final item = FavoriteItem(
                    id: currentId,
                    title: widget.title,
                    posterUrl: widget.poster ?? '',
                    bannerUrl: widget.banner ?? '',
                    category: widget.category,
                    source: widget.source,
                    url: widget.url,
                    addedAt: DateTime.now(),
                    profileId: profileId,
                  );
                  ref.read(favoritesProvider.notifier).toggleFavorite(item);
                },
              ),

              const SizedBox(height: 10),

              // 5. ELIMINAR DE SEGUIR VIENDO
              if (latestHistory != null)
                _NetflixListButton(
                  icon: Icons.close,
                  label: 'Eliminar de seguir viendo',
                  onPressed: () {
                    ref.read(playbackHistoryStateProvider.notifier).clearContentHistory(widget.title);
                  },
                ),
            ],
          );
        });
      }
    );
  }

  Widget _buildSynopsis(dynamic detail, {bool isCompact = false}) => Text(
    detail?.overview ?? '', 
    maxLines: 4, 
    overflow: TextOverflow.ellipsis, 
    style: TextStyle(
      color: Colors.white.withOpacity(0.9), 
      fontSize: ResponsiveUtils.sp(context, 18), // Aumentado para mejor legibilidad en TV
      height: 1.3, 
      fontWeight: FontWeight.w500, 
      letterSpacing: -0.1
    )
  );
  Widget _buildUpperButtons(BuildContext context) {
    return Stack(children: [
      Positioned(top: ResponsiveUtils.sp(context, 20), left: ResponsiveUtils.sp(context, 30), child: PointerInterceptor(child: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white, size: ResponsiveUtils.sp(context, 24)), onPressed: () => Navigator.of(context).pop()))),
    ]);
  }
}

class _SeasonSelector extends StatefulWidget {
  final String title; final int currentSeason; final int totalSeasons; final Function(int) onSeasonSelected; final bool compact;
  const _SeasonSelector({required this.title, required this.currentSeason, required this.totalSeasons, required this.onSeasonSelected, this.compact = false});
  @override State<_SeasonSelector> createState() => _SeasonSelectorState();
}

class _SeasonSelectorState extends State<_SeasonSelector> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isFocused;
    
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1E1E26)), 
      child: PopupMenuButton<int>(
        onSelected: widget.onSeasonSelected, 
        offset: Offset(0, ResponsiveUtils.sp(context, 50)), 
        constraints: BoxConstraints(minWidth: ResponsiveUtils.sp(context, 180)), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)), 
        itemBuilder: (context) => List.generate(widget.totalSeasons, (i) => PopupMenuItem(value: i + 1, height: ResponsiveUtils.sp(context, 48), child: Text('Temporada ${i + 1}', style: TextStyle(color: (i + 1) == widget.currentSeason ? Colors.white : const Color(0xFFA5A5AA), fontWeight: (i + 1) == widget.currentSeason ? FontWeight.bold : FontWeight.normal, fontSize: ResponsiveUtils.sp(context, 16))))), 
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true), 
            onExit: (_) => setState(() => _isHovered = false), 
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200), 
              width: ResponsiveUtils.sp(context, widget.compact ? 130 : 180), 
              height: ResponsiveUtils.sp(context, widget.compact ? 38 : 48), 
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF454652) : Colors.transparent, 
                borderRadius: BorderRadius.circular(8), 
                border: Border.all(
                  color: isActive ? Colors.white : Colors.white24, 
                  width: isActive ? 2.0 : 1.5
                ),
              ), 
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.sp(context, 16)), 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Text('T ${widget.currentSeason}', style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.sp(context, 18), fontWeight: FontWeight.bold)), 
                    Icon(Icons.keyboard_arrow_down, color: isActive ? Colors.white : const Color(0xFFA5A5AA), size: ResponsiveUtils.sp(context, 20))
                  ]
                )
              )
            )
          ),
        )
      )
    );
  }
}

class _ServerSelector extends ConsumerStatefulWidget {
  final SearchResult currentSource; final List<SearchResult> sources; final Function(int) onSourceSelected; final bool compact; final Set<String>? unavailableSources; final int? season;
  const _ServerSelector({required this.currentSource, required this.sources, required this.onSourceSelected, this.compact = false, this.unavailableSources, this.season});
  @override ConsumerState<_ServerSelector> createState() => _ServerSelectorState();
}

class _ServerSelectorState extends ConsumerState<_ServerSelector> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isFocused;
    final groupedSources = <String, int>{};
    for (int i = 0; i < widget.sources.length; i++) {
      final s = widget.sources[i];
      final sName = simplifySourceName(s.source);
      if (s.url == widget.currentSource.url) {
        groupedSources[sName] = i;
      } else if (!groupedSources.containsKey(sName)) {
        groupedSources[sName] = i;
      }
    }
    
    final uniqueIndices = groupedSources.values
        .where((i) => widget.unavailableSources?.contains(simplifySourceName(widget.sources[i].source)) != true)
        .where((i) {
          final s = widget.sources[i];
          if (s.source != 'AnimeD23') return true;
          final ok = ref.watch(d23SeasonCheckProvider((
            url: s.url,
            title: s.title,
            fullTitle: s.metadataTitle,
            category: 'anime',
            season: widget.season ?? s.season,
            year: s.year,
          ))).valueOrNull;
          return ok == true;
        })
        .toList();
    uniqueIndices.sort((a, b) => sourceDisplayRank(widget.sources[a].source)
        .compareTo(sourceDisplayRank(widget.sources[b].source)));

    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1E1E26)), 
      child: PopupMenuButton<int>(
        onSelected: widget.onSourceSelected, 
        offset: Offset(0, ResponsiveUtils.sp(context, 50)), 
        constraints: BoxConstraints(minWidth: ResponsiveUtils.sp(context, 180)), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)), 
        itemBuilder: (context) => uniqueIndices.map((i) {
          final s = widget.sources[i];
          final sName = simplifySourceName(s.source);
          final isSelected = sName == simplifySourceName(widget.currentSource.source);
          return PopupMenuItem(
            value: i,
            height: ResponsiveUtils.sp(context, 48),
            child: Row(children: [
              Expanded(child: Text(
                sName,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFA5A5AA),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: ResponsiveUtils.sp(context, 14)
                )
              )),
            ])
          );
        }).toList(),
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true), 
            onExit: (_) => setState(() => _isHovered = false), 
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200), 
              width: ResponsiveUtils.sp(context, widget.compact ? 130 : 180), 
              height: ResponsiveUtils.sp(context, widget.compact ? 38 : 48), 
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF454652) : Colors.transparent, 
                borderRadius: BorderRadius.circular(8), 
                border: Border.all(
                  color: isActive ? Colors.white : Colors.white24, 
                  width: isActive ? 2.0 : 1.5
                ),
              ), 
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.sp(context, 16)), 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Expanded(
                      child: Text(
                        simplifySourceName(widget.currentSource.source), 
                        overflow: TextOverflow.ellipsis, 
                        style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.sp(context, 16), fontWeight: FontWeight.bold)
                      )
                    ), 
                    Icon(Icons.dns_rounded, color: isActive ? Colors.white : const Color(0xFFA5A5AA), size: ResponsiveUtils.sp(context, 20))
                  ]
                )
              )
            )
          ),
        )
      )
    );
  }
}

Widget _episodePlaceholder(int episodeNumber) => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2C36), Color(0xFF14151A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          episodeNumber > 0 ? episodeNumber.toString() : '',
          style: const TextStyle(color: Colors.white38, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );

class _EpisodeCard extends ConsumerStatefulWidget {
  final int episodeNumber; final String title; final String description; final String imageUrl; final String fallbackImageUrl; final String? releaseDate; final String? duration; final String quality; final String? certification; final double? progress; final VoidCallback onTap;
  final ScrollController? scrollController;
  final String? episodeUrl;
  final String? source;
  final String? category;
  final String? episodeType;
  const _EpisodeCard({required this.episodeNumber, required this.title, required this.description, required this.imageUrl, required this.fallbackImageUrl, this.releaseDate, this.duration, required this.quality, this.certification, this.progress, required this.onTap, this.scrollController, this.episodeUrl, this.source, this.category, this.episodeType});
  @override ConsumerState<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends ConsumerState<_EpisodeCard> {
  bool _isHovered = false;
  bool _focused = false;

  String get _displayTitle {
    if (widget.episodeType != null) {
      if (widget.episodeType == 'special' && widget.episodeNumber > 0) {
        return '${widget.episodeNumber}. ${widget.title}';
      }
      return widget.title;
    }
    final String rawTitle = widget.title;
    if (widget.episodeNumber == 0) {
      final bool already = rawTitle.toLowerCase().startsWith('ep ') ||
          rawTitle.toLowerCase().startsWith('ep0') ||
          rawTitle.startsWith('0');
      return already ? rawTitle : 'EP 0 · $rawTitle';
    }
    final bool startsWithNumber = rawTitle.startsWith('${widget.episodeNumber}') || 
                                rawTitle.startsWith('0${widget.episodeNumber}') ||
                                rawTitle.toLowerCase().startsWith('episodio') ||
                                rawTitle.toLowerCase().startsWith('ep ') ||
                                rawTitle.contains('${widget.episodeNumber}\u00AA');
    return startsWithNumber ? rawTitle : '${widget.episodeNumber}. $rawTitle';
  }

  String? get _typeBadge {
    switch (widget.episodeType) {
      case 'movie': return 'MOVIE';
      case 'ova': return 'OVA';
      case 'special': return 'SPECIAL';
      default: return null;
    }
  }

  bool get _isSpecial => widget.episodeNumber == 0;

  String? get _languageBadge {    final q = widget.quality;
    if (q == null || q.isEmpty) return null;
    final isDub = isDubQuality(q);
    return isDub ? 'DUB' : 'SUB';
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    final double padding = ResponsiveUtils.sp(context, 6); 

    return Focus(
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter || 
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            focusColor: Colors.transparent, // Senior Fix: Quitar naranja de enfoque
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. MINIATURA
                  Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => CachedNetworkImage(
                            imageUrl: widget.fallbackImageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _episodePlaceholder(widget.episodeNumber),
                          ),
                        ),
                      ),
                    ),
                    if (widget.progress != null && widget.progress! > 0)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 3,
                          color: Colors.black26,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: widget.progress,
                            child: Container(color: const Color(0xFFEF7A1E)),
                          ),
                        ),
                      ),
                  ]),
                  SizedBox(height: ResponsiveUtils.sp(context, 10)),
                  
                  // 2. TÍTULO
                  Text(
                    _displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.sp(context, 14),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.sp(context, 4)),
                  
                  // 3. DESCRIPCIÓN
                  Expanded(
                    child: Text(
                      widget.description.isNotEmpty ? widget.description : 'Sin descripción disponible.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFA5A5AA),
                        fontSize: ResponsiveUtils.sp(context, 11),
                        height: 1.3,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.sp(context, 8)),
                  
                  // 4. METADATA
                  Row(
                    children: [
                      if (widget.certification != null && widget.certification != 'NR') ...[
                        _buildAgeBadge(context, widget.certification!, small: true),
                        SizedBox(width: ResponsiveUtils.sp(context, 6)),
                      ],
                      if (_typeBadge != null) ...[
                        _buildAgeBadge(context, _typeBadge!, small: true),
                        SizedBox(width: ResponsiveUtils.sp(context, 6)),
                      ],
                      if (_languageBadge != null) ...[
                        _buildAgeBadge(context, _languageBadge, small: true),
                        SizedBox(width: ResponsiveUtils.sp(context, 8)),
                      ],
                      if (!_isSpecial && widget.duration != null) ...[
                        Text(
                          widget.duration!,
                          style: TextStyle(
                            color: const Color(0xFFA5A5AA), 
                            fontSize: ResponsiveUtils.sp(context, 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (!_isSpecial && widget.releaseDate != null)
                        Text(
                          _formatDate(widget.releaseDate),
                          style: TextStyle(
                            color: const Color(0xFFA5A5AA), 
                            fontSize: ResponsiveUtils.sp(context, 10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }
}

class _EpisodesSkeleton extends StatelessWidget {
  const _EpisodesSkeleton();
  @override Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final count = (width < 1000 ? 2 : (width < 1400 ? 3 : (width < 2100 ? 4 : (width < 2800 ? 5 : 6))));
    final aspectRatio = (width < 1000 ? 1.25 : 1.1);
    return SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, mainAxisSpacing: 20, crossAxisSpacing: 20, childAspectRatio: aspectRatio), delegate: SliverChildBuilderDelegate((context, index) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ AspectRatio(aspectRatio: 16 / 9, child: Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)))), const SizedBox(height: 12), Container(height: 14, width: 80, color: Colors.white10), const SizedBox(height: 6), Container(height: 10, width: double.infinity, color: Colors.white10) ]), childCount: 8));
  }
}

class _ThemeCard extends StatefulWidget {
  final AnimeThemeInfo theme; final bool isOP; final String? fallbackImage;
  const _ThemeCard({required this.theme, required this.isOP, this.fallbackImage});
  @override State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _isHovered = false;

  @override Widget build(BuildContext context) {
    String? img = ApiEndpoints.proxyImage((widget.theme.imageUrl?.isNotEmpty == true) ? widget.theme.imageUrl! : widget.fallbackImage);
    final bool isSelected = _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true), 
      onExit: (_) => setState(() => _isHovered = false), 
      child: GestureDetector(
        onTap: () {
          String url = widget.theme.videoUrl; final typeLabel = widget.isOP ? 'OP' : 'ED';
          if (!url.startsWith('http')) { 
            url = 'https://www.youtube.com/watch?v=$url'; 
            context.push('/player/${Uri.encodeComponent(widget.theme.title)}?source=YouTube&url=${Uri.encodeComponent(url)}&episode=$typeLabel&serverName=YouTube&language=SUB'); 
          }
          else { 
            String url720 = widget.theme.video720 ?? '';
            String url1080 = widget.theme.video1080 ?? '';
            final v720Param = url720.isNotEmpty ? '&video720=${Uri.encodeComponent(url720)}' : '';
            final v1080Param = url1080.isNotEmpty ? '&video1080=${Uri.encodeComponent(url1080)}' : '';
            context.push('/player/${Uri.encodeComponent(widget.theme.title)}?source=&url=${Uri.encodeComponent(url)}&episode=$typeLabel&serverName=Themes&language=SUB$v720Param$v1080Param'); 
          }
        }, 
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white12, 
              width: isSelected ? 2.5 : 1
            ),
            boxShadow: isSelected 
              ? [BoxShadow(color: (widget.isOP ? Colors.blueAccent : Colors.pinkAccent).withOpacity(0.2), blurRadius: 15, spreadRadius: 1)] 
              : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand, 
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0, 
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutQuart,
                  child: img != null 
                    ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.white10)) 
                    : Container(color: Colors.white10),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200), 
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, 
                      end: Alignment.bottomCenter, 
                      colors: [
                        Colors.black.withOpacity(isSelected ? 0.2 : 0.4), 
                        Colors.black.withOpacity(isSelected ? 0.7 : 0.9)
                      ]
                    )
                  )
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12), 
                      decoration: BoxDecoration(
                        color: (widget.isOP ? Colors.blueAccent : Colors.pinkAccent).withOpacity(isSelected ? 1.0 : 0.8), 
                        shape: BoxShape.circle,
                        boxShadow: isSelected ? [BoxShadow(color: (widget.isOP ? Colors.blueAccent : Colors.pinkAccent).withOpacity(0.5), blurRadius: 10)] : [],
                      ), 
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32)
                    ),
                    const SizedBox(height: 12), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8), 
                      child: Text(
                        widget.theme.title, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      )
                    ),
                    Text(
                      widget.isOP ? 'OPENING' : 'ENDING', 
                      style: TextStyle(
                        color: (widget.isOP ? Colors.blueAccent.shade100 : Colors.pinkAccent.shade100).withOpacity(0.8), 
                        fontSize: 10, 
                        fontWeight: FontWeight.w900
                      )
                    )
                  ]
                ),
              ]
            )
          )
        )
      )
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text; final TextStyle style; final int maxLines;
  const _ExpandableText({required this.text, required this.style, this.maxLines = 4});
  @override State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  @override Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final tp = TextPainter(text: TextSpan(text: widget.text, style: widget.style), textDirection: ui.TextDirection.ltr, maxLines: widget.maxLines)..layout(maxWidth: constraints.maxWidth);
      final hasOverflow = tp.didExceedMaxLines;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.text, maxLines: _expanded ? null : widget.maxLines, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis, style: widget.style),
        if (hasOverflow) Padding(padding: const EdgeInsets.only(top: 8), child: InkWell(onTap: () => setState(() => _expanded = !_expanded), child: Text(_expanded ? 'Ver menos' : 'Ver m\u00E1s', style: TextStyle(color: widget.style.color?.withOpacity(0.8), fontWeight: FontWeight.bold)))),
      ]);
    });
  }
}

class _DetailButton extends StatefulWidget {
  final VoidCallback? onPressed; final IconData icon; final String label; final bool isPrimary; final bool compact; final bool isLoading;
  const _DetailButton({required this.onPressed, required this.icon, required this.label, this.isPrimary = false, this.compact = false, this.isLoading = false});

  @override
  State<_DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<_DetailButton> {
  bool _focused = false;
  bool _hovered = false;

  @override Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;
    final bool isActive = (_focused || _hovered) && !isDisabled;

    // Estilo Netflix de Home: Blanco con ligera opacidad al enfocar/hover
    final Color bgColor = widget.isPrimary 
        ? (isActive ? Colors.white.withOpacity(0.9) : Colors.white)
        : (isActive ? Colors.white.withOpacity(0.2) : Colors.white10);
    
    final Color fgColor = widget.isPrimary ? Colors.black : Colors.white;

    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !isDisabled) {
          if (event.logicalKey == LogicalKeyboardKey.enter || 
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: ResponsiveUtils.sp(context, widget.compact ? 38 : 48), 
          decoration: BoxDecoration(
            color: bgColor, 
            borderRadius: BorderRadius.circular(8),
            boxShadow: _focused ? [
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ] : [],
          ), 
          child: Material(
            color: Colors.transparent, 
            child: InkWell(
              onTap: isDisabled ? null : widget.onPressed, 
              borderRadius: BorderRadius.circular(8), 
              focusColor: Colors.transparent, // Desactivar resaltado naranja del tema
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.white.withOpacity(0.1),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.sp(context, 16)), 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    if (widget.isLoading) 
                      SizedBox(
                        width: ResponsiveUtils.sp(context, 20), 
                        height: ResponsiveUtils.sp(context, 20), 
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, 
                          color: fgColor,
                        )
                      )
                    else
                      Icon(widget.icon, color: fgColor, size: ResponsiveUtils.sp(context, 24)),
                    SizedBox(width: ResponsiveUtils.sp(context, 10)), 
                    Text(
                      widget.isLoading ? 'Buscando fuentes...' : widget.label, 
                      style: TextStyle(
                        color: fgColor, 
                        fontSize: ResponsiveUtils.sp(context, 18), 
                        fontWeight: FontWeight.bold
                      )
                    )
                  ]
                )
              )
            )
          )
        ),
      ),
    );
  }
}

class _DetailIconButton extends StatefulWidget {
  final IconData icon; final VoidCallback onPressed; final String label; final double? size; final double? iconSize; final Color? color;
  const _DetailIconButton({required this.icon, required this.onPressed, required this.label, this.size, this.iconSize, this.color});
  @override State<_DetailIconButton> createState() => _DetailIconButtonState();
}

class _DetailIconButtonState extends State<_DetailIconButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override Widget build(BuildContext context) {
    final bool isActive = _isHovered || _isFocused;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter || 
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true), 
        onExit: (_) => setState(() => _isHovered = false), 
        child: Tooltip(
          message: widget.label, 
          child: AnimatedScale(
            scale: isActive ? 1.1 : 1.0, 
            duration: const Duration(milliseconds: 200), 
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: widget.size ?? ResponsiveUtils.sp(context, 48), 
              width: widget.size ?? ResponsiveUtils.sp(context, 48), 
              decoration: const BoxDecoration(), 
              child: IconButton(
                icon: Icon(
                  widget.icon, 
                  color: widget.color ?? (isActive ? Colors.white : Colors.white.withOpacity(0.6)), 
                  size: widget.iconSize ?? ResponsiveUtils.sp(context, 24)
                ), 
                onPressed: widget.onPressed,
                style: IconButton.styleFrom(
                  focusColor: Colors.transparent, 
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
              )
            )
          )
        )
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  final Widget child; const _DetailInfoCard({required this.child});
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: EdgeInsets.all(ResponsiveUtils.sp(context, 20)), decoration: BoxDecoration(color: const Color(0xFF121519), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF66696E), width: 1.0)), child: child);
}

// --- MAIN WIDGETS ---

class ContentScreen extends ConsumerStatefulWidget {
  final String title; final String source; final String url; final String? metadataTitle; final String? banner; final String category; final int? year; final int? totalSeasons;
  final SearchResult? result;
  const ContentScreen({super.key, required this.title, required this.source, required this.url, this.metadataTitle, this.banner, this.category = 'all', this.year, this.totalSeasons, this.result});
  @override ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> {
  int _selectedSourceIndex = 0; int? _selectedSeason;
  int _selectedTabIndex = 0;
  bool _hasExtras = false; bool _tabRebuildPending = false;
  final Map<String, bool> _movieAvail = {};
  bool _movieValidating = false;
  bool _movieValidated = false;
  bool _movieValidationScheduled = false;
  final ScrollController _scrollController = ScrollController();
  bool _showContent = false;
  Timer? _loadTimer;
  String? _stableBanner;
  // Fuente por defecto congelada al abrir (mejor por rank presente en ese
  // momento) y clave de la fuente elegida manualmente por el usuario. Evitan el
  // parpadeo A23 -> AV1 cuando AV1/AnimeJara llegan tarde vía búsqueda suplementaria.
  String? _frozenDefaultKey;
  String? _userSelectedSourceKey;

  @override void initState() {
    super.initState();
    _loadTimer = Timer(const Duration(seconds: 130), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override void dispose() {
    _loadTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncExtras(bool desired) {
    if (_hasExtras == desired) return;
    final hasEpisodesTab = widget.category != 'movie' && widget.category != 'movie_anime' && !_isMovieLikeTitle(widget.title);
    final extrasInsertIndex = (hasEpisodesTab ? 1 : 0) + 1;
    int idx = _selectedTabIndex;
    if (_hasExtras && !desired) {
      idx = idx > extrasInsertIndex ? idx - 1 : (idx == extrasInsertIndex ? extrasInsertIndex - 1 : idx);
    } else {
      idx = idx >= extrasInsertIndex ? idx + 1 : idx;
    }
    _hasExtras = desired;
    _selectedTabIndex = idx.clamp(0, (hasEpisodesTab ? 1 : 0) + 1 + (desired ? 1 : 0) + 1 - 1);
    setState(() {});
  }

  void _validateMovieSources(List<SearchResult> sources) {
    if (sources.isEmpty || _movieValidated || _movieValidating) return;
    _movieValidating = true;
    final repo = ref.read(aurisRepositoryProvider);
    Future.wait(sources.map((s) async {
      final name = simplifySourceName(s.source);
      if (_movieAvail.containsKey(name)) return;
      try {
        final r = await repo.extractVideo(s.url ?? widget.url, s.source, category: widget.category, direct: true);
        final ok = (r.url.isNotEmpty && !r.url.contains('embed-undef')) ||
            r.tracks.any((t) => t.url.isNotEmpty) ||
            r.qualities.any((q) => q.url.isNotEmpty);
        _movieAvail[name] = ok;
      } catch (_) {
        _movieAvail[name] = true;
      }
    })).then((_) {
      _movieValidating = false;
      _movieValidated = true;
      final idx = sources.indexWhere((s) => _movieAvail[simplifySourceName(s.source)] == true);
      if (idx >= 0) {
        final curName = sources.isNotEmpty
            ? simplifySourceName(sources[_selectedSourceIndex % sources.length].source)
            : '';
        if (!_movieAvail.containsKey(curName) || _movieAvail[curName] != true) {
          _selectedSourceIndex = idx;
        }
      }
      if (mounted) setState(() {});
    });
  }

  Widget _buildTabBar(List<String> labels, int selectedIndex, double hPadding) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedTabIndex = i),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.sp(context, 12), vertical: ResponsiveUtils.sp(context, 8)),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: selected ? const Color(0xFFEF7A1E) : Colors.transparent, width: 3)),
              ),
              child: Text(labels[i], style: TextStyle(fontSize: ResponsiveUtils.sp(context, 18), fontWeight: FontWeight.w900, color: selected ? Colors.white : const Color(0xFFA5A5AA))),
            ),
          );
        }),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final hPadding = (width >= 800 && width < 1200 ? 24.0 : horizontalPadding);
    final episodesCrossAxisCount = (width < 1000 ? 5 : (width < 1400 ? 6 : (width < 2100 ? 6 : (width < 2800 ? 7 : 8))));
    final episodesAspectRatio = (width < 1000 ? 0.82 : 0.8); 

    final isAnimeCatFetch = widget.category == 'anime';
    final isMovieCatFetch = widget.category == 'movie' || widget.category == 'series' || widget.category == 'movie_anime' || _isMovieLikeTitle(widget.title) || widget.result?.kind?.toLowerCase() == 'movie' || widget.result?.kind?.toLowerCase() == 'series';
    final fetchAnimeDetail = isAnimeCatFetch || widget.category == 'movie_anime' || widget.category == 'all';

    const metadataSourceHints = {'anilist', 'tmdb', 'trakt', 'mal', 'jikan'};
    final isMetadataOriginSource = widget.source.isNotEmpty &&
        metadataSourceHints.contains(widget.source.toLowerCase());
    final String? originServer = (widget.source.isNotEmpty && !isMetadataOriginSource)
        ? ApiEndpoints.baseUrlForSource(widget.source)
        : (widget.category.toLowerCase() != 'all'
            ? ApiEndpoints.baseUrlForCategory(widget.category)
            : null);

    final animeDetailAsync = !fetchAnimeDetail
        ? const AsyncValue<AnimeDetail?>.data(null)
        : ref.watch(animeDetailProvider(AnimeDetailParams(title: widget.title, metadataTitle: widget.metadataTitle, year: widget.year, kind: widget.result?.kind)));

    final needMovieFallback = !isAnimeCatFetch &&
        !isMovieCatFetch &&
        !animeDetailAsync.isLoading &&
        animeDetailAsync.valueOrNull == null;

    final movieDetailAsync = isAnimeCatFetch
        ? const AsyncValue<MovieDetail?>.data(null)
        : (isMovieCatFetch || needMovieFallback)
            ? ref.watch(movieDetailProvider(MovieDetailParams(
                title: widget.title,
                metadataTitle: widget.metadataTitle,
                category: widget.category,
                server: originServer,
              )))
            : const AsyncValue<MovieDetail?>.data(null);

    final detailData = isMovieCatFetch
        ? (movieDetailAsync.valueOrNull ?? animeDetailAsync.valueOrNull)
        : (animeDetailAsync.valueOrNull ?? movieDetailAsync.valueOrNull);

    final resolvedKind = (detailData is AnimeDetail
            ? detailData.kind
            : (detailData is MovieDetail ? detailData.kind : null)) ??
        widget.result?.kind ??
        widget.category;
    final isAnimeCategory = resolvedKind == 'anime';
    final isMovieCategory = resolvedKind == 'movie' ||
        widget.result?.kind?.toLowerCase() == 'movie' ||
        _isMovieLikeTitle(widget.title);
    final effectiveCategory = isMovieCategory ? 'movie_anime' : widget.category;

    final detailLoading = (isMovieCategory ? movieDetailAsync.isLoading && animeDetailAsync.valueOrNull == null : animeDetailAsync.isLoading) || (isAnimeCategory ? false : movieDetailAsync.isLoading && animeDetailAsync.valueOrNull == null);

    final openedSeasonN = widget.result?.season
        ?? extractSeason(widget.result?.title)
        ?? extractSeason(widget.title)
        ?? extractSeason(widget.metadataTitle)
        ?? 1;
    final List<SearchResult> initialSources = widget.result != null
        ? [widget.result!]
        : [SearchResult(title: widget.title, url: widget.url, quality: 'TV', thumbnail: widget.banner ?? '', source: widget.source, romaji: widget.metadataTitle, year: widget.year, slug: null)];

    final sourcesParams = DiscoveredSourcesParams(title: widget.title, metadataTitle: widget.metadataTitle, category: effectiveCategory, year: widget.year, season: openedSeasonN, server: originServer, initialSources: initialSources);
    final searchSources = ref.watch(discoveredSourcesProvider(sourcesParams));

    final effectiveSeasonForUrl = _selectedSeason ?? (openedSeasonN > 1 ? openedSeasonN : null);

    final seasonSwitched = _selectedSeason != null && _selectedSeason != openedSeasonN;
    final seasonTitle = seasonSwitched ? seasonTitleFor(stripSeasonSuffix(widget.title ?? ''), _selectedSeason!) : null;
    final seasonSourcesParams = seasonTitle != null
        ? DiscoveredSourcesParams(title: seasonTitle, metadataTitle: seasonTitle, category: effectiveCategory, year: widget.year, season: _selectedSeason, server: originServer, initialSources: initialSources)
        : sourcesParams;
    final seasonSources = ref.watch(discoveredSourcesProvider(seasonSourcesParams));
    
    final seasonAnimeDetailAsync = seasonTitle != null
        ? ref.watch(animeDetailProvider(AnimeDetailParams(title: seasonTitle, metadataTitle: seasonTitle, year: null, season: _selectedSeason, kind: null)))
        : animeDetailAsync;
    final displayAnimeDetailAsync = seasonSwitched
        ? (seasonAnimeDetailAsync.valueOrNull != null ? seasonAnimeDetailAsync : animeDetailAsync)
        : animeDetailAsync;
    final displayDetail = isMovieCatFetch
        ? (movieDetailAsync.valueOrNull ?? displayAnimeDetailAsync.valueOrNull)
        : displayAnimeDetailAsync.valueOrNull;

    final hasEpisodesTab = widget.category != 'movie' && widget.category != 'movie_anime' && !_isMovieLikeTitle(widget.title);
    final _detailForExtras = displayAnimeDetailAsync.valueOrNull;
    final _desiredExtras = _detailForExtras != null &&
        (_detailForExtras.openings.isNotEmpty || _detailForExtras.endings.isNotEmpty);
    if (_detailForExtras != null && _desiredExtras != _hasExtras && !_tabRebuildPending) {
      _tabRebuildPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabRebuildPending = false;
        if (mounted) _syncExtras(_desiredExtras);
      });
    }
    int _ti = 0;
    final episodesTabIndex = hasEpisodesTab ? _ti++ : -1;
    final relatedTabIndex = _ti++;
    final extrasTabIndex = _hasExtras ? _ti++ : -1;
    final detailsTabIndex = _ti++;
    final galleryTabIndex = _ti++;

    final tabLabels = <String>[
      if (hasEpisodesTab) 'Episodios',
      'Relacionado',
      if (_hasExtras) 'Extras',
      'Detalles',
      'Galería',
    ];
    final selectedTabIndex = _selectedTabIndex.clamp(0, tabLabels.length - 1);

    final seasonUnifiedSources = searchSources
        .where((s) => isSeasonUnified(s.source))
        .map((s) => withSeasonUnified(s, effectiveSeasonForUrl))
        .where((s) => s != null)
        .cast<SearchResult>()
        .toList();

    final baseActive = seasonSources.isNotEmpty ? seasonSources : searchSources;
    final activeSources = <SearchResult>[
      ...baseActive.where((s) => !isSeasonUnified(s.source)),
      ...seasonUnifiedSources,
    ];
    activeSources.sort((a, b) => sourceDisplayRank(a.source).compareTo(sourceDisplayRank(b.source)));

    final searchQueryForLoading = widget.metadataTitle ?? widget.title;
    final searchLoading = ref.watch(contentSearchProvider(ContentSearchParams(
      query: searchQueryForLoading, 
      category: widget.category, 
      year: widget.year
    ))).isLoading;

    final dataReady = detailData != null || activeSources.isNotEmpty;
    if (dataReady && !_showContent) {
      _loadTimer?.cancel();
      _loadTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showContent = true);
      });
    }

    if (!_showContent) {
      return Scaffold(backgroundColor: const Color(0xFF0B0B0D), body: _buildPageSkeleton(context));
    }

    if (isMovieCategory && activeSources.isNotEmpty && !_movieValidationScheduled) {
      _movieValidationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _validateMovieSources(activeSources);
      });
    }

    // Selección de fuente estable: se congela la MEJOR fuente disponible al abrir
    // (por rank) para que, cuando AV1/AnimeJara lleguen tarde vía la búsqueda
    // suplementaria, la tarjeta no "parpadee" de A23 -> AV1. Los episodios se
    // cargan al instante desde esta fuente congelada; AV1 queda en el selector
    // para elegirla manualmente. La elección del usuario (_userSelectedSourceKey)
    // siempre tiene prioridad.
    String? _sourceKeyOf(SearchResult s) => '${s.source}|${s.url}';
    String? selectedKey = _userSelectedSourceKey ?? _frozenDefaultKey;
    if (_frozenDefaultKey == null && activeSources.isNotEmpty) {
      final ranked = [...activeSources]
        ..sort((a, b) => sourceDisplayRank(a.source).compareTo(sourceDisplayRank(b.source)));
      _frozenDefaultKey = _sourceKeyOf(ranked.first);
      selectedKey ??= _frozenDefaultKey;
    }
    int selIndex = 0;
    if (selectedKey != null && activeSources.isNotEmpty) {
      final found = activeSources.indexWhere((s) => _sourceKeyOf(s) == selectedKey);
      selIndex = found >= 0 ? found : (_selectedSourceIndex % activeSources.length);
    } else if (activeSources.isNotEmpty) {
      selIndex = _selectedSourceIndex % activeSources.length;
    }
    final rawCurrentSource = activeSources.isNotEmpty ? activeSources[selIndex] : null;
    final currentSource = withSeasonUnified(rawCurrentSource, effectiveSeasonForUrl);
    final episodesUrl = currentSource?.url ?? widget.url;
    final episodesSource = currentSource?.source ?? widget.source;
    final initialThumbnail = ApiEndpoints.proxyImage(currentSource?.thumbnail);
    final initialBanner = ApiEndpoints.proxyImage(widget.banner?.isNotEmpty == true ? widget.banner : (activeSources.isNotEmpty ? activeSources.first.banner : null));
    
    if (_stableBanner == null) {
      final detailBackdrop = detailData is MovieDetail
          ? (detailData as MovieDetail).backdrop
          : (detailData is AnimeDetail ? (detailData as AnimeDetail).backdrop : null);
      final candidate = widget.banner?.isNotEmpty == true
          ? widget.banner
          : (activeSources.isNotEmpty && activeSources.first.banner?.isNotEmpty == true
              ? activeSources.first.banner
              : (detailBackdrop?.isNotEmpty == true ? detailBackdrop : null));
      if (candidate?.isNotEmpty == true) {
        _stableBanner = ApiEndpoints.proxyImage(candidate);
      }
    }
    final stableBanner = _stableBanner ?? initialBanner;
    final familySourcesRaw = currentSource != null ? familySourcesFor(currentSource, activeSources) : <SearchResult>[];
    final familySources = familySourcesRaw.map((s) => withSeasonUnified(s, effectiveSeasonForUrl)!).toList();

    final historyAsync = ref.watch(playbackHistoryStateProvider);
    final history = historyAsync.valueOrNull ?? [];
    
    final unifiedRelationsAsync = ref.watch(unifiedRelationsProvider(searchSources));
    
    final certification = detailData != null ? ((detailData is MovieDetail ? (detailData as MovieDetail).certification : (detailData is AnimeDetail ? (detailData as AnimeDetail).certification : null)) ?? 'NR') : 'NR';
    final animeSeasonN = (detailData is AnimeDetail && detailData.season != null)
        ? (int.tryParse(detailData.season!) ?? openedSeasonN)
        : openedSeasonN;
    final currentSeason = _selectedSeason ??
        (detailData is MovieDetail
            ? (detailData.seasons.isNotEmpty ? detailData.seasons.first.seasonNumber : 1)
            : animeSeasonN);
    final seasonDetail = seasonAnimeDetailAsync.valueOrNull is AnimeDetail
        ? seasonAnimeDetailAsync.valueOrNull as AnimeDetail
        : null;
    final seasonBannerRaw = (seasonDetail != null && seasonDetail.backdrop?.isNotEmpty == true)
        ? seasonDetail.backdrop!
        : (seasonDetail != null && seasonDetail.poster?.isNotEmpty == true ? seasonDetail.poster! : null);
    final heroBanner = (seasonSwitched && seasonBannerRaw != null)
        ? ApiEndpoints.proxyImage(seasonBannerRaw)
        : stableBanner;
    final episodeLookupTitle = seasonSwitched
        ? (seasonDetail?.titleEnglish?.isNotEmpty == true
            ? seasonDetail!.titleEnglish!
            : seasonTitle!)
        : (widget.metadataTitle?.isNotEmpty == true ? widget.metadataTitle! : (detailData is AnimeDetail && detailData.titleEnglish?.isNotEmpty == true ? detailData.titleEnglish! : widget.title));

    const metadataSources = {'anilist', 'tmdb', 'trakt', 'mal', 'jikan'};
    final isMetadataSource = metadataSources.contains(episodesSource.toLowerCase());

    final episodeReqYear = seasonSwitched
        ? (seasonDetail?.year ?? widget.year)
        : widget.year;
    final episodeReqMetaTitle = seasonSwitched
        ? (seasonDetail?.titleEnglish?.isNotEmpty == true
            ? seasonDetail!.titleEnglish!
            : seasonTitle ?? widget.metadataTitle ?? widget.title)
        : (widget.metadataTitle?.isNotEmpty == true ? widget.metadataTitle! : widget.title);
    final episodeReqSeason = seasonSwitched ? _selectedSeason! : openedSeasonN;

    final episodesAsync = (isMovieCategory || widget.category == 'movie_anime')
        ? AsyncValue<GroupedEpisodesResult?>.data(GroupedEpisodesResult(
            response: EpisodesResponse(
              source: episodesSource,
              url: episodesUrl,
              slug: '',
              total: 1,
              episodes: [EpisodeInfo(number: 1, id: 0, url: episodesUrl, title: 'Pel\u00EDcula', thumbnail: initialThumbnail)],
            ),
            sources: [currentSource ?? SearchResult(title: widget.title, url: episodesUrl, quality: '', thumbnail: initialThumbnail ?? '', source: episodesSource)],
          ))
        : isMetadataSource
            ? const AsyncValue<GroupedEpisodesResult?>.loading()
            : ref.watch(groupedEpisodesProvider(GroupedEpisodesParams(
                title: seasonSwitched ? (seasonTitle ?? widget.title) : widget.title,
                metadataTitle: episodeReqMetaTitle,
                category: widget.category,
                year: episodeReqYear,
                season: episodeReqSeason,
                tmdbId: detailData is MovieDetail ? int.tryParse((detailData as MovieDetail).tmdbId) : null,
                familyKey: currentSource != null ? simplifySourceName(currentSource.source) : simplifySourceName(widget.source),
                currentSourceUrl: episodesUrl,
                sources: activeSources.isNotEmpty ? activeSources : (currentSource != null ? [currentSource] : <SearchResult>[]),
              )));

    SearchResult? episodeSourceForLocal(int episodeNumber) => episodesAsync.valueOrNull?.sourceForNumber(episodeNumber) ?? currentSource;
    final omdbSeasonAsync = isMovieCategory
        ? const AsyncValue<List<OmdbEpisode>>.data([])
        : ref.watch(omdbSeasonProvider(OmdbSeasonParams(title: episodeLookupTitle, season: currentSeason)));

    int totalSeasons = (detailData is MovieDetail)
        ? (detailData.totalSeasons ?? detailData.seasons.length)
        : (detailData is AnimeDetail ? (detailData.totalSeasons ?? 1) : 1);
    if (widget.totalSeasons != null && widget.totalSeasons! > totalSeasons) {
      totalSeasons = widget.totalSeasons!;
    }
    if (totalSeasons == 0) totalSeasons = 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D), 
      body: AnimatedOpacity(
        key: const ValueKey('content'), 
        opacity: 1.0, 
        duration: const Duration(milliseconds: 400), 
        child: _ContentHeader(
          title: widget.title, 
          source: widget.source, 
          url: widget.url, 
          category: widget.category,
          poster: initialThumbnail, 
          banner: heroBanner, 
          animeDetailAsync: displayAnimeDetailAsync, 
          movieDetailAsync: movieDetailAsync, 
          currentSource: currentSource, 
          sources: activeSources, 
          season: currentSeason, 
          sourceRating: currentSource?.score, 
          showRatingSkeleton: currentSource?.score == null && detailLoading, 
          isLoadingSources: searchLoading && activeSources.isEmpty,
          totalSeasons: totalSeasons, 
          currentSeason: currentSeason, 
          onSourceSelected: (index) {
            if (activeSources.isEmpty) return;
            setState(() {
              _selectedSourceIndex = index;
              _userSelectedSourceKey = '${activeSources[index].source}|${activeSources[index].url}';
            });
          },
          onSeasonSelected: (s) => setState(() => _selectedSeason = s), 
          onShowEpisodes: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                barrierColor: Colors.black.withOpacity(0.5),
                pageBuilder: (context, _, __) => EpisodesDetailOverlay(
                  detailData: displayDetail,
                  sources: activeSources,
                  currentSource: currentSource,
                  totalSeasons: totalSeasons,
                  currentSeason: currentSeason,
                  onSeasonSelected: (s) => setState(() => _selectedSeason = s),
                  episodesAsync: episodesAsync,
                  category: widget.category,
                  title: widget.title,
                  bannerUrl: heroBanner,
                  onPlayEpisode: (ep, epSource, total) {
                    final epNum = ep.number;
                    final src = epSource?.source ?? widget.source;
                    final playEpisodesUrl = epSource?.url ?? widget.url;
                    final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum.toString());
                    
                    final epThumb = (ep.thumbnail?.isNotEmpty ?? false) ? ep.thumbnail! : (epSource?.thumbnail ?? currentSource?.thumbnail ?? '');
                    final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
                    
                    context.push('/player/${Uri.encodeComponent(widget.title)}?source=${src}&url=${_episodeUrlFor(ep, playEpisodesUrl, src, epNum)}&episode=$epNum&season=$currentSeason&serverName=${simplifySourceName(src)}&language=${(epSource?.quality.toLowerCase().contains('latino') ?? false) ? 'LAT' : 'SUB'}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=$total$posterParam');
                  },
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          },
          inferredSeasonAirDate: episodesAsync.valueOrNull?.response.seasonAirDate, 
          latestHistory: ref.watch(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title), 
          unavailableSources: isMovieCategory ? _movieAvail.entries.where((e) => e.value == false).map((e) => e.key).toSet() : null, 
          onPlay: () {
            SearchResult? playSource = currentSource;
            if (isMovieCategory && playSource != null && _movieAvail[simplifySourceName(playSource.source)] == false) {
              playSource = activeSources.firstWhereOrNull((s) => _movieAvail[simplifySourceName(s.source)] == true) ?? playSource;
            }
            final src = playSource?.source ?? widget.source;
            final playEpisodesUrl = playSource?.url ?? widget.url;
            if (isMovieCategory) {
              final ep = EpisodeInfo(number: 1, id: 0, url: playEpisodesUrl, title: 'Pel\u00EDcula', thumbnail: initialThumbnail);
              final posterParam = '&title=${Uri.encodeComponent(widget.title)}&posterUrl=${Uri.encodeComponent(playSource?.thumbnail ?? '')}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
              context.push('/player/${Uri.encodeComponent(widget.title)}?source=${src}&url=${_episodeUrlFor(ep, playEpisodesUrl, src, 1)}&episode=1&serverName=${simplifySourceName(src)}&language=${((playSource?.quality ?? '').toLowerCase().contains('latino')) ? 'LAT' : 'SUB'}&startPosition=&category=${widget.category}&totalEpisodes=1$posterParam');
              return;
            }
            final latest = ref.read(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title);
            int epNum = latest != null ? int.tryParse(latest.episode ?? '1') ?? 1 : 1;
            final epData = episodesAsync.valueOrNull?.response;
            final epSource = episodeSourceForLocal(epNum) ?? currentSource;
            final ep = epData?.episodes.firstWhereOrNull((e) => e.number == epNum);
            
            final episodeThumb = ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? '';
            final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(episodeThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
            context.push('/player/${Uri.encodeComponent(widget.title)}?source=${epSource?.source ?? src}&url=${_episodeUrlFor(ep, epSource?.url ?? widget.url, epSource?.source ?? src, epNum)}&episode=$epNum&season=${latest?.season ?? currentSeason}&serverName=${simplifySourceName(epSource?.source ?? src)}&language=${(epSource?.quality.toLowerCase().contains('latino') ?? false) ? 'LAT' : 'SUB'}&startPosition=${latest?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${epData?.total ?? 0}$posterParam');
          }
        ),
      ),
    );
  }

  Widget _buildPageSkeleton(BuildContext context) {
    return AnimatedOpacity(
      key: const ValueKey('skeleton'),
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderSkeleton(context)),
          SliverToBoxAdapter(child: _buildTabsSkeleton(context)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.horizontalPadding(context)),
            sliver: const _EpisodesSkeleton(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton(BuildContext context) {
    return Stack(clipBehavior: Clip.hardEdge, children: [
      AspectRatio(aspectRatio: 3.2 / 1, child: Container(color: const Color(0xFF0B0B0D))),
      Positioned(
        left: 40, right: 40, bottom: 24,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const _SkeletonBox(width: 400, height: 80),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SkeletonBox(width: 64, height: 56, borderRadius: 28),
                const SizedBox(width: 16),
                const _SkeletonBox(width: 64, height: 56, borderRadius: 28),
                const SizedBox(width: 16),
                const _SkeletonBox(width: 64, height: 56, borderRadius: 28),
                const SizedBox(width: 16),
                const _SkeletonBox(width: 64, height: 56, borderRadius: 28),
              ],
            ),
            const SizedBox(height: 24),
            Container(width: 220, height: 56, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
          ]),
      ),
    ]);
  }

  Widget _buildTabsSkeleton(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPadding = (width >= 800 && width < 1200 ? 24.0 : ResponsiveUtils.horizontalPadding(context));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 32),
        Row(children: [
          _SkeletonBox(width: 100, height: 28),
          SizedBox(width: 24),
          _SkeletonBox(width: 100, height: 28),
          SizedBox(width: 24),
          _SkeletonBox(width: 90, height: 28),
        ]),
        SizedBox(height: 24),
      ]),
    );
  }

  List<Widget> _buildRelatedTab(
    double hPadding, {
    Map<String, List<RelatedInfo>>? unifiedRelations,
    SearchResult? currentSource,
  }) {
    if (unifiedRelations == null || unifiedRelations.isEmpty) {
      return [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Colors.white24))))];
    }
    
    final List<RelatedInfo> franchiseSource = unifiedRelations['franchise'] ?? [];
    final List<RelatedInfo> genreSource = unifiedRelations['genre'] ?? [];
    final List<RelatedInfo> recommendedSource = unifiedRelations['recommended'] ?? [];

    if (franchiseSource.isEmpty && genreSource.isEmpty && recommendedSource.isEmpty) {
      return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay contenido relacionado disponible', style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 18)))))];
    }

    return [
      if (franchiseSource.isNotEmpty)
        _RelatedCarouselRow(
          title: 'Franquicia y Secuelas',
          hPadding: hPadding,
          items: _unifyAndDeduplicateLocal(
            sourceItems: franchiseSource,
            currentSource: currentSource,
          ),
        ),

      if (recommendedSource.isNotEmpty)
        _RelatedCarouselRow(
          title: 'Te recomendamos',
          hPadding: hPadding,
          items: _unifyAndDeduplicateLocal(
            sourceItems: recommendedSource,
            currentSource: currentSource,
            isRecommendation: true,
          ),
        ),

      if (genreSource.isNotEmpty)
        _RelatedCarouselRow(
          title: 'Mismo G\u00E9nero',
          hPadding: hPadding,
          items: genreSource.map((r) => _RelatedCardData(
            title: _cleanRelatedTitleLocal(r.title), 
            poster: r.cover, 
            subtitle: r.relation,
            onTap: () => context.push('/content/${Uri.encodeComponent(r.title)}?source=${currentSource?.source ?? widget.source}&category=anime&url=${Uri.encodeComponent(r.url)}&metadataTitle=${Uri.encodeComponent(r.title)}')
          )).toList(),
        ),
    ];
  }

  String _cleanRelatedTitleLocal(String t) =>
      t.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim();

  List<_RelatedCardData> _unifyAndDeduplicateLocal({
    required List<RelatedInfo> sourceItems,
    SearchResult? currentSource,
    bool isRecommendation = false,
  }) {
    final Map<String, _RelatedCardData> unifiedMap = {};
    String normalize(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (var r in sourceItems) {
      final displayTitle = _cleanRelatedTitleLocal(r.title);
      final key = normalize(displayTitle);
      unifiedMap[key] = _RelatedCardData(
        title: displayTitle,
        poster: r.cover,
        subtitle: r.relation,
        onTap: () => context.push('/content/${Uri.encodeComponent(r.title)}?source=${currentSource?.source ?? widget.source}&category=anime&url=${Uri.encodeComponent(r.url)}&metadataTitle=${Uri.encodeComponent(r.title)}'),
      );
    }
    return unifiedMap.values.toList();
  }

  List<Widget> _buildGalleryTab(double hPadding, String kind, String? title, int? year) {
    return [
      _GalleryTabContent(
        hPadding: hPadding,
        kind: kind,
        title: title,
        year: year,
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Widget> _buildExtrasTab(AnimeDetail? detail, double hPadding) {
    if (detail == null) return [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Colors.white24))))];
    final ops = detail.openings; final eds = detail.endings;
    if (ops.isEmpty && eds.isEmpty) return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay temas musicales disponibles', style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 18)))))];
    return [
      if (ops.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: const Text('Openings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: ops[index], isOP: true, fallbackImage: detail.banner ?? detail.backdrop), childCount: ops.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
      if (eds.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: const Text('Endings', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: eds[index], isOP: false, fallbackImage: detail.banner ?? detail.backdrop), childCount: eds.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
    ];
  }

  List<Widget> _buildDetailsTab(dynamic detail, double hPadding, {String? inferredSeasonAirDate, double? sourceRating, bool showRatingSkeleton = false}) {
    if (detail == null) return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    final rating = formatRating((detail.rating as double?) ?? sourceRating);
    final effectiveDate = _pickDisplayDate((detail is AnimeDetail ? detail.firstAirDate : detail.releaseDate), inferredSeasonAirDate);
    final year = effectiveDate?.split('-').first ?? 'N/A';
    String sInfo = _isMovieContent(detail) ? _formatRuntime(_getRuntime(detail)) : (detail is AnimeDetail ? '${detail.episodes ?? 0} episodios' : (detail is MovieDetail ? '${detail.totalSeasons ?? 1} temporadas' : ''));
    List<String> dir = [], cast = [], std = [];
    if (detail is MovieDetail) { dir = detail.directors; cast = detail.cast.take(5).map((e) => e.name).toList(); std = detail.productionCompanies; }
    else if (detail is AnimeDetail) { std = detail.studios; }
    final cert = (detail is MovieDetail ? detail.certification : (detail is AnimeDetail ? detail.certification : null)) ?? 'NR';
    final platforms = detail is MovieDetail ? detail.platforms : <PlatformInfo>[];
    final status = detail is MovieDetail ? detail.status : (detail is AnimeDetail ? detail.status : null);
    final languages = detail is MovieDetail ? detail.languages : <String>[];

    return [ 
      SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 20), sliver: SliverToBoxAdapter(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 15, child: Column(children: [
          _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detail.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)), const SizedBox(height: 10),
            Wrap(spacing: 8, children: [ Text(detail is AnimeDetail ? 'Jap\u00F3n' : 'Internacional', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17)), const Text('•', style: TextStyle(color: Colors.white24)), Text(detail is AnimeDetail ? 'Anime' : 'Pel\u00EDcula', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17)) ]), const SizedBox(height: 10),
            Row(children: [ const Text('IMDb ', style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 17, fontWeight: FontWeight.w900)), if (showRatingSkeleton && rating == null) const _RatingSkeleton(width: 36, height: 18) else Text(rating ?? 'N/A', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17)), const Text('/10', style: TextStyle(color: Color(0xFFA5A5AA))), const SizedBox(width: 16), Text(year, style: const TextStyle(color: Color(0xFFA5A5AA))), if (sInfo.isNotEmpty) ...[const SizedBox(width: 16), Text(sInfo, style: const TextStyle(color: Color(0xFFA5A5AA)))] ]), const SizedBox(height: 16),
            if (detail.genres is List) ...[
              Wrap(spacing: 8, runSpacing: 8, children: (detail.genres as List).map<Widget>((g) => _buildBadge(context, g.toString().toUpperCase())).toList()),
              const SizedBox(height: 20),
            ],
            _ExpandableText(text: detail.overview ?? '', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 20), maxLines: 4)
          ])),
          const SizedBox(height: 24), if (dir.isNotEmpty || cast.isNotEmpty || std.isNotEmpty || status != null || languages.isNotEmpty) _DetailInfoCard(child: Column(children: [ 
            if (status != null) _buildPrimeRowLocal('Estado', status),
            if (languages.isNotEmpty) _buildPrimeRowLocal('idiomas', languages.join(', ')),
            if (dir.isNotEmpty) _buildPrimeRowLocal('Direcci\u00F3n', dir.join(', ')), 
            if (cast.isNotEmpty && detail is! MovieDetail) _buildPrimeRowLocal('Elenco', cast.join(', ')), 
            if (std.isNotEmpty) _buildPrimeRowLocal('Estudio', std.join(', ')) 
          ]))
        ])),
        const SizedBox(width: 24), Expanded(flex: 10, child: Column(
          children: [
            _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Advertencias de contenido', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 16), _buildAgeBadge(context, cert), const SizedBox(height: 16), Text('${getWarningText(cert)} Las luces intermitentes pueden afectar a espectadores fotosensibles', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 20)) ])),
            if (platforms.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Disponible en', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Wrap(spacing: 16, runSpacing: 16, children: platforms.map<Widget>((p) => _PlatformLogoLocal(platform: p)).toList()),
              ])),
            ],
          ],
        ))
      ]))),
      ..._buildCharacterSectionLocal(detail, hPadding),
      ..._buildCastSectionLocal(detail, hPadding),
    ];
  }

  List<Widget> _buildCharacterSectionLocal(dynamic detail, double hPadding) {
    if (detail is! AnimeDetail || detail.characters.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPadding, ResponsiveUtils.sp(context, 24), hPadding, ResponsiveUtils.sp(context, 12)), 
          child: Text(
            'Personajes y Actores de Voz', 
            style: GoogleFonts.poppins(
              fontSize: ResponsiveUtils.sp(context, 22),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: _CharacterCarouselLocal(characters: detail.characters, horizontalPadding: hPadding)),
      SliverToBoxAdapter(child: SizedBox(height: ResponsiveUtils.sp(context, 24))),
    ];
  }

  List<Widget> _buildCastSectionLocal(dynamic detail, double hPadding) {
    if (detail is! MovieDetail || detail.cast.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPadding, ResponsiveUtils.sp(context, 24), hPadding, ResponsiveUtils.sp(context, 12)), 
          child: Text(
            'Elenco Principal', 
            style: GoogleFonts.poppins(
              fontSize: ResponsiveUtils.sp(context, 22),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: _CastCarouselLocal(cast: detail.cast, horizontalPadding: hPadding)),
      SliverToBoxAdapter(child: SizedBox(height: ResponsiveUtils.sp(context, 24))),
    ];
  }

  Widget _buildPrimeRowLocal(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17, fontWeight: FontWeight.w600))), Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 17)))]));
}

class _RelatedCardData {
  final String title;
  final String poster;
  final String subtitle;
  final String? rating;
  final VoidCallback onTap;
  _RelatedCardData({required this.title, required this.poster, required this.subtitle, this.rating, required this.onTap});
}

class _RelatedCarouselRow extends StatefulWidget {
  final String title;
  final double hPadding;
  final List<_RelatedCardData> items;
  const _RelatedCarouselRow({required this.title, required this.hPadding, required this.items});
  @override State<_RelatedCarouselRow> createState() => _RelatedCarouselRowState();
}

class _RelatedCarouselRowState extends State<_RelatedCarouselRow> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    setState(() {
      _canScrollLeft = currentScroll > 5;
      _canScrollRight = maxScroll > currentScroll + 5;
    });
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = 200.0;
    const carouselHeight = 400.0;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
            child: Text(
              widget.title, 
              style: GoogleFonts.poppins(
                fontSize: ResponsiveUtils.sp(context, 22),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              children: [
                SizedBox(
                  height: carouselHeight,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _updateScrollIndicators();
                      return false;
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: EdgeInsets.only(
                        left: widget.hPadding, 
                        right: widget.hPadding,
                        top: 20, 
                        bottom: 20,
                      ),
                      itemCount: widget.items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return SizedBox(
                          width: cardWidth,
                          child: FocusablePosterCard(
                            title: item.title,
                            posterUrl: item.poster,
                            subtitle: item.subtitle,
                            rating: item.rating,
                            showInfo: true,
                            onTap: item.onTap,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 0, top: 20, bottom: 90,
                  child: AnimatedOpacity(
                    opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !(_isHovered && _canScrollLeft),
                      child: Center(child: NavArrow(icon: Icons.arrow_back_ios_new, useBackground: true, onTap: () => _scroll(-cardWidth * 3))),
                    ),
                  ),
                ),
                Positioned(
                  right: 0, top: 20, bottom: 90,
                  child: AnimatedOpacity(
                    opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !(_isHovered && _canScrollRight),
                      child: Center(child: NavArrow(icon: Icons.arrow_forward_ios, useBackground: true, onTap: () => _scroll(cardWidth * 3))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterCarouselLocal extends StatefulWidget {
  final List<CharacterInfo> characters;
  final double horizontalPadding;
  const _CharacterCarouselLocal({required this.characters, required this.horizontalPadding});
  @override State<_CharacterCarouselLocal> createState() => _CharacterCarouselLocalState();
}

class _CharacterCarouselLocalState extends State<_CharacterCarouselLocal> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 5;
    final canRight = maxScroll > currentScroll + 5;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() { _canScrollLeft = canLeft; _canScrollRight = canRight; });
    }
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = (_scrollController.offset + offset).clamp(0.0, maxScroll);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = 160.0;
    const carouselHeight = 320.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          SizedBox(
            height: carouselHeight,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) { _updateScrollIndicators(); return false; },
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
                itemCount: widget.characters.length,
                itemBuilder: (context, index) => _CharacterCardLocal(character: widget.characters[index], width: cardWidth),
              ),
            ),
          ),
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: NavArrow(icon: Icons.arrow_back_ios_new, useBackground: true, onTap: () => _scroll(-cardWidth * 3)),
              ),
            ),
          ),
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: NavArrow(icon: Icons.arrow_forward_ios, useBackground: true, onTap: () => _scroll(cardWidth * 3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformLogoLocal extends StatelessWidget {
  final PlatformInfo platform;
  final double size;
  const _PlatformLogoLocal({required this.platform, this.size = 48});
  @override Widget build(BuildContext context) {
    return Tooltip(
      message: platform.providerName,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          border: Border.all(color: Colors.white10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: CachedNetworkImage(
            imageUrl: platform.logo ?? '',
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Center(
              child: Text(
                platform.providerName.substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CastCarouselLocal extends StatefulWidget {
  final List<CastMember> cast;
  final double horizontalPadding;
  const _CastCarouselLocal({required this.cast, required this.horizontalPadding});
  @override State<_CastCarouselLocal> createState() => _CastCarouselLocalState();
}

class _CastCarouselLocalState extends State<_CastCarouselLocal> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 5;
    final canRight = maxScroll > currentScroll + 5;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() { _canScrollLeft = canLeft; _canScrollRight = canRight; });
    }
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final target = (_scrollController.offset + offset).clamp(0.0, maxScroll);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = 160.0;
    const carouselHeight = 320.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          SizedBox(
            height: carouselHeight,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) { _updateScrollIndicators(); return false; },
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
                itemCount: widget.cast.length,
                itemBuilder: (context, index) => _CastCardLocal(member: widget.cast[index], width: cardWidth),
              ),
            ),
          ),
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: NavArrow(icon: Icons.arrow_back_ios_new, useBackground: true, onTap: () => _scroll(-cardWidth * 3)),
              ),
            ),
          ),
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: NavArrow(icon: Icons.arrow_forward_ios, useBackground: true, onTap: () => _scroll(cardWidth * 3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastCardLocal extends StatelessWidget {
  final CastMember member;
  final double width;
  const _CastCardLocal({required this.member, required this.width});
  @override Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1 / 1.2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: member.profile ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorWidget: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.person, color: Colors.white24, size: 40)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            member.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 4),
          if (member.character != null)
            Text(
              member.character!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 14),
            ),
        ],
      ),
    );
  }
}

class _CharacterCardLocal extends StatelessWidget {
  final CharacterInfo character;
  final double width;
  const _CharacterCardLocal({required this.character, required this.width});
  String _translateRoleLocal(String? role) {
    if (role == null) return '';
    final r = role.toLowerCase();
    if (r == 'main') return 'Principal';
    if (r == 'supporting') return 'Secundario';
    if (r == 'background') return 'Fondo';
    return role;
  }
  @override Widget build(BuildContext context) {
    final voiceActor = character.voiceActors.firstWhereOrNull((va) => va.language == 'Japanese') ?? character.voiceActors.firstOrNull;
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1 / 1.2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: character.image ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorWidget: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.person, color: Colors.white24, size: 40)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            character.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 4),
          if (voiceActor != null)
            Text(
              voiceActor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 14),
            ),
          const SizedBox(height: 2),
          Text(
            _translateRoleLocal(character.role),
            style: TextStyle(color: (character.role?.toLowerCase() == 'main') ? const Color(0xFFEF7A1E) : Colors.white24, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _GalleryTabContent extends ConsumerStatefulWidget {
  final double hPadding;
  final String kind;
  final String? title;
  final int? year;
  const _GalleryTabContent({required this.hPadding, required this.kind, this.title, this.year});
  @override ConsumerState<_GalleryTabContent> createState() => _GalleryTabContentState();
}

class _GalleryTabContentState extends ConsumerState<_GalleryTabContent> {
  String _selectedFilter = "all";
  @override Widget build(BuildContext context) {
    final params = GalleryParams(kind: widget.kind, title: stripSeasonSuffix(widget.title ?? ''), year: widget.year);
    final async = ref.watch(galleryProvider(params));
    return async.when(
      loading: () => SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
            childCount: 15,
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text("Error al cargar la galería", style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 18)),
          ),
        ),
      ),
      data: (g) {
        if (g.gallery.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text("No hay imágenes disponibles", style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 18)),
              ),
            ),
          );
        }
        final filtered = _selectedFilter == "all" ? g.gallery : g.gallery.where((img) => img.type == _selectedFilter).toList();
        final hasPosters = g.gallery.any((img) => img.type == "poster");
        final hasBackdrops = g.gallery.any((img) => img.type == "backdrop");
        final hasLogos = g.gallery.any((img) => img.type == "logo");
        final hasBanners = g.gallery.any((img) => img.type == "banner");
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.hPadding, vertical: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _GalleryFilterChipLocal(label: "Todos", selected: _selectedFilter == "all", onSelected: () => setState(() => _selectedFilter = "all")),
                      if (hasPosters) ...[ const SizedBox(width: 8), _GalleryFilterChipLocal(label: "Pósters", selected: _selectedFilter == "poster", onSelected: () => setState(() => _selectedFilter = "poster")) ],
                      if (hasBackdrops) ...[ const SizedBox(width: 8), _GalleryFilterChipLocal(label: "Fondos", selected: _selectedFilter == "backdrop", onSelected: () => setState(() => _selectedFilter = "backdrop")) ],
                      if (hasLogos) ...[ const SizedBox(width: 8), _GalleryFilterChipLocal(label: "Logos", selected: _selectedFilter == "logo", onSelected: () => setState(() => _selectedFilter = "logo")) ],
                      if (hasBanners) ...[ const SizedBox(width: 8), _GalleryFilterChipLocal(label: "Banners", selected: _selectedFilter == "banner", onSelected: () => setState(() => _selectedFilter = "banner")) ],
                    ],
                  ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text("No hay imágenes de este tipo", style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 16)))))
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: (_selectedFilter == "backdrop" || _selectedFilter == "banner" ? 4 : 6),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _selectedFilter == "backdrop" ? 16 / 9 : (_selectedFilter == "banner" ? 3.0 : (_selectedFilter == "logo" ? 1.0 : 0.67)),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final img = filtered[index];
                      return _GalleryItemLocal(
                        image: img,
                        onTap: () {
                          Navigator.of(context).push(PageRouteBuilder(opaque: false, barrierColor: Colors.black.withOpacity(0.5), pageBuilder: (context, _, __) => FullScreenViewer(images: filtered, initialIndex: index), transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child)));
                        },
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GalleryFilterChipLocal extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onSelected;
  const _GalleryFilterChipLocal({required this.label, required this.selected, required this.onSelected});
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: selected ? const Color(0xFFEF7A1E) : Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? const Color(0xFFEF7A1E) : Colors.white24, width: 1)),
        child: Text(label, style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
      ),
    );
  }
}

class _GalleryItemLocal extends StatefulWidget {
  final GalleryImage image; final VoidCallback onTap;
  const _GalleryItemLocal({required this.image, required this.onTap});
  @override State<_GalleryItemLocal> createState() => _GalleryItemLocalState();
}

class _GalleryItemLocalState extends State<_GalleryItemLocal> {
  bool _isHovered = false;
  String _getTypeLabelLocal(String type) {
    switch (type) {
      case "logo": return "Logo";
      case "backdrop": return "Fondo";
      case "banner": return "Banner";
      case "poster": return "Póster";
      default: return type.toUpperCase();
    }
  }
  @override Widget build(BuildContext context) {
    final url = ApiEndpoints.proxyImage(widget.image.url);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Hero(
          tag: "gallery_${widget.image.url}",
          child: AnimatedScale(
            scale: _isHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _isHovered ? const Color(0xFFEF7A1E) : Colors.white10, width: 2), boxShadow: _isHovered ? [BoxShadow(color: const Color(0xFFEF7A1E).withOpacity(0.3), blurRadius: 10, spreadRadius: 2)] : []),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: url, fit: widget.image.type == "logo" ? BoxFit.contain : BoxFit.cover, placeholder: (_, __) => Container(color: Colors.white10), errorWidget: (_, __, ___) => Container(color: Colors.white10)),
                    if (_isHovered) Container(color: Colors.black26),
                    Positioned(top: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text(_getTypeLabelLocal(widget.image.type), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                    Positioned(bottom: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), child: Text(widget.image.source.toUpperCase(), style: const TextStyle(color: Color(0xFF9AA0FF), fontSize: 10, fontWeight: FontWeight.bold)))),
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

class _NetflixListButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double? progress;
  final bool isPrimary;
  final bool autofocus;

  const _NetflixListButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.progress,
    this.isPrimary = false,
    this.autofocus = false,
  });

  @override
  State<_NetflixListButton> createState() => _NetflixListButtonState();
}

class _NetflixListButtonState extends State<_NetflixListButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focused = widget.autofocus;
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = _focused || _hovered;
    final Color bgColor = isActive ? Colors.white : Colors.transparent;
    final Color fgColor = isActive ? Colors.black : const Color(0xFFC8C8CE);

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: isActive ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: ResponsiveUtils.sp(context, 480),
            height: ResponsiveUtils.sp(context, 52),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4), // Redondeo sutil exacto de la captura
            ),
            clipBehavior: Clip.antiAlias, // Obligatorio para que se vea la curva en blanco sólido
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(4),
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashColor: isActive ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 20), // Padding izquierdo ajustado a 6
                      child: Row(
                        children: [
                          Icon(widget.icon, color: fgColor, size: 28),
                          const SizedBox(width: 10), // Más apegado como en la captura
                          Expanded(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fgColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w500, // Peso medio como en la captura
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.progress != null && widget.progress! > 0)
                      Positioned(
                        right: 20,
                        child: Container(
                          width: 80,
                          height: 6,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: widget.progress!.clamp(0.0, 1.0),
                            child: Container(
                              color: const Color(0xFFE50914), // Netflix Red
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
      ),
    );
  }
}
