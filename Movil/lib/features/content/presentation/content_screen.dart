import 'dart:async';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/foundation.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../../shared/widgets/nav_arrow.dart';
import '../../../shared/widgets/full_screen_viewer.dart';

// --- Galería Local Helpers ---
final _galleryLocalProvider = FutureProvider.family<GalleryResponse, GalleryParams>((ref, params) async {
  return ref.watch(galleryProvider(params).future);
});

bool _isDubQuality(String q) => isDubQuality(q);
bool _isMovieResult(SearchResult r) => isMovieResult(r);
int? _extractSeason(String? s) => extractSeason(s);
String _stripSeasonSuffix(String? title) => stripSeasonSuffix(title ?? '');
String _seasonTitleFor(String baseTitle, int season) => seasonTitleFor(baseTitle, season);
String _seasonTitleRoman(String baseTitle, int season) => seasonTitleRoman(baseTitle, season);
bool _isSeasonUnified(String source) => isSeasonUnified(source);
String _sourceSignature(SearchResult source) => sourceSignature(source);
SearchResult? _withSeasonUnified(SearchResult? source, int? season) => withSeasonUnified(source, season);
List<SearchResult> _familySourcesFor(SearchResult currentSource, List<SearchResult> sources) => familySourcesFor(currentSource, sources);
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

String _getWarningText(String? certification) {
  if (certification == null || certification.isEmpty || certification == 'NR') return 'Contenido no calificado. Se recomienda discreci\u00F3n del espectador.';
  final cert = certification.toUpperCase();
  if (cert.contains('18') || cert == 'TV-MA' || cert == 'R' || cert.contains('NC-17')) return 'Violencia expl\u00EDcita, lenguaje fuerte, contenido sexual, consumo de sustancias.';
  if (cert.contains('16') || cert == 'TV-14') return 'Violencia moderada, lenguaje malsonante, temas sugerentes.';
  if (cert.contains('12') || cert == 'PG-13' || cert == 'TV-PG') return 'Acci\u00F3n intensa, lenguaje moderado, algunas escenas de riesgo.';
  if (cert.contains('7') || cert == 'PG') return 'Fantas\u00EDa suave, algunas escenas de miedo o acci\u00F3n ligera.';
  if (cert == 'G' || cert == 'ALL' || cert.contains('U')) return 'Apto para todos los p\u00FAblicos. Sin advertencias espec\u00EDficas.';
  return 'Se recomienda discreci\u00F3n del espectador.';
}

bool _isMovieLikeTitle(String title) {
  return RegExp(r'\b(movie|film)\b|pel[\u00EDi]culas?', caseSensitive: false).hasMatch(title);
}

bool _isMovieContent(dynamic detail) {
  if (detail is AnimeDetail) {
    final f = detail.format?.toLowerCase() ?? '';
    return f == 'movie' || f == 'Pel\u00EDcula' || f == 'ova' || f == 'ona' || f == 'special';
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
      horizontal: ResponsiveUtils.sp(context, small ? 5 : 8), 
      vertical: ResponsiveUtils.sp(context, small ? 1.5 : 3)
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
        fontSize: ResponsiveUtils.sp(context, small ? 10 : 13), 
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

String _formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    // Manejar formato YYYY-MM-DD o ISO
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

// --- SUB-WIDGETS ---

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
  });

  @override ConsumerState<_ContentHeader> createState() => _ContentHeaderState();
}

class _ContentHeaderState extends ConsumerState<_ContentHeader> {
  YoutubePlayerController? _ytController; StreamSubscription? _ytSubscription; Timer? _fadeTimer; String? _lastTrailerKey; bool _isMuted = true; bool _showPlayer = false; bool _isPlayedOnce = false; Timer? _delayTimer;
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
      if (_ytController != null) {
        _fadeTimer?.cancel(); _ytController!.pauseVideo(); _ytController!.seekTo(seconds: 0);
        if (!_isMuted) { _ytController!.unMute(); _ytController!.setVolume(100); } else { _ytController!.mute(); }
        _ytController!.playVideo();
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
      final ctrl = YoutubePlayerController.fromVideoId(videoId: key, autoPlay: true, params: const YoutubePlayerParams(showControls: false, showFullscreenButton: false, mute: true, loop: false, showVideoAnnotations: false, playsInline: true, strictRelatedVideos: true, enableKeyboard: false));
      ctrl.listen((state) {
        if (state.playerState == PlayerState.cued && mounted) { ctrl.playVideo(); }
        if (state.playerState == PlayerState.playing && mounted && !_showPlayer) { 
          setState(() { _showPlayer = true; _showTitle = true; }); 
          _startTitleHideTimer();
        }
        if (state.playerState == PlayerState.ended && mounted) { 
          setState(() { _showPlayer = false; _isPlayedOnce = true; _showTitle = true; }); 
          _titleHideTimer?.cancel();
        }
      });
      _ytSubscription = ctrl.videoStateStream.listen((state) {
        final d = ctrl.value.metaData.duration.inSeconds; final p = state.position.inSeconds;
        if (p > 0 && !_showPlayer && mounted) { 
          setState(() { _showPlayer = true; _showTitle = true; }); 
          _startTitleHideTimer();
        }
        
        // Senior Fix: Sincronizar desaparición de Tráiler y audio en los últimos 12 segundos.
        if (p > 5 && d > 30 && (d - p) < 12) { 
          if (_showPlayer && mounted) { 
            setState(() { 
              _showPlayer = false; 
              _isPlayedOnce = true; 
              _showTitle = true;
            }); 
            _titleHideTimer?.cancel();
            // Iniciar desvanecimiento sincronizado con la animación (500ms).
            _fadeOutAudio(ctrl); 
          } 
        }
      });
      if (mounted) {
        setState(() { _ytController = ctrl; _showPlayer = false; _isPlayedOnce = false; _showTitle = true; });
        _titleHideTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 400), () { 
          if (mounted) { 
            ctrl.playVideo(); 
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
  void _fadeOutAudio(YoutubePlayerController ctrl) {
    _fadeTimer?.cancel(); 
    if (_isMuted) { 
      ctrl.pauseVideo(); 
      return; 
    }
    
    // Senior: Desvanecimiento en 3 pasos para no saturar el iframe y asegurar la pausa final.
    // Paso 1: 50% volumen
    ctrl.setVolume(50);
    
    _fadeTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      // Paso 2: 0% volumen
      ctrl.setVolume(0);
      
      _fadeTimer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        // Paso 3: Silencio total y Pausa definitiva
        ctrl.mute();
        ctrl.pauseVideo();
      });
    });
  }
  void _disposeController() { _delayTimer?.cancel(); _fadeTimer?.cancel(); _titleHideTimer?.cancel(); _ytSubscription?.cancel(); _ytSubscription = null; _ytController?.close(); _ytController = null; }
  @override void dispose() { _disposeController(); super.dispose(); }

  Widget _buildMetaRow(dynamic d, {required bool isMobile}) {
    final year = (d is AnimeDetail) ? d.year?.toString() : (d is MovieDetail ? d.releaseDate?.split('-').first : null);
    final rating = (d is AnimeDetail) ? d.rating?.toStringAsFixed(1) : (d is MovieDetail ? d.rating?.toStringAsFixed(1) : null);
    
    // Obtenemos géneros
    List<String> genres = [];
    if (d is AnimeDetail) genres = d.genres;
    else if (d is MovieDetail) genres = d.genres;

    // Obtenemos certificación (priorizando detalle)
    final cert = (d != null && d.certification != null && d.certification!.isNotEmpty) ? d.certification : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Badges (Certificación + Géneros)
        if ((cert != null && cert.isNotEmpty && cert != 'NR') || genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (cert != null && cert.isNotEmpty && cert != 'NR') ...[
                    _buildAgeBadge(context, cert.toUpperCase(), small: false),
                    const SizedBox(width: 8),
                  ],
                  ...genres.take(5).map((g) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBadge(context, g.toUpperCase(), small: false),
                  )),
                ],
              ),
            ),
          ),
        
        // Fila 2: Rating (Estrella Amarilla) y Año
        Row(
          children: [
            if (rating != null) ...[
              const Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
              const SizedBox(width: 6),
              Text(rating, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
            ],
            if (year != null)
              Text(year, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildMainActionButton(BuildContext context, {required bool isMobile}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.onPlay,
        icon: const Icon(Icons.play_arrow, size: 24, color: Colors.black),
        label: const Text("Reproducir", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildCircularActions(BuildContext context, {required bool isMobile}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionSquareButton(icon: Icons.movie_outlined, label: "Tráiler", onTap: () {}),
        _ActionSquareButton(icon: Icons.add, label: "Mi lista", onTap: () {}),
        _ActionSquareButton(icon: Icons.thumb_up_outlined, label: "Me gusta", onTap: () {}),
        _ActionSquareButton(icon: Icons.thumb_down_outlined, label: "No es para mí", onTap: () {}),
      ],
    );
  }

  Widget _heroTitleWidget(String title, String? logo, bool logoReady, double maxW, double maxH, TextStyle style) {
    // Mientras el detalle carga y aún no sabemos si hay logo, no mostramos nada
    // (ni el texto del título) para evitar el parpadeo de texto antes del logo.
    if (!logoReady) {
      return SizedBox(width: maxW, height: maxH);
    }
    if (logo != null && logo.isNotEmpty) {
      return SizedBox(
        width: maxW,
        height: maxH,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: CachedNetworkImage(
            imageUrl: logo,
            height: maxH,
            fit: BoxFit.contain,
            fadeInDuration: const Duration(milliseconds: 300),
            // Vacío mientras descarga; si nunca llega/falla, caemos al texto.
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => Text(
              title.toUpperCase(), 
              style: style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    // El detalle cargó pero no hay logo: mostramos el título como respaldo.
    return Text(
      title.toUpperCase(), 
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override Widget build(BuildContext context) {
    final d = widget.category == 'movie_anime'
        ? (widget.movieDetailAsync.valueOrNull ?? widget.animeDetailAsync.valueOrNull)
        : (widget.animeDetailAsync.valueOrNull ?? widget.movieDetailAsync.valueOrNull);
    final logoReady = widget.animeDetailAsync.hasValue || widget.movieDetailAsync.hasValue;
    final b = (widget.banner?.isNotEmpty == true)
        ? widget.banner!
        : (d?.backdrop?.isNotEmpty == true ? d!.backdrop! : widget.poster);
    final heroTitle = _stripSeasonSuffix(widget.title);

    return MouseRegion(
      onHover: (_) => _handleInteraction(),
      child: Listener(
        onPointerDown: (_) => _handleInteraction(),
        onPointerMove: (_) => _handleInteraction(),
        onPointerHover: (_) => _handleInteraction(),
        child: Column(children: [
          Stack(clipBehavior: Clip.hardEdge, children: [
            AspectRatio(aspectRatio: 16 / 12, child: LayoutBuilder(builder: (context, constraints) {
              final h = constraints.maxHeight; final ph = h * 1.35; final pw = ph * (16 / 9);
              return Stack(fit: StackFit.expand, clipBehavior: Clip.hardEdge, children: [
                Container(color: const Color(0xFF0B0B0D)),
                if (b != null) Positioned.fill(child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.transparent],
                    stops: [0.4, 1.0],
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
                        child: CachedNetworkImage(imageUrl: b, fit: BoxFit.cover, alignment: Alignment.topCenter, fadeInDuration: const Duration(milliseconds: 300), errorWidget: (_, __, ___) => Container(color: Colors.black12))
                      )
                    )
                  ),
                )),
                if (_ytController != null) Positioned.fill(child: AnimatedOpacity(duration: const Duration(milliseconds: 500), opacity: _showPlayer ? 1.0 : 0.0, child: PointerInterceptor(child: IgnorePointer(ignoring: true, child: ClipRect(child: OverflowBox(alignment: Alignment.center, minWidth: pw, maxWidth: pw, minHeight: ph, maxHeight: ph, child: YoutubePlayer(key: ValueKey(_lastTrailerKey), controller: _ytController!, aspectRatio: 16 / 9))))))),
                Positioned(left: 20, bottom: 16, right: 20, child: AnimatedOpacity(duration: const Duration(milliseconds: 1200), curve: Curves.easeInOut, opacity: (_showPlayer && !_showTitle) ? 0.0 : 1.0, child: _heroTitleWidget(heroTitle, d?.logo, logoReady, double.infinity, 80, const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.1, letterSpacing: 4, shadows: [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 4), Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 10)])))),
              ]);
            })),
            Positioned.fill(child: _buildUpperButtons(context)),
          ]),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 8), _buildMetaRow(d, isMobile: true), 
            const SizedBox(height: 24), _buildMainActionButton(context, isMobile: true), 
            const SizedBox(height: 16), _buildCircularActions(context, isMobile: true),
            const SizedBox(height: 16),
            if (widget.totalSeasons > 1 || widget.currentSource != null) ...[
              Row(
                children: [
                  if (widget.totalSeasons > 1) 
                    Expanded(
                      child: _SeasonSelector(
                        title: widget.title, 
                        currentSeason: widget.currentSeason, 
                        totalSeasons: widget.totalSeasons, 
                        onSeasonSelected: widget.onSeasonSelected, 
                        compact: true
                      ),
                    ),
                  if (widget.totalSeasons > 1 && widget.currentSource != null) const SizedBox(width: 12),
                  if (widget.currentSource != null) 
                    Expanded(
                      child: SourceChipsBar(
                        sources: widget.sources, 
                        currentSource: widget.currentSource, 
                        onSourceSelected: widget.onSourceSelected, 
                        unavailableSources: widget.unavailableSources,
                        season: widget.season,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ])),
        ]),
      ),
    );
  }

  Widget _buildUpperButtons(BuildContext context) {
    return Stack(children: [
      Positioned(top: 45, left: 15, child: PointerInterceptor(child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => Navigator.of(context).pop()))),
      Positioned(top: 45, right: 15, child: PointerInterceptor(child: IconButton(icon: const Icon(Icons.cast, color: Colors.white, size: 24), onPressed: () {}))),
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
  @override Widget build(BuildContext context) => Theme(data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1E1E26)), child: PopupMenuButton<int>(onSelected: widget.onSeasonSelected, offset: const Offset(0, 56), constraints: const BoxConstraints(minWidth: 220), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)), itemBuilder: (context) => List.generate(widget.totalSeasons, (i) => PopupMenuItem(value: i + 1, height: 56, child: Text('Temporada ${i + 1}', style: TextStyle(color: (i + 1) == widget.currentSeason ? Colors.white : const Color(0xFFA5A5AA), fontWeight: (i + 1) == widget.currentSeason ? FontWeight.bold : FontWeight.normal, fontSize: 18)))), child: MouseRegion(onEnter: (_) => setState(() => _isHovered = true), onExit: (_) => setState(() => _isHovered = false), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: widget.compact ? 160 : 220, height: widget.compact ? 44 : 56, decoration: BoxDecoration(color: _isHovered ? const Color(0xFF454652) : const Color(0xFF32333E), borderRadius: BorderRadius.circular(8), border: Border.all(color: _isHovered ? const Color(0xFFA5A5AA) : Colors.transparent, width: 1.5)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('T ${widget.currentSeason}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), Icon(Icons.keyboard_arrow_down, color: _isHovered ? Colors.white : const Color(0xFFA5A5AA))]))))));
}

class _ServerSelector extends ConsumerStatefulWidget {
  final SearchResult currentSource; final List<SearchResult> sources; final Function(int) onSourceSelected; final bool compact; final Set<String>? unavailableSources; final int? season;
  const _ServerSelector({required this.currentSource, required this.sources, required this.onSourceSelected, this.compact = false, this.unavailableSources, this.season});
  @override ConsumerState<_ServerSelector> createState() => _ServerSelectorState();
}

class _ServerSelectorState extends ConsumerState<_ServerSelector> {
  bool _isHovered = false;
  @override Widget build(BuildContext context) {
    // Senior Clean Logic: Agrupamos por nombre de servidor para evitar duplicados visuales (SUB/LAT)
    final groupedSources = <String, int>{};
    for (int i = 0; i < widget.sources.length; i++) {
      final s = widget.sources[i];
      final sName = simplifySourceName(s.source);
      
      // Si el servidor actual es esta variante, priorizamos este índice para que salga como "seleccionado"
      if (s.url == widget.currentSource.url) {
        groupedSources[sName] = i;
      } else if (!groupedSources.containsKey(sName)) {
        groupedSources[sName] = i;
      }
    }
    
    // Ocultar servidores sin stream (validados como no disponibles) en lugar de
    // mostrarlos deshabilitados: si no tiene stream, no aparece en la lista.
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
    // Orden de display fijo: AnimeAV1 -> AnimeJara -> AnimeD23 -> JKAnime ->
    // TIOAnime -> FLV -> Aniyae (al final, por catálogos incompletos).
    uniqueIndices.sort((a, b) => sourceDisplayRank(widget.sources[a].source)
        .compareTo(sourceDisplayRank(widget.sources[b].source)));

    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1E1E26)), 
      child: PopupMenuButton<int>(
        onSelected: widget.onSourceSelected, 
        offset: const Offset(0, 56), 
        constraints: const BoxConstraints(minWidth: 220), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)), 
        itemBuilder: (context) => uniqueIndices.map((i) {
          final s = widget.sources[i];
          final sName = simplifySourceName(s.source);
          final isSelected = sName == simplifySourceName(widget.currentSource.source);
          return PopupMenuItem(
            value: i,
            height: 56,
            child: Row(children: [
              Expanded(child: Text(
                sName,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFA5A5AA),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16
                )
              )),
            ])
          );
        }).toList(),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true), 
          onExit: (_) => setState(() => _isHovered = false), 
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), 
            width: widget.compact ? 160 : 220, 
            height: widget.compact ? 44 : 56, 
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFF454652) : const Color(0xFF32333E), 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: _isHovered ? const Color(0xFFA5A5AA) : Colors.transparent, width: 1.5)
            ), 
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Expanded(
                    child: Text(
                      simplifySourceName(widget.currentSource.source), 
                      overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    )
                  ), 
                  Icon(Icons.dns_rounded, color: _isHovered ? Colors.white : const Color(0xFFA5A5AA))
                ]
              )
            )
          )
        )
      )
    );
  }
}

// Placeholder de respaldo para miniaturas de episodio sin imagen (ni still de
// TMDB ni póster de la fuente): degradado neutro con el número de episodio, para
// que la tarjeta nunca quede en blanco aunque falle la red.
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
  final int episodeNumber; final String title; final String description; final String imageUrl; final String fallbackImageUrl; final String? releaseDate; final String? duration; final String quality; final String? certification; final bool isMobile; final double? progress; final VoidCallback onTap;
  final ScrollController? scrollController;

  /// URL y source del episodio, usados para resolver el idioma REAL (DUB/SUB)
  /// de forma perezosa por episodio cuando el listado no expone el idioma.
  final String? episodeUrl;
  final String? source;
  final String? category;

  /// Tipo de contenido especial ('movie'|'ova'|'special'). Cuando no es null,
  /// la tarjeta muestra el tipo como badge y no antepone el número al título.
  final String? episodeType;
  const _EpisodeCard({required this.episodeNumber, required this.title, required this.description, required this.imageUrl, required this.fallbackImageUrl, this.releaseDate, this.duration, required this.quality, this.certification, this.isMobile = false, this.progress, required this.onTap, this.scrollController, this.episodeUrl, this.source, this.category, this.episodeType});
  @override ConsumerState<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends ConsumerState<_EpisodeCard> {
  static _EpisodeCardState? _activeState;

  bool _isHovered = false;
  OverlayEntry? _overlayEntry;
  bool _isOverlayShown = false;
  bool _isMouseInside = false;
  final LayerLink _layerLink = LayerLink();

  Timer? _showTimer;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
  }

  String get _displayTitle {
    // Especiales (Temporada 0): se muestran con su número y título
    // (p. ej. "1 · Eris la Cazadora de Goblins"). Películas solo con título.
    if (widget.episodeType != null) {
      if (widget.episodeType == 'special' && widget.episodeNumber > 0) {
        return '${widget.episodeNumber}. ${widget.title}';
      }
      return widget.title;
    }
    final String rawTitle = widget.title;
    // EP 0 (OVA/ONA/especial previo): se etiqueta como "EP 0" para no verse
    // como un número de capítulo roto.
    if (widget.episodeNumber == 0) {
      final bool already = rawTitle.toLowerCase().startsWith('ep ') ||
          rawTitle.toLowerCase().startsWith('ep0') ||
          rawTitle.startsWith('0');
      return already ? rawTitle : 'EP 0 · $rawTitle';
    }
    // Senior Clean Logic: Evitamos duplicados si el título ya trae el número o la palabra Episodio/EP
    final bool startsWithNumber = rawTitle.startsWith('${widget.episodeNumber}') || 
                                rawTitle.startsWith('0${widget.episodeNumber}') ||
                                rawTitle.toLowerCase().startsWith('episodio') ||
                                rawTitle.toLowerCase().startsWith('ep ') ||
                                rawTitle.contains('${widget.episodeNumber}\u00AA');
    
    return startsWithNumber ? rawTitle : '${widget.episodeNumber}. $rawTitle';
  }

  // Badge del tipo de especial (MOVIE/OVA/SPECIAL) o null en episodios normales.
  String? get _typeBadge {
    switch (widget.episodeType) {
      case 'movie': return 'MOVIE';
      case 'ova': return 'OVA';
      case 'special': return 'SPECIAL';
      default: return null;
    }
  }

  // EP 0 / especiales (OVA, ONA, especial): se ocultan sinopsis, duración y
  // fecha para no mostrar metadata que suele faltar o ser irrelevante. Se
  // conservan las etiquetas (badges) y el título.
  bool get _isSpecial => widget.episodeNumber == 0;

  // Badge dinámico de idioma: identifica capítulos doblados (DUB) vs
  // subtitulados (SUB) a partir del quality del episodio. Cuando el listado
  // no expone idioma (quality null), no se muestra badge.
  String? get _languageBadge {    final q = widget.quality;
    if (q == null || q.isEmpty) return null;
    final isDub = q.toLowerCase().contains('latino') ||
        q.toLowerCase().contains('dub') ||
        q.toLowerCase().contains('doblado') ||
        q.toLowerCase().contains('castellano');
    return isDub ? 'DUB' : 'SUB';
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_activeState == this) _activeState = null;
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.sp(context, 16)),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, 8)),
                  child: SizedBox(
                    width: ResponsiveUtils.sp(context, 160),
                    child: Stack(
                      children: [
                        AspectRatio(
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
                        if (widget.progress != null && widget.progress! > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
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
                      ],
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.sp(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: ResponsiveUtils.sp(context, 15), fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: ResponsiveUtils.sp(context, 6)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isSpecial)
                            Text(
                              '${widget.duration ?? ''}${widget.duration != null && widget.releaseDate != null ? ' ' : ''}${_formatDate(widget.releaseDate)}',
                              style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: ResponsiveUtils.sp(context, 12)),
                            ),
                          if (!_isSpecial) SizedBox(height: ResponsiveUtils.sp(context, 6)),
                          Row(
                            children: [
                              if (widget.certification != null && widget.certification != 'NR') ...[
                                _buildAgeBadge(context, widget.certification!, small: true),
                                SizedBox(width: ResponsiveUtils.sp(context, 8)),
                              ],
                              if (_typeBadge != null) ...[
                                _buildAgeBadge(context, _typeBadge!, small: true),
                                SizedBox(width: ResponsiveUtils.sp(context, 8)),
                              ],
                              _buildAgeBadge(context, _languageBadge, small: true),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_isSpecial && widget.description.isNotEmpty) ...[
              SizedBox(height: ResponsiveUtils.sp(context, 12)),
              Text(
                widget.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: ResponsiveUtils.sp(context, 13), height: 1.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EpisodesSkeleton extends StatelessWidget {
  final bool isMobile;
  const _EpisodesSkeleton({this.isMobile = false});
  @override Widget build(BuildContext context) {
    return SliverList(delegate: SliverChildBuilderDelegate((context, index) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [ Container(width: 140, height: 80, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6))), const SizedBox(width: 16), Expanded(child: Column(children: [Container(height: 16, color: Colors.white10), const SizedBox(height: 8), Container(height: 12, color: Colors.white10)])) ])), childCount: 5));
  }
}

// Helper widget for circular actions
class _ActionSquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionSquareButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 48,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white12),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
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
    final isMobile = ResponsiveUtils.isMobile(context); 
    String? img = ApiEndpoints.proxyImage((widget.theme.imageUrl?.isNotEmpty == true) ? widget.theme.imageUrl! : widget.fallbackImage);
    final bool isSelected = !isMobile && _isHovered;

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
            if (kIsWeb && url.contains('animethemes.moe')) {
              url = '${ApiEndpoints.baseUrl}/api/proxy/video?url=${Uri.encodeComponent(url)}';
              if (url720.isNotEmpty) url720 = '${ApiEndpoints.baseUrl}/api/proxy/video?url=${Uri.encodeComponent(url720)}';
              if (url1080.isNotEmpty) url1080 = '${ApiEndpoints.baseUrl}/api/proxy/video?url=${Uri.encodeComponent(url1080)}';
            }
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
                // Imagen con Zoom (Estilo Home)
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0, 
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutQuart,
                  child: img != null 
                    ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.white10)) 
                    : Container(color: Colors.white10),
                ),
                
                // Gradiente Dinómico
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
                
                // Contenido Central
                Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(isMobile ? 8 : 12), 
                      decoration: BoxDecoration(
                        color: (widget.isOP ? Colors.blueAccent : Colors.pinkAccent).withOpacity(isSelected ? 1.0 : 0.8), 
                        shape: BoxShape.circle,
                        boxShadow: isSelected ? [BoxShadow(color: (widget.isOP ? Colors.blueAccent : Colors.pinkAccent).withOpacity(0.5), blurRadius: 10)] : [],
                      ), 
                      child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: isMobile ? 24 : 32)
                    ),
                    const SizedBox(height: 12), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8), 
                      child: Text(
                        widget.theme.title, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 16)
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

class _DetailButton extends StatelessWidget {
  final VoidCallback? onPressed; final IconData icon; final String label; final bool isPrimary; final bool compact; final bool isLoading;
  const _DetailButton({required this.onPressed, required this.icon, required this.label, this.isPrimary = false, this.compact = false, this.isLoading = false});
  @override Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final bool isDisabled = onPressed == null || isLoading;

    return Container(
      height: isMobile ? 52 : (compact ? 44 : 56), 
      decoration: BoxDecoration(
        color: isPrimary ? (isDisabled ? const Color(0xFFA5A5AA) : Colors.white) : Colors.white10, 
        borderRadius: BorderRadius.circular(8)
      ), 
      child: Material(
        color: Colors.transparent, 
        child: InkWell(
          onTap: isDisabled ? null : onPressed, 
          borderRadius: BorderRadius.circular(8), 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                if (isLoading) 
                  SizedBox(
                    width: isMobile ? 20 : 24, 
                    height: isMobile ? 20 : 24, 
                    child: CircularProgressIndicator(
                      strokeWidth: 3, 
                      color: isPrimary ? Colors.black : Colors.white
                    )
                  )
                else
                  Icon(icon, color: isPrimary ? Colors.black : Colors.white, size: isMobile ? 24 : 30),
                const SizedBox(width: 12), 
                Text(
                  isLoading ? 'Buscando fuentes...' : label, 
                  style: TextStyle(
                    color: isPrimary ? Colors.black : Colors.white, 
                    fontSize: isMobile ? 18 : 20, 
                    fontWeight: FontWeight.bold
                  )
                )
              ]
            )
          )
        )
      )
    );
  }
}

class _DetailIconButton extends StatefulWidget {
  final IconData icon; final VoidCallback onPressed; final String label; final bool isMobile; final double? size; final double? iconSize; final Color? color;
  const _DetailIconButton({required this.icon, required this.onPressed, required this.label, this.isMobile = false, this.size, this.iconSize, this.color});
  @override State<_DetailIconButton> createState() => _DetailIconButtonState();
}

class _DetailIconButtonState extends State<_DetailIconButton> {
  bool _isHovered = false;
  @override Widget build(BuildContext context) {
    if (widget.isMobile) {
      return Expanded(
        child: InkWell(
          onTap: widget.onPressed, 
          child: Column(
            mainAxisSize: MainAxisSize.min, // Senior: Evitar que el Column ocupe espacio extra
            children: [
              Container(
                height: 48, 
                decoration: BoxDecoration(
                  border: Border.all(color: widget.color ?? Colors.white24), 
                  borderRadius: BorderRadius.circular(4)
                ), 
                child: Center(child: Icon(widget.icon, color: widget.color ?? Colors.white, size: 24))
              ), 
              const SizedBox(height: 8), 
              SizedBox(
                height: 28, // Senior Fix: Altura ajustada para 2 líneas sin exceso de espacio
                child: Text(
                  widget.label, 
                  style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 10.5, height: 1.1), 
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ]
          )
        )
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true), 
      onExit: (_) => setState(() => _isHovered = false), 
      child: Tooltip(
        message: widget.label, 
        child: AnimatedScale(
          scale: _isHovered ? 1.1 : 1.0, 
          duration: const Duration(milliseconds: 200), 
          child: Container(
            height: widget.size ?? 56, 
            width: widget.size ?? 56, 
            decoration: BoxDecoration(
              color: Colors.white10, 
              shape: BoxShape.circle, 
              border: Border.all(color: widget.color ?? Colors.white24)
            ), 
            child: IconButton(
              icon: Icon(widget.icon, color: widget.color ?? Colors.white, size: widget.iconSize ?? 28), 
              onPressed: widget.onPressed
            )
          )
        )
      )
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  final Widget child; const _DetailInfoCard({required this.child});
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: const Color(0xFF121519), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF66696E), width: 1.0)), child: child);
}

// --- MAIN WIDGETS ---

class ContentScreen extends ConsumerStatefulWidget {
  final String title; final String source; final String url; final String? metadataTitle; final String? banner; final String category; final int? year; final int? totalSeasons;
  /// Card abierta (con sus fuentes/servidores). Se usa para sembrar al instante la
  /// lista de servidores sin re-raspear en vivo. Para deep-links (sin card) es null
  /// y se reconstruye una sola fuente desde title/source/url.
  final SearchResult? result;
  const ContentScreen({super.key, required this.title, required this.source, required this.url, this.metadataTitle, this.banner, this.category = 'all', this.year, this.totalSeasons, this.result});
  @override ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> {
  int _selectedSourceIndex = 0; int? _selectedSeason;
  // Selección de pestaña simple (int sobre la lista de tabs visibles). Se usa una
  // tab bar propia en vez de TabController/TabBar para poder mostrar/ocultar el
  // tab "Extras" sin recrear un TabController (lo que provocaba crashes de lifecycle).
  int _selectedTabIndex = 0;
  bool _hasExtras = false; bool _tabRebuildPending = false;
  // Pel\u00EDculas: disponibilidad de cada servidor (por nombre) validada contra el
  // extractor real. Permite deshabilitar la fuente que no devuelve stream y que
  // el "Reproducir" global elija autom\u00E1ticamente la primera que s\u00ED da stream.
  final Map<String, bool> _movieAvail = {};
  bool _movieValidating = false;
  bool _movieValidated = false;
  bool _movieValidationScheduled = false;
  final ScrollController _scrollController = ScrollController();
  bool _showContent = false;
  Timer? _loadTimer;
  // Banner del hero congelado: se captura UNA sola vez con la primera imagen
  // disponible al abrir (ruta > fuente > backdrop del detalle) and ya no cambia
  // al switchear temporada, para no re-solicitar banner ni provocar timeouts.
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

  // Sincroniza _hasExtras con la disponibilidad de OP/ED y re-mapea _selectedTabIndex
  // por semántica (el tab Extras se inserta en el medio) para que el usuario no
  // "salte" de pestaña al aparecer/desaparecer. No recrea ningún controlador.
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

  // Valida cada servidor de la pel\u00EDcula contra el extractor real. Las fuentes que
  // no devuelven stream se marcan como no disponibles; luego auto-seleccionamos la
  // primera disponible para el "Reproducir" global. Solo se ejecuta una vez.
  void _validateMovieSources(List<SearchResult> sources) {
    if (sources.isEmpty || _movieValidated || _movieValidating) return;
    _movieValidating = true;
    final repo = ref.read(aurisRepositoryProvider);
    Future.wait(sources.map((s) async {
      final name = simplifySourceName(s.source);
      if (_movieAvail.containsKey(name)) return;
      try {
        final r = await repo.extractVideo(s.url ?? widget.url, s.source, category: widget.category, direct: !kIsWeb);
        final ok = (r.url.isNotEmpty && !r.url.contains('embed-undef')) ||
            r.tracks.any((t) => t.url.isNotEmpty) ||
            r.qualities.any((q) => q.url.isNotEmpty);
        _movieAvail[name] = ok;
      } catch (_) {
        // Error de red transitorio: mantenemos la fuente como disponible para no
        // ocultar fuentes que s\u00ED funcionan. Solo marcamos "no disponible" cuando el
        // extractor responde de forma definitiva sin stream (ok == false).
        _movieAvail[name] = true;
      }
    })).then((_) {
      _movieValidating = false;
      _movieValidated = true;
      // Auto-seleccionar la primera fuente disponible.
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

  // Tab bar propia (sin TabController): selecci\u00F3n con int y subrayado animado.
  Widget _buildTabBar(List<String> labels, int selectedIndex, double hPadding, bool isMobile) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: selected ? const Color(0xFFEF7A1E) : Colors.transparent, width: 3)),
              ),
              child: Text(labels[i], style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w900, color: selected ? Colors.white : const Color(0xFFA5A5AA))),
            ),
          );
        }),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final hPadding = isMobile ? 20.0 : (width >= 800 && width < 1200 ? 24.0 : horizontalPadding);
    final episodesCrossAxisCount = isMobile ? 1 : (width < 1000 ? 2 : (width < 1400 ? 3 : (width < 2100 ? 4 : (width < 2800 ? 5 : 6))));
    final episodesAspectRatio = isMobile ? 1.15 : (width < 1000 ? 1.25 : 1.1);

    // Clasificación pre-carga (solo categoría, porque aún no tenemos el payload).
    final isAnimeCatFetch = widget.category == 'anime';
    final isMovieCatFetch = widget.category == 'movie' || widget.category == 'series' || widget.category == 'movie_anime' || _isMovieLikeTitle(widget.title) || widget.result?.kind?.toLowerCase() == 'movie' || widget.result?.kind?.toLowerCase() == 'series';
    // Una movie_anime es una Pel\u00EDcula de anime: tambi\u00E9n queremos el detalle de
    // anime (AniList) para mostrar la franquicia en "Relacionado" + sus OP/ED.
    // 'all' (b\u00FAsqueda global) tambi\u00E9n incluye anime, as\u00ED que lo pedimos igual.
    final fetchAnimeDetail = isAnimeCatFetch || widget.category == 'movie_anime' || widget.category == 'all';

    // Servidor de origen de la tarjeta: si llegó de una búsqueda global ('all'),
    // usamos el source del resultado para dirigir el detalle y las fuentes al
    // servidor correcto y NO hacer fan-out a 3001/3002. Si no hay source y la
    // categoría es concreta, la usamos. Si todo es 'all' sin source, seguimos
    // con el fan-out original (comportamiento previo).
    //
    // Excepción: los proveedores de metadata (AniList, TMDB, Trakt, MAL, Jikan)
    // no son fuentes de scraping y NO indican a qué servidor pertenece el
    // contenido. Usarlos para elegir servidor mandaba la búsqueda de fuentes al
    // puerto de Películas (3001) para animes abiertos desde "Relacionado",
    // dejando la lista de servidores vacía (DioException de conexión). Para
    // ellos resolvemos por categoría concreta, como si no hubiera source.
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

    // Para category='all' no sabemos de antemano si es anime o movie. Pedimos
    // el detalle de anime primero y solo consultamos /api/detail/movie como
    // fallback si el anime no resolvió nada, evitando la doble llamada
    // innecesaria para animes abiertos desde la búsqueda global/Relacionado.
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

    // Para las Pel\u00EDculas de anime el detalle "principal" es el de Pel\u00EDcula
    // (runtime, plataformas, directores...); el de anime se usa solo para el tab
    // Relacionado. Para el resto de animes, el principal es el de anime.
    final detailData = isMovieCatFetch
        ? (movieDetailAsync.valueOrNull ?? animeDetailAsync.valueOrNull)
        : (animeDetailAsync.valueOrNull ?? movieDetailAsync.valueOrNull);

    // Tipo resuelto a partir del payload (kind) y no solo de la categoría, para
    // no confundir backend/categoría al abrir contenido de 3000/3001/3002.
    final resolvedKind = (detailData is AnimeDetail
            ? detailData.kind
            : (detailData is MovieDetail ? detailData.kind : null)) ??
        widget.result?.kind ??
        widget.category;
    final isAnimeCategory = resolvedKind == 'anime';
    final isMovieCategory = resolvedKind == 'movie' ||
        widget.result?.kind?.toLowerCase() == 'movie' ||
        _isMovieLikeTitle(widget.title);
    // categor\u00EDa efectiva: si el t\u00EDtulo es de Pel\u00EDcula pero lleg\u00F3 con category="all"
    // (p.ej. abierto desde la b\u00FAsqueda "Todo"), el provider debe tratarlo como movie
    // y no como serie, o descartaría los resultados de movie y pediría episodios de la
    // serie. El server etiqueta kind:'movie' y acota la búsqueda a Películas.
    final effectiveCategory = isMovieCategory ? 'movie_anime' : widget.category;

    final detailLoading = (isMovieCategory ? movieDetailAsync.isLoading && animeDetailAsync.valueOrNull == null : animeDetailAsync.isLoading) || (isAnimeCategory ? false : movieDetailAsync.isLoading && animeDetailAsync.valueOrNull == null);

    // Temporada de la pantalla abierta, inferida del título. Se usa para fijar
    // la fuente y la temporada OMDB a la temporada correcta (evita que una S2
    // abierta caiga a la S1 por defecto).
    // La temporada abierta debe derivarse de la CARD ORIGINAL (widget.result), no
    // de widget.title: este último es `displayTitle` (result.scrapedTitle ??
    // metadataTitle ?? title) y el server suele enriquecerlo con el título base de
    // AniList ("Youjo Senki"), perdiendo el sufijo "2nd Season". Si usáramos
    // widget.title, openedSeasonN quedaría en 1 y seasonSwitched nunca se activaría
    // al pasar de S2 -> S1 (se evaluaría 1 != 1 = false): la lista y el detalle se
    // quedaban en S2. widget.result.title conserva "youjo senki 2nd season".
    final openedSeasonN = widget.result?.season
        ?? _extractSeason(widget.result?.title)
        ?? _extractSeason(widget.title)
        ?? _extractSeason(widget.metadataTitle)
        ?? 1;
    // Solo fijamos el "season" del proveedor cuando el título declara una
    // temporada > 1, para no romper la lógica original de títulos base (S1).
    // [Senior] Semilla instantánea: la card abierta ya es un SearchResult con sus
    // servidores en `.sources`, así que la lista de servidores se muestra de inmediato
    // y la búsqueda suplementaria (discoveredSourcesProvider) solo la enriquece/fusiona
    // cuando termine de raspear. Evita el "corta a la mitad" si el server tarda.
    final List<SearchResult> initialSources = widget.result != null
        ? [widget.result!]
        : [SearchResult(title: widget.title, url: widget.url, quality: 'TV', thumbnail: widget.banner ?? '', source: widget.source, romaji: widget.metadataTitle, year: widget.year, slug: null)];

    final sourcesParams = DiscoveredSourcesParams(title: widget.title, metadataTitle: widget.metadataTitle, category: effectiveCategory, year: widget.year, season: openedSeasonN, server: originServer, initialSources: initialSources);
    final searchSources = ref.watch(discoveredSourcesProvider(sourcesParams));

    // AnimeJara expone todas las temporadas en la URL base vía `#season-N`, por
    // lo que no depende de la re-búsqueda por temporada (que en ese proveedor
    // puede devolver resultados erróneos). Reusamos la fuente base de la
    // búsqueda original y le anexamos la temporada seleccionada, manteniéndola
    // siempre disponible en el selector de servidores.
    final effectiveSeasonForUrl = _selectedSeason ?? (openedSeasonN > 1 ? openedSeasonN : null);

    // [Senior] El switch de temporada reusa la búsqueda base ya cacheada (mismo
    // título SIN sufijo de temporada) y solo cambia el filtro `season`: así NO se
    // hace un re-scrapeo lento de "X 2nd Season" y la lista de la otra temporada
    // aparece al instante, porque sus fuentes ya vinieron en la búsqueda base
    // (AV1/JKAnime traen youjo-senki-ii; GnulaHD/AnimeJara unifican vía #season-N).
    // El scrapeo de episodios sólo usa la URL correcta de la temporada por fuente.
    final seasonSwitched = _selectedSeason != null && _selectedSeason != openedSeasonN;
    // [Senior] El switch busca el título DE LA TEMPORADA (p.ej. "youjo senki 2nd
    // Season") y NO solo la base: la búsqueda base "youjo senki" no devuelve la S2
    // de forma fiable, así que filtrar la base por temporada 2 daba lista vacía y
    // solo cargaba AnimeJara (vía #season-N). El provider ya busca searchQuery
    // (temporada) + baseSearchQuery (base, cacheada) y fusiona, así S2 se encuentra
    // por query específica y S1 sale instantáneo desde la base cacheada.
    final seasonTitle = seasonSwitched ? _seasonTitleFor(_stripSeasonSuffix(widget.title), _selectedSeason!) : null;
    final seasonSourcesParams = seasonTitle != null
        ? DiscoveredSourcesParams(title: seasonTitle, metadataTitle: seasonTitle, category: effectiveCategory, year: widget.year, season: _selectedSeason, server: originServer, initialSources: initialSources)
        : sourcesParams;
    final seasonSources = ref.watch(discoveredSourcesProvider(seasonSourcesParams));
    ref.listen(discoveredSourcesProvider(seasonSourcesParams), (prev, next) {
      final nextList = next;
      if (nextList != null && nextList.isNotEmpty) {
        // AnimeJara/GnulaHD se derivan del mismo `next` que se está fusionando.
        // Antes se derivaba de `searchSources`, que por el timing asíncrono de los
        // providers puede no haber resuelto AJR todavía cuando este listener
        // dispara, dejando a AnimeJara fuera del player (veías 4 de 5).
        final ajr = nextList
            .where((s) => _isSeasonUnified(s.source))
            .map((s) => _withSeasonUnified(s, effectiveSeasonForUrl))
            .where((s) => s != null)
            .cast<SearchResult>()
            .toList();
        final merged = <SearchResult>[
          ...nextList.where((s) => !_isSeasonUnified(s.source)),
          ...ajr,
        ];
        ref.read(activeContentSourcesProvider.notifier).state = merged;
      }
    });

    // Al cambiar de temporada, el detalle (año, estado, OP/ED, sinopsis...) debe
    // corresponder a la temporada seleccionada, no al de la temporada con la que
    // se abrió la pantalla. Pedimos el detalle de la temporada concreta y, mientras
    // carga, seguimos mostrando el detalle abierto para no romper el hero.
    // El metadato de la temporada debe usar el título de la temporada concreta
    // (seasonTitle), no el del card con el que se abrió (widget.metadataTitle).
    // Si se abre el card S2 (metadataTitle="Youjo Senki II") y se switchea a S1,
    // mantener widget.metadataTitle obligaba al server a resolver S2 aunque el
    // title fuera la base, dejando el detalle/header en S2 (bug #S2→S1).
    // Pasamos además `season: _selectedSeason` para que el server resuelva la
    // temporada de forma determinística (sin él, un título base ambiguo como
    // "Youjo Senki" devuelve S1 o S2 según el ranking de AniList).
    final seasonAnimeDetailAsync = seasonTitle != null
        ? ref.watch(animeDetailProvider(AnimeDetailParams(title: seasonTitle, metadataTitle: seasonTitle, year: null, season: _selectedSeason, kind: null)))
        : animeDetailAsync;
    final displayAnimeDetailAsync = seasonSwitched
        ? (seasonAnimeDetailAsync.valueOrNull != null ? seasonAnimeDetailAsync : animeDetailAsync)
        : animeDetailAsync;
    final displayDetail = isMovieCatFetch
        ? (movieDetailAsync.valueOrNull ?? displayAnimeDetailAsync.valueOrNull)
        : displayAnimeDetailAsync.valueOrNull;

    // Tab "Extras" (OP/ED): solo se muestra si el detalle trae openings/endings.
    // _syncExtras actualiza _hasExtras y re-mapea _selectedTabIndex (sin recrear
    // ningún TabController, evitando crashes de lifecycle al ocultar/mostrar el tab).
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
        .where((s) => _isSeasonUnified(s.source))
        .map((s) => _withSeasonUnified(s, effectiveSeasonForUrl))
        .where((s) => s != null)
        .cast<SearchResult>()
        .toList();

    // AnimeJara/GnulaHD se mantienen desde la búsqueda base (con `#season-N`);
    // el resto de fuentes usa la re-búsqueda por temporada.
    final baseActive = seasonSources.isNotEmpty ? seasonSources : searchSources;
    final activeSources = <SearchResult>[
      ...baseActive.where((s) => !_isSeasonUnified(s.source)),
      ...seasonUnifiedSources,
    ];
    // Orden de display/fuente por defecto: AnimeAV1 -> AnimeJara -> AnimeD23 ->
    // JKAnime -> TIOAnime -> FLV -> Aniyae (al final, catálogos incompletos).
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
      return Scaffold(backgroundColor: const Color(0xFF0B0B0D), body: _buildPageSkeleton(context, true));
    }

    // Pel\u00EDculas: validar disponibilidad de cada servidor una sola vez al mostrar la UI.
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
    final currentSource = _withSeasonUnified(rawCurrentSource, effectiveSeasonForUrl);
    final episodesUrl = currentSource?.url ?? widget.url;
    final episodesSource = currentSource?.source ?? widget.source;
    final initialThumbnail = ApiEndpoints.proxyImage(currentSource?.thumbnail);
    final initialBanner = ApiEndpoints.proxyImage(widget.banner?.isNotEmpty == true ? widget.banner : (activeSources.isNotEmpty ? activeSources.first.banner : null));
    // Congelar el banner del hero con la primera imagen disponible. Una vez
    // capturado no vuelve a cambiar aunque se switchee de temporada.
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
    final familySourcesRaw = currentSource != null ? _familySourcesFor(currentSource, activeSources) : <SearchResult>[];
    final familySources = familySourcesRaw.map((s) => _withSeasonUnified(s, effectiveSeasonForUrl)!).toList();

    final historyAsync = ref.watch(playbackHistoryStateProvider);
    final history = historyAsync.valueOrNull ?? [];
    
    // Senior Unified Relations: Obtenemos relacionados de TODAS las fuentes disponibles
    final unifiedRelationsAsync = ref.watch(unifiedRelationsProvider(searchSources));
    
    final certification = detailData != null ? ((detailData is MovieDetail ? (detailData as MovieDetail).certification : (detailData is AnimeDetail ? (detailData as AnimeDetail).certification : null)) ?? 'NR') : 'NR';
    // Para anime, el "N" de temporada lo manda el server en animeDetail.season
    // (curado por IdentityResolver a partir del título, p.ej. "2nd Season" -> 2).
    final animeSeasonN = (detailData is AnimeDetail && detailData.season != null)
        ? (int.tryParse(detailData.season!) ?? openedSeasonN)
        : openedSeasonN;
    final currentSeason = _selectedSeason ??
        (detailData is MovieDetail
            ? (detailData.seasons.isNotEmpty ? detailData.seasons.first.seasonNumber : 1)
            : animeSeasonN);
    // Al cambiar de temporada, la metadata (títulos, miniaturas, año) de los
    // episodios debe corresponder a la temporada seleccionada, no a la temporada
    // con la que se abrió la pantalla. Preferimos el título ingl\u00E9s del detalle de
    // la temporada destino (si ya cargó) y caemos a seasonTitle como fallback.
    final seasonDetail = seasonAnimeDetailAsync.valueOrNull is AnimeDetail
        ? seasonAnimeDetailAsync.valueOrNull as AnimeDetail
        : null;
    // Hero banner season-aware: al cambiar de temporada, si el detalle de la
    // temporada destino ya cargó, usamos su backdrop; si aún no, mantenemos el
    // banner congelado de la temporada abierta para no romper el hero.
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

    // Una Pel\u00EDcula (movie/movie_anime) no tiene capítulos: no tiene sentido pedir
    // títulos/metadata/thumbnails de episodios al servidor. Construimos un único
    // "episodio" sintético que apunta a la URL de la fuente (la Pel\u00EDcula misma) para
    // que el reproductor pueda hacer /api/extract directamente contra ella.
    //
    // Guard: si la fuente es un proveedor de metadatos (AniList, TMDB, Trakt),
    // NO hacemos la petición de episodios — no tienen un endpoint de scraping real.
    // Esto evita que la app llame al puerto 3001 con source=AniList y una URL numérica,
    // lo que causaba un DioException de conexión. En su lugar devolvemos loading
    // para que la UI muestre el esqueleto mientras searchSources se rellena.
    const metadataSources = {'anilist', 'tmdb', 'trakt', 'mal', 'jikan'};
    final isMetadataSource = metadataSources.contains(episodesSource.toLowerCase());

    // Parámetros de la petición de episodios CONGELADOS a los valores conocidos al
    // abrir la pantalla (widget) y a la temporada abierta, salvo al switchear de
    // temporada. NO dependen de `detailData` (la cabecera/hero): los episodios se
    // scrapean por URL de fuente, y `year`/`titleEnglish` solo alimentan el
    // enriquecimiento TMDB/OMDB. Si usáramos `detailData.year`/`titleEnglish` aquí,
    // al cargar la cabecera cambiaría la clave del provider y se RE-SCRAPEARÍAN
    // todas las fuentes innecesariamente (los episodios ya venían enriquecidos).
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
              episodes: [EpisodeInfo(number: 1, id: 0, url: episodesUrl, title: 'Película', thumbnail: initialThumbnail)],
            ),
            sources: [currentSource ?? SearchResult(title: widget.title, url: episodesUrl, quality: '', thumbnail: initialThumbnail ?? '', source: episodesSource)],
          ))
        : isMetadataSource
            // Fuente de metadatos sin endpoint de episodios: mostrar skeleton
            // mientras las fuentes de scraping (JKAnime, AnimeAV1, Aniyae) terminan de cargarse.
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

    SearchResult? episodeSourceFor(int episodeNumber) => episodesAsync.valueOrNull?.sourceForNumber(episodeNumber) ?? currentSource;
    // Las Pel\u00EDculas no tienen temporadas/episodios en TMDB: evitar búsquedas innecesarias de OMDB.
    final omdbSeasonAsync = isMovieCategory
        ? const AsyncValue<List<OmdbEpisode>>.data([])
        : ref.watch(omdbSeasonProvider(OmdbSeasonParams(title: episodeLookupTitle, season: currentSeason)));

    int totalSeasons = (detailData is MovieDetail)
        ? (detailData.totalSeasons ?? detailData.seasons.length)
        : (detailData is AnimeDetail ? (detailData.totalSeasons ?? 1) : 1);
    // Respaldo del search: si el detail (AniList) no trajo totalSeasons,
    // usamos el que el server calculó por franquicia desde el campo `season`.
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
        child: CustomScrollView(
          controller: _scrollController, 
          physics: const ClampingScrollPhysics(), 
          slivers: [
            SliverToBoxAdapter(child: _ContentHeader(
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
              // El spinner del botón "Reproducir" se detiene en cuanto llega el
              // primer servidor (activeSources no vacío); el resto sigue cargando
              // en segundo plano mientras searchLoading sigue true.
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
              inferredSeasonAirDate: episodesAsync.valueOrNull?.response.seasonAirDate, 
              latestHistory: ref.watch(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title), 
              unavailableSources: isMovieCategory ? _movieAvail.entries.where((e) => e.value == false).map((e) => e.key).toSet() : null, 
              onPlay: () {
                // Pel\u00EDcula: elegir la primera fuente disponible si la seleccionada
                // no entrega stream (degradaci\u00F3n elegante del extractor).
                SearchResult? playSource = currentSource;
                if (isMovieCategory && playSource != null && _movieAvail[simplifySourceName(playSource.source)] == false) {
                  playSource = activeSources.firstWhereOrNull((s) => _movieAvail[simplifySourceName(s.source)] == true) ?? playSource;
                }
                final src = playSource?.source ?? widget.source;
                final url = playSource?.url ?? widget.url;
                final playEpisodesUrl = playSource?.url ?? widget.url;
                // Pel\u00EDcula: reproducir directo con la URL de movie de la fuente
                // seleccionada, sin depender de la lista de episodios (unhas fuentes la
                // presentan como ep1 en su detail, otras con URL directa como AnimeJara
                // "animejara.com/movie/...", otras como GNU no la listan). No usamos el
                // episode/season del historial para no arrastrar la temporada de la serie.
                if (isMovieCategory) {
                  final ep = EpisodeInfo(number: 1, id: 0, url: playEpisodesUrl, title: 'Pel\u00EDcula', thumbnail: initialThumbnail);
                  final posterParam = '&title=${Uri.encodeComponent(widget.title)}&posterUrl=${Uri.encodeComponent(playSource?.thumbnail ?? '')}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
                  context.push('/player/${Uri.encodeComponent(widget.title)}?source=${src}&url=${_episodeUrlFor(ep, playEpisodesUrl, src, 1)}&episode=1&serverName=${simplifySourceName(src)}&language=${((playSource?.quality ?? '').toLowerCase().contains('latino')) ? 'LAT' : 'SUB'}&startPosition=&category=${widget.category}&totalEpisodes=1$posterParam');
                  return;
                }
                final latest = ref.read(playbackHistoryStateProvider.notifier).getLatestWatched(widget.title);
                int epNum = latest != null ? int.tryParse(latest.episode ?? '1') ?? 1 : 1;
                final epData = episodesAsync.valueOrNull?.response;
                final epSource = episodeSourceFor(epNum) ?? currentSource;
                final ep = epData?.episodes.firstWhereOrNull((e) => e.number == epNum);
                
                // Prioridad de miniatura: Episode Thumbnail (TMDB/OMDB) > Series Poster
                final episodeThumb = ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? '';
                final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(episodeThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
                context.push('/player/${Uri.encodeComponent(widget.title)}?source=${epSource?.source ?? src}&url=${_episodeUrlFor(ep, epSource?.url ?? url, epSource?.source ?? src, epNum)}&episode=$epNum&season=${latest?.season ?? currentSeason}&serverName=${simplifySourceName(epSource?.source ?? src)}&language=${(epSource?.quality.toLowerCase().contains('latino') ?? false) ? 'LAT' : 'SUB'}&startPosition=${latest?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${epData?.total ?? 0}$posterParam');
              }
            )),
            if (isMobile) SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ExpandableText(text: (detailData as dynamic)?.overview ?? 'No hay sinopsis disponible.', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 16), maxLines: 3),
              const SizedBox(height: 16),
              if (detailData is MovieDetail && detailData.platforms.isNotEmpty) ...[
                Wrap(spacing: 8, runSpacing: 8, children: detailData.platforms.take(5).map<Widget>((p) => _PlatformLogo(platform: p, size: 24)).toList()),
                const SizedBox(height: 16),
              ],
              Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12), bottom: BorderSide(color: Colors.white12))), child: Row(children: [
                Expanded(child: Column(children: [const Text('Lanzamientos', style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 12)), const SizedBox(height: 4), Text((detailData is AnimeDetail ? detailData.firstAirDate : (detailData is MovieDetail ? detailData.releaseDate : null))?.split('-').first ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))])),
                Expanded(child: Column(children: [Text(isMovieCategory ? 'Duraci\u00F3n' : 'Temporadas', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 12)), const SizedBox(height: 4), Text(isMovieCategory ? _formatRuntime(_getRuntime(detailData)) : (detailData == null ? 'N/A' : '$totalSeasons'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]))
              ])),
              const SizedBox(height: 24),
            ]))),
            SliverMainAxisGroup(slivers: [
              SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildTabBar(tabLabels, selectedTabIndex, hPadding, isMobile),
                const SizedBox(height: 16),
              ]))),
              if (episodesTabIndex >= 0 && selectedTabIndex == episodesTabIndex) episodesAsync.when(
                data: (epBundle) {
                  final epData = epBundle?.response;
                  if (epData == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  final omdbEpisodes = omdbSeasonAsync.valueOrNull ?? [];
                  return SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverMainAxisGroup(slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isMobile ? 6 : 32),
                        child: Text(
                          '${epData.total} episodios', 
                          style: TextStyle(
                            color: const Color(0xFFA5A5A5), 
                            fontSize: isMobile ? 15 : 20,
                            fontWeight: isMobile ? FontWeight.w600 : FontWeight.normal,
                          )
                        )
                      )
                    ),
                    if (isMobile) SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                      final ep = index < epData.episodes.length ? epData.episodes[index] : null; final omdb = index < omdbEpisodes.length ? omdbEpisodes[index] : null;
                      final epNum = (ep?.number ?? index + 1).toString();
                      final epHistory = history.firstWhereOrNull((h) => h.contentId == widget.title && h.season == currentSeason && h.episode == epNum);
                      final epSource = epBundle?.sourceForIndex(index) ?? currentSource;
                      final epQuality = ep?.quality ?? epSource?.quality ?? '';
                      return _EpisodeCard(episodeNumber: ep?.number ?? index + 1, title: ep?.title ?? omdb?.title ?? 'Episodio ${index + 1}', description: ep?.description ?? omdb?.description ?? '', imageUrl: ApiEndpoints.proxyImage(ep?.thumbnail ?? omdb?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), fallbackImageUrl: ApiEndpoints.proxyImage(epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), releaseDate: ep?.airDate ?? omdb?.released, duration: ep?.duration ?? (ep?.runtime != null ? '${ep!.runtime} min' : omdb?.duration), quality: epQuality, episodeUrl: ep?.url, source: epSource?.source ?? currentSource?.source, category: widget.category, certification: certification, isMobile: true, scrollController: _scrollController, progress: epHistory?.progressPercentage, onTap: () {
                        final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum);
                        final tapSource = epBundle?.sourceForIndex(index) ?? currentSource;
                        final epThumb = ep?.thumbnail ?? omdb?.thumbnail ?? tapSource?.thumbnail ?? '';
                        final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
                        context.push('/player/${Uri.encodeComponent(widget.title)}?source=${tapSource?.source ?? currentSource?.source ?? widget.source}&url=${_episodeUrlFor(ep, tapSource?.url ?? currentSource?.url ?? widget.url, tapSource?.source ?? currentSource?.source ?? widget.source, ep?.number ?? index + 1)}&episode=${ep?.number ?? index + 1}&season=$currentSeason&serverName=${simplifySourceName(tapSource?.source ?? currentSource?.source ?? widget.source)}&language=${(epQuality.toLowerCase().contains('latino')) ? 'LAT' : 'SUB'}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${epData.total}$posterParam');
                      });
                    }, childCount: epData.total))
                    else SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: episodesCrossAxisCount, mainAxisSpacing: 20, crossAxisSpacing: 24, childAspectRatio: episodesAspectRatio), delegate: SliverChildBuilderDelegate((context, index) {
                      final ep = index < epData.episodes.length ? epData.episodes[index] : null; final omdb = index < omdbEpisodes.length ? omdbEpisodes[index] : null;
                      final epNum = (ep?.number ?? index + 1).toString();
                      final epHistory = history.firstWhereOrNull((h) => h.contentId == widget.title && h.season == currentSeason && h.episode == epNum);
                      final epSource = epBundle?.sourceForIndex(index) ?? currentSource;
                      final epQuality = ep?.quality ?? epSource?.quality ?? '';
                      return _EpisodeCard(episodeNumber: ep?.number ?? index + 1, title: ep?.title ?? omdb?.title ?? 'Episodio ${index + 1}', description: ep?.description ?? omdb?.description ?? '', imageUrl: ApiEndpoints.proxyImage(ep?.thumbnail ?? omdb?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), fallbackImageUrl: ApiEndpoints.proxyImage(epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), releaseDate: ep?.airDate ?? omdb?.released, duration: ep?.duration ?? (ep?.runtime != null ? '${ep!.runtime} min' : omdb?.duration), quality: epQuality, episodeUrl: ep?.url, source: epSource?.source ?? currentSource?.source, category: widget.category, certification: certification, scrollController: _scrollController, progress: epHistory?.progressPercentage, onTap: () {
                        final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum);
                        final tapSource = epBundle?.sourceForIndex(index) ?? currentSource;
                        final epThumb = ep?.thumbnail ?? omdb?.thumbnail ?? tapSource?.thumbnail ?? '';
                        final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
                        context.push('/player/${Uri.encodeComponent(widget.title)}?source=${tapSource?.source ?? currentSource?.source ?? widget.source}&url=${_episodeUrlFor(ep, tapSource?.url ?? currentSource?.url ?? widget.url, tapSource?.source ?? currentSource?.source ?? widget.source, ep?.number ?? index + 1)}&episode=${ep?.number ?? index + 1}&season=$currentSeason&serverName=${simplifySourceName(tapSource?.source ?? currentSource?.source ?? widget.source)}&language=${(epQuality.toLowerCase().contains('latino')) ? 'LAT' : 'SUB'}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${epData.total}$posterParam');
                      });
                    }, childCount: epData.total)),
                      if (epData.specials.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: isMobile ? 28 : 40, bottom: isMobile ? 16 : 32),
                          child: Text(
                            'Temporada 0',
                            style: TextStyle(
                              color: const Color(0xFFA5A5A5),
                              fontSize: isMobile ? 15 : 20,
                              fontWeight: isMobile ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      if (isMobile) SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                        final sp = epData.specials[index];
                        final spNum = sp.number;
                        final spSource = currentSource;
                        final spQuality = sp.quality ?? spSource?.quality ?? '';
                        return _EpisodeCard(episodeNumber: sp.number, title: sp.title ?? 'Especial', description: sp.description ?? '', imageUrl: ApiEndpoints.proxyImage(sp.thumbnail ?? spSource?.thumbnail ?? currentSource?.thumbnail ?? ''), fallbackImageUrl: ApiEndpoints.proxyImage(spSource?.thumbnail ?? currentSource?.thumbnail ?? ''), releaseDate: sp.airDate, duration: sp.duration ?? (sp.runtime != null ? '${sp.runtime} min' : null), quality: spQuality, episodeUrl: sp.url, source: spSource?.source ?? currentSource?.source, category: widget.category, certification: certification, episodeType: sp.episodeType, isMobile: true, scrollController: _scrollController, onTap: () {
                          final epThumb = sp.thumbnail ?? spSource?.thumbnail ?? '';
                          final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
                          context.push('/player/${Uri.encodeComponent(widget.title)}?source=${spSource?.source ?? currentSource?.source ?? widget.source}&url=${_episodeUrlFor(sp, spSource?.url ?? currentSource?.url ?? widget.url, spSource?.source ?? currentSource?.source ?? widget.source, sp.number)}&episode=$spNum&season=0&serverName=${simplifySourceName(spSource?.source ?? currentSource?.source ?? widget.source)}&language=${(spQuality.toLowerCase().contains('latino')) ? 'LAT' : 'SUB'}&startPosition=&category=${widget.category}&episodeTitle=${Uri.encodeComponent(sp.title ?? 'Especial')}&totalEpisodes=${epData.total}$posterParam');
                        });
                      }, childCount: epData.specials.length))
                      else SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: episodesCrossAxisCount, mainAxisSpacing: 20, crossAxisSpacing: 24, childAspectRatio: episodesAspectRatio), delegate: SliverChildBuilderDelegate((context, index) {
                        final sp = epData.specials[index];
                        final spSource = currentSource;
                        final spQuality = sp.quality ?? spSource?.quality ?? '';
                        return _EpisodeCard(episodeNumber: sp.number, title: sp.title ?? 'Especial', description: sp.description ?? '', imageUrl: ApiEndpoints.proxyImage(sp.thumbnail ?? spSource?.thumbnail ?? currentSource?.thumbnail ?? ''), fallbackImageUrl: ApiEndpoints.proxyImage(spSource?.thumbnail ?? currentSource?.thumbnail ?? ''), releaseDate: sp.airDate, duration: sp.duration ?? (sp.runtime != null ? '${sp.runtime} min' : null), quality: spQuality, episodeUrl: sp.url, source: spSource?.source ?? currentSource?.source, category: widget.category, certification: certification, episodeType: sp.episodeType, scrollController: _scrollController, onTap: () {
                          final epThumb = sp.thumbnail ?? spSource?.thumbnail ?? '';
                          final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}';
                          context.push('/player/${Uri.encodeComponent(widget.title)}?source=${spSource?.source ?? currentSource?.source ?? widget.source}&url=${_episodeUrlFor(sp, spSource?.url ?? currentSource?.url ?? widget.url, spSource?.source ?? currentSource?.source ?? widget.source, sp.number)}&episode=${sp.number}&season=0&serverName=${simplifySourceName(spSource?.source ?? currentSource?.source ?? widget.source)}&language=${(spQuality.toLowerCase().contains('latino')) ? 'LAT' : 'SUB'}&startPosition=&category=${widget.category}&episodeTitle=${Uri.encodeComponent(sp.title ?? 'Especial')}&totalEpisodes=${epData.total}$posterParam');
                        });
                      }, childCount: epData.specials.length)),
                    ],
                    SliverToBoxAdapter(child: SizedBox(height: isMobile ? 32 : 150)),
                  ]));
                },
                loading: () => SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: _EpisodesSkeleton(isMobile: isMobile)),
                error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $err', style: const TextStyle(color: const Color(0xFFA5A5AA))))),
              ),
              // Para Películas (sin Episodios) las pestañas se desplazan: Relacionado = 0, Extras = 1, Detalles = 2.
              if (selectedTabIndex == relatedTabIndex) ..._buildRelatedTab(
                hPadding, 
                unifiedRelations: unifiedRelationsAsync.valueOrNull,
                currentSource: currentSource,
              ),
    if (selectedTabIndex == extrasTabIndex) ..._buildExtrasTab(displayAnimeDetailAsync.valueOrNull, hPadding),
    if (selectedTabIndex == detailsTabIndex) ..._buildDetailsTab(displayDetail, hPadding, inferredSeasonAirDate: episodesAsync.valueOrNull?.response.seasonAirDate, sourceRating: currentSource?.score, showRatingSkeleton: currentSource?.score == null && detailLoading),
    if (selectedTabIndex == galleryTabIndex) ..._buildGalleryTab(
      hPadding,
      isMovieCategory ? 'movie' : 'tv',
      episodeReqMetaTitle,
      episodeReqYear,
    ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPageSkeleton(BuildContext context, bool isMobile) {
    return AnimatedOpacity(
      key: const ValueKey('skeleton'),
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeaderSkeleton(context, isMobile)),
          if (isMobile) SliverToBoxAdapter(child: _buildSynopsisSkeleton(context)),
          SliverToBoxAdapter(child: _buildTabsSkeleton(context, isMobile)),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.horizontalPadding(context)),
            sliver: _EpisodesSkeleton(isMobile: isMobile),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton(BuildContext context, bool isMobile) {
    if (isMobile) {
      return Column(children: [
        Stack(clipBehavior: Clip.hardEdge, children: [
          AspectRatio(aspectRatio: 16 / 12, child: Container(color: const Color(0xFF0B0B0D))),
        ]),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Row(children: [
            _RatingSkeleton(width: 44, height: 18, mobile: true),
            const SizedBox(width: 12),
            _SkeletonBox(width: 60, height: 18),
            const SizedBox(width: 8),
            _SkeletonBox(width: 40, height: 18),
          ]),
          const SizedBox(height: 24),
          Container(height: 52, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
        ])),
      ]);
    }
    return Stack(clipBehavior: Clip.hardEdge, children: [
      AspectRatio(aspectRatio: 2.8 / 1, child: Container(color: const Color(0xFF0B0B0D))),
      Positioned(
        left: 40, right: 40, bottom: 24,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 800,
              child: _SkeletonBox(width: 500, height: 60),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SkeletonBox(width: 64, height: 56, borderRadius: 28),
                const SizedBox(width: 16),
                _SkeletonBox(width: 64, height: 56, borderRadius: 28),
                const SizedBox(width: 16),
                _SkeletonBox(width: 64, height: 56, borderRadius: 28),
                const SizedBox(width: 16),
                _SkeletonBox(width: 64, height: 56, borderRadius: 28),
              ],
            ),
            const SizedBox(height: 24),
            Container(width: 220, height: 56, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _RatingSkeleton(width: 52, height: 20),
              const SizedBox(width: 12),
              _SkeletonBox(width: 60, height: 20),
              const SizedBox(width: 8),
              _SkeletonBox(width: 40, height: 20),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _SkeletonBox(width: 80, height: 18),
              const SizedBox(width: 12),
              _SkeletonBox(width: 50, height: 18),
              const SizedBox(width: 8),
              _SkeletonBox(width: 30, height: 18),
            ]),
          ]),
        ]),
      ),
    ]);
  }

  Widget _buildSynopsisSkeleton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        _SkeletonBox(width: double.infinity, height: 16),
        const SizedBox(height: 8),
        _SkeletonBox(width: double.infinity, height: 16),
        const SizedBox(height: 8),
        _SkeletonBox(width: 200, height: 16),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildTabsSkeleton(BuildContext context, bool isMobile) {
    final width = MediaQuery.sizeOf(context).width;
    final hPadding = isMobile ? 20.0 : (width >= 800 && width < 1200 ? 24.0 : ResponsiveUtils.horizontalPadding(context));
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 32),
        Row(children: [
          _SkeletonBox(width: isMobile ? 80 : 100, height: isMobile ? 24 : 28),
          const SizedBox(width: 24),
          _SkeletonBox(width: isMobile ? 80 : 100, height: isMobile ? 24 : 28),
          const SizedBox(width: 24),
          _SkeletonBox(width: isMobile ? 70 : 90, height: isMobile ? 24 : 28),
        ]),
        const SizedBox(height: 24),
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
    
    final isMobile = ResponsiveUtils.isMobile(context); 
    
    // Extraemos las categorías unificadas de las fuentes
    final List<RelatedInfo> franchiseSource = unifiedRelations?['franchise'] ?? [];
    final List<RelatedInfo> genreSource = unifiedRelations?['genre'] ?? [];
    final List<RelatedInfo> recommendedSource = unifiedRelations?['recommended'] ?? [];

    // Solo se muestran los relacionados extraídos de los servidores (URLs
    // directas). No se consulta AniList para esta sección.
    if (franchiseSource.isEmpty && genreSource.isEmpty && recommendedSource.isEmpty) {
      return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay contenido relacionado disponible', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)))))];
    }

    return [
      // 1. Carrusel: Franquicia y Secuelas (solo servidores)
      if (franchiseSource.isNotEmpty)
        _RelatedCarouselRow(
          title: 'Franquicia y Secuelas',
          hPadding: hPadding,
          items: _unifyAndDeduplicate(
            sourceItems: franchiseSource,
            currentSource: currentSource,
          ),
        ),

      // 2. Carrusel: Te recomendamos (solo servidores)
      if (recommendedSource.isNotEmpty)
        _RelatedCarouselRow(
          title: 'Te recomendamos',
          hPadding: hPadding,
          items: _unifyAndDeduplicate(
            sourceItems: recommendedSource,
            currentSource: currentSource,
            isRecommendation: true,
          ),
        ),

      // 3. Carrusel: mismo Género (UNIFICADO)
      if (genreSource.isNotEmpty)
        _RelatedCarouselRow(
          title: 'Mismo G\u00E9nero',
          hPadding: hPadding,
          items: genreSource.map((r) => _RelatedCardData(
            title: _cleanRelatedTitle(r.title), 
            poster: r.cover, 
            subtitle: r.relation,
            onTap: () => context.push('/content/${Uri.encodeComponent(r.title)}?source=${currentSource?.source ?? widget.source}&category=anime&url=${Uri.encodeComponent(r.url)}&metadataTitle=${Uri.encodeComponent(r.title)}')
          )).toList(),
        ),
    ];
  }

  /// Senior Helper: Une datos de fuentes locales con metadatos globales y elimina duplicados
  /// Senior Helper: Une datos de fuentes locales con metadatos globales y elimina duplicados
  String _cleanRelatedTitle(String t) =>
      t.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim();

  List<_RelatedCardData> _unifyAndDeduplicate({
    required List<RelatedInfo> sourceItems,
    SearchResult? currentSource,
    bool isRecommendation = false,
  }) {
    final Map<String, _RelatedCardData> unifiedMap = {};

    String normalize(String t) => t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    // Solo relacionados extraídos de los servidores (URLs directas).
    for (var r in sourceItems) {
      final displayTitle = _cleanRelatedTitle(r.title);
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

  String _galleryTypeLabel(String type) {
    switch (type) {
      case 'logo':
        return 'Logo';
      case 'backdrop':
        return 'Fondo';
      case 'banner':
        return 'Banner';
      case 'poster':
        return 'Póster';
      default:
        return type;
    }
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
    final isMobile = ResponsiveUtils.isMobile(context); final ops = detail.openings; final eds = detail.endings;
    if (ops.isEmpty && eds.isEmpty) return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay temas musicales disponibles', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)))))];
    return [
      if (ops.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Text('Openings', style: TextStyle(color: Colors.white, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: ops[index], isOP: true, fallbackImage: detail.banner ?? detail.backdrop), childCount: ops.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
      if (eds.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Text('Endings', style: TextStyle(color: Colors.white, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: eds[index], isOP: false, fallbackImage: detail.banner ?? detail.backdrop), childCount: eds.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
    ];
  }

  List<Widget> _buildDetailsTab(dynamic detail, double hPadding, {String? inferredSeasonAirDate, double? sourceRating, bool showRatingSkeleton = false}) {
    if (detail == null) return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    final isMobile = ResponsiveUtils.isMobile(context);     final rating = formatRating((detail.rating as double?) ?? sourceRating);
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

    if (isMobile) return [ 
      SliverPadding(padding: EdgeInsets.only(left: hPadding, right: hPadding, top: 0, bottom: 10), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ 
        const Text('M\u00E1s informaci\u00F3n', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 20), 
        if (detail.genres is List) Wrap(spacing: 8, runSpacing: 8, children: (detail.genres as List).map<Widget>((g) => _buildBadge(context, g.toString().toUpperCase())).toList()), 
        const SizedBox(height: 20), 
        Text(detail.overview ?? '', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 15, height: 1.5)), 
        const SizedBox(height: 24),
        if (platforms.isNotEmpty) ...[
          const Text('Disponible en', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: platforms.map<Widget>((p) => _PlatformLogo(platform: p, size: 32)).toList()),
          const SizedBox(height: 24),
        ],
        const Text('Advertencias de contenido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 8), 
        Text(_getWarningText(cert), style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 14)), 
        const SizedBox(height: 24), 
        if (status != null) ...[const Text('Estado', style: TextStyle(color: Colors.white, fontSize: 16)), Text(status, style: const TextStyle(color: const Color(0xFFA5A5AA))), const SizedBox(height: 24)],
        if (languages.isNotEmpty) ...[const Text('Idiomas', style: TextStyle(color: Colors.white, fontSize: 16)), Text(languages.join(', '), style: const TextStyle(color: const Color(0xFFA5A5AA))), const SizedBox(height: 24)],
        if (dir.isNotEmpty) ...[const Text('Direcci\u00F3n', style: TextStyle(color: Colors.white, fontSize: 16)), Text(dir.join(', '), style: const TextStyle(color: Color(0xFFA5A5AA)))], 
        if (cast.isNotEmpty && detail is! MovieDetail) ...[const SizedBox(height: 24), const Text('Elenco', style: TextStyle(color: Colors.white, fontSize: 16)), Text(cast.join(', '), style: const TextStyle(color: const Color(0xFFA5A5AA)))], 
        if (std.isNotEmpty) ...[const SizedBox(height: 24), const Text('Estudio', style: TextStyle(color: Colors.white, fontSize: 16)), Text(std.join(', '), style: const TextStyle(color: const Color(0xFFA5A5AA)))] 
      ]))),
      ..._buildCharacterSection(detail, hPadding),
      ..._buildCastSection(detail, hPadding),
    ];

    return [ 
      SliverPadding(padding: EdgeInsets.only(left: hPadding, right: hPadding, top: 8, bottom: 20), sliver: SliverToBoxAdapter(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 15, child: Column(children: [
          _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detail.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)), const SizedBox(height: 10),
            Wrap(spacing: 8, children: [ Text(detail is AnimeDetail ? 'Jap\u00F3n' : 'Internacional', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17)), const Text('•', style: TextStyle(color: Colors.white24)), Text(detail is AnimeDetail ? 'Anime' : 'Pel\u00EDcula', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17)) ]), const SizedBox(height: 10),
            Row(children: [ const Text('IMDb ', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 17, fontWeight: FontWeight.w900)), if (showRatingSkeleton && rating == null) const _RatingSkeleton(width: 36, height: 18) else Text(rating ?? 'N/A', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 17)), const Text('/10', style: TextStyle(color: const Color(0xFFA5A5AA))), const SizedBox(width: 16), Text(year, style: const TextStyle(color: const Color(0xFFA5A5AA))), if (sInfo.isNotEmpty) ...[const SizedBox(width: 16), Text(sInfo, style: const TextStyle(color: const Color(0xFFA5A5AA)))] ]), const SizedBox(height: 16),
            _ExpandableText(text: detail.overview ?? '', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 20), maxLines: 4)
          ])),
          const SizedBox(height: 24), if (dir.isNotEmpty || cast.isNotEmpty || std.isNotEmpty || status != null || languages.isNotEmpty) _DetailInfoCard(child: Column(children: [ 
            if (status != null) _buildPrimeRow('Estado', status),
            if (languages.isNotEmpty) _buildPrimeRow('idiomas', languages.join(', ')),
            if (dir.isNotEmpty) _buildPrimeRow('Direcci\u00F3n', dir.join(', ')), 
            if (cast.isNotEmpty && detail is! MovieDetail) _buildPrimeRow('Elenco', cast.join(', ')), 
            if (std.isNotEmpty) _buildPrimeRow('Estudio', std.join(', ')) 
          ]))
        ])),
        const SizedBox(width: 24), Expanded(flex: 10, child: Column(
          children: [
            _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Advertencias de contenido', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 16), _buildAgeBadge(context, cert), const SizedBox(height: 16), Text('${_getWarningText(cert)} Las luces intermitentes pueden afectar a espectadores fotosensibles', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 20)) ])),
            if (platforms.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Disponible en', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Wrap(spacing: 16, runSpacing: 16, children: platforms.map<Widget>((p) => _PlatformLogo(platform: p)).toList()),
              ])),
            ],
          ],
        ))
      ]))),
      ..._buildCharacterSection(detail, hPadding),
      ..._buildCastSection(detail, hPadding),
    ];
  }

  List<Widget> _buildCharacterSection(dynamic detail, double hPadding) {
    if (detail is! AnimeDetail || detail.characters.isEmpty) return [];
    final width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTabletOrFoldable = width >= 800 && width < 1100;
    
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPadding, 32, hPadding, 16), 
          child: Text(
            'Personajes y Actores de Voz', 
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: _CharacterCarousel(characters: detail.characters, horizontalPadding: hPadding)),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Widget> _buildCastSection(dynamic detail, double hPadding) {
    if (detail is! MovieDetail || detail.cast.isEmpty) return [];
    final width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTabletOrFoldable = width >= 800 && width < 1100;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPadding, 32, hPadding, 16), 
          child: Text(
            'Elenco Principal', 
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: _CastCarousel(cast: detail.cast, horizontalPadding: hPadding)),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  Widget _buildPrimeRow(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 17, fontWeight: FontWeight.w600))), Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 17)))]));
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

  const _RelatedCarouselRow({
    required this.title,
    required this.hPadding,
    required this.items,
  });

  @override
  State<_RelatedCarouselRow> createState() => _RelatedCarouselRowState();
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
    final width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTabletOrFoldable = width >= 800 && width < 1100;
    
    final cardWidth = isMobile ? 140.0 : 200.0;
    final carouselHeight = isMobile ? 290.0 : 400.0; // Senior Fix: Ajustado para ser más compacto sin overflow

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isMobile ? 0 : 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
            child: Text(
              widget.title, 
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 20 : 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
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
                      clipBehavior: Clip.none, // Senior Fix: Permite escalado sin recorte
                      padding: EdgeInsets.only(
                        left: widget.hPadding, 
                        right: widget.hPadding,
                        top: isMobile ? 10 : 20, // Espacio superior para el zoom
                        bottom: isMobile ? 10 : 20,
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
                if (!isMobile) ...[
                  Positioned(
                    left: 0, 
                    top: 20, 
                    bottom: 90, // Senior Fix: Centrado sobre el póster (Excluyendo texto)
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
                    right: 0, 
                    top: 20, 
                    bottom: 90, // Senior Fix: Centrado sobre el póster
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterCarousel extends StatefulWidget {
  final List<CharacterInfo> characters;
  final double horizontalPadding;

  const _CharacterCarousel({required this.characters, required this.horizontalPadding});

  @override
  State<_CharacterCarousel> createState() => _CharacterCarouselState();
}

class _CharacterCarouselState extends State<_CharacterCarousel> {
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
    final isMobile = ResponsiveUtils.isMobile(context);
    final cardWidth = isMobile ? 110.0 : 160.0;
    final carouselHeight = isMobile ? 220.0 : 320.0;

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
                itemBuilder: (context, index) => _CharacterCard(character: widget.characters[index], width: cardWidth),
              ),
            ),
          ),
          if (!isMobile) ...[
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
        ],
      ),
    );
  }
}

class _PlatformLogo extends StatelessWidget {
  final PlatformInfo platform;
  final double size;
  const _PlatformLogo({required this.platform, this.size = 48});

  @override
  Widget build(BuildContext context) {
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

class _CastCarousel extends StatefulWidget {
  final List<CastMember> cast;
  final double horizontalPadding;

  const _CastCarousel({required this.cast, required this.horizontalPadding});

  @override
  State<_CastCarousel> createState() => _CastCarouselState();
}

class _CastCarouselState extends State<_CastCarousel> {
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
    final isMobile = ResponsiveUtils.isMobile(context);
    final cardWidth = isMobile ? 110.0 : 160.0;
    final carouselHeight = isMobile ? 220.0 : 320.0;

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
                itemBuilder: (context, index) => _CastCard(member: widget.cast[index], width: cardWidth),
              ),
            ),
          ),
          if (!isMobile) ...[
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
        ],
      ),
    );
  }
}

class _CastCard extends StatelessWidget {
  final CastMember member;
  final double width;
  const _CastCard({required this.member, required this.width});

  @override Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
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
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 4),
          if (member.character != null)
            Text(
              member.character!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: isMobile ? 11 : 14),
            ),
        ],
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final CharacterInfo character;
  final double width;
  const _CharacterCard({required this.character, required this.width});

  String _translateRole(String? role) {
    if (role == null) return '';
    final r = role.toLowerCase();
    if (r == 'main') return 'Principal';
    if (r == 'supporting') return 'Secundario';
    if (r == 'background') return 'Fondo';
    return role;
  }

  @override Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
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
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 4),
          if (voiceActor != null)
            Text(
              voiceActor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: isMobile ? 11 : 14),
            ),
          const SizedBox(height: 2),
          Text(
            _translateRole(character.role),
            style: TextStyle(color: (character.role?.toLowerCase() == 'main') ? const Color(0xFFEF7A1E) : Colors.white24, fontSize: isMobile ? 10 : 13, fontWeight: FontWeight.w900),
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

  const _GalleryTabContent({
    required this.hPadding,
    required this.kind,
    this.title,
    this.year,
  });

  @override
  ConsumerState<_GalleryTabContent> createState() => _GalleryTabContentState();
}

class _GalleryTabContentState extends ConsumerState<_GalleryTabContent> {
  String _selectedFilter = "all";

  @override
  Widget build(BuildContext context) {
    final params = GalleryParams(kind: widget.kind, title: _stripSeasonSuffix(widget.title), year: widget.year);
    final async = ref.watch(galleryProvider(params));
    final isMobile = ResponsiveUtils.isMobile(context);

    return async.when(
      loading: () => SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 3 : 5,
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
      error: (_, __) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text("Error al cargar la galería", style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)),
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

        final filtered = _selectedFilter == "all"
            ? g.gallery
            : g.gallery.where((img) => img.type == _selectedFilter).toList();

        final hasPosters = g.gallery.any((img) => img.type == "poster");
        final hasBackdrops = g.gallery.any((img) => img.type == "backdrop");
        final hasLogos = g.gallery.any((img) => img.type == "logo");
        final hasBanners = g.gallery.any((img) => img.type == "banner");

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.hPadding, 
                  right: widget.hPadding, 
                  top: isMobile ? 0 : 8, 
                  bottom: 16
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _GalleryFilterChip(
                        label: "Todos",
                        selected: _selectedFilter == "all",
                        onSelected: () => setState(() => _selectedFilter = "all"),
                      ),
                      if (hasPosters) ...[
                        const SizedBox(width: 8),
                        _GalleryFilterChip(
                          label: "Pósters",
                          selected: _selectedFilter == "poster",
                          onSelected: () => setState(() => _selectedFilter = "poster"),
                        ),
                      ],
                      if (hasBackdrops) ...[
                        const SizedBox(width: 8),
                        _GalleryFilterChip(
                          label: "Fondos",
                          selected: _selectedFilter == "backdrop",
                          onSelected: () => setState(() => _selectedFilter = "backdrop"),
                        ),
                      ],
                      if (hasLogos) ...[
                        const SizedBox(width: 8),
                        _GalleryFilterChip(
                          label: "Logos",
                          selected: _selectedFilter == "logo",
                          onSelected: () => setState(() => _selectedFilter = "logo"),
                        ),
                      ],
                      if (hasBanners) ...[
                        const SizedBox(width: 8),
                        _GalleryFilterChip(
                          label: "Banners",
                          selected: _selectedFilter == "banner",
                          onSelected: () => setState(() => _selectedFilter = "banner"),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Text("No hay imágenes de este tipo", style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 16)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile 
                        ? (_selectedFilter == "backdrop" || _selectedFilter == "banner" ? 2 : 3)
                        : (_selectedFilter == "backdrop" || _selectedFilter == "banner" ? 4 : 6),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _selectedFilter == "backdrop" 
                        ? 16 / 9 
                        : (_selectedFilter == "banner" ? 3.0 : (_selectedFilter == "logo" ? 1.0 : 0.67)),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final img = filtered[index];
                      return _GalleryItem(
                        image: img,
                        onTap: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              opaque: false,
                              barrierColor: Colors.black.withOpacity(0.5),
                              pageBuilder: (context, _, __) => FullScreenViewer(
                                images: filtered,
                                initialIndex: index,
                              ),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                            ),
                          );
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

class _GalleryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _GalleryFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEF7A1E) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFEF7A1E) : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _GalleryItem extends StatefulWidget {
  final GalleryImage image;
  final VoidCallback onTap;

  const _GalleryItem({required this.image, required this.onTap});

  @override
  State<_GalleryItem> createState() => _GalleryItemState();
}

class _GalleryItemState extends State<_GalleryItem> {
  bool _isHovered = false;

  String _getTypeLabel(String type) {
    switch (type) {
      case "logo": return "Logo";
      case "backdrop": return "Fondo";
      case "banner": return "Banner";
      case "poster": return "Póster";
      default: return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = ApiEndpoints.proxyImage(widget.image.url);
    final isMobile = ResponsiveUtils.isMobile(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Hero(
          tag: "gallery_${widget.image.url}",
          child: AnimatedScale(
            scale: (!isMobile && _isHovered) ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (!isMobile && _isHovered) ? const Color(0xFFEF7A1E) : Colors.white10,
                  width: 2,
                ),
                boxShadow: (!isMobile && _isHovered) 
                    ? [BoxShadow(color: const Color(0xFFEF7A1E).withOpacity(0.3), blurRadius: 10, spreadRadius: 2)] 
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: widget.image.type == "logo" ? BoxFit.contain : BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Container(color: Colors.white10),
                    ),
                    if (!isMobile && _isHovered)
                      Container(color: Colors.black26),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getTypeLabel(widget.image.type),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.image.source.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF9AA0FF), fontSize: 10, fontWeight: FontWeight.bold),
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

