import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';
import '../../core/theme/editorial_themes.dart';
import 'editorial_animation_controller.dart';

const String _mythicCornerSvg = r'''
<svg width="74" height="74" viewBox="0 0 74 74" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M443.85.1h418.2c.95 0 2.07-.35 2.82.2.83.61.31 1.8.44 2.72 1.21 8.17 5.47 14.08 13 17.57 2.43 1.13 5.03 1.56 7.67 1.82 1.3.12 1.3.13 1.36 1.37.02.48 0 .96 0 1.44V381.8q-.02 1.77-1.71 1.94c-5.57.57-10.45 2.59-14.36 6.72-3.48 3.67-5.46 8-5.98 13.01-.16 1.48-.14 1.49-1.58 1.53-.48.01-.96 0-1.44 0-278.98 0-557.97 0-836.95-.01-.88 0-1.91.34-2.62-.25-.68-.56-.36-1.59-.5-2.39-1.18-6.95-4.78-12.21-10.85-15.77-3.01-1.77-6.34-2.53-9.78-2.84-1.45-.13-1.46-.11-1.5-1.6-.01-.48 0-.96 0-1.44 0-118.44 0-236.88.01-355.32 0-.88-.34-1.91.25-2.63.57-.7 1.59-.3 2.4-.41 4.19-.56 8.06-1.91 11.38-4.6 5.04-4.07 7.8-9.34 8.26-15.8.13-1.81.08-1.81 1.81-1.83h419.64Zm.02 402.85h417.3c2.03 0 2.03-.01 2.45-2 2.02-9.75 9.89-17.43 19.68-18.87 2.5-.37 2.2-.72 2.22-2.7V27.31c0-.48.01-.96 0-1.44-.05-1.44-.08-1.48-1.51-1.66-10.36-1.32-18.57-9.18-20.48-19.51-.49-2.64.15-2.51-3.02-2.51H27.17c-2.65 0-2.53-.41-3.06 2.51-1.83 10.05-9.51 17.65-19.56 19.41q-2.38.42-2.38 2.81V379c0 .48-.01.96 0 1.44.05 1.36.05 1.36 1.41 1.51 9.52 1.1 17.76 8.36 20.14 17.71.26 1.03.05 2.35.94 3.01.93.68 2.22.28 3.35.28 138.62.01 277.24.01 415.86.01Z" fill="white"/>
<path d="M3.31 9.25c0-1.68.02-3.36 0-5.03-.01-.82.31-1.21 1.16-1.21 3.48.02 6.95 0 10.43.01.81 0 1.04.42.87 1.17-1.37 6.13-5.46 10.08-11.24 11.25-.98.2-1.18.05-1.2-.98-.04-1.74-.01-3.48-.01-5.21ZM6.64 44.79V31.28c0-2.32.17-2.51 2.36-3.11 4.09-1.11 7.94-2.73 11.27-5.43 4.21-3.41 6.63-7.83 7.54-13.11.33-1.88.64-2.26 2.55-2.26 8.65-.01 17.3 0 25.95 0h.36c.61.04 1.35.04 1.31.86-.04.8-.79.76-1.39.79-.42.02-.84 0-1.26 0H41.27c-2.46 0-2.4.01-2.77 2.41-.94 6.03-3.48 11.34-7.56 15.86-4.93 5.47-11.2 8.76-18.14 10.91-.8.25-1.61.5-2.43.68-2.55.56-2.07.8-2.07 2.77-.02 5.59 0 11.17 0 16.76 0 .42 0 .84-.01 1.26-.02.49-.08 1.03-.73 1.04-.59 0-.8-.48-.86-.98-.06-.47-.05-.96-.05-1.44V44.78ZM33.42 9.03c-.78 0-1.56-.02-2.34 0-1.57.03-1.59.07-1.86 1.55-1.02 5.63-3.91 10.14-8.36 13.65-3.29 2.6-7.07 4.27-11.12 5.33-1.42.37-1.43.4-1.45 1.8-.02 1.5-.02 3 0 4.5.02 1.83.1 1.9 1.83 1.46 4.15-1.05 8.12-2.57 11.82-4.74 5.47-3.2 9.76-7.51 12.51-13.28 1.36-2.84 2.18-5.83 2.6-8.94.15-1.07-.02-1.27-1.11-1.32-.84-.04-1.68 0-2.52 0Z" fill="white"/>
</svg>
''';

class PrimeExpandableCard extends ConsumerStatefulWidget {
  final MediaItem media;
  final VoidCallback onTap;
  final EditorialBadge badge;

  const PrimeExpandableCard({
    super.key,
    required this.media,
    required this.onTap,
    required this.badge,
  });

  @override
  ConsumerState<PrimeExpandableCard> createState() => _PrimeExpandableCardState();
}

class _PrimeExpandableCardState extends ConsumerState<PrimeExpandableCard> {
  bool _isFocused = false;
  bool _isHovered = false;

  bool get _isActive => _isFocused || _isHovered;

  @override
  void initState() {
    super.initState();
    EditorialAnimationController.instance.acquire();
  }

  @override
  void dispose() {
    EditorialAnimationController.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorialBadgeTheme.getTheme(widget.badge);
    final bool isMobileDevice = ResponsiveUtils.isMobile(context);
    final double normalWidth = isMobileDevice ? ResponsiveUtils.sp(context, 140) : 200;

    return Focus(
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) {
          Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        }
      },
      child: MouseRegion(
        onEnter: (_) { if (mounted) setState(() => _isHovered = true); },
        onExit: (_) { if (mounted) setState(() => _isHovered = false); },
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: normalWidth,
            height: isMobileDevice ? ResponsiveUtils.sp(context, 280) : 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isActive ? [BoxShadow(color: const Color(0xFF6C32FF).withOpacity(0.3), blurRadius: 15, spreadRadius: 1)] : [],
                    ),
                    child: AnimatedBuilder(
                      animation: EditorialAnimationController.instance,
                      builder: (context, _) {
                        final mythicVal = EditorialAnimationController.instance.mythicValue;
                        return Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AnimatedScale(
                                    scale: _isActive ? 1.12 : 1.0,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                    child: CachedNetworkImage(
                                      imageUrl: widget.media.posterUrl,
                                      fit: BoxFit.cover,
                                      memCacheWidth: (normalWidth * MediaQuery.of(context).devicePixelRatio).round().clamp(1, 2048),
                                      filterQuality: FilterQuality.low,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                          stops: const [0.0, 0.4],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.media.rating != null)
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
                                            Text(formatRating(widget.media.rating) ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Positioned.fill(child: _MythicBorder(value: mythicVal, primaryColor: theme.primary)),
                            _MythicCorner(alignment: Alignment.topLeft, value: mythicVal, primaryColor: theme.primary),
                            _MythicCorner(alignment: Alignment.topRight, value: mythicVal, primaryColor: theme.primary),
                            _MythicCorner(alignment: Alignment.bottomLeft, value: mythicVal, primaryColor: theme.primary),
                            _MythicCorner(alignment: Alignment.bottomRight, value: mythicVal, primaryColor: theme.primary),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.only(top: 12, left: 4),
                  width: normalWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarqueeText(
                        text: widget.media.title,
                        animate: isMobileDevice ? true : _isActive,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95), 
                            fontSize: isMobileDevice ? ResponsiveUtils.sp(context, 13) : 16, 
                            fontWeight: FontWeight.w700, 
                            height: 1.2, 
                            letterSpacing: 0.2
                          ),
                      ),
                      const SizedBox(height: 6),
                      DefaultTextStyle(
                        style: TextStyle(
                          color: Colors.white54, 
                          fontSize: isMobileDevice ? ResponsiveUtils.sp(context, 13) : 15, 
                          fontWeight: FontWeight.w600
                        ),
                        child: Row(
                          children: [
                            if (widget.media.year != null && (widget.media.subtitle == null || !widget.media.subtitle!.contains(widget.media.year.toString()))) ...[
                              Text('${widget.media.year}'),
                              _buildMetaDot(),
                            ],
                            Expanded(child: Text(widget.media.subtitle ?? (widget.media.aired ? 'Finalizado' : 'En emisión'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
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

  Widget _buildMetaDot() {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 6), width: 3, height: 3, decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle));
  }
}

class _MythicCorner extends StatelessWidget {
  final Alignment alignment; final double value; final Color primaryColor;
  const _MythicCorner({required this.alignment, required this.value, required this.primaryColor});
  @override Widget build(BuildContext context) {
    int quarterTurns = 0;
    if (alignment == Alignment.topRight) quarterTurns = 1;
    else if (alignment == Alignment.bottomRight) quarterTurns = 2;
    else if (alignment == Alignment.bottomLeft) quarterTurns = 3;
    return Align(
      alignment: alignment,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: SizedBox(
          width: 48, height: 48,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: const [Color(0xFF6C32FF), Color(0xFF00FFC3), Color(0xFF6C32FF), Color(0xFF00FFC3), Color(0xFF6C32FF)],
                stops: [0.0, (value - 0.2).clamp(0.0, 1.0), value, (value + 0.2).clamp(0.0, 1.0), 1.0],
              ).createShader(bounds);
            },
            child: SvgPicture.string(_mythicCornerSvg, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          ),
        ),
      ),
    );
  }
}

class _MythicBorder extends StatelessWidget {
  final double value; final Color primaryColor;
  const _MythicBorder({required this.value, required this.primaryColor});
  @override Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: const [Color(0xFF6C32FF), Color(0xFF00FFC3), Color(0xFF6C32FF), Color(0xFF00FFC3), Color(0xFF6C32FF)],
          stops: [0.0, (value - 0.2).clamp(0.0, 1.0), value, (value + 0.2).clamp(0.0, 1.0), 1.0],
        ).createShader(bounds);
      },
      child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2.5))),
    );
  }
}
