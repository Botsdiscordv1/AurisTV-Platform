import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/responsive_utils.dart';
import 'marquee_text.dart';

Color _colorFromString(String s) {
  final hash = s.codeUnits.fold<int>(0, (h, c) => h * 31 + c);
  const colors = [
    Color(0xFFE57373), Color(0xFFF06292), Color(0xFFBA68C8),
    Color(0xFF64B5F6), Color(0xFF4FC3F7), Color(0xFF4DD0E1),
    Color(0xFF81C784), Color(0xFFAED581), Color(0xFFFFD54F),
    Color(0xFFFF8A65), Color(0xFFA1887F), Color(0xFF90A4AE),
  ];
  return colors[hash.abs() % colors.length];
}

Widget _letterPlaceholder(String title) {
  final letter = title.isNotEmpty ? title[0].toUpperCase() : '?';
  final color = _colorFromString(title);
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withOpacity(0.6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(
        letter,
        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
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
  final String? rating;
  final bool showInfo;

  const FocusablePosterCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.onTap,
    this.badge,
    this.badgeOverlay,
    this.subtitle,
    this.rating,
    this.showInfo = true,
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
                aspectRatio: 2 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: _isActive
                        ? Border.all(color: Colors.white, width: 1.5)
                        : Border.all(color: Colors.white12, width: 1),
                    boxShadow: _isActive
                        ? [BoxShadow(color: Colors.white.withOpacity(0.12), blurRadius: 10, spreadRadius: 0)]
                        : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.5), // Ajustado para encajar con el borde externo
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
                        if (widget.badgeOverlay != null)
                          Positioned(top: 8, left: 8, child: widget.badgeOverlay!)
                        else if (widget.badge != null)
                          Positioned(
                            top: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFFC107), width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.window_rounded, color: Color(0xFFFFC107), size: 10),
                                  const SizedBox(width: 4),
                                  Text(widget.badge!, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        if (widget.rating != null)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
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
                        // Senior Fix: Integrar Subtítulo como Badge en la parte inferior del póster
                        if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                          Positioned(
                            bottom: 8, left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white10, width: 0.5),
                              ),
                              child: Text(
                                widget.subtitle!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
