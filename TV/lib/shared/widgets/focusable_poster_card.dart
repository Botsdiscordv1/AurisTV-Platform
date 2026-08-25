import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final bool showInfo;
  final Color? activeBorderColor;
  final double aspectRatio;

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
    final double normalWidth = isMobile ? ResponsiveUtils.sp(context, 125) : 200;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
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
        child: GestureDetector(
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. EL POSTER (Contenido Base)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isActive
                            ? [BoxShadow(color: (widget.activeBorderColor ?? Colors.white).withOpacity(0.12), blurRadius: 12, spreadRadius: 1)]
                            : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isMobile ? 10 : 8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AnimatedScale(
                              scale: _isActive ? 1.12 : 1.0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              child: CachedNetworkImage(
                                imageUrl: widget.posterUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: (normalWidth * MediaQuery.of(context).devicePixelRatio).round().clamp(1, 2048),
                                filterQuality: FilterQuality.medium,
                                placeholder: (context, url) => _letterPlaceholder(widget.title),
                                errorWidget: (context, url, error) => _letterPlaceholder(widget.title),
                              ),
                            ),
                            // Degradado inferior para legibilidad de subtítulos/badges
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                                    stops: const [0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 2. EL BORDE (Capa Superior para evitar Shifting)
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isActive ? (widget.activeBorderColor ?? Colors.white) : Colors.white12, 
                            width: _isActive ? 2.0 : 1.0, // Idéntico a Home
                          ),
                        ),
                      ),
                    ),

                    // 3. OVERLAYS (Badges, Ratings, etc)
                    if (widget.badgeOverlay != null)
                      Positioned(top: 8, left: 8, child: widget.badgeOverlay!)
                    else if (widget.badge != null)
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.badgeColor ?? Colors.black.withOpacity(0.8),
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), topRight: Radius.circular(11)),
                            border: Border.all(color: Colors.white12, width: 0.5),
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
                    if (widget.rating != null && widget.badge == null)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8), 
                            borderRadius: BorderRadius.circular(4), 
                            border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3), width: 0.8)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Color(0xFFFFC107), size: 10),
                              const SizedBox(width: 4),
                              Text(widget.rating!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                      Positioned(
                        bottom: 0, left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.subtitleColor ?? Colors.black.withOpacity(0.85),
                            borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomLeft: Radius.circular(11)),
                            border: Border.all(color: Colors.white12, width: 0.5),
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
                        fontSize: isMobile ? ResponsiveUtils.sp(context, 13) : 16,
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
