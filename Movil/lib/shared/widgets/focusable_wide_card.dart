import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/responsive_utils.dart';
import 'marquee_text.dart';

class FocusableWideCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final double? progress;
  final String? subtitle;
  final String? rating;
  final Widget? badgeOverlay;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final double width;
  final double height;

  const FocusableWideCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.onDelete,
    this.progress,
    this.subtitle,
    this.rating,
    this.badgeOverlay,
    this.width = 440,
    this.height = 248,
  });

  @override
  State<FocusableWideCard> createState() => _FocusableWideCardState();
}

class _FocusableWideCardState extends State<FocusableWideCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get isSelected => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected ? [BoxShadow(color: Colors.white.withOpacity(0.15), blurRadius: 15, spreadRadius: 1)] : [],
                      border: Border.all(color: isSelected ? Colors.white : Colors.white12, width: isSelected ? 2.5 : 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            child: CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              placeholder: (context, url) => Container(color: Colors.white10),
                              errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(isSelected ? 0.7 : 0.5)],
                                    stops: const [0.6, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.onDelete != null && (isSelected || isMobile))
                            Positioned(
                              top: 8, left: 8,
                              child: Tooltip(
                                message: 'Eliminar de continuar viendo',
                                child: InkWell(
                                  onTap: widget.onDelete,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(isSelected ? 0.8 : 0.4),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(isSelected ? 0.4 : 0.1)),
                                    ),
                                    child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7), size: isMobile ? 14 : 16),
                                  ),
                                ),
                              ),
                            ),
                          if (widget.badgeOverlay != null) Positioned(top: 10, left: 10, child: widget.badgeOverlay!),
                          if (widget.rating != null)
                            Positioned(
                              top: 10, right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white10)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 12),
                                    const SizedBox(width: 4),
                                    Text(widget.rating!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ),
                          if (widget.progress != null && widget.progress! > 0)
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                height: 4, color: Colors.white24,
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: widget.progress!.clamp(0.0, 1.0),
                                  child: Container(decoration: const BoxDecoration(color: Color(0xFFEF7A1E), boxShadow: [BoxShadow(color: Color(0xFFEF7A1E), blurRadius: 4)])),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Senior Fix: Área de texto con altura fija para 2 líneas (Título + Subtítulo)
                // Esto permite que el banner mantenga su información extra sin romper la alineación inferior.
                SizedBox(
                  height: isMobile ? ResponsiveUtils.sp(context, 42) : 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: MarqueeText(
                          text: widget.title,
                          animate: isMobile ? true : isSelected,
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.95),
                            fontSize: isMobile ? ResponsiveUtils.sp(context, 14) : 17,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: isMobile ? ResponsiveUtils.sp(context, 13) : 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
