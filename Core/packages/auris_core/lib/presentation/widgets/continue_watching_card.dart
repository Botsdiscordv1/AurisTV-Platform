import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auris_core.dart';

/// Widget reutilizable para "Continuar Viendo", basado en el diseño oficial de AurisTV.
class ContinueWatchingCard extends StatefulWidget {
  final PlaybackHistory history;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double? width;
  final double? height;

  const ContinueWatchingCard({
    super.key,
    required this.history,
    this.onTap,
    this.onDelete,
    this.width,
    this.height,
  });

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFEF7A1E);
    const textPrimary = Color(0xFFF5F5F5);
    const progressTrack = Color(0xFF39393D);

    final double effectiveWidth = widget.width ?? ResponsiveUtils.bannerWidth(context);
    final String? imageUrl = widget.history.bannerUrl ?? widget.history.posterUrl;
    final String? logoUrl = widget.history.logoUrl;
    final remainingMs = widget.history.durationInMilliseconds - widget.history.positionInMilliseconds;

    final String titleText = isMovieLike(widget.history.category, widget.history.title, widget.history.durationInMilliseconds)
        ? (widget.history.title ?? '').replaceAll(RegExp(r'^[Ee]p\s*\d+\s*[.\-•]\s*'), '').trim()
        : '${widget.history.episode != null ? 'Ep ${widget.history.episode} • ' : ''}${widget.history.title ?? ''}';

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap != null ? () => SafeTap.run(widget.onTap!) : null,
          child: Container(
            width: effectiveWidth,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedScale(
                    scale: _isActive ? 1.06 : 1.0,
                    duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuint,
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuint,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _isActive ? [BoxShadow(color: Colors.white.withOpacity(0.12), blurRadius: 40, spreadRadius: 0)] : [],
                        border: Border.all(color: _isActive ? Colors.white : Colors.transparent, width: _isActive ? 2.5 : 0.0),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (imageUrl != null)
                              CachedNetworkImage(
                                imageUrl: ApiEndpoints.proxyImage(
                                  imageUrl,
                                  width: (widget.history.category == 'movie' || widget.history.category == 'movie_anime') ? 1280 : 800,
                                ),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white10),
                                errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                              )
                            else
                              const Center(child: Icon(Icons.movie, color: Colors.white24)),

                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(_isActive ? 0.7 : 0.5)],
                                      stops: const [0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            if (logoUrl != null && logoUrl.isNotEmpty)
                              Positioned(
                                bottom: 16,
                                left: 12,
                                child: Container(
                                  height: (effectiveWidth / 1.77) * 0.35,
                                  width: effectiveWidth * 0.65,
                                  alignment: Alignment.bottomLeft,
                                  child: CachedNetworkImage(
                                    imageUrl: ApiEndpoints.proxyImage(logoUrl),
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              )
                            else
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Text(
                                  titleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: ResponsiveUtils.bannerTitleFontSize(context),
                                    fontWeight: FontWeight.w700,
                                    shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2))],
                                  ),
                                ),
                              ),

                            if (widget.onDelete != null)
                              Positioned(
                                top: 8, left: 8,
                                child: GestureDetector(
                                  onTap: widget.onDelete,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                                  ),
                                ),
                              ),

                            if (widget.history.progress > 0)
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  height: 4,
                                  color: progressTrack,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: widget.history.progress.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: brandOrange,
                                        boxShadow: [BoxShadow(color: brandOrange, blurRadius: 4)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (remainingMs > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: ResponsiveUtils.sp(context, 20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Quedan ${AurisStringUtils.formatRemainingTime(remainingMs)}',
                          style: TextStyle(
                            color: textPrimary.withOpacity(0.6),
                            fontSize: ResponsiveUtils.bannerTitleFontSize(context) - 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
