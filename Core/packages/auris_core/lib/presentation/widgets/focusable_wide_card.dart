import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

/// Widget de tarjeta panorámica (16:9) enfocado en la experiencia de usuario premium.
/// Soporta estados de foco, hover, escala animada, logos de contenido y barra de progreso.
class FocusableWideCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String? logoUrl;
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
    this.logoUrl,
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
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);
  bool _isFocused = false;

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.useMobileLayout;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) { _isHovered.value = true; },
        onExit: (_) { _isHovered.value = false; },
        child: ValueListenableBuilder<bool>(
          valueListenable: _isHovered,
          builder: (context, hovered, _) {
            final isSelected = hovered || _isFocused;
            return GestureDetector(
              onTap: () => SafeTap.run(widget.onTap),
              child: SizedBox(
                width: widget.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AnimatedScale(
                        scale: isSelected ? 1.06 : 1.0,
                        duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuint,
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                          curve: Curves.easeOutQuint,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.white.withOpacity(0.12), blurRadius: 40, spreadRadius: 0)] : [],
                            border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: isSelected ? 2.5 : 0.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: widget.imageUrl,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                  placeholder: (context, url) => Container(color: Colors.white10),
                                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
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
                                if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
                                  Positioned(
                                    bottom: 16, left: 12,
                                    child: Container(
                                      height: widget.height * 0.35,
                                      width: widget.width * 0.65,
                                      alignment: Alignment.bottomLeft,
                                      child: CachedNetworkImage(
                                        imageUrl: widget.logoUrl!,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.medium,
                                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    bottom: 12, left: 12, right: 12,
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: ResponsiveUtils.bannerTitleFontSize(context),
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 2)),
                                        ],
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
                    ),
                    if (widget.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: ResponsiveUtils.sp(context, 20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: ResponsiveUtils.bannerTitleFontSize(context) - 2.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
