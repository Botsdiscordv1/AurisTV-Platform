import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart' hide MarqueeText;
import 'marquee_text.dart';
import 'tv_focus_wrapper.dart';
import 'tv_scroll.dart';
import '../../core/utils/tv_responsive_utils.dart';
import 'package:flutter_svg/flutter_svg.dart';

Color _colorFromString(String s) {
  final hash = s.codeUnits.fold<int>(0, (h, c) => h * 31 + c);
  // Paleta AurisTV: Naranjas, Grises Pro y Azules Cine
  const colors = [
    Color(0xFFEF7A1E), // Brand Orange
    Color(0xFF2A2A2A), // Deep Grey
    Color(0xFF1E1E26), // Blue Tint Grey
    Color(0xFF3D1D0A), // Dark Orange
    Color(0xFF1976D2), // Cinema Blue
  ];
  return colors[hash.abs() % colors.length];
}

Widget _letterPlaceholder(String title) {
  final baseColor = _colorFromString(title);
  
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D0D),
      gradient: RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          baseColor.withOpacity(0.15),
          const Color(0xFF0D0D0D),
        ],
      ),
    ),
    child: Center(
      child: Opacity(
        opacity: 0.15, // Un poco más visible ahora que no hay letra
        child: SvgPicture.asset(
          'assets/icons/auris-tv-icon.svg',
          width: 80, // Tamaño más equilibrado como icono central
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    ),
  );
}

class FocusablePosterCard extends StatefulWidget {
  final String title;
  final String posterUrl;
  final VoidCallback onTap;
  final String? badge;
  final Widget? badgeOverlay;
  final String? subtitle;
  final Color? subtitleColor;
  final String? rating;
  final Color? badgeColor;
  final bool showInfo;
  final Color? activeBorderColor;
  final double aspectRatio;
  final Widget? airingOverlay; // Senior Fix: Slot para esquina superior izquierda
  /// Ancho de lo que precede al póster dentro de su elemento de fila (p. ej.
  /// el número gigante del Top10): el scroll lo ancla al INICIO del elemento
  /// para que el número y su tarjeta se vean siempre juntos.
  final double anchorInset;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;
  /// Tamaño de fuente del título. Si es null usa el valor por defecto.
  final double? titleFontSize;
  final bool isLarge;
  final double? width;

  const FocusablePosterCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.onTap,
    this.badge,
    this.badgeOverlay,
    this.subtitle,
    this.subtitleColor,
    this.rating,
    this.badgeColor,
    this.showInfo = true,
    this.activeBorderColor,
    this.aspectRatio = 2 / 3,
    this.airingOverlay,
    this.anchorInset = 0.0,
    this.focusNode,
    this.onKeyEvent,
    this.titleFontSize,
    this.isLarge = false,
    this.width,
  });

  @override
  State<FocusablePosterCard> createState() => _FocusablePosterCardState();
}

class _FocusablePosterCardState extends State<FocusablePosterCard> {
  bool _focused = false;
  bool _hovered = false;

  bool get _isActive => _focused || _hovered;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final double normalWidth = widget.width ??
        (widget.isLarge
            ? TVResponsiveUtils.largePosterWidth(context)
            : (isMobile ? ResponsiveUtils.sp(context, 125) : TVResponsiveUtils.posterWidth(context)));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          if (focused) {
            // Ancla en la ranura inicial del carrusel (misma posición que la
            // primera tarjeta de la fila); en rejillas verticales centra.
            // anchorInset respeta el prefijo del elemento (número Top10).
            TvScroll.ensureCardVisible(
              context,
              leadingInset: widget.anchorInset,
            );
          }
        },
        onKeyEvent: (node, event) {
          if (widget.onKeyEvent != null) {
            final res = widget.onKeyEvent!(node, event);
            if (res != KeyEventResult.ignored) return res;
          }
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter || 
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space) {
              SafeTap.run(widget.onTap);
              return KeyEventResult.handled;
            }
            // D-pad arriba con la fila de arriba vacía en esta columna: saltar
            // al primero de esa fila. Si hay algo alineado, no interviene.
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (TvDirectionalFocus.focusFirstAboveIfEmpty()) {
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => SafeTap.run(widget.onTap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: widget.aspectRatio,
                // Tratamiento Disney+ (clon del hub deportivo de Disney+):
                // scale 1.0 -> 1.03, anillo outline-4/offset-4 #FAFAFA fuera de
                // la tarjeta y sombra dual (≥768), todo 300ms cubic-bezier(0,0,.2,1).
                // Las filas usan Clip.none para que el crecimiento no se recorte.
                child: _NoScaleFocusShell(
                  active: _isActive,
                  activeShadow: DisneyFocusTokens.shadowFor(context),
                  ringColor: widget.activeBorderColor ?? DisneyFocusTokens.ringColor,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. EL PÓSTER (Base)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DisneyFocusTokens.radius),
                        clipBehavior: Clip.antiAlias,
                        child: Builder(
                          builder: (context) {
                            final dpr = MediaQuery.of(context).devicePixelRatio;
                            // Senior 1GB TV Box Tuning: Límite estricto de 360x540 en memoria RAM
                            // Evita agotar los ~250MB utilizables de Android y anula el LRU Thrashing
                            final targetWidth = (normalWidth * dpr).round().clamp(1, 360);
                            final targetHeight = (targetWidth * 1.5).round().clamp(1, 540);

                            return CachedNetworkImage(
                              imageUrl: ApiEndpoints.proxyImage(
                                widget.posterUrl,
                                policy: ImageSize.poster,
                              ),
                              fit: BoxFit.cover,
                              memCacheWidth: targetWidth,
                              memCacheHeight: targetHeight,
                              fadeInDuration: AurisImageConfig.defaultFadeInDuration,
                              fadeOutDuration: AurisImageConfig.defaultFadeOutDuration,
                              cacheManager: AurisImageCacheManager.instance,
                              filterQuality: FilterQuality.medium,
                              placeholder: (context, url) => _letterPlaceholder(widget.title),
                              errorWidget: (context, url, error) => _letterPlaceholder(widget.title),
                            );
                          }
                        ),
                      ),

                      // Degradado inferior para legibilidad de subtítulos/badges
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(DisneyFocusTokens.radius),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                                stops: const [0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. OVERLAYS (Clipeados individualmente o por el Stack)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DisneyFocusTokens.radius),
                        clipBehavior: Clip.antiAlias, // Senior Fix: Máxima calidad de recorte
                        child: Stack(
                          children: [
                            // TOP-LEFT: Airing
                            if (widget.airingOverlay != null)
                              Positioned(
                                top: -1, left: -1, // Senior Fix: Sangrado para evitar fugas en la curva
                                child: widget.airingOverlay!
                              ),

                            // TOP-RIGHT: Category
                            if (widget.badge != null)
                              Positioned(
                                top: -1, right: -1, // Senior Fix: Sangrado
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.badgeColor ?? const Color(0xFF1E1E26).withOpacity(0.9),
                                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                                    border: Border.all(color: Colors.white10, width: 0.5),
                                  ),
                                  child: Text(
                                    widget.badge!, 
                                    style: GoogleFonts.poppins(
                                      color: Colors.white, 
                                      fontSize: 10, 
                                      fontWeight: FontWeight.w800, 
                                      letterSpacing: 0.5
                                    )
                                  ),
                                ),
                              ),

                            // BOTTOM-RIGHT: Season
                            if (widget.badgeOverlay != null)
                              Positioned(bottom: -1, right: -1, child: widget.badgeOverlay!), // Senior Fix: Sangrado

                            // BOTTOM-LEFT: Episode/Status
                            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                              Positioned(
                                bottom: -1, left: -1, // Senior Fix: Sangrado
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.subtitleColor ?? const Color(0xFF1E1E26).withOpacity(0.95),
                                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                                    border: Border.all(color: Colors.white10, width: 0.5),
                                  ),
                                  child: Text(
                                    widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
              if (widget.showInfo) ...[
                SizedBox(height: isMobile ? ResponsiveUtils.sp(context, 8) : 8),
                // Senior Fix: Solo mostramos el título debajo. Altura fija para una sola línea.
                SizedBox(
                  height: isMobile ? ResponsiveUtils.sp(context, 22) : TVResponsiveUtils.grid(context, 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: MarqueeText(
                      text: widget.title,
                      animate: isMobile ? true : _isActive,
                      style: GoogleFonts.poppins(
                        color: _isActive ? Colors.white : Colors.white.withOpacity(0.95),
                        fontSize: widget.titleFontSize ?? (isMobile ? ResponsiveUtils.sp(context, 13) : TVResponsiveUtils.grid(context, 20)),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoScaleFocusShell extends StatelessWidget {
  final bool active;
  final Widget child;
  final double radius;
  final Color ringColor;
  final List<BoxShadow>? activeShadow;

  const _NoScaleFocusShell({
    required this.active,
    required this.child,
    this.radius = DisneyFocusTokens.radius,
    this.ringColor = DisneyFocusTokens.ringColor,
    this.activeShadow,
  });

  @override
  Widget build(BuildContext context) {
    const double customWidth = 1.5;
    const double customOffset = 1.5;
    const double customInset = customOffset + customWidth;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: DisneyFocusTokens.duration,
          curve: DisneyFocusTokens.curve,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: active ? (activeShadow ?? DisneyFocusTokens.shadowFor(context)) : null,
          ),
          child: child,
        ),
        Positioned(
          left: -customInset,
          top: -customInset,
          right: -customInset,
          bottom: -customInset,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: active ? 1.0 : 0.0,
              duration: DisneyFocusTokens.duration,
              curve: DisneyFocusTokens.curve,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ringColor,
                    width: customWidth,
                  ),
                  borderRadius: BorderRadius.circular(radius + customOffset + customWidth),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
