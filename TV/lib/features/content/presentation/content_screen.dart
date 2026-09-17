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
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../../shared/widgets/full_screen_viewer.dart';
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
      borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, 3)),
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
    required this.detailAsync, 
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
  bool _revealed = false;
  Timer? _revealTimeout;

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
  
  @override void initState() {
    super.initState();
    _revealTimeout = Timer(ApiEndpoints.detailRevealTimeout, () {
      if (mounted && !_revealed) setState(() => _revealed = true);
    });
  }

  @override void dispose() { 
    _revealTimeout?.cancel();
    _disposeController(); 
    super.dispose(); 
  }

  @override Widget build(BuildContext context) {
    final d = widget.detailAsync.valueOrNull?.main;
    final logoReady = widget.detailAsync.hasValue;
    final b = DetailBackdropResolver.resolve(
      detail: d,
      bannerParam: widget.banner,
      poster: widget.poster,
      season: widget.currentSeason,
    );
    final heroTitle = widget.title;
    final width = MediaQuery.sizeOf(context).width;

    return MouseRegion(
      onHover: (_) => _handleInteraction(),
      child: Listener(
        onPointerDown: (_) => _handleInteraction(),
        onPointerMove: (_) => _handleInteraction(),
        onPointerHover: (_) => _handleInteraction(),
        child: Stack(clipBehavior: Clip.hardEdge, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(builder: (context, constraints) {
              final h = constraints.maxHeight; 
              final ph = h; 
              final pw = ph * (16 / 9);
              return Stack(fit: StackFit.expand, clipBehavior: Clip.hardEdge, children: [
                Container(color: const Color(0xFF0B0B0D)),
                if (b != null) Positioned.fill(child: ShaderMask(
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
                if (_trailerController != null && _lastTrailerKey != null) Positioned.fill(child: AnimatedOpacity(duration: const Duration(milliseconds: 500), opacity: _showPlayer ? 1.0 : 0.0, child: PointerInterceptor(child: IgnorePointer(ignoring: true, child: ClipRect(child: OverflowBox(alignment: Alignment.center, minWidth: pw, maxWidth: pw, minHeight: ph, maxHeight: ph, child: YouTubeTrailerPlayer(key: ValueKey(_lastTrailerKey), controller: _trailerController!, videoId: _lastTrailerKey!, autoPlay: true, mute: true, aspectRatio: 16 / 9))))))),
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
    final titleSize = ResponsiveUtils.sp(context, width < 1050 ? 22.0 : 36.0); 
    final contentSpacing = ResponsiveUtils.sp(context, 14.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 1200), 
          curve: Curves.easeInOut, 
          opacity: (_showPlayer && !_showTitle) ? 0.0 : 1.0, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroTitle(
                title: heroTitle,
                logo: d?.logo,
                logoReady: logoReady,
                maxWidth: width < 1050 ? width * 0.45 : 500.0,
                maxHeight: titleSize * 2.2,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize * 1.5,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: 1.5,
                  shadows: const [Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 8)]
                ),
              ),
              if (d is MovieDetail && d.originalTitle != null && d.originalTitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
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
          )
        ),
        SizedBox(height: contentSpacing * 1.5),
        _buildNetflixMetaRow(d),
        SizedBox(height: contentSpacing),
        _buildSynopsis(d),
        SizedBox(height: contentSpacing),
        _buildCastInfo(d),
        SizedBox(height: contentSpacing * 1.5),
        _buildCircularActions(context),
        SizedBox(height: contentSpacing * 2),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNetflixActionList(context),
                if (widget.totalSeasons > 1) ...[
                  SizedBox(height: contentSpacing),
                  SeasonSelector(
                    data: SeasonSelectorData(
                      currentSeason: widget.currentSeason,
                      totalSeasons: widget.totalSeasons,
                      onSeasonSelected: widget.onSeasonSelected,
                      compact: false,
                      enableFocus: true,
                      scale: ResponsiveUtils.sp,
                    ),
                  ),
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

  Widget _buildCircularActions(BuildContext context) {
    final size = ResponsiveUtils.sp(context, 42.0); 
    final iconSize = ResponsiveUtils.sp(context, 20.0); 
    final spacing = ResponsiveUtils.sp(context, 10.0);
    
    return Row(
      mainAxisSize: MainAxisSize.min, 
      children: [
        _DetailIconButton(icon: Icons.thumb_down_off_alt, label: 'No es para mí', onPressed: () {}, size: size, iconSize: iconSize), 
        SizedBox(width: spacing),
        _DetailIconButton(icon: Icons.thumb_up_off_alt, label: 'Me gusta', onPressed: () {}, size: size, iconSize: iconSize), 
        SizedBox(width: spacing),
        _DetailIconButton(icon: Icons.heart_broken_outlined, label: 'Me encanta', onPressed: () {}, size: size, iconSize: iconSize),
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
          style: GoogleFonts.poppins(color: Colors.white, fontSize: ResponsiveUtils.sp(context, 17), fontWeight: FontWeight.w600),
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
                else if (detail?.episodes != null) ...[ Text('${detail.episodes} Episodios') ],
                if (genres.isNotEmpty) ...genres.take(2).map((g) => _buildBadge(context, g.toUpperCase(), small: true)),
                if (r != null && r > 0) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, color: Colors.amber, size: ResponsiveUtils.sp(context, 20)), const SizedBox(width: 4), Text(formatRating(r) ?? 'N/A')]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (!_revealed) _SkeletonBox(width: ResponsiveUtils.sp(context, 200), height: ResponsiveUtils.sp(context, 16))
        else Row(children: [_buildAgeBadge(context, cert, small: true), const SizedBox(width: 12), Expanded(child: Text(_getWarningText(cert), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: const Color(0xFFA5A5AA), fontSize: ResponsiveUtils.sp(context, 14), fontWeight: FontWeight.w500)))]),
      ],
    );
  }

  Widget _buildCastInfo(dynamic d) {
    String castText = '';
    if (d is AnimeDetail) castText = d.characters.take(3).map((c) => c.name).join(', ');
    else if (d is MovieDetail) castText = d.cast.take(3).map((c) => c.name).join(', ');
    if (castText.isEmpty) return const SizedBox.shrink();
    return RichText(text: TextSpan(style: GoogleFonts.poppins(color: Colors.white70, fontSize: ResponsiveUtils.sp(context, 16), fontWeight: FontWeight.w500), children: [const TextSpan(text: 'Cast: ', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)), TextSpan(text: castText)]));
  }

  Widget _buildNetflixActionList(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final historyManager = ref.watch(playbackHistoryStateProvider.notifier);
      final latestHistory = historyManager.getLatestWatched(widget.title);
      final favorites = ref.watch(favoritesProvider);
      final String currentId = widget.url.isNotEmpty ? widget.url : widget.title;
      final bool isFav = favorites.any((f) => f.id == currentId);
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NetflixListButton(
            icon: Icons.play_arrow,
            label: (latestHistory != null && !latestHistory.isFinished) 
              ? (latestHistory.season != null ? 'Reanudar T${latestHistory.season}:EP ${latestHistory.episode}' : 'Reanudar Episodio ${latestHistory.episode}')
              : 'Reproducir',
            progress: latestHistory?.progress,
            isPrimary: true,
            autofocus: true,
            onPressed: widget.onPlay,
          ),
          const SizedBox(height: 10),
          _NetflixListButton(icon: Icons.replay, label: 'Reproducir desde el inicio', onPressed: widget.onPlay),
          const SizedBox(height: 10),
          if (_lastTrailerKey != null) _NetflixListButton(icon: Icons.movie_outlined, label: 'Ver tráiler', onPressed: () => _initTrailer(_lastTrailerKey!, immediate: true)),
          const SizedBox(height: 10),
          if (widget.totalSeasons > 1 || (widget.category != 'movie' && widget.category != 'movie_anime'))
            _NetflixListButton(icon: Icons.layers_outlined, label: 'Episodios y más', onPressed: () => widget.onShowEpisodes?.call()),
          const SizedBox(height: 10),
          _NetflixListButton(
            icon: isFav ? Icons.check : Icons.add,
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
              );
              ref.read(favoritesProvider.notifier).toggleFavorite(item);
            },
          ),
        ],
      );
    });
  }

  Widget _buildSynopsis(dynamic detail) {
    final text = detail?.overview ?? '';
    if (!_revealed && text.isEmpty) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_SkeletonBox(width: ResponsiveUtils.sp(context, 400), height: ResponsiveUtils.sp(context, 16)), const SizedBox(height: 8), _SkeletonBox(width: ResponsiveUtils.sp(context, 380), height: ResponsiveUtils.sp(context, 16))]);
    return Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: ResponsiveUtils.sp(context, 18), height: 1.3, fontWeight: FontWeight.w500));
  }

  Widget _buildUpperButtons(BuildContext context) {
    return Stack(children: [
      Positioned(top: ResponsiveUtils.sp(context, 20), left: ResponsiveUtils.sp(context, 30), child: PointerInterceptor(child: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white, size: ResponsiveUtils.sp(context, 24)), onPressed: () => Navigator.of(context).pop()))),
    ]);
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
        if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onPressed(); return KeyEventResult.handled;
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
            child: IconButton(
              icon: Icon(widget.icon, color: widget.color ?? (isActive ? Colors.white : Colors.white.withOpacity(0.6)), size: widget.iconSize ?? ResponsiveUtils.sp(context, 24)), 
              onPressed: widget.onPressed,
            )
          )
        )
      ),
    );
  }
}

class _NetflixListButton extends StatefulWidget {
  final IconData icon; final String label; final VoidCallback onPressed; final double? progress; final bool isPrimary; final bool autofocus;
  const _NetflixListButton({required this.icon, required this.label, required this.onPressed, this.progress, this.isPrimary = false, this.autofocus = false});
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
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          scale: isActive ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: ResponsiveUtils.sp(context, 480),
            height: ResponsiveUtils.sp(context, 52),
            decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(4)),
            child: InkWell(
              onTap: widget.onPressed,
              child: Stack(alignment: Alignment.centerLeft, children: [
                Padding(padding: const EdgeInsets.only(left: 6, right: 20), child: Row(children: [Icon(widget.icon, color: isActive ? Colors.black : const Color(0xFFC8C8CE), size: 28), const SizedBox(width: 10), Expanded(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isActive ? Colors.black : const Color(0xFFC8C8CE), fontSize: 18, fontWeight: FontWeight.w500)))])),
                if (widget.progress != null && widget.progress! > 0)
                  Positioned(right: 20, child: Container(width: 80, height: 6, decoration: BoxDecoration(color: isActive ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: widget.progress!.clamp(0.0, 1.0), child: Container(color: const Color(0xFFE50914))))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class ContentScreen extends ConsumerStatefulWidget {
  final String title; final String source; final String url; final String? quality; final String? type; final String? metadataTitle; final String? banner; final String category; final int? year; final int? totalSeasons; final String? sectionId; final SearchResult? result;
  const ContentScreen({super.key, required this.title, required this.source, required this.url, this.quality, this.type, this.metadataTitle, this.banner, this.category = 'all', this.year, this.totalSeasons, this.sectionId, this.result});
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
      kind: widget.result?.kind ?? widget.type,
      year: widget.year,
      season: widget.result?.season,
      source: widget.source,
      url: widget.url,
      type: widget.type,
      sectionId: widget.sectionId,
      initialSources: widget.result != null ? List.unmodifiable([widget.result!]) : null,
    );
    final detailState = ref.watch(unifiedContentProvider(detailParams));
    
    // [Intelligence] Tracking de personalización al entrar a la pantalla
    ref.watch(detailViewTrackerProvider(detailParams));

    // Senior Sync Fix: Sincronizar fuentes con el player de forma segura (sin microtasks)
    ref.listen<UnifiedContentState>(unifiedContentProvider(detailParams), (prev, next) {
      if (next.allSources.isNotEmpty) {
        final currentInPlayer = ref.read(activeContentSourcesProvider);
        if (!const ListEquality().equals(currentInPlayer, next.allSources)) {
          ref.read(activeContentSourcesProvider.notifier).state = next.allSources;
        }
      }
    });

    if (!_showContent) return Scaffold(backgroundColor: const Color(0xFF0B0B0D), body: _buildPageSkeleton(context));

    final detailData = detailState.detail.valueOrNull?.main;
    final currentSource = detailState.selectedSource;
    final heroBanner = ApiEndpoints.proxyImage(DetailBackdropResolver.resolve(detail: detailData, bannerParam: widget.banner, sourceBanner: detailState.allSources.isNotEmpty ? detailState.allSources.first.banner : null, season: detailState.currentSeason), highQuality: true);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D), 
      body: _ContentHeader(
        title: widget.title, source: widget.source, url: widget.url, category: widget.category, poster: ApiEndpoints.proxyImage(currentSource?.thumbnail), banner: heroBanner, detailAsync: detailState.detail, currentSource: currentSource, sources: detailState.allSources, totalSeasons: detailState.totalSeasons, currentSeason: detailState.currentSeason, onSourceSelected: (index) => ref.setSource(detailParams, detailState.allSources[index]), onSeasonSelected: (s) => ref.setSeason(detailParams, s), 
        onShowEpisodes: () {
          Navigator.of(context).push(PageRouteBuilder(opaque: false, barrierColor: Colors.black.withOpacity(0.5), pageBuilder: (context, _, __) => EpisodesDetailOverlay(detailData: detailData, sources: detailState.allSources, currentSource: currentSource, totalSeasons: detailState.totalSeasons, currentSeason: detailState.currentSeason, onSeasonSelected: (s) => ref.setSeason(detailParams, s), episodesAsync: detailState.episodes, category: widget.category, title: widget.title, bannerUrl: heroBanner, onPlayEpisode: (ep, epSource, total) {
            final epNum = ep.number; final effectiveSrc = epSource?.source ?? widget.source; final playEpisodesUrl = epSource?.url ?? widget.url; final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, detailState.currentSeason, epNum.toString());
            final epThumb = (ep.thumbnail?.isNotEmpty ?? false) ? ep.thumbnail! : (epSource?.thumbnail ?? currentSource?.thumbnail ?? '');
            context.push('/player/${Uri.encodeComponent(widget.title)}?source=${effectiveSrc}&url=${_episodeUrlFor(ep, playEpisodesUrl, effectiveSrc, epNum)}&episode=$epNum&season=${detailState.currentSeason}&serverName=${simplifySourceName(effectiveSrc)}&language=${(epSource?.quality.toLowerCase().contains('latino') ?? false) ? 'LAT' : 'SUB'}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=$total&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}');
          })));
        },
        inferredSeasonAirDate: detailState.episodes.valueOrNull?.response.seasonAirDate, 
        latestHistory: ref.watch(playbackHistoryStateProvider).valueOrNull?.where((h) => h.contentId == widget.title).firstOrNull, 
        onPlay: () {
          SearchResult? playSource = currentSource;
          final effectiveSrc = playSource?.source ?? widget.source;
          final playEpisodesUrl = playSource?.url ?? widget.url;
          if (detailState.isMovieish) {
            final ep = EpisodeInfo(number: 1, id: 0, url: playEpisodesUrl, title: 'Película', thumbnail: ApiEndpoints.proxyImage(playSource?.thumbnail));
            context.push('/player/${Uri.encodeComponent(widget.title)}?source=${effectiveSrc}&url=${_episodeUrlFor(ep, playEpisodesUrl, effectiveSrc, 1)}&episode=1&serverName=${simplifySourceName(effectiveSrc)}&language=${((playSource?.quality ?? '').toLowerCase().contains('latino')) ? 'LAT' : 'SUB'}&startPosition=&category=${widget.category}&totalEpisodes=1&posterUrl=${Uri.encodeComponent(playSource?.thumbnail ?? '')}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}');
            return;
          }
          final latest = ref.read(playbackHistoryStateProvider).valueOrNull?.where((h) => h.contentId == widget.title).firstOrNull;
          int epNum = latest != null ? int.tryParse(latest.episode ?? '1') ?? 1 : 1;
          final epData = detailState.episodes.valueOrNull?.response;
          final epSource = detailState.episodes.valueOrNull?.sourceForNumber(epNum) ?? currentSource;
          final ep = epData?.episodes.firstWhereOrNull((e) => e.number == epNum);
          final epThumb = ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? '';
          context.push('/player/${Uri.encodeComponent(widget.title)}?source=${epSource?.source ?? effectiveSrc}&url=${_episodeUrlFor(ep, epSource?.url ?? widget.url, epSource?.source ?? effectiveSrc, epNum)}&episode=$epNum&season=${latest?.season ?? detailState.currentSeason}&serverName=${simplifySourceName(epSource?.source ?? effectiveSrc)}&language=${(epSource?.quality.toLowerCase().contains('latino') ?? false) ? 'LAT' : 'SUB'}&startPosition=${latest?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${epData?.total ?? 0}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}');
        }
      ),
    );
  }

  Widget _buildPageSkeleton(BuildContext context) {
    return Stack(clipBehavior: Clip.hardEdge, children: [
      AspectRatio(aspectRatio: 3.2 / 1, child: Container(color: const Color(0xFF0B0B0D))),
      Positioned(left: 40, right: 40, bottom: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const _SkeletonBox(width: 400, height: 80), const SizedBox(height: 24), Row(mainAxisSize: MainAxisSize.min, children: [const _SkeletonBox(width: 64, height: 56, borderRadius: 28), const SizedBox(width: 16), const _SkeletonBox(width: 64, height: 56, borderRadius: 28)]), const SizedBox(height: 24), Container(width: 220, height: 56, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)))]))
    ]);
  }
}
