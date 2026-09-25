import 'dart:async';
import 'dart:ui' as ui;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:auris_core/auris_core.dart';
import '../../../shared/widgets/auris_bottom_bar.dart';
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

bool _isMovieContent(dynamic detail, [String? kind]) {
  final k = kind?.toLowerCase() ?? '';
  if (k.isNotEmpty) return k == 'movie' || k == 'movie_anime';

  if (detail is AnimeDetail) {
    return detail.format?.toLowerCase() == 'movie';
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
    return DetailRatingSkeleton(width: width, height: height, mobile: mobile);
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const _SkeletonBox({required this.width, required this.height, this.borderRadius = 4});
  @override
  Widget build(BuildContext context) {
    return DetailSkeletonBox(width: width, height: height, borderRadius: borderRadius);
  }
}

// --- SUB-WIDGETS ---

// _SeasonSelector removed - using SeasonSelector from auris_core

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
    // Aniyae (al final, por catálogos incompletos).
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
  final String? episodeUrl;
  final String? source;
  final String? category;
  final String? episodeType;
  final bool isCompact;

  const _EpisodeCard({
    required this.episodeNumber, 
    required this.title, 
    required this.description, 
    required this.imageUrl, 
    required this.fallbackImageUrl, 
    this.releaseDate, 
    this.duration, 
    required this.quality, 
    this.certification, 
    this.isMobile = false, 
    this.progress, 
    required this.onTap, 
    this.scrollController, 
    this.episodeUrl, 
    this.source, 
    this.category, 
    this.episodeType,
    this.isCompact = false,
  });
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
    if (widget.isMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: ResponsiveUtils.sp(context, 16), top: 0),
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
              if (widget.description.isNotEmpty) ...[
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

    // Tablet / Desktop Grid Layout
    final double screenW = MediaQuery.sizeOf(context).width;
    final double titleFontSize = widget.isCompact ? 14.5 : (screenW * 0.009).clamp(16.0, 19.0);
    final double descFontSize = widget.isCompact ? 12.0 : (screenW * 0.008).clamp(13.0, 15.0);
    final double gapImageToText = widget.isCompact ? 8.0 : 12.0;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ]),
            SizedBox(height: gapImageToText),
            Text(
              _displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // Fecha y duración en Grid (con elipsis)
            if (!_isSpecial && (widget.duration != null || widget.releaseDate != null))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${widget.duration ?? ''}${widget.duration != null && widget.releaseDate != null ? ' ' : ''}${_formatDate(widget.releaseDate)}',
                  style: TextStyle(
                    color: const Color(0xFFA5A5AA),
                    fontSize: widget.isCompact ? 11.5 : 13.0,
                  ),
                ),
              ),
            if (!widget.isCompact && (!_isSpecial || widget.description.isNotEmpty))
              Text(
                widget.description.isNotEmpty ? widget.description : 'Sin descripción disponible.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFFA5A5AA),
                  fontSize: descFontSize,
                  height: 1.4,
                  fontWeight: FontWeight.normal,
                ),
              ),
            if (!widget.isCompact && !_isSpecial) const SizedBox(height: 6),
            Row(
              children: [
                if (widget.certification != null && widget.certification != 'NR') ...[
                  _buildAgeBadge(context, widget.certification!, small: true),
                  const SizedBox(width: 8),
                ],
                if (_typeBadge != null) ...[
                  _buildAgeBadge(context, _typeBadge!, small: true),
                  const SizedBox(width: 8),
                ],
                _buildAgeBadge(context, _languageBadge, small: true),
              ],
            ),
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
  final AnimeThemeInfo theme; final bool isOP; final String? fallbackImage; final String animeTitle; final String? logoUrl;
  const _ThemeCard({required this.theme, required this.isOP, this.fallbackImage, required this.animeTitle, this.logoUrl});
  @override State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _isHovered = false;

  @override Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context); 
    String? img = ApiEndpoints.proxyImage(
      (widget.theme.imageUrl?.isNotEmpty == true) ? widget.theme.imageUrl! : widget.fallbackImage,
      width: 1280,
    );
    final bool isSelected = !isMobile && _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true), 
      onExit: (_) => setState(() => _isHovered = false), 
      child: GestureDetector(
        onTap: () {
          String url = widget.theme.videoUrl; final typeLabel = widget.isOP ? 'OP' : 'ED';
          if (!url.startsWith('http')) { 
            url = 'https://www.youtube.com/watch?v=$url'; 
            final extraTitleParam = '&title=${Uri.encodeComponent(widget.animeTitle)}&episodeTitle=${Uri.encodeComponent(widget.theme.title)}&logoUrl=${Uri.encodeComponent(widget.logoUrl ?? '')}';
            context.push('/player/${Uri.encodeComponent(widget.theme.title)}?source=YouTube&url=${Uri.encodeComponent(url)}&episode=$typeLabel&serverName=YouTube$extraTitleParam');
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
            final extraTitleParam = '&title=${Uri.encodeComponent(widget.animeTitle)}&episodeTitle=${Uri.encodeComponent(widget.theme.title)}&logoUrl=${Uri.encodeComponent(widget.logoUrl ?? '')}';
            context.push('/player/${Uri.encodeComponent(widget.theme.title)}?source=&url=${Uri.encodeComponent(url)}&episode=$typeLabel&serverName=Themes$v720Param$v1080Param$extraTitleParam');
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
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style), 
        textDirection: ui.TextDirection.ltr, 
        maxLines: widget.maxLines
      )..layout(maxWidth: constraints.maxWidth);
      final hasOverflow = tp.didExceedMaxLines;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: hasOverflow ? () => setState(() => _expanded = !_expanded) : null,
          child: Text(
            widget.text, 
            maxLines: _expanded ? null : widget.maxLines, 
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis, 
            style: widget.style
          ),
        ),
        if (hasOverflow) 
          Padding(
            padding: const EdgeInsets.only(top: 4), 
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded), 
              child: Text(
                _expanded ? 'Ver menos' : 'Ver m\u00E1s...', 
                style: const TextStyle(color: Color(0xFFEF7A1E), fontWeight: FontWeight.bold, fontSize: 14)
              )
            )
          ),
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
  final bool isLoading;
  const _DetailIconButton({required this.icon, required this.onPressed, required this.label, this.isMobile = false, this.size, this.iconSize, this.color, this.isLoading = false});
  @override State<_DetailIconButton> createState() => _DetailIconButtonState();
}

class _DetailIconButtonState extends State<_DetailIconButton> {
  bool _isHovered = false;
  @override Widget build(BuildContext context) {
    if (widget.isMobile) {
      return InkWell(
        onTap: widget.isLoading ? null : widget.onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: widget.color ?? Colors.white24, width: 0.8), 
            borderRadius: BorderRadius.circular(8)
          ), 
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: widget.color ?? Colors.white),
                )
              else
                Icon(widget.icon, color: widget.color ?? Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.isLoading ? 'Cargando...' : widget.label,
                style: GoogleFonts.poppins(
                  color: Colors.white, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
            child: widget.isLoading
              ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.color ?? Colors.white)))
              : IconButton(
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

class _CastCreditsModal extends ConsumerWidget {
  final CastInfo person;
  const _CastCreditsModal({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveUtils.isMobile(context);

    final creditsAsync = ref.watch(castCreditsProvider(CastCreditsParams(
      url: person.url ?? '',
      name: person.name,
      profile: person.rawProfile, // Senior: Enviar URL original al backend
      personId: person.id,
    )));

    return Dialog(
      backgroundColor: const Color(0xFF0B0B0D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : width * 0.08,
        vertical: isMobile ? 20 : 40,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            // Header del Modal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: person.profile != null && person.profile!.isNotEmpty
                        ? CachedNetworkImageProvider(person.profile!)
                        : null,
                    backgroundColor: Colors.white10,
                    child: person.profile == null || person.profile!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Filmografía',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFEF7A1E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Cuerpo - Metadata + Bio + Filmografía
            Expanded(
              child: creditsAsync.when(
                data: (response) {
                  if (response == null || (response.results.isEmpty && response.biography == null)) {
                    return Center(
                      child: Text(
                        'No se encontró información disponible',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                      ),
                    );
                  }

                  final results = response.results;
                  final double posterWidth = ResponsiveUtils.posterWidth(context);
                  final double availableWidth = isMobile ? (width - 32) : (width * 0.8 - 48);
                  final int crossAxisCount = (availableWidth / (posterWidth + 12)).round().clamp(isMobile ? 2 : 3, 8);

                  return CustomScrollView(
                    slivers: [
                      // Bio y Metadata
                      if (response.biography != null || response.birthday != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (response.birthday != null || response.placeOfBirth != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Wrap(
                                      spacing: 20,
                                      runSpacing: 10,
                                      children: [
                                        if (response.birthday != null)
                                          _buildInfoItem('Nacimiento', response.birthday!),
                                        if (response.placeOfBirth != null)
                                          _buildInfoItem('Lugar', response.placeOfBirth!),
                                        if (response.gender != null)
                                          _buildInfoItem('Género', response.gender!),
                                      ],
                                    ),
                                  ),
                                if (response.biography != null) ...[
                                  Text(
                                    'Biografía',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    response.biography!,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                Text(
                                  'Conocido por',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),

                      // Lista de Créditos
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: isMobile ? 0.54 : 0.58,
                            crossAxisSpacing: isMobile ? 12 : 20,
                            mainAxisSpacing: isMobile ? 12 : 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = results[index];
                              return FocusablePosterCard(
                                title: item.title,
                                posterUrl: item.thumbnail,
                                subtitle: item.year?.toString(),
                                rating: formatRating(item.score),
                                showInfo: true,
                                onTap: () {
                                  Navigator.pop(context); // Cerrar modal antes de navegar

                                  if (item.url.isNotEmpty && item.url.startsWith('http')) {
                                    final String cat = item.kind?.isNotEmpty == true
                                        ? item.kind!
                                        : (item.totalSeasons != null && item.totalSeasons! > 0 ? 'series' : 'movie');

                                    final posterParam = '&title=${Uri.encodeComponent(item.title)}&posterUrl=${Uri.encodeComponent(item.thumbnail)}&bannerUrl=${Uri.encodeComponent(item.banner ?? '')}&logoUrl=${Uri.encodeComponent(item.logo ?? '')}';

                                    context.push('/detalles/${Uri.encodeComponent(item.title)}?source=${item.source}&url=${Uri.encodeComponent(item.url)}&category=$cat$posterParam', extra: item);
                                  } else {
                                    // Anime: los items NO traen url de scraper -> click en filmografía = search normal por title
                                    context.push('/busqueda?q=${Uri.encodeComponent(item.title)}');
                                  }
                                },
                              );
                            },
                            childCount: results.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
                error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white54))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            color: const Color(0xFFEF7A1E),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// --- MAIN WIDGETS ---

class ContentScreen extends ConsumerStatefulWidget {
  final String title;
  final String source;
  final String url;
  final String? quality;
  final String? type;
  final String? metadataTitle;
  final String? banner;
  final String category;
  final int? year;
  final int? totalSeasons;
  final String? sectionId;

  /// Card abierta (con sus fuentes/servidores). Se usa para sembrar al instante la
  /// lista de servidores sin re-raspear en vivo. Para deep-links (sin card) es null
  /// y se reconstruye una sola fuente desde title/source/url.
  final SearchResult? result;

  const ContentScreen({
    super.key,
    required this.title,
    required this.source,
    required this.url,
    this.quality,
    this.type,
    this.metadataTitle,
    this.banner,
    this.category = 'all',
    this.year,
    this.totalSeasons,
    this.sectionId,
    this.result,
  });

  @override
  ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> {
  int _selectedTabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _showContent = false;
  Timer? _loadTimer;
  GroupedEpisodesResult? _lastEpisodes;

  // Trailer & Revealed State
  String? _lastTrailerKey;
  bool _revealed = false;
  Timer? _revealTimeout;
  bool _isTrailerLoading = false;
  YoutubePlayerController? _ytController;
  StreamSubscription? _ytSubscription;
  Timer? _fadeTimer;
  Timer? _delayTimer;
  Timer? _titleHideTimer;
  bool _showTitle = true;
  bool _isMuted = true;
  bool _showPlayer = false;
  bool _isPlayedOnce = false;

  @override void initState() {
    super.initState();
    _loadTimer = Timer(ApiEndpoints.pageLoadTimeout, () {
      if (mounted) setState(() => _showContent = true);
    });
    _revealTimeout = Timer(ApiEndpoints.detailRevealTimeout, () {
      if (mounted && !_revealed) setState(() => _revealed = true);
    });
  }

  @override void dispose() {
    _loadTimer?.cancel();
    _revealTimeout?.cancel();
    _ytSubscription?.cancel();
    _delayTimer?.cancel();
    _fadeTimer?.cancel();
    _titleHideTimer?.cancel();
    _disposeController();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTitleHideTimer() {
    _titleHideTimer?.cancel();
    _titleHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showPlayer && _showTitle) {
        setState(() => _showTitle = false);
      }
    });
  }

  void _handleInteraction() {
    if (!mounted) return;
    if (!_showTitle) {
      setState(() => _showTitle = true);
    }
    _startTitleHideTimer();
  }

  void _checkAndInitTrailer(AsyncValue<ContentDetailResponse?> detailAsync) {
    final d = detailAsync.valueOrNull?.main;
    final k = (d is AnimeDetail) ? d.trailerKey : (d is MovieDetail ? d.trailerKey : null);
    if (k != null && k.isNotEmpty) { 
      if (k != _lastTrailerKey) { 
        _lastTrailerKey = k; 
      }
    } else if (_lastTrailerKey != null) { 
      _lastTrailerKey = null; 
    }
  }

  void _initTrailer(String key, {bool immediate = false}) {
    _delayTimer?.cancel();
    void start() {
      if (!mounted || key != _lastTrailerKey) return;
      if (_ytController != null) {
        _fadeTimer?.cancel(); 
        _ytController!.pauseVideo(); 
        _ytController!.seekTo(seconds: 0);
        if (!_isMuted) { _ytController!.unMute(); _ytController!.setVolume(100); } else { _ytController!.mute(); }
        setState(() { _showPlayer = false; _isPlayedOnce = false; _showTitle = true; });
        _titleHideTimer?.cancel();
        return;
      }
      final ctrl = YoutubePlayerController.fromVideoId(
        videoId: key, 
        autoPlay: false, 
        params: const YoutubePlayerParams(
          showControls: false, 
          showFullscreenButton: false, 
          mute: true, 
          loop: false, 
          showVideoAnnotations: false, 
          playsInline: true, 
          strictRelatedVideos: true, 
          enableKeyboard: false
        )
      );
      ctrl.listen((state) {
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
        if (p > 5 && d > 30 && (d - p) < 12) { 
          if (_showPlayer && mounted) { 
            setState(() { 
              _showPlayer = false; 
              _isPlayedOnce = true; 
              _showTitle = true;
            }); 
            _titleHideTimer?.cancel();
            _fadeOutAudio(ctrl); 
          } 
        }
      });
      if (mounted) {
        setState(() { _ytController = ctrl; _showPlayer = false; _isPlayedOnce = false; _showTitle = true; });
        _titleHideTimer?.cancel();
      }
    }
    if (immediate) start(); else _delayTimer = Timer(const Duration(seconds: 1), start);
  }

  void _fadeOutAudio(YoutubePlayerController ctrl) {
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

  void _disposeController() { 
    _ytController?.close();
    _ytController = null;
    _lastTrailerKey = null; 
  }

  void _handlePlay(
    BuildContext context, 
    UnifiedContentState state, 
    List<PlaybackHistory> history,
    String? heroBanner,
    dynamic detailData,
  ) {
    final currentSource = state.selectedSource;
    if (currentSource == null) return;
    
    final isMovieCategory = state.isMovieish;
    final currentSeason = state.currentSeason;
    
    String? playUrl;
    String? episodeLabel;
    int? epNum;
    SearchResult? tapSource;
    
    if (isMovieCategory) {
      playUrl = currentSource.url;
      episodeLabel = 'Película';
      tapSource = currentSource;
    } else {
      final latest = history.where((h) => h.contentId == widget.title).firstOrNull;
      epNum = latest != null ? int.tryParse(latest.episode ?? '1') ?? 1 : 1;
      final epBundle = state.episodes.valueOrNull;
      tapSource = epBundle?.sourceForNumber(epNum) ?? currentSource;
      final ep = epBundle?.response.episodes.firstWhereOrNull((e) => e.number == epNum);
      playUrl = _episodeUrlFor(ep, tapSource.url, tapSource.source, epNum);
      episodeLabel = epNum.toString();
    }
    
    if (playUrl == null || playUrl.isEmpty) return;
    
    final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum?.toString() ?? '1');
    final epThumb = currentSource.thumbnail ?? '';
    final posterParam = '&title=${Uri.encodeComponent(state.seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}&logoUrl=${Uri.encodeComponent(detailData?.logo ?? '')}';
    
    context.push('/player/${Uri.encodeComponent(widget.title)}?source=${tapSource.source}&url=${Uri.encodeComponent(playUrl)}&episode=$episodeLabel&season=$currentSeason&serverName=${simplifySourceName(tapSource.source)}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${state.episodes.valueOrNull?.response.total ?? 1}$posterParam');
  }

  Widget _buildMetaRow(dynamic d, {required bool isMobile, double? sourceRating, String? kind}) {
    final year = (d is AnimeDetail) ? d.year?.toString() : (d is MovieDetail ? d.releaseDate?.split('-').first : null);
    final r = (d?.rating ?? sourceRating) as double?;
    final rating = formatRating(r);
    List<String> genres = [];
    if (d is AnimeDetail) genres = d.genres;
    else if (d is MovieDetail) genres = d.genres;
    final cert = (d != null && d.certification != null && d.certification!.isNotEmpty) ? d.certification : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row of badges (Certification FIRST, then genres) - FORZADO A 1 SOLA LÍNEA
        if ((cert != null && cert.isNotEmpty && cert != 'NR') || (genres.isNotEmpty && _revealed))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none, // Permitir que las etiquetas respiren
              child: Row(
                children: [
                  if (cert != null && cert.isNotEmpty && cert != 'NR')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildAgeBadge(context, cert.toUpperCase(), small: false),
                    ),
                  ...genres.map((g) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBadge(context, g.toUpperCase(), small: false),
                  )),
                ],
              ),
            ),
          )
        else if (!_revealed) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                _SkeletonBox(width: 40, height: 22, borderRadius: 4),
                const SizedBox(width: 8),
                _SkeletonBox(width: 80, height: 22, borderRadius: 4),
              ],
            ),
          ),
        ],
        Row(
          children: [
            if (!_revealed) ...[
              const _RatingSkeleton(width: 50, height: 18, mobile: true),
              const SizedBox(width: 16),
              const _SkeletonBox(width: 40, height: 18),
            ] else ...[
              if (r != null && r > 0) ...[
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
                const SizedBox(width: 6),
                Text(rating ?? 'N/A', style: const TextStyle(color: Color(0xFFFFC107), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
              ],
              if (year != null) ...[
                Text(year, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                if (_isMovieContent(d, kind)) ...[
                  const SizedBox(width: 16),
                  Text(_formatRuntime(_getRuntime(d)), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ],
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMainActionButton(BuildContext context, {required bool isMobile, PlaybackHistory? latestHistory, VoidCallback? onPlay}) {
    final hasHistory = latestHistory != null;
    final String label = hasHistory ? 'Continuar viendo' : 'Reproducir ahora';
    final IconData icon = Icons.play_arrow_rounded;

    final double? progress = hasHistory ? latestHistory.progress : null;
    final bool hasProgress = progress != null && progress > 0.02;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPlay,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 32),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black, 
                fontWeight: FontWeight.bold, 
                fontSize: 18
              )
            ),
            if (hasProgress) ...[
              const SizedBox(width: 16),
              _buildButtonProgressBar(progress, isMobile: isMobile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtonProgressBar(double progress, {bool isMobile = false}) {
    return Container(
      width: isMobile ? 85 : 140,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEF7A1E),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularActions(BuildContext context, {required bool isMobile, String? poster, String? banner}) {
    const bool isFav = false; 
    final actionRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
      if (_lastTrailerKey != null) ...[
        _DetailIconButton(
          icon: Icons.movie_outlined,
          label: 'Ver tráiler',
          isLoading: _isTrailerLoading,
          onPressed: () async {
            if (_isTrailerLoading) return;
            setState(() => _isTrailerLoading = true);
            try {
              final directUrl = await YoutubeResolver.getDirectStreamUrl(_lastTrailerKey!);
              if (directUrl != null && context.mounted) {
                final posterParam = '&title=${Uri.encodeComponent(widget.title)}&posterUrl=${Uri.encodeComponent(poster ?? '')}&bannerUrl=${Uri.encodeComponent(banner ?? '')}';
                context.push('/player/${Uri.encodeComponent(widget.title)}?source=YouTube&url=${Uri.encodeComponent(directUrl)}&episode=Trailer&serverName=YouTube&totalEpisodes=1$posterParam');
              }
            } finally {
              if (mounted) setState(() => _isTrailerLoading = false);
            }
          },
          isMobile: isMobile,
        ),
        const SizedBox(width: 8),
      ],
      _DetailIconButton(
        icon: isFav ? Icons.check : Icons.add,
        label: isFav ? 'En mi lista' : 'Mi lista',
        onPressed: () {},
        isMobile: isMobile,
      ),
      const SizedBox(width: 8),
      _DetailIconButton(
        icon: Icons.thumb_up_off_alt,
        label: 'Me gusta',
        onPressed: () {},
        isMobile: isMobile,
      ),
      const SizedBox(width: 8),
      _DetailIconButton(
        icon: Icons.thumb_down_off_alt,
        label: 'No me gusta',
        onPressed: () {},
        isMobile: isMobile,
      ),
      const SizedBox(width: 8),
      _DetailIconButton(
        icon: Icons.share_outlined,
        label: 'Compartir',
        onPressed: () {},
        isMobile: isMobile,
      ),
    ],
  );
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none, // Senior Fix: Permitir que los botones respiren fuera del contenedor sin recortes
      padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.isMobile(context) ? 24 : 0),
      child: actionRow,
    ),
  );
}

  @override Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isCompact = width < 1200 || height < 900;
    
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final hPadding = isMobile ? 20.0 : (width >= 800 && width < 1200 ? 24.0 : horizontalPadding);
    final episodesCrossAxisCount = isMobile ? 1 : (width < 700 ? 2 : (width < 1150 ? 3 : (width < 1550 ? 4 : (width < 2100 ? 5 : 6))));
    final episodesAspectRatio = isMobile ? 1.15 : (width < 1150 ? 1.05 : 1.1);

    final detailParams = UnifiedDetailParams(
      title: widget.title,
      metadataTitle: widget.metadataTitle,
      category: widget.category,
      kind: widget.result?.kind,
      year: widget.year,
      season: widget.result?.season,
      source: widget.source,
      url: widget.url,
      type: widget.result?.type ?? widget.type,
      sectionId: widget.sectionId,
      initialSources: widget.result != null ? List.unmodifiable([widget.result!]) : null,
    );

    final detailState = ref.watch(unifiedContentProvider(detailParams));
    
    // Tracking de personalización
    ref.watch(detailViewTrackerProvider(detailParams));

    // Sincronizar fuentes y estado del tráiler
    ref.listen<UnifiedContentState>(unifiedContentProvider(detailParams), (prev, next) {
      if (next.allSources.isNotEmpty) {
        final currentInPlayer = ref.read(activeContentSourcesProvider);
        if (!const ListEquality().equals(currentInPlayer, next.allSources)) {
          ref.read(activeContentSourcesProvider.notifier).state = next.allSources;
        }
      }
      _checkAndInitTrailer(next.detail);
      if (!_revealed && (next.detail.valueOrNull != null || next.detail.hasValue)) {
        setState(() => _revealed = true);
      }
    });

    final detailAsync = detailState.detail;
    final detailData = detailAsync.valueOrNull?.main;
    final isMovieCategory = detailState.isMovieish;
    final currentSeason = detailState.currentSeason;
    final totalSeasons = detailState.totalSeasons;
    final activeSources = detailState.allSources;
    final currentSource = detailState.selectedSource;
    final episodesAsync = detailState.episodes;
    final unifiedRelationsAsync = detailState.relations;
    final seasonTitle = detailState.seasonTitle;

    final dataReady = detailAsync.hasValue || activeSources.isNotEmpty;
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

    final hasEpisodesTab = !isMovieCategory;

    final castAsync = detailState.cast;
    // Tabs visibles solo con datos recibidos del servidor: sin placeholders
    // mientras carga y sin fallback de detalles. Si llega vacío [], se oculta.
    final bool hasCast = castAsync.maybeWhen(
      data: (d) => d.isNotEmpty,
      orElse: () => false,
    );

    // OP/ED desde /api/themes (fuera del detail: no lo bloquean). Movies
    // siguen leyéndolos de su detail (si el server los envía).
    final themesData = detailState.themes.valueOrNull;
    final currentOpenings = detailData is AnimeDetail
        ? (themesData?.openings ?? const <AnimeThemeInfo>[])
        : (detailData is MovieDetail ? (detailData as MovieDetail).openings : const <AnimeThemeInfo>[]);
    final currentEndings = detailData is AnimeDetail
        ? (themesData?.endings ?? const <AnimeThemeInfo>[])
        : (detailData is MovieDetail ? (detailData as MovieDetail).endings : const <AnimeThemeInfo>[]);
    final extrasTabIndexRaw = (currentOpenings.isNotEmpty || currentEndings.isNotEmpty) ? 1 : -1;
    
    final bool hasRelatedData = unifiedRelationsAsync.maybeWhen(data: (d) => d.isNotEmpty, orElse: () => false);
    final tabLabels = <String>[
      if (hasEpisodesTab) 'Episodios',
      if (hasRelatedData) 'Relacionado',
      if (hasCast) 'Elenco',
      'Detalles',
      if (extrasTabIndexRaw != -1) 'Extras',
      'Galería',
    ];

    final int episodesTabIndex = tabLabels.indexOf('Episodios');
    final int relatedTabIndex = tabLabels.indexOf('Relacionado');
    final int castTabIndex = tabLabels.indexOf('Elenco');
    final int detailsTabIndex = tabLabels.indexOf('Detalles');
    final int extrasTabIndexFinal = tabLabels.indexOf('Extras');
    final int galleryTabIndex = tabLabels.indexOf('Galería');

    final selectedTabIndex = _selectedTabIndex.clamp(0, tabLabels.length - 1);

    final certification = detailData != null ? ((detailData is MovieDetail ? (detailData as MovieDetail).certification : (detailData is AnimeDetail ? (detailData as AnimeDetail).certification : null)) ?? 'NR') : 'NR';

    final heroBanner = ApiEndpoints.proxyImage(
      DetailBackdropResolver.resolve(
        detail: detailData,
        bannerParam: widget.banner,
        sourceBanner: activeSources.isNotEmpty ? activeSources.first.banner : null,
        season: currentSeason,
      ),
      width: 1920,
      height: 1080,
    );

    final historyAsync = ref.watch(playbackHistoryStateProvider);
    final history = historyAsync.valueOrNull ?? [];
    final detailLoading = detailAsync.isLoading && detailAsync.valueOrNull == null;

    // Pre-fetch Strategy
    if (currentSource != null && _showContent) {
      String? prefetchUrl;
      if (isMovieCategory) {
        prefetchUrl = currentSource.url;
      } else {
        final latest = history.where((h) => h.contentId == widget.title).firstOrNull;
        int epNum = latest != null ? int.tryParse(latest.episode ?? '1') ?? 1 : 1;
        final epData = episodesAsync.valueOrNull?.response;
        final epSource = episodesAsync.valueOrNull?.sourceForNumber(epNum) ?? currentSource;
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

    final int displayTotalSeasons = [totalSeasons, widget.totalSeasons ?? 0].reduce((a, b) => a > b ? a : b);

    return MouseRegion(
      onHover: (_) => _handleInteraction(),
      child: Listener(
        onPointerDown: (_) => _handleInteraction(),
        onPointerMove: (_) => _handleInteraction(),
        onPointerHover: (_) => _handleInteraction(),
        child: AdaptiveDetailLayout(
          maxContentWidth: 1000,
          bottomNavigationBar: AurisBottomBar(
            currentIndex: -1, // No hay rama seleccionada en detalles
            onTap: (index) {
              final routes = ['/', '/search', '/explore', '/settings'];
              context.go(routes[index]);
            },
          ),
          topBar: Stack(children: [
            Positioned(top: 12, left: 15, child: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28), onPressed: () => Navigator.of(context).pop())),
            Positioned(top: 12, right: 15, child: IconButton(icon: const Icon(Icons.cast, color: Colors.white, size: 24), onPressed: () {})),
          ]),
          backdrop: DetailBackdrop(
            imageUrl: heroBanner,
            revealed: _revealed,
            showTrailer: _showPlayer,
            ytController: _ytController,
          ),
          logo: HeroTitle(
            title: widget.title,
            logo: detailData?.logo,
            logoReady: detailAsync.hasValue,
            maxWidth: isMobile ? double.infinity : 500,
            maxHeight: isMobile ? 80 : 120,
            style: TextStyle(
              color: Colors.white, 
              fontSize: isMobile ? 14 : 18, 
              fontWeight: FontWeight.bold, 
              height: 1.1, 
              letterSpacing: 4, 
              shadows: const [
                Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 4), 
                Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 10)
              ],
            ),
          ),
          meta: _buildMetaRow(detailData, isMobile: isMobile, sourceRating: currentSource?.score, kind: detailParams.kind),
          mainAction: _buildMainActionButton(
            context, 
            isMobile: isMobile,
            latestHistory: history.where((h) => h.contentId == widget.title).firstOrNull,
            onPlay: () => _handlePlay(context, detailState, history, heroBanner, detailData),
          ),
          secondaryActions: _buildCircularActions(context, isMobile: isMobile, poster: currentSource?.thumbnail, banner: heroBanner),
          synopsis: _buildSynopsis(detailData),
          selectors: (!isMovieCategory && (displayTotalSeasons > 0 || currentSource != null)) ? Row(
            children: [
              if (!isMovieCategory && displayTotalSeasons > 0)
                SeasonSelector(
                  data: SeasonSelectorData(
                    currentSeason: currentSeason,
                    totalSeasons: displayTotalSeasons > 0 ? displayTotalSeasons : 1,
                    onSeasonSelected: (s) => ref.setSeason(detailParams, s),
                    compact: true,
                    totalEpisodes: episodesAsync.valueOrNull?.response?.total ?? _lastEpisodes?.response?.total,
                  ),
                ),
              if (!isMovieCategory && displayTotalSeasons > 0 && currentSource != null) const SizedBox(width: 12),
              if (currentSource != null)
                Expanded(
                  child: SourceChipsBar(
                    sources: activeSources,
                    currentSource: currentSource,
                    onSourceSelected: (index) => ref.setSource(detailParams, activeSources[index]),
                    unavailableSources: null,
                    season: widget.year,
                  ),
                ),
            ],
          ) : null,
          tabs: ContentTabBar(
            labels: tabLabels,
            selectedIndex: selectedTabIndex,
            onTabSelected: (i) => setState(() => _selectedTabIndex = i),
            hPadding: 0,
            isMobile: isMobile,
            isCompact: isCompact,
          ),
          content: SliverMainAxisGroup(slivers: [
            if (episodesTabIndex >= 0 && selectedTabIndex == episodesTabIndex)
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: AdaptiveEpisodesOrCountdown(
                    params: detailParams,
                    episodesBuilder: (episodes) {
                      final epBundle = episodesAsync.valueOrNull ?? _lastEpisodes;
                      if (epBundle != null) {
                        _lastEpisodes = epBundle;
                        final epData = epBundle.response;
                        final total = epData.total;

                        if (isMobile) {
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: total,
                            itemBuilder: (context, index) {
                              final ep = index < epData.episodes.length ? epData.episodes[index] : null;
                              final epNum = (ep?.number ?? index + 1).toString();
                              final epHistory = history.firstWhereOrNull((h) => h.contentId == widget.title && h.season == currentSeason && h.episode == epNum);
                              final epSource = epBundle.sourceForIndex(index) ?? currentSource;
                              return _EpisodeCard(episodeNumber: ep?.number ?? index + 1, title: ep?.title ?? 'Episodio ${index + 1}', description: ep?.description ?? '', imageUrl: ApiEndpoints.proxyImage(ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), fallbackImageUrl: ApiEndpoints.proxyImage(epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), releaseDate: ep?.airDate, duration: ep?.duration ?? (ep?.runtime != null ? '${ep!.runtime} min' : null), quality: ep?.quality ?? epSource?.quality ?? '', episodeUrl: ep?.url, source: epSource?.source ?? currentSource?.source, category: widget.category, certification: certification, isMobile: true, scrollController: _scrollController, progress: epHistory?.progressPercentage, isCompact: isCompact, onTap: () {
                                final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum);
                                final tapSource = epBundle.sourceForIndex(index) ?? currentSource;
                                final epThumb = ep?.thumbnail ?? tapSource?.thumbnail ?? '';
                                final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}&logoUrl=${Uri.encodeComponent(detailData?.logo ?? '')}';
                                context.push('/player/${Uri.encodeComponent(widget.title)}?source=${tapSource?.source ?? currentSource?.source ?? widget.source}&url=${_episodeUrlFor(ep, tapSource?.url ?? currentSource?.url ?? widget.url, tapSource?.source ?? currentSource?.source ?? widget.source, ep?.number ?? index + 1)}&episode=${ep?.number ?? index + 1}&season=$currentSeason&serverName=${simplifySourceName(tapSource?.source ?? currentSource?.source ?? widget.source)}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${epData.total}$posterParam');
                              });
                            },
                          );
                        } else {
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: episodesCrossAxisCount, mainAxisSpacing: 20, crossAxisSpacing: 24, childAspectRatio: episodesAspectRatio),
                            itemCount: total,
                            itemBuilder: (context, index) {
                              final ep = index < epData.episodes.length ? epData.episodes[index] : null;
                              final epNum = (ep?.number ?? index + 1).toString();
                              final epHistory = history.firstWhereOrNull((h) => h.contentId == widget.title && h.season == currentSeason && h.episode == epNum);
                              final epSource = epBundle.sourceForIndex(index) ?? currentSource;
                              final epQuality = ep?.quality ?? epSource?.quality ?? '';
                              return _EpisodeCard(episodeNumber: ep?.number ?? index + 1, title: ep?.title ?? 'Episodio ${index + 1}', description: ep?.description ?? '', imageUrl: ApiEndpoints.proxyImage(ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), fallbackImageUrl: ApiEndpoints.proxyImage(epSource?.thumbnail ?? currentSource?.thumbnail ?? ''), releaseDate: ep?.airDate, duration: ep?.duration ?? (ep?.runtime != null ? '${ep!.runtime} min' : null), quality: epQuality, episodeUrl: ep?.url, source: epSource?.source ?? currentSource?.source, category: widget.category, certification: certification, scrollController: _scrollController, progress: epHistory?.progressPercentage, isCompact: isCompact, onTap: () {
                                final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum);
                                final tapSource = epBundle.sourceForIndex(index) ?? currentSource;
                                final epThumb = ep?.thumbnail ?? tapSource?.thumbnail ?? '';
                                final posterParam = '&title=${Uri.encodeComponent(seasonTitle ?? widget.title)}&posterUrl=${Uri.encodeComponent(epThumb)}&bannerUrl=${Uri.encodeComponent(heroBanner ?? '')}&logoUrl=${Uri.encodeComponent(detailData?.logo ?? '')}';
                                context.push('/player/${Uri.encodeComponent(widget.title)}?source=${tapSource?.source ?? currentSource?.source ?? widget.source}&url=${_episodeUrlFor(ep, tapSource?.url ?? currentSource?.url ?? widget.url, tapSource?.source ?? currentSource?.source ?? widget.source, ep?.number ?? index + 1)}&episode=${ep?.number ?? index + 1}&season=$currentSeason&serverName=${simplifySourceName(tapSource?.source ?? currentSource?.source ?? widget.source)}&startPosition=${hist?.positionInMilliseconds ?? ''}&category=${widget.category}&totalEpisodes=${epData.total}$posterParam');
                              });
                            },
                          );
                        }
                      }
                      return episodesAsync.when(
                        data: (_) => const SizedBox.shrink(),
                        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Color(0xFFA5A5AA)))),
                      );
                    },
                  ),
                ),
              ),
            if (selectedTabIndex == relatedTabIndex && relatedTabIndex != -1) ..._buildRelatedTab(0, unifiedRelations: unifiedRelationsAsync, currentSource: currentSource),
            if (selectedTabIndex == castTabIndex && castTabIndex != -1) ..._buildCastTab(detailData, castAsync.valueOrNull ?? const [], 0),
            if (selectedTabIndex == extrasTabIndexFinal && extrasTabIndexFinal != -1) ..._buildExtrasTab(detailData, 0, openings: currentOpenings, endings: currentEndings),
            if (selectedTabIndex == detailsTabIndex && detailsTabIndex != -1) ..._buildDetailsTab(detailData, 0, inferredSeasonAirDate: episodesAsync.valueOrNull?.response.seasonAirDate, sourceRating: currentSource?.score, showRatingSkeleton: currentSource?.score == null && detailLoading),
            if (selectedTabIndex == galleryTabIndex && galleryTabIndex != -1) ..._buildGalleryTab(0, isMovieCategory ? 'movie' : 'tv', detailData?.title ?? widget.title, detailData is AnimeDetail ? (detailData as AnimeDetail).year : widget.year),
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildCastTab(dynamic detailData, List<CastInfo> serverCast, double hPadding) {
    final List<CastInfo> cast;

    // Senior Strategy: Si hay datos del servidor, reemplazan totalmente a los de detalles.
    // Mientras carga (serverCast será [] si lo manejamos así desde el build), mostramos detalles.
    if (serverCast.isNotEmpty) {
      cast = serverCast;
    } else {
      final Map<String, CastInfo> detailCast = {};

      // 1. Cast de Películas/Series (TMDB)
      if (detailData is MovieDetail) {
        for (var c in detailData.cast) {
          detailCast[c.name] = CastInfo(
            name: c.name,
            character: c.character,
            profile: c.profile,
          );
        }
      }

      // 2. Personajes de Anime (AniList)
      if (detailData is AnimeDetail) {
        for (var c in detailData.characters) {
          if (!detailCast.containsKey(c.name)) {
            detailCast[c.name] = CastInfo(
              name: c.name,
              character: c.role,
              profile: c.image,
            );
          }
        }
      }
      cast = detailCast.values.toList();
    }

    final width = MediaQuery.of(context).size.width;
    
    if (cast.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                'No hay información del elenco disponible',
                style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 18),
              ),
            ),
          ),
        )
      ];
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    final crossAxisCount = isMobile ? 3 : (width < 1000 ? 4 : 6);

    return [
      SliverPadding(
        padding: EdgeInsets.only(left: hPadding, right: hPadding, top: 8, bottom: 24),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 32,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65, // Senior Fix: Ratio reducido para evitar overflow en vista móvil web
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _CastCard(person: cast[index]),
            childCount: cast.length,
          ),
        ),
      ),
    ];
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
            padding: EdgeInsets.zero, // Senior Fix: Padding centralizado en AdaptiveDetailLayout
            sliver: _EpisodesSkeleton(isMobile: isMobile),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSynopsis(dynamic detail, {bool isCompact = false, bool revealed = true}) {
    final text = detail?.overview ?? '';
    final isMobile = ResponsiveUtils.isMobile(context);
    
    if (!revealed && text.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBox(width: double.infinity, height: 16),
          SizedBox(height: 8),
          _SkeletonBox(width: double.infinity, height: 16),
          SizedBox(height: 8),
          _SkeletonBox(width: 200, height: 16),
        ],
      );
    }

    final textStyle = TextStyle(
      color: const Color(0xFFA5A5AA), 
      fontSize: isMobile ? 14.5 : 16.5, 
      height: 1.4, 
      fontWeight: FontWeight.w500, 
      letterSpacing: -0.1
    );

    if (isMobile) {
      return Text(
        text.isNotEmpty ? text : 'Sinopsis no disponible.',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }
    
    return _ExpandableText(
      text: text.isNotEmpty ? text : 'Sinopsis no disponible.', 
      maxLines: 4, 
      style: textStyle,
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
    required AsyncValue<Map<String, List<RelatedInfo>>> unifiedRelations,
    SearchResult? currentSource,
  }) {
    return unifiedRelations.when(
      data: (relations) {
        if (relations.isEmpty) {
          return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay contenido relacionado disponible', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)))))];
        }

        final List<RelatedInfo> franchiseSource = relations['franchise'] ?? [];
        final List<RelatedInfo> similarSource = relations['similar'] ?? [];
        final List<RelatedInfo> recommendedSource = relations['recommended'] ?? [];

        if (franchiseSource.isEmpty && similarSource.isEmpty && recommendedSource.isEmpty) {
          return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay contenido relacionado disponible', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)))))];
        }

        return [
          if (franchiseSource.isNotEmpty)
            _RelatedCarouselRow(
              title: 'Franquicia y Secuelas',
              hPadding: hPadding,
              items: _unifyAndDeduplicate(
                sourceItems: franchiseSource,
                currentSource: currentSource,
              ),
            ),
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
          if (similarSource.isNotEmpty)
            _RelatedCarouselRow(
              title: 'Similares a ${cleanTitleForDisplay(stripSeasonSuffix(widget.title))}',
              hPadding: hPadding,
              items: _unifyAndDeduplicate(
                sourceItems: similarSource,
                currentSource: currentSource,
              ),
            ),
        ];
      },
      loading: () => [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Colors.white24))))],
      error: (err, _) => [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('Error al cargar relacionados', style: TextStyle(color: Colors.redAccent)))))]
    );
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
        onTap: () {
          final sName = r.source ?? currentSource?.source ?? widget.source;
          final result = SearchResult(
            title: r.title,
            url: r.url,
            source: sName,
            quality: 'HD',
            thumbnail: r.cover,
            slug: r.slug,
            metadataTitle: r.title,
            year: r.year,
            sources: [SourceItem(source: sName, url: r.url, quality: 'HD', slug: r.slug)],
          );
          context.push(
            '/content/${Uri.encodeComponent(r.title)}?source=${Uri.encodeComponent(result.source)}&category=${widget.category}&url=${Uri.encodeComponent(r.url)}&metadataTitle=${Uri.encodeComponent(r.title)}',
            extra: result,
          );
        },
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

  List<Widget> _buildExtrasTab(dynamic detail, double hPadding,
      {List<AnimeThemeInfo> openings = const [], List<AnimeThemeInfo> endings = const []}) {
    if (detail == null) return [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Colors.white24))))];
    final isMobile = ResponsiveUtils.isMobile(context);
    // Los OP/ED del anime llegan de /api/themes (detail ya no los incluye).
    final List<AnimeThemeInfo> ops = detail is AnimeDetail
        ? openings
        : (detail is MovieDetail ? (detail as MovieDetail).openings : const []);
    final List<AnimeThemeInfo> eds = detail is AnimeDetail
        ? endings
        : (detail is MovieDetail ? (detail as MovieDetail).endings : const []);
    final String? fallbackImg = detail is AnimeDetail 
        ? (detail.banner ?? detail.backdrop) 
        : (detail is MovieDetail ? ((detail as MovieDetail).backdrop ?? (detail as MovieDetail).poster) : null);

    final String animeTitle = (detail is AnimeDetail ? (detail as AnimeDetail).title : (detail is MovieDetail ? (detail as MovieDetail).title : ''));
    final String? logoUrl = (detail is AnimeDetail ? (detail as AnimeDetail).logo : (detail is MovieDetail ? (detail as MovieDetail).logo : null));

    if (ops.isEmpty && eds.isEmpty) return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay temas musicales disponibles', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)))))];
    return [
      if (ops.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Text('Openings', style: TextStyle(color: Colors.white, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: ops[index], isOP: true, fallbackImage: fallbackImg, animeTitle: animeTitle, logoUrl: logoUrl), childCount: ops.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
      if (eds.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Text('Endings', style: TextStyle(color: Colors.white, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: eds[index], isOP: false, fallbackImage: fallbackImg, animeTitle: animeTitle, logoUrl: logoUrl), childCount: eds.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
    ];
  }

  List<Widget> _buildDetailsTab(dynamic detail, double hPadding, {String? inferredSeasonAirDate, double? sourceRating, bool showRatingSkeleton = false}) {
    if (detail == null) return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    final isMobile = ResponsiveUtils.isMobile(context);     final rating = formatRating((detail.rating as double?) ?? sourceRating);
    final effectiveDate = _pickDisplayDate((detail is AnimeDetail ? detail.firstAirDate : detail.releaseDate), inferredSeasonAirDate);
    final year = effectiveDate?.split('-').first ?? 'N/A';
    String sInfo = _isMovieContent(detail, widget.result?.kind ?? widget.type) ? _formatRuntime(_getRuntime(detail)) : (detail is AnimeDetail ? '${detail.episodes ?? 0} episodios' : (detail is MovieDetail ? '${detail.totalSeasons ?? 1} temporadas' : ''));
    List<String> dir = [], cast = [], std = [];
    if (detail is MovieDetail) { dir = detail.directors; cast = detail.cast.take(5).map((e) => e.name).toList(); std = detail.productionCompanies; }
    else if (detail is AnimeDetail) { std = detail.studios; }
    final cert = (detail is MovieDetail ? detail.certification : (detail is AnimeDetail ? detail.certification : null)) ?? 'NR';
    final platforms = (detail is MovieDetail) ? detail.platforms : (detail is AnimeDetail ? detail.platforms : <PlatformInfo>[]);
    final status = detail is MovieDetail ? detail.status : (detail is AnimeDetail ? detail.status : null);
    final languages = detail is MovieDetail ? detail.languages : <String>[];

    if (isMobile) return [ 
      SliverPadding(padding: EdgeInsets.only(left: hPadding, right: hPadding, top: 0, bottom: 10), sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ 
        Text(detail.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        if (detail is MovieDetail && detail.originalTitle != null && detail.originalTitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            detail.originalTitle!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (detail.genres is List) Wrap(spacing: 8, runSpacing: 8, children: (detail.genres as List).map<Widget>((g) => _buildBadge(context, g.toString().toUpperCase())).toList()), 
        const SizedBox(height: 20), 
        _ExpandableText(
          text: detail.overview ?? '', 
          style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 15, height: 1.5),
          maxLines: 4,
        ),
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
        if (status != null) ...[
          const Text('Estado', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(status, style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 14)),
          const SizedBox(height: 24),
        ],
        if (languages.isNotEmpty) ...[
          const Text('Pa\u00EDs', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(() {
              return languages.map((l) {
                final country = l.toLowerCase();
                String emoji = '';
                if (country.contains('jap')) emoji = '🇯🇵';
                else if (country.contains('cor')) emoji = '🇰🇷';
                else if (country.contains('usa') || country.contains('estat') || country.contains('eeuu')) emoji = '🇺🇸';
                else if (country.contains('esp') || country.contains('spain')) emoji = '🇪🇸';
                else if (country.contains('mex')) emoji = '🇲🇽';
                else if (country.contains('chi')) emoji = '🇨🇳';
                else if (country.contains('fra')) emoji = '🇫🇷';
                else if (country.contains('ing') || country.contains('uk')) emoji = '🇬🇧';
                else if (country.contains('ale') || country.contains('ger')) emoji = '🇩🇪';
                else if (country.contains('ita')) emoji = '🇮🇹';

                return emoji.isNotEmpty ? '$emoji $l' : l;
              }).join('  ');
          }(), style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 14)),
          const SizedBox(height: 24),
        ],
        if (dir.isNotEmpty) ...[
          const Text('Direcci\u00F3n', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(dir.join(', '), style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 14)),
          const SizedBox(height: 24),
        ], 
        if (std.isNotEmpty) ...[
          const Text('Estudio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(std.join(', '), style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 14)),
        ] 
      ]))),
    ];

    return [ 
      SliverPadding(padding: EdgeInsets.only(left: hPadding, right: hPadding, top: 8, bottom: 20), sliver: SliverToBoxAdapter(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 15, child: Column(children: [
          _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detail.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
            if (detail is MovieDetail && detail.originalTitle != null && detail.originalTitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detail.originalTitle!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [ Text(detail is AnimeDetail ? 'Jap\u00F3n' : 'Internacional', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17)), const Text('•', style: TextStyle(color: Colors.white24)), Text(detail is AnimeDetail ? 'Anime' : 'Pel\u00EDcula', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 17)) ]), const SizedBox(height: 10),
            Row(children: [ const Text('IMDb ', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 17, fontWeight: FontWeight.w900)), if (showRatingSkeleton && rating == null) const _RatingSkeleton(width: 36, height: 18) else Text(rating ?? 'N/A', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 17)), const Text('/10', style: TextStyle(color: const Color(0xFFA5A5AA))), const SizedBox(width: 16), Text((detail is MovieDetail && detail.releaseDate != null && detail.releaseDate!.isNotEmpty) ? detail.releaseDate! : year, style: const TextStyle(color: const Color(0xFFA5A5AA))), if (sInfo.isNotEmpty) ...[const SizedBox(width: 16), Text(sInfo, style: const TextStyle(color: const Color(0xFFA5A5AA)))] ]), const SizedBox(height: 16),
            _ExpandableText(text: detail.overview ?? '', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 20), maxLines: 4)
          ])),
          const SizedBox(height: 24), if (dir.isNotEmpty || cast.isNotEmpty || std.isNotEmpty || status != null || languages.isNotEmpty) _DetailInfoCard(child: Column(children: [ 
            if (status != null) _buildPrimeRow('Estado', status),
            if (languages.isNotEmpty) _buildPrimeRow('Pa\u00EDs', () {
              return languages.map((l) {
                final country = l.toLowerCase();
                String emoji = '';
                if (country.contains('jap')) emoji = '🇯🇵';
                else if (country.contains('cor')) emoji = '🇰🇷';
                else if (country.contains('usa') || country.contains('estat') || country.contains('eeuu')) emoji = '🇺🇸';
                else if (country.contains('esp') || country.contains('spain')) emoji = '🇪🇸';
                else if (country.contains('mex')) emoji = '🇲🇽';
                else if (country.contains('chi')) emoji = '🇨🇳';
                else if (country.contains('fra')) emoji = '🇫🇷';
                else if (country.contains('ing') || country.contains('uk')) emoji = '🇬🇧';
                else if (country.contains('ale') || country.contains('ger')) emoji = '🇩🇪';
                else if (country.contains('ita')) emoji = '🇮🇹';

                return emoji.isNotEmpty ? '$emoji $l' : l;
              }).join('  ');
            }()),
            if (dir.isNotEmpty) _buildPrimeRow('Direcci\u00F3n', dir.join(', ')), 
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
    
    final cardWidth = ResponsiveUtils.posterWidth(context);
    final carouselHeight = ResponsiveUtils.rowHeight(context, hasInfo: true) + 4.0; // Senior Fix: +4px de seguridad

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
                fontSize: ResponsiveUtils.rowTitleFontSize(context),
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
                      padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
                      itemCount: widget.items.length,
                      separatorBuilder: (_, __) => SizedBox(width: isMobile ? 8 : 24),
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

class _CastCard extends ConsumerStatefulWidget {
  final CastInfo person;
  const _CastCard({required this.person});

  @override
  ConsumerState<_CastCard> createState() => _CastCardState();
}

class _CastCardState extends ConsumerState<_CastCard> {
  bool _isHovered = false;

  void _showCastCredits() {
    if (widget.person.url == null || widget.person.url!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => _CastCreditsModal(
        person: widget.person,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isClickable = widget.person.url != null && widget.person.url!.isNotEmpty;

    return MouseRegion(
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (isClickable) setState(() => _isHovered = true); },
      onExit: (_) { if (isClickable) setState(() => _isHovered = false); },
      child: GestureDetector(
        onTap: isClickable ? _showCastCredits : null,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isHovered 
                        ? const Color(0xFFEF7A1E).withOpacity(0.8) 
                        : Colors.white.withOpacity(0.1),
                    width: 2.0,
                  ),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.person.profile ?? '',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.35),
                    placeholder: (context, url) => Container(
                      decoration: const BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: const BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white24, size: 32),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.person.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: _isHovered ? const Color(0xFFEF7A1E) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (widget.person.character != null && widget.person.character!.isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(
                widget.person.character!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
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
        padding: EdgeInsets.zero,
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(isMobile ? 24 : widget.hPadding, isMobile ? 0 : 8, isMobile ? 24 : widget.hPadding, 16),
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
                padding: EdgeInsets.zero,
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

