import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:auris_core/auris_core.dart';
import 'package:auris_core/presentation/widgets/adaptive_episodes_or_countdown.dart';
import 'package:auristv_web/core/utils/responsive_utils.dart';
import 'package:auristv_web/core/utils/url_utils.dart';
import 'package:auristv_web/shared/widgets/auris_bottom_bar.dart';
import 'package:auristv_web/shared/widgets/full_screen_viewer.dart';
import 'package:auristv_web/features/player/presentation/player_screen.dart';
import 'package:auristv_web/core/router/app_router.dart';

// --- Galería Local Helpers ---

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



// _SeasonSelector removed - using SeasonSelector from auris_core

class _ServerSelector extends ConsumerStatefulWidget {
  final SearchResult currentSource; final List<SearchResult> sources; final Function(int) onSourceSelected; final bool compact; final Set<String>? unavailableSources; final int? season; final double? width; final double? height; final double? fontSize;
  const _ServerSelector({required this.currentSource, required this.sources, required this.onSourceSelected, this.compact = false, this.unavailableSources, this.season, this.width, this.height, this.fontSize});
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
          ))).asData?.value;
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
          onEnter: (_) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isHovered = true);
              });
            }
          },
          onExit: (_) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isHovered = false);
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), 
            width: widget.width ?? (widget.compact ? 160 : 220), 
            height: widget.height ?? (widget.compact ? 44 : 56), 
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFF454652) : const Color(0xFF32333E), 
              borderRadius: BorderRadius.circular(8), 
              border: Border.all(color: _isHovered ? const Color(0xFFA5A5AA) : Colors.transparent, width: 1.5)
            ), 
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 12 : 20), 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Expanded(
                    child: Text(
                      simplifySourceName(widget.currentSource.source), 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(color: Colors.white, fontSize: widget.fontSize ?? 18, fontWeight: FontWeight.bold)
                    )
                  ), 
                  Icon(Icons.dns_rounded, size: widget.compact ? 18 : 24, color: _isHovered ? Colors.white : const Color(0xFFA5A5AA))
                ]
              )
            )
          )
        )
      )
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

  // Filmografía disponible: fuente (url), TMDB (id) o búsqueda en vivo por
  // nombre (fallback AniList / sin id). El modal resuelve según lo que haya.
  bool get _hasCredits =>
      (widget.person.url != null && widget.person.url!.isNotEmpty) ||
      widget.person.id != null ||
      widget.person.name.isNotEmpty;

  void _showCastCredits() {
    if (!_hasCredits) return;

    showDialog(
      context: context,
      builder: (context) => _CastCreditsModal(
        person: widget.person,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isClickable = _hasCredits;

    return MouseRegion(
      cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (isClickable) setState(() => _isHovered = true); },
      onExit: (_) { if (isClickable) setState(() => _isHovered = false); },
      child: GestureDetector(
        onTap: isClickable ? _showCastCredits : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Senior Fix: Efecto de escala dinámico tipo Avatar
            AnimatedScale(
              scale: _isHovered ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isHovered
                          ? const Color(0xFFEF7A1E).withOpacity(0.8)
                          : Colors.white.withOpacity(0.1),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isHovered
                            ? const Color(0xFFEF7A1E).withOpacity(0.3)
                            : Colors.black.withOpacity(0.4),
                        blurRadius: _isHovered ? 16 : 12,
                        spreadRadius: _isHovered ? 2 : 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.person.profile ?? '',
                      fit: BoxFit.cover,
                      // Senior Fix: Ajuste de alineamiento vertical para centrar mejor los rostros
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
                        child: const Icon(Icons.person, color: Colors.white24, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.person.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: _isHovered ? const Color(0xFFEF7A1E) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
            if (widget.person.character != null && widget.person.character!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                widget.person.character!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
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

class _EpisodeCard extends ConsumerStatefulWidget {
  final int episodeNumber; final String title; final String description; final String imageUrl; final String fallbackImageUrl; final String? releaseDate; final String? duration; final String quality; final String? certification;  final bool isMobile; final double? progress; final VoidCallback onTap;
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
  final ScrollController _synopsisScrollController = ScrollController();

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
    if (q.isEmpty) return null;
    final isDub = q.toLowerCase().contains('latino') ||
        q.toLowerCase().contains('dub') ||
        q.toLowerCase().contains('doblado') ||
        q.toLowerCase().contains('castellano');
    return isDub ? 'DUB' : 'SUB';
  }

  void _showOverlay(BuildContext context) {
    if (widget.isMobile) return;
    _hideTimer?.cancel();
    if (_isOverlayShown || _overlayEntry != null) return;
    
    _isMouseInside = true;
    _showTimer?.cancel();
    
    // Debounce ultra-rápido (30ms) para filtrar ruido pero mantener fluidez total
    _showTimer = Timer(const Duration(milliseconds: 30), () {
      if (mounted && _isMouseInside) {
        _performShow(context);
      }
    });
  }

  void _performShow(BuildContext context) {
    if (!mounted || !_isMouseInside || _overlayEntry != null) return;

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject == null || renderObject is! RenderBox || !renderObject.hasSize) {
      // Reintentar en el siguiente frame si el render object aún no está listo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMouseInside && _overlayEntry == null) {
          _performShow(context);
        }
      });
      return;
    }

    final oldActiveState = _activeState;
    _activeState = this;
    _isOverlayShown = true;
    
    final overlay = Overlay.of(context);
    final RenderBox renderBox = renderObject;
    final Size cardSize = renderBox.size;
    final Offset position = renderBox.localToGlobal(Offset.zero);
    final double screenWidth = MediaQuery.of(context).size.width;

    final double popupWidth = (cardSize.width + 48).clamp(320.0, 380.0);
    const double edgePadding = 24.0;
    
    double cardCenterX = position.dx + cardSize.width / 2;
    double popupHalfWidth = popupWidth / 2;
    
    double targetCenterX = cardCenterX;
    if (targetCenterX - popupHalfWidth < edgePadding) {
      targetCenterX = edgePadding + popupHalfWidth;
    } else if (targetCenterX + popupHalfWidth > screenWidth - edgePadding) {
      targetCenterX = screenWidth - edgePadding - popupHalfWidth;
    }
    
    double offsetX = targetCenterX - cardCenterX; 
    double offsetY = -27; 

    _overlayEntry = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.topCenter,
        offset: Offset(offsetX, offsetY),
        child: UnconstrainedBox(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { _hideTimer?.cancel(); }),
              onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { _hideOverlay(); }),
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent && widget.scrollController != null) {
                    final controller = widget.scrollController!;
                    if (controller.hasClients) {
                      final newOffset = controller.offset + pointerSignal.scrollDelta.dy;
                      controller.jumpTo(newOffset.clamp(0.0, controller.position.maxScrollExtent));
                    }
                  }
                },
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: popupWidth,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 420),
                      decoration: BoxDecoration(
                        color: const Color(0xFF191E25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                                        errorWidget: (_, __, ___) => _ContentScreenState._episodePlaceholder(widget.episodeNumber),
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
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: ResponsiveUtils.sp(context, 15),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!_isSpecial && widget.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      constraints: const BoxConstraints(minHeight: 60, maxHeight: 110),
                                      child: NotificationListener<ScrollNotification>(
                                        onNotification: (notification) => true,
                                        child: Listener(
                                          behavior: HitTestBehavior.opaque,
                                          onPointerSignal: (pointerSignal) {
                                            if (pointerSignal is PointerScrollEvent) {
                                              if (_synopsisScrollController.hasClients) {
                                                final offset = (_synopsisScrollController.offset + pointerSignal.scrollDelta.dy)
                                                    .clamp(0.0, _synopsisScrollController.position.maxScrollExtent);
                                                _synopsisScrollController.jumpTo(offset);
                                              }
                                            }
                                          },
                                          child: RawScrollbar(
                                            controller: _synopsisScrollController,
                                            thumbColor: const Color(0xFFEF7A1E).withOpacity(0.4),
                                            radius: const Radius.circular(20),
                                            thickness: 3,
                                            thumbVisibility: true,
                                            child: SingleChildScrollView(
                                              controller: _synopsisScrollController,
                                              physics: const ClampingScrollPhysics(),
                                              padding: const EdgeInsets.only(right: 14),
                                              child: Text(
                                                widget.description,
                                                style: TextStyle(
                                                  color: const Color(0xFFA5A5AA),
                                                  fontSize: ResponsiveUtils.sp(context, 12),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (widget.certification != null && widget.certification != 'NR') ...[
                                        _ContentScreenState._buildAgeBadge(context, widget.certification!, small: true),
                                        const SizedBox(width: 8),
                                      ],
                                      if (_typeBadge != null) ...[
                                        _ContentScreenState._buildAgeBadge(context, _typeBadge!, small: true),
                                        const SizedBox(width: 8),
                                      ],
                                      _ContentScreenState._buildAgeBadge(context, _languageBadge, small: true),
                                      const Spacer(),
                                      if (!_isSpecial && widget.duration != null)
                                        Text(
                                          widget.duration!,
                                          style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    
    if (oldActiveState != null && oldActiveState != this) {
      oldActiveState._performHide();
    }

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _hideOverlay({bool immediate = false}) {
    _showTimer?.cancel();
    _isMouseInside = false;
    
    if (immediate) {
      _performHide();
    } else {
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 100), () {
        if (mounted && !_isMouseInside) {
          _performHide();
        }
      });
    }
  }

  void _performHide() {
    _isOverlayShown = false;
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    if (_activeState == this) _activeState = null;
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isHovered = false);
      });
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _synopsisScrollController.dispose();
    if (_activeState == this) _activeState = null;
    _overlayEntry?.remove();
    super.dispose();
  }

  @override Widget build(BuildContext context) {
    if (widget.isMobile) {
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
                                errorWidget: (_, __, ___) => _ContentScreenState._episodePlaceholder(widget.episodeNumber),
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
                                '${widget.duration ?? ''}${widget.duration != null && widget.releaseDate != null ? ' ' : ''}${_ContentScreenState._formatDate(widget.releaseDate)}',
                                style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: ResponsiveUtils.sp(context, 12)),
                              ),
                            if (!_isSpecial) SizedBox(height: ResponsiveUtils.sp(context, 6)),
                            Row(
                              children: [
                                if (widget.certification != null && widget.certification != 'NR') ...[
                                  _ContentScreenState._buildAgeBadge(context, widget.certification!, small: true),
                                  SizedBox(width: ResponsiveUtils.sp(context, 8)),
                                ],
                                if (_typeBadge != null) ...[
                                  _ContentScreenState._buildAgeBadge(context, _typeBadge!, small: true),
                                  SizedBox(width: ResponsiveUtils.sp(context, 8)),
                                ],
                                _ContentScreenState._buildAgeBadge(context, _languageBadge, small: true),
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
    final double screenW = MediaQuery.sizeOf(context).width;
    final double titleFontSize = widget.isCompact ? 14.5 : (screenW * 0.009).clamp(16.0, 19.0);
    final double descFontSize = widget.isCompact ? 12.0 : (screenW * 0.008).clamp(13.0, 15.0);
    final double gapImageToText = widget.isCompact ? 8.0 : 12.0;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _showOverlay(context));
          }
        },
        onExit: (_) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _hideOverlay());
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: (_isOverlayShown || _overlayEntry != null) ? 0.1 : 1.0,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
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
                            errorWidget: (_, __, ___) => _ContentScreenState._episodePlaceholder(widget.episodeNumber),
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
                  if (!_isSpecial && (widget.duration != null || widget.releaseDate != null))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${widget.duration ?? ''}${widget.duration != null && widget.releaseDate != null ? ' ' : ''}${_ContentScreenState._formatDate(widget.releaseDate)}',
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
                        _ContentScreenState._buildAgeBadge(context, widget.certification!, small: true),
                        const SizedBox(width: 8),
                      ],
                      if (_typeBadge != null) ...[
                        _ContentScreenState._buildAgeBadge(context, _typeBadge!, small: true),
                        const SizedBox(width: 8),
                      ],
                      _ContentScreenState._buildAgeBadge(context, _languageBadge, small: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final isMobile = context.isMobile; 
    String? img = ApiEndpoints.proxyImage(
      (widget.theme.imageUrl?.isNotEmpty == true) ? widget.theme.imageUrl! : widget.fallbackImage,
      width: 1280,
    );
    final bool isSelected = !isMobile && _isHovered;

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted && _isHovered) setState(() => _isHovered = false);
      },
      onHover: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
      child: GestureDetector(
        onTap: () {
          String url = widget.theme.videoUrl; final typeLabel = widget.isOP ? 'OP' : 'ED';
          if (!url.startsWith('http')) { 
            url = 'https://www.youtube.com/watch?v=$url'; 
            final player = PlayerScreen(
              contentId: widget.theme.title,
              sourceUrl: url,
              source: 'YouTube',
              episode: typeLabel,
              serverName: 'YouTube',
              totalEpisodes: 1,
              logoUrl: widget.logoUrl,
            );
            UrlUtils.openPlayer(context, player);
          }
          else { 
            String url720 = widget.theme.video720 ?? '';
            String url1080 = widget.theme.video1080 ?? '';
            if (kIsWeb && url.contains('animethemes.moe')) {
              url = '${ApiEndpoints.baseUrl}/api/proxy/video?url=${Uri.encodeComponent(url)}';
              if (url720.isNotEmpty) url720 = '${ApiEndpoints.baseUrl}/api/proxy/video?url=${Uri.encodeComponent(url720)}';
              if (url1080.isNotEmpty) url1080 = '${ApiEndpoints.baseUrl}/api/proxy/video?url=${Uri.encodeComponent(url1080)}';
            }

            // Senior Web Fix: Para evitar colisiones y doble inicialización de audio en Web con media_kit,
            // abrimos la pantalla directamente pasándole los metadatos correctos sin pasar por la precarga redundante.
            showGeneralDialog(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.black,
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
                contentId: widget.theme.title,
                sourceUrl: url,
                source: 'Themes',
                episode: typeLabel,
                serverName: 'Themes',
                totalEpisodes: 1,
                logoUrl: widget.logoUrl,
                video720: url720.isNotEmpty ? url720 : null,
                video1080: url1080.isNotEmpty ? url1080 : null,
                title: widget.animeTitle, // Pasamos el título del anime a través del nuevo parámetro
                episodeTitle: widget.theme.title, // El título del OP/ED es el IRIS OUT, etc.
              ),
            );
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
                  child: CachedNetworkImage(imageUrl: img!, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: Colors.white10)),
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
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted && _isHovered) setState(() => _isHovered = false);
      },
      onHover: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
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
    final isMobile = context.isMobile;

    final creditsAsync = ref.watch(castCreditsProvider(CastCreditsParams(
      url: person.url ?? '',
      name: person.name,
      profile: person.rawProfile, // Senior: Enviar URL original al backend para evitar doble proxy
      personId: person.id,
    )));

    return Dialog(
      backgroundColor: const Color(0xFF0B0B0D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : width * 0.15,
        vertical: isMobile ? 24 : 60,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header del Modal
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: person.profile != null && person.profile!.isNotEmpty
                        ? CachedNetworkImageProvider(person.profile!)
                        : null,
                    backgroundColor: Colors.white10,
                    child: person.profile == null || person.profile!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white24)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Filmografía',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFEF7A1E),
                            fontSize: 14,
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
            Flexible(
              child: creditsAsync.when(
                data: (response) {
                  if (response == null || (response.results.isEmpty && response.biography == null)) {
                    return Center(
                      child: Text(
                        'No se encontró información disponible',
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                      ),
                    );
                  }

                  final results = response.results;
                  final double posterWidth = ResponsiveUtils.posterWidth(context);
                  final double availableWidth = isMobile ? (width - 32) : (width < 1200 ? width * 0.8 : 1200 - 48);
                  final int crossAxisCount = (availableWidth / (posterWidth + 20)).round().clamp(isMobile ? 2 : 3, 8);

                  return CustomScrollView(
                    slivers: [
                      // Bio y Metadata
                      if (response.biography != null || response.birthday != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (response.birthday != null || response.placeOfBirth != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Wrap(
                                      spacing: 24,
                                      runSpacing: 12,
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    response.biography!,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                ],
                                Text(
                                  'Conocido por',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                      // Lista de Créditos
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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

                                    final shareableUri = UrlUtils.buildShareableUri(
                                      title: item.title,
                                      source: item.source,
                                      url: item.url,
                                      category: cat,
                                      year: item.year,
                                    );
                                    context.go(shareableUri, extra: item);
                                  } else {
                                    // Anime: los items NO traen url de scraper -> click en filmografía = search normal por title
                                    context.go('/busqueda?q=${Uri.encodeComponent(item.title)}');
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
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
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
  final String? from;

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
    this.from,
  });

  @override
  ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> with WidgetsBindingObserver {
  int? _extractSeason(String? s) => extractSeason(s);
  String _stripSeasonSuffix(String? title) => stripSeasonSuffix(title ?? '');
  String _seasonTitleFor(String baseTitle, int season) => seasonTitleFor(baseTitle, season);
  bool _isSeasonUnified(String source) => isSeasonUnified(source);
  SearchResult? _withSeasonUnified(SearchResult? source, int? season) => withSeasonUnified(source, season);
  List<SearchResult> _familySourcesFor(SearchResult currentSource, List<SearchResult> sources) => familySourcesFor(currentSource, sources);
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

  static Widget _buildBadge(BuildContext context, String? text, {bool small = false}) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.sp(context, small ? 6 : 10),
        vertical: ResponsiveUtils.sp(context, small ? 1.5 : 3)
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1.0
        ),
        borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, small ? 3 : 4)),
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

  static Widget _buildPlatformLogo(BuildContext context, PlatformInfo platform, {double size = 48}) {
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
                platform.providerName.isNotEmpty ? platform.providerName.substring(0, 1).toUpperCase() : '?',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildAgeBadge(BuildContext context, String? text, {bool small = false}) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.sp(context, small ? 5 : 8),
        vertical: ResponsiveUtils.sp(context, small ? 1.5 : 3)
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white10,
          width: 1.0
        ),
        borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, small ? 3 : 4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: ResponsiveUtils.sp(context, small ? 10 : 13),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  static Widget _episodePlaceholder(int episodeNumber) => Container(
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

  int _selectedTabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _synopsisScrollController = ScrollController();
  bool _showContent = false;
  Timer? _loadTimer;

  // Trailer & Header State
  YoutubePlayerController? _ytController;
  StreamSubscription? _ytSubscription;
  StreamSubscription? _playerSubscription;
  Timer? _fadeTimer;
  String? _lastTrailerKey;
  bool _isMuted = true;
  bool _showPlayer = false;
  bool _isPlayedOnce = false;
  Timer? _delayTimer;
  bool _showTitle = true;
  Timer? _titleHideTimer;
  bool _revealed = false;
  Timer? _revealTimeout;
  bool _isSynopsisExpanded = false;
  bool _isTrailerLoading = false;
  bool _useHtmlIframeFallback = false;
  Timer? _timeoutFallbackTimer;

  Widget _buildEpisodesSkeleton(BuildContext context, bool isMobile) {
    try {
      final width = MediaQuery.of(context).size.width;
      final count = isMobile ? 1 : (width < 1000 ? 2 : (width < 1400 ? 3 : (width < 2100 ? 4 : (width < 2800 ? 5 : 6))));
      final aspectRatio = isMobile ? 1.15 : (width < 1000 ? 1.25 : 1.1);

      if (isMobile) {
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(width: 140, height: 80, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 16, width: double.infinity, color: Colors.white10), const SizedBox(height: 8), Container(height: 12, width: 100, color: Colors.white10)]))
                ]
              )
            ),
            childCount: 5
          )
        );
      }
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, mainAxisSpacing: 20, crossAxisSpacing: 20, childAspectRatio: aspectRatio),
        delegate: SliverChildBuilderDelegate(
          (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 12),
              Container(height: 14, width: 80, color: Colors.white10),
              const SizedBox(height: 6),
              Container(height: 10, width: double.infinity, color: Colors.white10)
            ]
          ),
          childCount: 8
        )
      );
    } catch (e) {
      return SliverToBoxAdapter(child: Center(child: Text('Skeleton Error: $e', style: const TextStyle(color: Colors.red))));
    }
  }

  void _openPlayer(PlayerScreen player) {
    UrlUtils.openPlayer(context, player);
  }

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimer = Timer(ApiEndpoints.pageLoadTimeout, () {
      if (mounted) setState(() => _showContent = true);
    });
    _revealTimeout = Timer(ApiEndpoints.detailRevealTimeout, () {
      if (mounted && !_revealed) setState(() => _revealed = true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_ytController != null && _showPlayer) {
        _ytController!.playVideo();
        _syncMute(_isMuted);
      }
    }
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadTimer?.cancel();
    _revealTimeout?.cancel();
    _timeoutFallbackTimer?.cancel();
    _disposeController();
    _scrollController.dispose();
    _synopsisScrollController.dispose();
    super.dispose();
  }

  void _startTitleHideTimer() {
    if (!mounted) return;
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

  void _checkAndInitTrailer(AsyncValue<ContentDetailResponse?> detailAsync, UserSettings settings) {
    final isMobile = context.isMobile;
    final d = detailAsync.asData?.value?.main;
    final k = (d is AnimeDetail) ? d.trailerKey : (d is MovieDetail ? d.trailerKey : null);

    if (k != null && k.isNotEmpty) {
      if (k != _lastTrailerKey) {
        if (_lastTrailerKey != null) _disposeController();
        _lastTrailerKey = k;
        if (!isMobile && settings.autoPlayTrailers) {
          _initTrailer(k);
        }
      } else if (!settings.autoPlayTrailers && _showPlayer) {
        // Si el trailer ya está cargado pero el usuario desactiva la opción, lo quitamos.
        _disposeController();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _showPlayer = false; _lastTrailerKey = null; });
        });
      }
    } else if (_lastTrailerKey != null) {
      _lastTrailerKey = null; _disposeController();
    }

    final hasRealData = detailAsync.asData?.value != null;
    if (!_revealed && (hasRealData || detailAsync.hasValue)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_revealed) setState(() => _revealed = true);
      });
    }
  }

  void _disableYoutubeCaptions(YoutubePlayerController ctrl) {
    try {
      ctrl.webViewController.runJavaScript('''
        try {
          if (window.player) {
            if (typeof window.player.unloadModule === 'function') {
              window.player.unloadModule('captions');
              window.player.unloadModule('cc');
            }
            if (typeof window.player.setOption === 'function') {
              window.player.setOption('captions', 'track', {});
              window.player.setOption('cc', 'track', {});
              window.player.setOption('captions', 'reload', false);
            }
          }
        } catch (e) {}
      ''');
    } catch (_) {}
  }

  void _initTrailer(String key, {bool immediate = false}) {
    _delayTimer?.cancel();
    void start() {
      final settings = ref.read(settingsProvider);
      if (!mounted || key != _lastTrailerKey || (!immediate && !settings.autoPlayTrailers)) return;
      if (_ytController != null) {
        _fadeTimer?.cancel(); _ytController!.pauseVideo(); _ytController!.seekTo(seconds: 0);
        if (!_isMuted) { _ytController!.unMute(); _ytController!.setVolume(100); } else { _ytController!.mute(); }
        _ytController!.playVideo();
        _disableYoutubeCaptions(_ytController!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _showPlayer = false; _isPlayedOnce = false; _showTitle = true; });
        });
        _titleHideTimer?.cancel();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_showPlayer) {
            setState(() { _showPlayer = true; _showTitle = true; });
            _startTitleHideTimer();
          }
        });
        return;
      }
      _timeoutFallbackTimer?.cancel();
      _useHtmlIframeFallback = false;
      
      // Temporizador de control Senior (4.5 segundos) para Error 153
      if (kIsWeb) {
        _timeoutFallbackTimer = Timer(const Duration(milliseconds: 4500), () {
          if (mounted && !_showPlayer && _ytController != null) {
            debugPrint('[Trailer Fallback] Detectado posible Error 153 / congelamiento. Activando Iframe HTML Puro.');
            setState(() {
              _useHtmlIframeFallback = true;
              _showPlayer = true; // Forzamos visibilidad para el Iframe plano
              _showTitle = true;
            });
            _startTitleHideTimer();
          }
        });
      }

      final ctrl = YoutubePlayerController.fromVideoId(
        videoId: key,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          mute: true,
          loop: false,
          showVideoAnnotations: false,
          playsInline: true,
          strictRelatedVideos: true,
          enableKeyboard: false,
          captionLanguage: '',
          enableCaption: false,
        ),
      );
      _playerSubscription = ctrl.listen((state) {
        if (!mounted) return;
        if (state.playerState == PlayerState.playing) {
          _timeoutFallbackTimer?.cancel(); // Cancelamos fallback si reproduce bien
          _syncMute(_isMuted);
          _disableYoutubeCaptions(ctrl);
        }
        if (state.playerState == PlayerState.cued) {
          ctrl.playVideo();
          _syncMute(_isMuted);
          _disableYoutubeCaptions(ctrl);
        }
        if (state.playerState == PlayerState.playing && !_showPlayer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) { setState(() { _showPlayer = true; _showTitle = true; }); _startTitleHideTimer(); }
          });
        }
        if (state.playerState == PlayerState.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) { setState(() { _showPlayer = false; _isPlayedOnce = true; _showTitle = true; }); _titleHideTimer?.cancel(); }
          });
        }
      });
      _ytSubscription = ctrl.videoStateStream.listen((state) {
        if (!mounted) return;
        final d = ctrl.value.metaData.duration.inSeconds; final p = state.position.inSeconds;
        if (p > 0) {
          _timeoutFallbackTimer?.cancel(); // Doble verificación: cancelamos fallback si se mueve la pista
        }
        if (p > 0 && !_showPlayer && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) { setState(() { _showPlayer = true; _showTitle = true; }); _startTitleHideTimer(); }
          });
        }

        if (p > 5 && d > 30 && (d - p) < 12) {
          if (_showPlayer && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _showPlayer = false;
                  _isPlayedOnce = true;
                  _showTitle = true;
                });
                _titleHideTimer?.cancel();
                _fadeOutAudio(ctrl);
              }
            });
          }
        }
      });
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() { _ytController = ctrl; _showPlayer = false; _isPlayedOnce = false; _showTitle = true; });
        });
        _titleHideTimer?.cancel();

        _delayTimer = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            ctrl.playVideo();
            if (!_showPlayer) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) { setState(() { _showPlayer = true; _showTitle = true; }); _startTitleHideTimer(); }
              });
            }
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

  void _syncMute(bool isMuted) {
    if (_ytController != null) {
      if (isMuted) _ytController!.mute();
      else { _ytController!.unMute(); _ytController!.setVolume(100); }
    }
  }

  void _disposeController() {
    _delayTimer?.cancel();
    _fadeTimer?.cancel();
    _titleHideTimer?.cancel();
    _timeoutFallbackTimer?.cancel();
    _ytSubscription?.cancel();
    _playerSubscription?.cancel();
    _ytSubscription = null;
    _playerSubscription = null;
    if (_ytController != null) {
      _ytController!.pauseVideo();
      _ytController!.close();
      _ytController = null;
    }
    if (mounted) {
      setState(() {
        _useHtmlIframeFallback = false;
      });
    }
  }

  Widget _buildMetaRow(dynamic detail, {bool isMobile = false, bool isCompact = false, String? kind}) {
    final r = (detail?.rating as double?) ?? 0.0;
    final rawDate = (detail is AnimeDetail) ? detail.firstAirDate : (detail is MovieDetail ? detail.releaseDate : null);
    final d = rawDate ?? '';
    final g = detail?.genres as List<dynamic>?;
    final cert = (detail is MovieDetail ? detail.certification : (detail is AnimeDetail ? detail.certification : null)) ?? 'NR';
    final runtime = _getRuntime(detail);
    final isMovie = _isMovieContent(detail, kind);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row of badges (Certification FIRST, then genres) - FORZADO A 1 SOLA LÍNEA
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  if (cert != 'NR')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ContentScreenState._buildAgeBadge(context, cert, small: false),
                    ),
                  if (g != null && g.isNotEmpty)
                    ...g.map<Widget>((genre) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildBadge(context, genre.toString().toUpperCase())
                    )).toList(),
                ],
              ),
            ),
          ),
          Row(
            children: [
              if (r > 0) ...[
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(formatRating(r) ?? 'N/A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(width: 12)
              ],
              if (d.length >= 4) ...[
                Text(d.substring(0, 4), style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 15)),
                const SizedBox(width: 12),
              ],
              if (isMovie) ...[
                if (runtime != null) Text(_formatRuntime(runtime), style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 15)),
              ] else if ((widget.totalSeasons ?? 0) > 1) ...[
                Text('${widget.totalSeasons} temporadas', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 15)),
              ],
            ]
          ),
        ]
      );
    }

    final double screenW = MediaQuery.sizeOf(context).width;
    final double maxPossibleW = screenW - 100.0;
    final double metaWidth = (screenW * 0.52).clamp(300.0, maxPossibleW > 300.0 ? maxPossibleW : 300.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, parentConstraints) {
            final String leftText = [
              if (d.length >= 4) d.substring(0, 4),
              if (isMovie && runtime != null) _formatRuntime(runtime),
              if (!isMovie && (widget.totalSeasons ?? 0) > 1) '${widget.totalSeasons} temporadas',
            ].join(' · ');

            final leftPainter = TextPainter(
              text: TextSpan(
                text: leftText,
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 15 : 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();

            final double leftW = leftPainter.width;
            final double rightW = r > 0 ? 65.0 : 0.0;
            const double separatorsAndPadding = 48.0;

            final double genresMaxW = (metaWidth - leftW - rightW - separatorsAndPadding).clamp(60.0, 600.0);

            final List<String> visibleGenres = [];
            double totalW = 0.0;
            const double badgePadding = 24.0;
            const double badgeSpacing = 8.0;

            if (g != null) {
              for (final genre in g) {
                final textSpan = TextSpan(
                  text: genre.toString().toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                );
                final textPainter = TextPainter(
                  text: textSpan,
                  textDirection: TextDirection.ltr,
                )..layout();
                
                final double badgeW = textPainter.width + badgePadding;
                final double requiredW = visibleGenres.isEmpty ? badgeW : (badgeW + badgeSpacing);

                if (totalW + requiredW <= genresMaxW) {
                  totalW += requiredW;
                  visibleGenres.add(genre.toString().toUpperCase());
                } else {
                  break;
                }
              }
            }

            return SizedBox(
              width: metaWidth,
              child: DefaultTextStyle(
                style: GoogleFonts.poppins(
                  color: const Color(0xFFD1D1D6),
                  fontSize: isCompact ? 15 : 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (d.length >= 4) ...[
                      Text(d.substring(0, 4)),
                    ],
                    if (isMovie) ...[
                      if (runtime != null) ...[
                        if (d.length >= 4) _buildDotSeparator(),
                        Text(_formatRuntime(runtime)),
                      ],
                    ] else if ((widget.totalSeasons ?? 0) > 1) ...[
                      if (d.length >= 4) _buildDotSeparator(),
                      Text('${widget.totalSeasons} temporadas'),
                    ],
                    if (visibleGenres.isNotEmpty) ...[
                      if (d.length >= 4 || isMovie || (widget.totalSeasons ?? 0) > 1)
                        _buildDotSeparator(),
                      SizedBox(
                        height: isCompact ? 28 : 34,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: visibleGenres.map((genre) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildBadge(context, genre, small: isCompact),
                          )).toList(),
                        ),
                      ),
                    ],
                    if (r > 0) ...[
                      _buildDotSeparator(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFACC15), size: 22),
                          const SizedBox(width: 4),
                          Text(
                            formatRating(r) ?? 'N/A',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8), // Senior Fix: Espaciado interno más compacto en metadata
        SizedBox(
          width: metaWidth,
          child: Row(
            children: [
              if (cert != 'NR') ...[
                _buildAgeBadge(context, cert, small: isCompact),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  _getWarningText(cert),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFA5A5AA),
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDotSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text('•', style: TextStyle(color: Colors.white.withOpacity(0.3))),
    );
  }

  Widget _buildSynopsis(dynamic detail, {bool isCompact = false, bool isScrollable = false}) {
    final text = detail?.overview ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    final isMobile = context.isMobile;
    final isTablet = context.isTablet;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenW = MediaQuery.sizeOf(context).width;
        final double fontSize = isMobile 
            ? 14.0 
            : (isTablet ? 15.0 : (screenW * 0.0095).clamp(13.5, 16.0));
        final double lineHeight = isMobile ? 1.35 : 1.45;

        final style = GoogleFonts.poppins(
          color: isMobile ? const Color(0xFFA5A5AA) : Colors.white.withOpacity(0.9),
          fontSize: fontSize,
          height: lineHeight,
          fontWeight: FontWeight.w500
        );

        if (isScrollable) {
          final double linePixelHeight = fontSize * lineHeight;
          final double fixedH = (linePixelHeight * 4.0).ceilToDouble(); // 4 líneas base exactas
          
          return SizedBox(
            height: fixedH,
            child: RawScrollbar(
              controller: _synopsisScrollController,
              thumbColor: const Color(0xFFEF7A1E).withOpacity(0.4),
              radius: const Radius.circular(20),
              thickness: 3,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _synopsisScrollController,
                physics: const ClampingScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.only(right: 14, top: 0, bottom: 2),
                child: Text(
                  text,
                  style: style,
                ),
              ),
            ),
          );
        }

        final span = TextSpan(text: text, style: style);
        final tp = TextPainter(
          text: span,
          maxLines: isMobile ? 3 : 4,
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout(maxWidth: constraints.maxWidth);
        final isOverflowing = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              maxLines: isMobile ? 3 : (_isSynopsisExpanded ? null : 4),
              overflow: isMobile ? TextOverflow.ellipsis : (_isSynopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
              style: style,
            ),
            if (!isMobile && isOverflowing && !_isSynopsisExpanded)
              GestureDetector(
                onTap: () => setState(() => _isSynopsisExpanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ver más...',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEF7A1E),
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 14 : 16,
                    ),
                  ),
                ),
              ),
            if (!isMobile && _isSynopsisExpanded)
              GestureDetector(
                onTap: () => setState(() => _isSynopsisExpanded = false),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ver menos',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEF7A1E).withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 14 : 16,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMainActionButton(BuildContext context, {bool isMobile = false, bool isCompact = false}) {
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
    final detailState = ref.read(unifiedContentProvider(detailParams));
    final history = ref.read(playbackHistoryStateProvider).asData?.value?.where((h) => h.contentId == widget.title).firstOrNull;
    final hasHistory = history != null;
    final String label = hasHistory ? 'Continuar viendo' : 'Reproducir ahora';
    final double? progress = hasHistory ? history.progress : null;

    final onPlay = () {
      final currentSource = detailState.selectedSource;
      final effectiveSrc = currentSource?.source ?? widget.source;
      final playEpisodesUrl = currentSource?.url ?? widget.url;
      final heroBanner = ApiEndpoints.proxyImage(
        DetailBackdropResolver.resolve(
          detail: detailState.detail.asData?.value?.main,
          bannerParam: widget.banner,
          sourceBanner: currentSource?.banner,
          season: detailState.currentSeason,
        ),
        highQuality: true,
      );

      if (detailState.isMovieish) {
        final ep = EpisodeInfo(number: 1, id: 0, url: playEpisodesUrl, title: 'Película', thumbnail: ApiEndpoints.proxyImage(currentSource?.thumbnail));
        final player = PlayerScreen(
          contentId: widget.title,
          sourceUrl: _episodeUrlFor(ep, playEpisodesUrl, effectiveSrc, 1),
          source: effectiveSrc,
          episode: '1',
          serverName: simplifySourceName(effectiveSrc),
          category: widget.category,
          totalEpisodes: 1,
          posterUrl: currentSource?.thumbnail,
          bannerUrl: heroBanner,
          logoUrl: detailState.detail.asData?.value?.main.logo,
        );
        _openPlayer(player);
      } else {
        int epNum = history != null ? int.tryParse(history.episode ?? '1') ?? 1 : 1;
        final epData = detailState.episodes.asData?.value?.response;
        final epSource = detailState.episodes.asData?.value?.sourceForNumber(epNum) ?? currentSource;
        final ep = epData?.episodes.firstWhereOrNull((e) => e.number == epNum);

        final episodeThumb = ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? '';
        final player = PlayerScreen(
          contentId: widget.title,
          sourceUrl: _episodeUrlFor(ep, epSource?.url ?? widget.url, epSource?.source ?? effectiveSrc, epNum),
          source: epSource?.source ?? effectiveSrc,
          episode: epNum.toString(),
          season: history?.season ?? detailState.currentSeason,
          serverName: simplifySourceName(epSource?.source ?? effectiveSrc),
          startPosition: history?.positionInMilliseconds,
          category: widget.category,
          totalEpisodes: epData?.total ?? 0,
          title: detailState.seasonTitle ?? widget.title,
          logoUrl: detailState.detail.asData?.value?.main.logo,
          posterUrl: currentSource?.thumbnail ?? widget.result?.thumbnail,
          bannerUrl: episodeThumb,
        );
        _openPlayer(player);
      }
    };

    if (isMobile) {
      final bool hasProgress = progress != null && progress > 0.02;
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onPlay,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.symmetric(horizontal: hasProgress ? 16 : 0),
          ),
          child: Row(
            mainAxisAlignment: hasProgress ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 36),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
              if (hasProgress) ...[
                const Spacer(),
                _buildButtonProgressBar(progress, isMobile: true),
              ],
            ],
          ),
        ),
      );
    }

    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    final bool isCompactScreen = isCompact || width < 1200 || height < 850;
    final double btnHeight = isMobile ? 54.0 : (isCompactScreen ? 42.0 : (width * 0.032).clamp(46.0, 56.0));
    final double fontSize = isMobile ? 18.0 : (isCompactScreen ? 13.5 : (width * 0.0098).clamp(14.0, 16.5));
    final double iconSize = isMobile ? 36.0 : (isCompactScreen ? 28.0 : (width * 0.021).clamp(32.0, 38.0));

    return SizedBox(
      height: btnHeight,
      child: ElevatedButton(
        onPressed: onPlay,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.2),
          padding: EdgeInsets.symmetric(horizontal: (width * 0.008).clamp(12.0, 20.0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.black, size: iconSize),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
            if (progress != null && progress > 0.02) ...[
              const SizedBox(width: 10),
              _buildButtonProgressBar(progress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtonProgressBar(double progress, {bool isMobile = false}) {
    return Container(
      width: isMobile ? 50 : 80,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: progress,
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

  Widget _buildCircularActions(BuildContext context, {bool isMobile = false, bool isCompact = false}) {
    final favorites = ref.watch(favoritesProvider);
    final String currentId = widget.url.isNotEmpty ? widget.url : widget.title;
    final bool isFav = favorites.any((f) => f.id == currentId);
    final user = ref.watch(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';

    final double width = MediaQuery.sizeOf(context).width;
    final double height = MediaQuery.sizeOf(context).height;
    final bool isCompactScreen = isCompact || width < 1200 || height < 850;
    final double? size = isMobile ? null : (isCompactScreen ? 38.0 : (width * 0.027).clamp(42.0, 52.0));
    final double? iconSize = isMobile ? null : (isCompactScreen ? 20.0 : (width * 0.0135).clamp(22.0, 26.0));
    final double spacing = isMobile ? 8.0 : (isCompactScreen ? 8.0 : (width * 0.007).clamp(8.0, 14.0));

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: isMobile ? 0 : 4),
      child: isMobile
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none, // Senior Fix: Permitir que los botones respiren fuera del contenedor
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildActionRow(context, isFav, currentId, profileId, isMobile, size, iconSize, spacing),
          )
        : _buildActionRow(context, isFav, currentId, profileId, isMobile, size, iconSize, spacing),
    );
  }

  Widget _buildActionRow(BuildContext context, bool isFav, String currentId, String profileId, bool isMobile, double? size, double? iconSize, double spacing) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (_lastTrailerKey != null) ...[
          _DetailIconButton(
            icon: (isMobile || !_showPlayer) ? Icons.movie_outlined : Icons.videocam_off_outlined,
            label: (isMobile || !_showPlayer) ? 'Ver tráiler' : 'Quitar tráiler',
            isLoading: _isTrailerLoading,
            onPressed: () async {
              if (_isTrailerLoading) return;
              if (isMobile) {
                setState(() => _isTrailerLoading = true);
                try {
                  final directUrl = await YoutubeResolver.getDirectStreamUrl(_lastTrailerKey!);
                  if (directUrl != null && context.mounted) {
                    final player = PlayerScreen(
                      contentId: widget.title,
                      sourceUrl: directUrl,
                      source: 'YouTube',
                      episode: 'Trailer',
                      serverName: 'YouTube',
                      totalEpisodes: 1,
                      posterUrl: widget.result?.thumbnail,
                      bannerUrl: widget.banner,
                    );
                    _openPlayer(player);
                  }
                } finally {
                  if (mounted) setState(() => _isTrailerLoading = false);
                }
              } else {
                if (_showPlayer) {
                  _disposeController();
                  setState(() { _showPlayer = false; _isPlayedOnce = true; _showTitle = true; });
                  _titleHideTimer?.cancel();
                } else {
                  _isMuted = false;
                  _initTrailer(_lastTrailerKey!, immediate: true);
                }
              }
            },
            isMobile: isMobile, size: size, iconSize: iconSize,
          ),
          SizedBox(width: spacing),
          if (!isMobile && _showPlayer) ...[
            _DetailIconButton(
              icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              label: _isMuted ? 'Activar audio' : 'Silenciar',
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                  _syncMute(_isMuted);
                });
              },
              isMobile: isMobile,
              size: size,
              iconSize: iconSize,
            ),
            SizedBox(width: spacing),
          ],
        ],

        _DetailIconButton(
          icon: isFav ? Icons.check : Icons.add,
          label: isMobile ? 'Mi lista' : (isFav ? 'En mi lista' : 'Mi lista'),
          onPressed: () {
            final item = FavoriteItem(
              id: currentId,
              title: widget.title,
              posterUrl: widget.result?.thumbnail ?? '',
              bannerUrl: widget.banner ?? '',
              category: widget.category,
              source: widget.source,
              url: widget.url,
              addedAt: DateTime.now(),
              profileId: profileId,
            );
            ref.read(favoritesProvider.notifier).toggleFavorite(item);
          },
          isMobile: isMobile, size: size, iconSize: iconSize,
        ),
        SizedBox(width: spacing),

        _DetailIconButton(
          icon: Icons.thumb_up_off_alt,
          label: isMobile ? 'Me gusta' : 'Me gusta',
          onPressed: () {},
          isMobile: isMobile, size: size, iconSize: iconSize,
        ),
        SizedBox(width: spacing),

        _DetailIconButton(
          icon: Icons.thumb_down_off_alt,
          label: isMobile ? 'Dislike' : 'No es para mí',
          onPressed: () {},
          isMobile: isMobile, size: size, iconSize: iconSize,
        ),

        if (isMobile) ...[
          SizedBox(width: spacing),
          _DetailIconButton(
            icon: Icons.share_outlined,
            label: 'Compartir',
            onPressed: () {},
            isMobile: true,
          ),
        ],
      ],
    );
  }

  Widget _buildUpperButtons(BuildContext context, {double? desktopTop}) {
    final isMobile = context.isMobile;
    // Senior Fix: En nativo los botones deben estar más arriba (cerca del safe area) para no quedar muy bajos.
    // En web mantenemos 35px para evitar que el botón toque el borde superior del navegador.
    final double mobileTop = ResponsiveUtils.isNative ? 10 : 35;

    return Stack(
      children: [
        Positioned(
          top: isMobile ? mobileTop : (desktopTop ?? 40),
          left: isMobile ? 15 : 60,
          child: PointerInterceptor(
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28, shadows: [Shadow(color: Colors.black45, blurRadius: 8)]),
              onPressed: () {
                if (mounted) {
                  if (context.canPop()) {
                    context.pop();
                  } else if (widget.from != null && widget.from!.isNotEmpty) {
                    context.go(widget.from!);
                  } else {
                    context.go('/inicio');
                  }
                }
              }
            ),
          ),
        ),
        if (isMobile)
          Positioned(
            top: mobileTop,
            right: 15,
            child: PointerInterceptor(
              child: IconButton(
                icon: const Icon(Icons.cast, color: Colors.white, size: 24, shadows: [Shadow(color: Colors.black45, blurRadius: 8)]),
                onPressed: () {}
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildContentSlivers({
    required BuildContext context,
    required bool isMobile,
    required int selectedTabIndex,
    required int episodesTabIndex,
    required int relatedTabIndex,
    required int castTabIndex,
    required int extrasTabIndex,
    required int detailsTabIndex,
    required int galleryTabIndex,
    required bool hasEpisodesTab,
    required dynamic detailData,
    required dynamic epBundle,
    required dynamic epData,
    required List<dynamic> history,
    required int currentSeason,
    required SearchResult? currentSource,
    required String certification,
    required String? seasonTitle,
    required String? detailLogo,
    required int episodesCrossAxisCount,
    required double episodesAspectRatio,
    required AsyncValue<GroupedEpisodesResult?> episodesAsync,
    required AsyncValue<List<CastInfo>> castAsync,
    required double hPadding,
    required bool detailLoading,
    required AsyncValue<Map<String, List<RelatedInfo>>> unifiedRelationsAsync,
    required bool isMovieCategory,
    List<AnimeThemeInfo> openings = const [],
    List<AnimeThemeInfo> endings = const [],
    bool isCompact = false,
  }) {
    final List<Widget> slivers = [];
    final double screenW = MediaQuery.sizeOf(context).width;
    final double epCountFontSize = isMobile 
        ? 15.0 
        : (isCompact ? 14.5 : (screenW * 0.011).clamp(16.5, 20.5));
    final double epCountBottomPadding = isMobile ? 6.0 : (isCompact ? 12.0 : 26.0);

    if (selectedTabIndex == episodesTabIndex && hasEpisodesTab) {
      episodesAsync.maybeWhen(
        loading: () {
          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _buildEpisodesSkeleton(context, isMobile),
            ),
          );
        },
        orElse: () {
          slivers.add(
            SliverToBoxAdapter(
              child: AdaptiveEpisodesOrCountdown(
                params: UnifiedDetailParams(
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
                ),
                episodesBuilder: (episodes) {
                  final epBundleVal = episodesAsync.valueOrNull;
                  final epDataVal = epBundleVal?.response;
                  if (epDataVal == null) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMobile) const SizedBox(height: 24),
                    if (isMobile)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: epDataVal.total,
                        itemBuilder: (context, index) {
                          final ep = index < epDataVal.episodes.length ? epDataVal.episodes[index] : null;
                          final epNum = (ep?.number ?? index + 1).toString();
                          final epHistory = history.firstWhereOrNull((h) => h.contentId == widget.title && h.season == currentSeason && h.episode == epNum);
                          final epSource = epBundleVal?.sourceForIndex(index) ?? currentSource;
                          return _EpisodeCard(
                            episodeNumber: ep?.number ?? index + 1,
                            title: ep?.title ?? 'Episodio ${index + 1}',
                            description: ep?.description ?? '',
                            imageUrl: ApiEndpoints.proxyImage(ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                            fallbackImageUrl: ApiEndpoints.proxyImage(epSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                            releaseDate: ep?.airDate,
                            duration: ep?.duration ?? (ep?.runtime != null ? '${ep!.runtime} min' : null),
                            quality: ep?.quality ?? epSource?.quality ?? '',
                            episodeUrl: ep?.url,
                            source: epSource?.source ?? currentSource?.source,
                            category: widget.category,
                            certification: certification,
                            isMobile: true,
                            scrollController: _scrollController,
                            progress: epHistory?.progressPercentage,
                            isCompact: isCompact,
                            onTap: () {
                              final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum);
                              final tapSource = epBundleVal?.sourceForIndex(index) ?? currentSource;
                              final epThumb = ep?.thumbnail ?? tapSource?.thumbnail ?? '';
                              final player = PlayerScreen(
                                contentId: widget.title,
                                sourceUrl: _episodeUrlFor(ep, tapSource?.url ?? widget.url, tapSource?.source ?? (currentSource?.source ?? widget.source), ep?.number ?? index + 1),
                                source: tapSource?.source ?? (currentSource?.source ?? widget.source),
                                episode: (ep?.number ?? index + 1).toString(),
                                season: currentSeason,
                                serverName: simplifySourceName(tapSource?.source ?? (currentSource?.source ?? widget.source)),
                                startPosition: hist?.positionInMilliseconds,
                                category: widget.category,
                                totalEpisodes: epDataVal.total,
                                title: seasonTitle ?? widget.title,
                                logoUrl: detailLogo,
                                posterUrl: tapSource?.thumbnail ?? (currentSource?.thumbnail ?? widget.result?.thumbnail),
                                bannerUrl: epThumb,
                              );
                              _openPlayer(player);
                            },
                          );
                        },
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: episodesCrossAxisCount,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 24,
                          childAspectRatio: episodesAspectRatio,
                        ),
                        itemCount: epDataVal.total,
                        itemBuilder: (context, index) {
                          final ep = index < epDataVal.episodes.length ? epDataVal.episodes[index] : null;
                          final epNum = (ep?.number ?? index + 1).toString();
                          final epHistory = history.firstWhereOrNull((h) => h.contentId == widget.title && h.season == currentSeason && h.episode == epNum);
                          final epSource = epBundleVal?.sourceForIndex(index) ?? currentSource;
                          return _EpisodeCard(
                            episodeNumber: ep?.number ?? index + 1,
                            title: ep?.title ?? 'Episodio ${index + 1}',
                            description: ep?.description ?? '',
                            imageUrl: ApiEndpoints.proxyImage(ep?.thumbnail ?? epSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                            fallbackImageUrl: ApiEndpoints.proxyImage(epSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                            releaseDate: ep?.airDate,
                            duration: ep?.duration ?? (ep?.runtime != null ? '${ep!.runtime} min' : null),
                            quality: ep?.quality ?? epSource?.quality ?? '',
                            episodeUrl: ep?.url,
                            source: epSource?.source ?? currentSource?.source,
                            category: widget.category,
                            certification: certification,
                            scrollController: _scrollController,
                            progress: epHistory?.progressPercentage,
                            isCompact: isCompact,
                            onTap: () {
                              final hist = ref.read(playbackHistoryStateProvider.notifier).getProgress(widget.title, currentSeason, epNum);
                              final tapSource = epBundleVal?.sourceForIndex(index) ?? currentSource;
                              final epThumb = ep?.thumbnail ?? tapSource?.thumbnail ?? '';
                              final player = PlayerScreen(
                                contentId: widget.title,
                                sourceUrl: _episodeUrlFor(ep, tapSource?.url ?? widget.url, tapSource?.source ?? (currentSource?.source ?? widget.source), ep?.number ?? index + 1),
                                source: tapSource?.source ?? (currentSource?.source ?? widget.source),
                                episode: (ep?.number ?? index + 1).toString(),
                                season: currentSeason,
                                serverName: simplifySourceName(tapSource?.source ?? (currentSource?.source ?? widget.source)),
                                startPosition: hist?.positionInMilliseconds,
                                category: widget.category,
                                totalEpisodes: epDataVal.total,
                                title: seasonTitle ?? widget.title,
                                logoUrl: detailLogo,
                                posterUrl: tapSource?.thumbnail ?? (currentSource?.thumbnail ?? widget.result?.thumbnail),
                                bannerUrl: epThumb,
                              );
                              _openPlayer(player);
                            },
                          );
                        },
                      ),
                    if (epDataVal.specials.isNotEmpty) ...[
                      Padding(
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
                      if (isMobile)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: epDataVal.specials.length,
                          itemBuilder: (context, index) {
                            final sp = epDataVal.specials[index];
                            final spNum = sp.number;
                            final spSource = currentSource;
                            return _EpisodeCard(
                              episodeNumber: sp.number,
                              title: sp.title ?? 'Especial',
                              description: sp.description ?? '',
                              imageUrl: ApiEndpoints.proxyImage(sp.thumbnail ?? spSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                              fallbackImageUrl: ApiEndpoints.proxyImage(spSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                              releaseDate: sp.airDate,
                              duration: sp.duration ?? (sp.runtime != null ? '${sp.runtime} min' : null),
                              quality: sp.quality ?? spSource?.quality ?? '',
                              episodeUrl: sp.url,
                              source: spSource?.source ?? currentSource?.source,
                              category: widget.category,
                              certification: certification,
                              episodeType: sp.episodeType,
                              isMobile: true,
                              scrollController: _scrollController,
                              isCompact: isCompact,
                              onTap: () {
                                final epThumb = sp.thumbnail ?? spSource?.thumbnail ?? '';
                                final player = PlayerScreen(
                                  contentId: widget.title,
                                  sourceUrl: _episodeUrlFor(sp, spSource?.url ?? widget.url, spSource?.source ?? (currentSource?.source ?? widget.source), sp.number),
                                  source: spSource?.source ?? (currentSource?.source ?? widget.source),
                                  episode: spNum.toString(),
                                  season: 0,
                                  serverName: simplifySourceName(spSource?.source ?? (currentSource?.source ?? widget.source)),
                                  category: widget.category,
                                  totalEpisodes: epDataVal.total,
                                  title: seasonTitle ?? widget.title,
                                  logoUrl: detailLogo,
                                  posterUrl: spSource?.thumbnail ?? (currentSource?.thumbnail ?? widget.result?.thumbnail),
                                  bannerUrl: epThumb,
                                );
                                _openPlayer(player);
                              },
                            );
                          },
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: episodesCrossAxisCount,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 24,
                            childAspectRatio: episodesAspectRatio,
                          ),
                          itemCount: epDataVal.specials.length,
                          itemBuilder: (context, index) {
                            final sp = epDataVal.specials[index];
                            final spSource = currentSource;
                            return _EpisodeCard(
                              episodeNumber: sp.number,
                              title: sp.title ?? 'Especial',
                              description: sp.description ?? '',
                              imageUrl: ApiEndpoints.proxyImage(sp.thumbnail ?? spSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                              fallbackImageUrl: ApiEndpoints.proxyImage(spSource?.thumbnail ?? currentSource?.thumbnail ?? ''),
                              releaseDate: sp.airDate,
                              duration: sp.duration ?? (sp.runtime != null ? '${sp.runtime} min' : null),
                              quality: sp.quality ?? spSource?.quality ?? '',
                              episodeUrl: sp.url,
                              source: spSource?.source ?? currentSource?.source,
                              category: widget.category,
                              certification: certification,
                              episodeType: sp.episodeType,
                              scrollController: _scrollController,
                              isCompact: isCompact,
                              onTap: () {
                                final epThumb = sp.thumbnail ?? spSource?.thumbnail ?? '';
                                final player = PlayerScreen(
                                  contentId: widget.title,
                                  sourceUrl: _episodeUrlFor(sp, spSource?.url ?? widget.url, spSource?.source ?? (currentSource?.source ?? widget.source), sp.number),
                                  source: spSource?.source ?? (currentSource?.source ?? widget.source),
                                  episode: sp.number.toString(),
                                  season: 0,
                                  serverName: simplifySourceName(spSource?.source ?? (currentSource?.source ?? widget.source)),
                                  category: widget.category,
                                  totalEpisodes: epDataVal.total,
                                  title: seasonTitle ?? widget.title,
                                  logoUrl: detailLogo,
                                  posterUrl: spSource?.thumbnail ?? (currentSource?.thumbnail ?? widget.result?.thumbnail),
                                  bannerUrl: epThumb,
                                );
                                _openPlayer(player);
                              },
                            );
                          },
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

    if (selectedTabIndex == relatedTabIndex) {
      slivers.addAll(_buildRelatedTab(0, unifiedRelations: unifiedRelationsAsync, currentSource: currentSource));
    }
    if (selectedTabIndex == castTabIndex && castTabIndex != -1) {
      slivers.addAll(_buildCastTab(detailData, castAsync.valueOrNull ?? const [], 0));
    }
    if (selectedTabIndex == extrasTabIndex) {
      slivers.addAll(_buildExtrasTab(detailData, 0, openings: openings, endings: endings));
    }
    if (selectedTabIndex == detailsTabIndex) {
      final epDataValue = episodesAsync.maybeWhen(data: (d) => d, orElse: () => null);
      slivers.addAll(_buildDetailsTab(detailData, 0, inferredSeasonAirDate: epDataValue?.response.seasonAirDate, sourceRating: currentSource?.score, showRatingSkeleton: currentSource?.score == null && detailLoading));
    }
    if (selectedTabIndex == galleryTabIndex) {
      slivers.addAll(_buildGalleryTab(0, isMovieCategory ? 'movie' : 'tv', detailData?.title ?? widget.title, detailData is AnimeDetail ? (detailData as AnimeDetail).year : widget.year));
    }

    return slivers;
  }

  @override Widget build(BuildContext context) {
    try {
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;
      final isMobile = context.isMobile;
      final isUltraCompact = context.breakpoint < Breakpoint.lg;
      final isCompact = isUltraCompact || height < 900;

      final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
      final hPadding = isMobile ? 20.0 : (width >= 800 && width < 1200 ? 24.0 : horizontalPadding);
      final episodesCrossAxisCount = isMobile ? 1 : (width < 700 ? 2 : (width < 1150 ? 3 : (width < 1550 ? 4 : (width < 2100 ? 5 : 6))));
      final episodesAspectRatio = isMobile ? 1.15 : (width < 1150 ? 0.98 : 1.01);

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
      final settings = ref.watch(settingsProvider);
      _checkAndInitTrailer(detailState.detail, settings);

      ref.watch(detailViewTrackerProvider(detailParams));

      ref.listen<UnifiedContentState>(unifiedContentProvider(detailParams), (prev, next) {
        if (next.allSources.isNotEmpty) {
          final currentInPlayer = ref.read(activeContentSourcesProvider);
          if (!const ListEquality().equals(currentInPlayer, next.allSources)) {
            ref.read(activeContentSourcesProvider.notifier).state = next.allSources;
          }
        }
      });

      final detailAsync = detailState.detail;
      final detailData = detailAsync.maybeWhen(data: (d) => d?.main, orElse: () => null);
      final String? _detailLogo = detailData?.logo;
      final isMovieCategory = detailState.isMovieish;
      final currentSeason = detailState.currentSeason;
      final totalSeasons = detailState.totalSeasons;
      final int resolvedTotalSeasons = [totalSeasons, widget.totalSeasons ?? 0].reduce((a, b) => a > b ? a : b);
      final activeSources = detailState.allSources;
      final currentSource = detailState.selectedSource;
      final episodesAsync = detailState.episodes;
      final unifiedRelationsAsync = detailState.relations;
      final seasonTitle = detailState.seasonTitle;
      final epBundle = episodesAsync.maybeWhen(data: (d) => d, orElse: () => null);
      final epData = epBundle?.response;

      final dataReady = detailAsync.hasValue || activeSources.isNotEmpty;
      if (dataReady && !_showContent) {
        _loadTimer?.cancel();
        _loadTimer = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showContent = true);
        });
      }

      if (!_showContent) {
        return Scaffold(backgroundColor: const Color(0xFF0B0B0D), body: _buildPageSkeleton(context, isMobile));
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
        highQuality: true,
      );

      final historyAsync = ref.watch(playbackHistoryStateProvider);
      final history = historyAsync.maybeWhen(data: (d) => d, orElse: () => const <dynamic>[]);
      final detailLoading = detailAsync.isLoading && detailAsync.maybeWhen(data: (d) => d == null, orElse: () => true);

      if (currentSource != null && _showContent) {
        String? prefetchUrl;
        if (isMovieCategory) {
          prefetchUrl = currentSource.url;
        } else {
          final latest = history.where((h) => h.contentId == widget.title).firstOrNull;
          int epNum = latest != null ? int.tryParse(latest.episode ?? '1') ?? 1 : 1;
          final epData = episodesAsync.asData?.value?.response;
          final epSource = episodesAsync.asData?.value?.sourceForNumber(epNum) ?? currentSource;
          final ep = epData?.episodes.firstWhereOrNull((e) => e.number == epNum);
          prefetchUrl = _episodeUrlFor(ep, epSource.url, epSource.source, epNum);
        }
        if (prefetchUrl.isNotEmpty) {
          ref.watch(extractProvider(ExtractParams(url: prefetchUrl, source: currentSource.source, category: widget.category)));
        }
      }

      final List<Widget> contentSlivers = _buildContentSlivers(
        context: context,
        isMobile: isMobile,
        selectedTabIndex: selectedTabIndex,
        episodesTabIndex: episodesTabIndex,
        relatedTabIndex: relatedTabIndex,
        castTabIndex: castTabIndex,
        extrasTabIndex: extrasTabIndexFinal,
        detailsTabIndex: detailsTabIndex,
        galleryTabIndex: galleryTabIndex,
        hasEpisodesTab: hasEpisodesTab,
        detailData: detailData,
        epBundle: epBundle,
        epData: epData,
        history: history,
        currentSeason: currentSeason,
        currentSource: currentSource,
        certification: certification,
        seasonTitle: seasonTitle,
        detailLogo: _detailLogo,
        episodesCrossAxisCount: episodesCrossAxisCount,
        episodesAspectRatio: episodesAspectRatio,
        episodesAsync: episodesAsync,
        castAsync: castAsync,
        hPadding: context.isDesktop ? 0 : hPadding,
        detailLoading: detailLoading,
        unifiedRelationsAsync: unifiedRelationsAsync,
        isMovieCategory: isMovieCategory,
        openings: currentOpenings,
        endings: currentEndings,
        isCompact: isCompact,
      );

      final Widget contentSliver = SliverMainAxisGroup(slivers: contentSlivers);

      if (context.isDesktop) {
        return _buildDesktopView(
          context: context,
          width: width,
          hPadding: context.isDesktop ? 0 : hPadding,
          heroBanner: heroBanner,
          detailData: detailData,
          detailAsync: detailAsync,
          detailParams: detailParams,
          activeSources: activeSources,
          currentSource: currentSource,
          currentSeason: currentSeason,
          totalSeasons: resolvedTotalSeasons,
          tabLabels: tabLabels,
          selectedTabIndex: selectedTabIndex,
          contentSliver: contentSliver,
          isCompactHeader: isCompact,
          epData: epData,
          isMovieCategory: isMovieCategory,
        );
      }

      return AdaptiveDetailLayout(
        maxContentWidth: 1000,
        bottomNavigationBar: isMobile ? AurisBottomBar(
          currentIndex: -1,
          onTap: (index) {
            final routes = ['/inicio', '/catalogo', '/explore', '/settings'];
            context.go(routes[index]);
          },
        ) : null,
        topBar: _buildUpperButtons(context, desktopTop: width / 2.8 > 400 ? 45 : 35),
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
          maxHeight: isMobile ? 80 : 130, // Senior Fix: Reducción de altura máxima del bloque de logo (160 -> 130)
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 14 : 24,
            fontWeight: FontWeight.bold,
            height: 1.1,
            letterSpacing: 4,
            shadows: const [
              Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 4),
              Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 10)
            ]
          )
        ),
        meta: _buildMetaRow(detailData, isMobile: isMobile, kind: detailParams.kind),
        mainAction: _buildMainActionButton(context, isMobile: isMobile),
        secondaryActions: _buildCircularActions(context, isMobile: isMobile),
        synopsis: _buildSynopsis(detailData, isCompact: !isMobile && width < 1200),
        selectors: (!isMovieCategory && (resolvedTotalSeasons > 0 || currentSource != null)) ? Row(
          children: [
            if (!isMovieCategory && resolvedTotalSeasons > 0) ...[
              SeasonSelector(
                data: SeasonSelectorData(
                  currentSeason: currentSeason,
                  totalSeasons: resolvedTotalSeasons > 0 ? resolvedTotalSeasons : 1,
                  onSeasonSelected: (s) => ref.setSeason(detailParams, s),
                  compact: true,
                  totalEpisodes: epData?.total,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (currentSource != null)
              _ServerSelector(
                currentSource: currentSource,
                sources: activeSources,
                onSourceSelected: (index) => ref.setSource(detailParams, activeSources[index]),
                compact: true,
                unavailableSources: null,
                season: widget.year,
                width: 140,
              ),
          ],
        ) : null,
        tabs: ContentTabBar(
          labels: tabLabels,
          selectedIndex: selectedTabIndex,
          onTabSelected: (i) => setState(() => _selectedTabIndex = i),
          hPadding: isMobile ? 0 : 16,
          isMobile: isMobile,
          isCompact: !isMobile && width < 1200,
        ),
        content: contentSliver,
      );

    } catch (e, stack) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B0D),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text('Error al cargar detalle: $e', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('$stack', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildDesktopView({
    required BuildContext context,
    required double width,
    required double hPadding,
    required String heroBanner,
    required dynamic detailData,
    required AsyncValue<ContentDetailResponse?> detailAsync,
    required UnifiedDetailParams detailParams,
    required List<SearchResult> activeSources,
    required SearchResult? currentSource,
    required int currentSeason,
    required int totalSeasons,
    required List<String> tabLabels,
    required int selectedTabIndex,
    required Widget contentSliver,
    required bool isCompactHeader,
    required dynamic epData,
    required bool isMovieCategory,
  }) {
    // Senior Responsive Desktop Architecture: Dimensiones fluidas continuas para cualquier resolución de pantalla (Laptops -> 4K Ultrawide)
    final double headerH = (width / 2.8).clamp(480.0, 620.0);
    final double overlayLeftPadding = 60.0; // Alineado permanentemente a 60px con los tabs inferiores en cualquier tamaño de ventana desktop
    final double synopsisWidth = (width * 0.46).clamp(400.0, 760.0);
    final double logoMaxWidth = (width * 0.32).clamp(320.0, 600.0);
    final double logoMaxHeight = (headerH * (isCompactHeader ? 0.20 : 0.25)).clamp(80.0, 140.0);
    final double titleSize = (width * 0.028).clamp(30.0, 52.0);
    final double topPadding = isCompactHeader 
        ? (headerH * 0.30).clamp(96.0, 140.0) 
        : (headerH * 0.22).clamp(90.0, 135.0);
    final bool hasLogo = detailData?.logo != null && detailData!.logo!.isNotEmpty;
    final double gapLogoToMeta = isCompactHeader ? 6.0 : (hasLogo ? 20.0 : 10.0);
    final double gapMetaToSynopsis = isCompactHeader ? 4.0 : (hasLogo ? 12.0 : 8.0);
    final double gapSynopsisToActions = isCompactHeader ? 4.0 : 16.0;
    final double gapActionsToSelectors = isCompactHeader ? 2.0 : 12.0;
    final double selectorWidth = isCompactHeader ? 220.0 : 320.0;
    final double selectorH = isCompactHeader ? 36.0 : (width * 0.026).clamp(42.0, 48.0);
    final double selectorFontSize = isCompactHeader ? 13.5 : (width * 0.009).clamp(14.0, 16.0);

    // Senior Dynamic Fusion: Cálculo exacto según el ancho real del reproductor en la pantalla
    final double trailerVideoW = headerH * (16.0 / 9.0);
    final double trailerStartFraction = (1.0 - (trailerVideoW / width)).clamp(0.10, 0.80);
    final double trailerSolidEnd = (trailerStartFraction + 0.03).clamp(0.15, 0.85);
    final double trailerFadeMid = (trailerSolidEnd + 0.10).clamp(0.25, 0.90);
    final double trailerFadeEnd = (trailerSolidEnd + 0.22).clamp(0.35, 0.98);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(), // Senior Fix: Bloquear rebote superior en Desktop para evitar bloque negro
            slivers: [
              // 1. HEADER CINEMATOGRÁFICO (Sliver Fijo Espacioso)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: headerH,
                  child: Stack(
                    children: [
                      // BACKDROP CON DESPLAZAMIENTO Y MÁSCARAS
                      Positioned.fill(
                        child: Stack(
                          children: [
                            Container(color: const Color(0xFF0B0B0D)),
                            // Imagen con desplazamiento lateral (Backdrop estático con offset 18% para no invadir el área de texto)
                            Positioned(
                              top: 0, left: width * 0.18, right: 0, bottom: 0,
                              child: ClipRect(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeInOut,
                                  opacity: (_revealed && !_showPlayer) ? 1.0 : 0.0,
                                  child: CachedNetworkImage(
                                    imageUrl: heroBanner,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    fadeInDuration: const Duration(milliseconds: 300),
                                    errorWidget: (_, __, ___) => Container(color: Colors.black12),
                                  ),
                                ),
                              ),
                            ),

                            // TRÁILER (YouTube IFrame con Fallback HTML) - Alineado 100% al borde derecho sin espacio sobrante
                            if (_ytController != null || _useHtmlIframeFallback)
                              Positioned(
                                top: 0, left: width * 0.25, right: 0, bottom: 0,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 500),
                                  opacity: _showPlayer ? 1.0 : 0.0,
                                  child: PointerInterceptor(
                                    child: IgnorePointer(
                                      ignoring: true,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: _useHtmlIframeFallback
                                              ? HtmlElementView.fromTagName(
                                                  key: ValueKey('html-iframe-$_lastTrailerKey'),
                                                  tagName: 'iframe',
                                                  onElementCreated: (Object element) {
                                                    // ignore: avoid_dynamic_calls
                                                    final dynamic el = element;
                                                    el.src = 'https://www.youtube-nocookie.com/embed/$_lastTrailerKey?autoplay=1&mute=1&controls=0&rel=0&modestbranding=1&iv_load_policy=3&showinfo=0&cc_load_policy=0&cc_lang_pref=none';
                                                    el.style.border = 'none';
                                                    el.style.width = '100%';
                                                    el.style.height = '100%';
                                                    el.allow = 'autoplay; encrypted-media';
                                                  },
                                                )
                                              : YoutubePlayer(
                                                  key: ValueKey(_lastTrailerKey),
                                                  controller: _ytController!,
                                                  aspectRatio: 16 / 9,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // GRADIENTES DE FUSIÓN (NETFLIX STYLE) — Todos dentro de un solo PointerInterceptor
                            // para evitar que el iframe de YouTube robe eventos del mouse.
                            Positioned.fill(
                              child: PointerInterceptor(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Gradiente Lateral (Netflix Style)
                                    // Gradientes Estáticos del Backdrop (Se ocultan cuando el tráiler está activo para no oscurecer el video)
                                    Positioned.fill(
                                      child: AnimatedOpacity(
                                        duration: const Duration(milliseconds: 600),
                                        opacity: _showPlayer ? 0.0 : 1.0,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Gradiente Lateral Estático (Fusión perfecta cubriendo el borde del offset al 18%)
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    const Color(0xFF0B0B0D),
                                                    const Color(0xFF0B0B0D),
                                                    const Color(0xFF0B0B0D).withOpacity(0.50),
                                                    Colors.transparent,
                                                  ],
                                                  stops: const [0.0, 0.22, 0.45, 0.70],
                                                ),
                                              ),
                                            ),
                                            // Gradiente Superior (Suave)
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    const Color(0xFF0B0B0D).withOpacity(0.6),
                                                    Colors.transparent,
                                                  ],
                                                  stops: const [0.0, 0.35],
                                                ),
                                              ),
                                            ),
                                            // Máscara Lateral Superior
                                            Positioned.fill(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      const Color(0xFF0B0B0D),
                                                      const Color(0xFF0B0B0D).withOpacity(0.8),
                                                      Colors.transparent,
                                                    ],
                                                    stops: const [0.0, 0.2, 0.45],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Máscara Inferior Maestra
                                    Positioned(
                                      bottom: -1, left: 0, right: 0, height: 160,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              const Color(0xFF0B0B0D),
                                              const Color(0xFF0B0B0D).withOpacity(0.9),
                                              const Color(0xFF0B0B0D).withOpacity(0.4),
                                              const Color(0xFF0B0B0D).withOpacity(0.0),
                                            ],
                                            stops: const [0.0, 0.15, 0.45, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Máscara Cinematográfica Tráiler (Fusión Dinámica Calculada por Ancho Real)
                                    Positioned.fill(
                                      child: AnimatedOpacity(
                                        duration: const Duration(milliseconds: 600),
                                        opacity: _showPlayer ? 1.0 : 0.0,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                const Color(0xFF0B0B0D),
                                                const Color(0xFF0B0B0D),
                                                const Color(0xFF0B0B0D).withOpacity(0.50),
                                                Colors.transparent,
                                              ],
                                              stops: [
                                                0.0,
                                                trailerSolidEnd,
                                                trailerFadeMid,
                                                trailerFadeEnd,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BOTONES SUPERIORES (Integrados en el header para que se desplacen con el scroll)
                      _buildUpperButtons(context, desktopTop: 45),

                      // OVERLAY DE INFORMACIÓN (FIJO ESPACIOSO / NO SCROLLEABLE)
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: overlayLeftPadding, 
                            top: topPadding, 
                            bottom: 16, 
                            right: 32,
                          ),
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minHeight: 0,
                            maxHeight: 1200,
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            // Logo
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeInOut,
                              opacity: _revealed ? 1.0 : 0.0,
                              child: HeroTitle(
                                title: widget.title,
                                logo: detailData?.logo,
                                logoReady: detailAsync.hasValue,
                                maxWidth: logoMaxWidth,
                                maxHeight: (detailData?.logo != null && detailData!.logo!.isNotEmpty) ? logoMaxHeight : (titleSize * 2.2),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                  letterSpacing: 2,
                                  shadows: const [
                                    Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4),
                                    Shadow(color: Colors.black54, offset: Offset(4, 4), blurRadius: 10),
                                  ]
                                )
                              ),
                            ),
                            SizedBox(height: gapLogoToMeta),
                            if (detailData != null) ...[
                              _buildMetaRow(detailData, isCompact: isCompactHeader, kind: detailParams.kind),
                              SizedBox(height: gapMetaToSynopsis),
                              SizedBox(
                                width: synopsisWidth,
                                child: _buildSynopsis(detailData, isCompact: isCompactHeader, isScrollable: true),
                              ),
                            ],
                            SizedBox(height: gapSynopsisToActions),
                            // Botones de acción
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _buildMainActionButton(context, isCompact: isCompactHeader),
                                _buildCircularActions(context, isCompact: isCompactHeader),
                              ],
                            ),
                            SizedBox(height: gapActionsToSelectors),
                            // Selectores
                            if (!isMovieCategory && (totalSeasons > 0 || currentSource != null))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isMovieCategory && totalSeasons > 0) ...[
                                    SizedBox(
                                      width: selectorWidth,
                                      child: SeasonSelector(
                                        data: SeasonSelectorData(
                                          currentSeason: currentSeason,
                                          totalSeasons: totalSeasons > 0 ? totalSeasons : 1,
                                          onSeasonSelected: (s) => ref.setSeason(detailParams, s),
                                          compact: isCompactHeader,
                                          width: selectorWidth,
                                          height: selectorH,
                                          fontSize: selectorFontSize,
                                          totalEpisodes: epData?.total,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (currentSource != null)
                                    SizedBox(
                                      width: selectorWidth,
                                      child: _ServerSelector(
                                        currentSource: currentSource,
                                        sources: activeSources,
                                        onSourceSelected: (index) => ref.setSource(detailParams, activeSources[index]),
                                        compact: isCompactHeader,
                                        width: selectorWidth,
                                        height: selectorH,
                                        fontSize: selectorFontSize,
                                        season: widget.year,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),

              // 2. CONTENIDO INFERIOR (Tabs y Episodios)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          ContentTabBar(
                            labels: tabLabels,
                            selectedIndex: selectedTabIndex,
                            onTabSelected: (i) => setState(() => _selectedTabIndex = i),
                            hPadding: 0,
                            isCompact: isCompactHeader,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    contentSliver,
                  ],
                ),
              ),
            ],
          ),
        ],
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
            sliver: _buildEpisodesSkeleton(context, isMobile),
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
    final width = MediaQuery.of(context).size.width;
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
            SliverToBoxAdapter(
              child: _RelatedCarouselRow(
                title: 'Franquicia y Secuelas',
                hPadding: context.isDesktop ? 0 : hPadding,
                items: _unifyAndDeduplicate(
                  sourceItems: franchiseSource,
                  currentSource: currentSource,
                ),
              ),
            ),
          if (recommendedSource.isNotEmpty)
            SliverToBoxAdapter(
              child: _RelatedCarouselRow(
                title: 'Te recomendamos',
                hPadding: context.isDesktop ? 0 : hPadding,
                items: _unifyAndDeduplicate(
                  sourceItems: recommendedSource,
                  currentSource: currentSource,
                  isRecommendation: true,
                ),
              ),
            ),
          if (similarSource.isNotEmpty)
            SliverToBoxAdapter(
              child: _RelatedCarouselRow(
                title: 'Similares a ${cleanTitleForDisplay(stripSeasonSuffix(widget.title))}',
                hPadding: context.isDesktop ? 0 : hPadding,
                items: _unifyAndDeduplicate(
                  sourceItems: similarSource,
                  currentSource: currentSource,
                ),
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
          final uri = UrlUtils.buildShareableUri(
            title: r.title,
            source: result.source,
            url: result.url,
            category: widget.category, // Senior: Mantener la categoría actual
            from: widget.from ?? '/inicio',
          );
          context.go(uri, extra: result);
        },
      );
    }

    return unifiedMap.values.toList();
  }

  List<Widget> _buildCastTab(dynamic detailData, List<CastInfo> serverCast, double hPadding) {
    final List<CastInfo> cast;

    // Senior Strategy: Prioridad absoluta al cast del servidor (scraper) si existe.
    // Si no ha llegado o está vacío, usamos el de detalles (TMDB/AniList) como placeholder.
    if (serverCast.isNotEmpty) {
      cast = serverCast;
    } else {
      final Map<String, CastInfo> detailCast = {};

      // 1. Cast de Películas/Series (TMDB)
      if (detailData is MovieDetail) {
        for (var c in detailData.cast) {
          detailCast[c.name] = CastInfo(
            id: c.id,
            name: c.name,
            character: c.character,
            profile: c.profile,
          );
        }
      }

      // 2. Anime (AniList): los actores de voz son las personas del cast;
      // con su nombre se resuelve la filmografía en vivo vía TMDB. Si no hay
      // seiyuu, se muestra el personaje (best-effort por nombre).
      if (detailData is AnimeDetail) {
        for (var c in detailData.characters) {
          if (c.voiceActors.isNotEmpty) {
            for (final va in c.voiceActors) {
              if (va.name.isEmpty || detailCast.containsKey(va.name)) continue;
              detailCast[va.name] = CastInfo(
                name: va.name,
                character: c.name,
                profile: va.image ?? c.image,
              );
            }
          } else if (!detailCast.containsKey(c.name)) {
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

    final isMobile = context.isMobile;
    final width = MediaQuery.of(context).size.width;
    // Senior Fix: Diseño de Avatar requiere una rejilla más compacta y centrada
    final crossAxisCount = isMobile ? 3 : (width < 1000 ? 4 : (width < 1400 ? 6 : (width < 1800 ? 8 : 10)));

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 32),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 32,
            crossAxisSpacing: 20,
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
      SliverToBoxAdapter(
        child: _GalleryTabContent(
          hPadding: context.isDesktop ? 0 : hPadding,
          kind: kind,
          title: title,
          year: year,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Widget> _buildExtrasTab(dynamic detail, double hPadding,
      {List<AnimeThemeInfo> openings = const [], List<AnimeThemeInfo> endings = const []}) {
    if (detail == null) return [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Colors.white24))))];
    final isMobile = context.isMobile;
    // Los OP/ED del anime llegan de /api/themes (detail ya no los incluye).
    final List<AnimeThemeInfo> ops = detail is AnimeDetail
        ? openings
        : (detail is MovieDetail ? (detail as MovieDetail).openings : const <AnimeThemeInfo>[]);
    final List<AnimeThemeInfo> eds = detail is AnimeDetail
        ? endings
        : (detail is MovieDetail ? (detail as MovieDetail).endings : const <AnimeThemeInfo>[]);
    final String? fallbackImg = detail is AnimeDetail
        ? (detail.banner ?? detail.backdrop)
        : (detail is MovieDetail ? ((detail as MovieDetail).backdrop ?? (detail as MovieDetail).poster) : null);

    final String animeTitle = detail is AnimeDetail ? detail.title : (detail is MovieDetail ? detail.title : '');
    final String? logoUrl = detail is AnimeDetail ? detail.logo : (detail is MovieDetail ? detail.logo : null);

    if (ops.isEmpty && eds.isEmpty) return [const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No hay temas musicales disponibles', style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)))))];
    return [
      if (ops.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Text('Openings', style: TextStyle(color: Colors.white, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: ops[index], isOP: true, fallbackImage: fallbackImg, animeTitle: animeTitle, logoUrl: logoUrl), childCount: ops.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
      if (eds.isNotEmpty) ...[ SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: hPadding), child: Text('Endings', style: TextStyle(color: Colors.white, fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)))), const SliverToBoxAdapter(child: SizedBox(height: 16)), SliverPadding(padding: EdgeInsets.symmetric(horizontal: hPadding), sliver: SliverGrid(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: isMobile ? 2 : 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.6), delegate: SliverChildBuilderDelegate((context, index) => _ThemeCard(theme: eds[index], isOP: false, fallbackImage: fallbackImg, animeTitle: animeTitle, logoUrl: logoUrl), childCount: eds.length))), const SliverToBoxAdapter(child: SizedBox(height: 32)) ],
    ];
  }

  List<Widget> _buildDetailsTab(dynamic detail, double hPadding, {String? inferredSeasonAirDate, double? sourceRating, bool showRatingSkeleton = false}) {
    if (detail == null) return [const SliverToBoxAdapter(child: SizedBox.shrink())];
    final isMobile = context.isMobile;     final rating = formatRating((detail.rating as double?) ?? sourceRating);
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
        const Text('M\u00E1s informaci\u00F3n', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
        if (detail is MovieDetail && detail.originalTitle != null && detail.originalTitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            detail.originalTitle!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (detail.genres is List) Wrap(spacing: 8, runSpacing: 8, children: (detail.genres as List).map<Widget>((g) => _buildBadge(context, g.toString().toUpperCase())).toList()), 
        const SizedBox(height: 20), 
        Text(detail.overview ?? '', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 15, height: 1.5)), 
        const SizedBox(height: 24),
        if (platforms.isNotEmpty) ...[
          const Text('Disponible en', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: platforms.map<Widget>((p) => _buildPlatformLogo(context, p, size: 32)).toList()),
          const SizedBox(height: 24),
        ],
        const Text('Advertencias de contenido', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), 
        const SizedBox(height: 8), 
        Text(_getWarningText(cert), style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 14)), 
        const SizedBox(height: 24), 
        if (status != null) ...[const Text('Estado', style: TextStyle(color: Colors.white, fontSize: 16)), Text(status, style: const TextStyle(color: const Color(0xFFA5A5AA))), const SizedBox(height: 24)],
        if (languages.isNotEmpty) ...[
          const Text('Pa\u00EDs', style: TextStyle(color: Colors.white, fontSize: 16)),
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
          }(), style: const TextStyle(color: const Color(0xFFA5A5AA))),
          const SizedBox(height: 24)
        ],
        if (dir.isNotEmpty) ...[const Text('Direcci\u00F3n', style: TextStyle(color: Colors.white, fontSize: 16)), Text(dir.join(', '), style: const TextStyle(color: Color(0xFFA5A5AA)))], 
        if (std.isNotEmpty) ...[const SizedBox(height: 24), const Text('Estudio', style: TextStyle(color: Colors.white, fontSize: 16)), Text(std.join(', '), style: const TextStyle(color: const Color(0xFFA5A5AA)))]
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
            _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Advertencias de contenido', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 16), _ContentScreenState._buildAgeBadge(context, cert), const SizedBox(height: 16), Text('${_getWarningText(cert)} Las luces intermitentes pueden afectar a espectadores fotosensibles', style: const TextStyle(color: const Color(0xFFA5A5AA), fontSize: 20)) ])),
            if (platforms.isNotEmpty) ...[
              const SizedBox(height: 24),
              _DetailInfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Disponible en', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Wrap(spacing: 16, runSpacing: 16, children: platforms.map<Widget>((p) => _buildPlatformLogo(context, p)).toList()),
              ])),
            ],
          ],
        ))
      ]))),
    ];
  }

  List<Widget> _buildCharacterSection(dynamic detail, double hPadding) {
    if (detail is! AnimeDetail || detail.characters.isEmpty) return [];
    final width = MediaQuery.of(context).size.width;
    final isMobile = context.isMobile;
    final isCompactDesktop = width >= 800 && width < 1100;
    
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
      SliverToBoxAdapter(
        child: _HorizontalInfoCarousel<CharacterInfo>(
          items: detail.characters,
          horizontalPadding: hPadding,
          itemKey: (c) => 'char_${c.name}',
          itemBuilder: (context, character, width) {
            final voiceActor = character.voiceActors.firstWhereOrNull((va) => va.language == 'Japanese') ?? character.voiceActors.firstOrNull;
            final role = character.role?.toLowerCase();
            String roleLabel = '';
            if (role == 'main') roleLabel = 'Principal';
            else if (role == 'supporting') roleLabel = 'Secundario';
            else if (role == 'background') roleLabel = 'Fondo';
            else roleLabel = character.role ?? '';

            return _InfoCard(
              imageUrl: character.image ?? '',
              title: character.name,
              subtitle: voiceActor?.name,
              label: roleLabel,
              labelColor: (role == 'main') ? const Color(0xFFEF7A1E) : Colors.white24,
              width: width,
            );
          },
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Widget> _buildCastSection(dynamic detail, double hPadding) {
    if (detail is! MovieDetail || detail.cast.isEmpty) return [];
    final width = MediaQuery.of(context).size.width;
    final isMobile = context.isMobile;
    final isCompactDesktop = width >= 800 && width < 1100;

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
      SliverToBoxAdapter(
        child: _HorizontalInfoCarousel<CastMember>(
          items: detail.cast,
          horizontalPadding: hPadding,
          itemKey: (m) => 'cast_${m.name}',
          itemBuilder: (context, member, width) => _InfoCard(
            imageUrl: member.profile ?? '',
            title: member.name,
            subtitle: member.character,
            width: width,
          ),
        ),
      ),
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
    
    final bool canLeft = currentScroll > 5;
    final bool canRight = maxScroll > currentScroll + 5;
    
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
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
    final isMobile = context.isMobile;
    
    final cardWidth = ResponsiveUtils.posterWidth(context);
    final carouselHeight = ResponsiveUtils.rowHeight(context, hasInfo: true) + 4.0; // Senior Fix: +4px de seguridad para evitar overflow sub-pixel

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        SizedBox(height: isMobile ? 8 : 12),
        MouseRegion(
          onEnter: (_) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isHovered = true);
              });
            }
          },
          onExit: (_) {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isHovered = false);
              });
            }
          },
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
                    padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
                    itemCount: widget.items.length,
                    separatorBuilder: (_, __) => SizedBox(width: context.useMobileLayout ? 8 : 24),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      return SizedBox(
                        width: cardWidth,
                        child: FocusablePosterCard(
                          key: ValueKey('related_${item.title}_${item.poster}'),
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
                  bottom: 90, 
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
                  bottom: 90, 
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
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? label;
  final Color? labelColor;
  final double width;

  const _InfoCard({
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.label,
    this.labelColor,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
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
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white10,
                  child: Icon(Icons.person, color: Colors.white24, size: width * 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1, // Senior: Nombres de elenco en 1 línea para evitar desalineación
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.sp(context, 14),
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFA5A5AA),
                fontSize: ResponsiveUtils.sp(context, 13),
              ),
            ),
          ],
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label!,
              style: TextStyle(
                color: labelColor ?? Colors.white24,
                fontSize: ResponsiveUtils.sp(context, 11),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HorizontalInfoCarousel<T> extends StatefulWidget {
  final List<T> items;
  final double horizontalPadding;
  final Widget Function(BuildContext, T, double) itemBuilder;
  final String Function(T) itemKey;

  const _HorizontalInfoCarousel({
    required this.items,
    required this.horizontalPadding,
    required this.itemBuilder,
    required this.itemKey,
  });

  @override
  State<_HorizontalInfoCarousel<T>> createState() => _HorizontalInfoCarouselState<T>();
}

class _HorizontalInfoCarouselState<T> extends State<_HorizontalInfoCarousel<T>> {
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
    final isMobile = context.isMobile;
    // Senior Fix: Las tarjetas de info (elenco/personajes) son ligeramente más pequeñas que los posters (~85%)
    final cardWidth = ResponsiveUtils.posterWidth(context) * 0.85;
    // Proporcionamos altura suficiente para imagen 1:1.2 + 3 líneas de texto
    final carouselHeight = (cardWidth * 1.2) + ResponsiveUtils.sp(context, 80); // Senior Fix: Aumento de 75 a 80 para evitar overflow

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted && _isHovered) setState(() => _isHovered = false);
      },
      onHover: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
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
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return Container(
                    key: ValueKey(widget.itemKey(item)),
                    child: widget.itemBuilder(context, item, cardWidth),
                  );
                },
              ),
            ),
          ),
          if (!isMobile) ...[
            Positioned(
              left: 0, top: 0, bottom: (carouselHeight - (cardWidth * 1.2)) / 2, // Centrar flechas en la imagen
              child: Center(
                child: AnimatedOpacity(
                  opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: NavArrow(icon: Icons.arrow_back_ios_new, useBackground: true, onTap: () => _scroll(-cardWidth * 3)),
                ),
              ),
            ),
            Positioned(
              right: 0, top: 0, bottom: (carouselHeight - (cardWidth * 1.2)) / 2, // Centrar flechas en la imagen
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

  bool _matchesFilter(String type, String filter) {
    final t = type.toLowerCase().trim();
    if (filter == "poster") {
      return t.contains("poster");
    }
    if (filter == "backdrop") {
      return t.contains("backdrop") || t.contains("fondo") || t.contains("banner") || t.contains("fanart") || t.contains("background");
    }
    if (filter == "logo") {
      return t.contains("logo") || t.contains("art");
    }
    return t == filter;
  }

  @override
  Widget build(BuildContext context) {
    final params = GalleryParams(kind: widget.kind, title: stripSeasonSuffix(widget.title ?? ''), year: widget.year);
    final async = ref.watch(galleryProvider(params));
    final isMobile = context.isMobile;

    return async.when(
      loading: () => Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 3 : 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
          itemCount: 15,
        ),
      ),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text("Error al cargar la galería", style: TextStyle(color: const Color(0xFFA5A5AA), fontSize: 18)),
        ),
      ),
      data: (g) {
        if (g.gallery.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text("No hay imágenes disponibles", style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 18)),
            ),
          );
        }

        final filtered = _selectedFilter == "all"
            ? g.gallery
            : g.gallery.where((img) => _matchesFilter(img.type, _selectedFilter)).toList();

        final hasPosters = g.gallery.any((img) => _matchesFilter(img.type, "poster"));
        final hasBackdrops = g.gallery.any((img) => _matchesFilter(img.type, "backdrop") || _matchesFilter(img.type, "banner"));
        final hasLogos = g.gallery.any((img) => _matchesFilter(img.type, "logo"));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(widget.hPadding, isMobile ? 0 : 8, widget.hPadding, 16),
              child: Align(
                alignment: isMobile ? Alignment.center : Alignment.centerLeft,
                child: Wrap(
                  alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GalleryFilterChip(
                      label: "Todos",
                      selected: _selectedFilter == "all",
                      onSelected: () => setState(() => _selectedFilter = "all"),
                    ),
                    if (hasPosters)
                      _GalleryFilterChip(
                        label: "Pósters",
                        selected: _selectedFilter == "poster",
                        onSelected: () => setState(() => _selectedFilter = "poster"),
                      ),
                    if (hasBackdrops)
                      _GalleryFilterChip(
                        label: "Fondos",
                        selected: _selectedFilter == "backdrop",
                        onSelected: () => setState(() => _selectedFilter = "backdrop"),
                      ),
                    if (hasLogos)
                      _GalleryFilterChip(
                        label: "Logos",
                        selected: _selectedFilter == "logo",
                        onSelected: () => setState(() => _selectedFilter = "logo"),
                      ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text("No hay imágenes de este tipo", style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 16)),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile 
                        ? (_selectedFilter == "backdrop" ? 2 : 3)
                        : (_selectedFilter == "backdrop" ? 4 : 6),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _selectedFilter == "backdrop" 
                        ? 16 / 9 
                        : (_selectedFilter == "banner" ? 3.0 : (_selectedFilter == "logo" ? 1.0 : 0.67)),
                  ),
                  itemBuilder: (context, index) {
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
                  itemCount: filtered.length,
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
    final isMobile = context.isMobile;

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted && _isHovered) setState(() => _isHovered = false);
      },
      onHover: (_) {
        if (mounted && !_isHovered) setState(() => _isHovered = true);
      },
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



