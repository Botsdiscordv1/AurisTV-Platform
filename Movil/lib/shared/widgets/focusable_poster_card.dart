import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';
import 'marquee_text.dart';
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
  final Widget? airingOverlay; // Senior Fix: Slot para esquina superior izquierda
  final bool showInfo;
  final double? progress; // Senior Fix: Soporte para barra de progreso en póster

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
    this.airingOverlay,
    this.showInfo = true,
    this.progress,
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
    final isMobile = context.useMobileLayout;
    final double normalWidth = ResponsiveUtils.posterWidth(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter || 
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space) {
              SafeTap.run(widget.onTap);
              return KeyEventResult.handled;
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
                aspectRatio: 2 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isActive
                        ? [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 15, spreadRadius: 1)]
                        : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. EL PÓSTER (Base)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: AnimatedScale(
                          scale: _isActive ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          child: Builder(
                            builder: (context) {
                              final dpr = MediaQuery.of(context).devicePixelRatio;
                              final targetWidth = (normalWidth * dpr).round();
                              final targetHeight = (targetWidth * 1.5).round();
                              
                              return CachedNetworkImage(
                                imageUrl: ApiEndpoints.proxyImage(
                                  widget.posterUrl,
                                  policy: ImageSize.poster,
                                ),
                                fit: BoxFit.cover,
                                memCacheWidth: targetWidth.clamp(1, 2048),
                                filterQuality: FilterQuality.medium,
                                placeholder: (context, url) => _letterPlaceholder(widget.title),
                                errorWidget: (context, url, error) => _letterPlaceholder(widget.title),
                              );
                            }
                          ),
                        ),
                      ),

                      // 2. OVERLAYS (Clipeados individualmente o por el Stack)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAliasWithSaveLayer, // Senior Fix: Máxima calidad de recorte
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
                              Positioned(
                                bottom: (widget.progress != null && widget.progress! > 0) ? 4 : 0,
                                right: 0,
                                child: widget.badgeOverlay!
                              ),

                            // BOTTOM-LEFT: Episode/Status
                            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                              Positioned(
                                bottom: (widget.progress != null && widget.progress! > 0) ? 4 : 0,
                                left: 0,
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

                            // PROGRESS BAR
                            if (widget.progress != null && widget.progress! > 0)
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  height: 4,
                                  color: Colors.black45,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: widget.progress!.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF7A1E),
                                        boxShadow: [BoxShadow(color: Color(0xFFEF7A1E), blurRadius: 4)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // 3. EL BORDE (Capa Superior para sellar imperfecciones)
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isActive ? Colors.white : Colors.white12,
                              width: _isActive ? 3.0 : 1.0,
                            ),
                          ),
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
                  height: isMobile ? ResponsiveUtils.sp(context, 22) : 28,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: MarqueeText(
                      text: widget.title,
                      animate: isMobile ? true : _isActive,
                      style: GoogleFonts.poppins(
                        color: _isActive ? Colors.white : Colors.white.withOpacity(0.95),
                        fontSize: ResponsiveUtils.posterTitleFontSize(context),
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
