import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';
import '../../core/utils/responsive_utils.dart';

class _NoScaleFocusShell extends StatelessWidget {
  final bool active;
  final Widget child;
  final double radius;

  const _NoScaleFocusShell({
    required this.active,
    required this.child,
    this.radius = DisneyFocusTokens.radius,
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
            boxShadow: active ? DisneyFocusTokens.shadowFor(context) : null,
          ),
          child: child,
        ),
        if (active)
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
                      color: DisneyFocusTokens.ringColor,
                      width: customWidth,
                    ),
                    borderRadius: BorderRadius.circular(radius + DisneyFocusTokens.ringOffset + customWidth),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class FocusableExpandablePosterCard extends ConsumerStatefulWidget {
  final String title;
  final String posterUrl;
  final String? bannerUrl;
  final VoidCallback onTap;
  final String? badge;
  final Widget? badgeOverlay;
  final String? subtitle;
  final Color? subtitleColor;
  final String? rating;
  final Color? badgeColor;
  final Widget? airingOverlay;
  final bool showInfo;
  final double? progress;
  final MediaItem? mediaItem;
  final ContentSports? sportsEvent;
  final VoidCallback? onDelete;
  final FavoriteItem? favoriteItem;
  final double? baseWidth;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const FocusableExpandablePosterCard({
    super.key,
    required this.title,
    required this.posterUrl,
    this.bannerUrl,
    required this.onTap,
    this.badge,
    this.badgeOverlay,
    this.subtitle,
    this.subtitleColor,
    this.rating,
    this.badgeColor,
    this.airingOverlay,
    this.showInfo = false,
    this.progress,
    this.mediaItem,
    this.sportsEvent,
    this.onDelete,
    this.favoriteItem,
    this.baseWidth,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  ConsumerState<FocusableExpandablePosterCard> createState() => _FocusableExpandablePosterCardState();
}

class _FocusableExpandablePosterCardState extends ConsumerState<FocusableExpandablePosterCard> {
  bool _focused = false;
  final ValueNotifier<bool> _hovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context) {
    handleCardTapOrSportsNavigation(
      context,
      title: widget.title,
      imageUrl: widget.posterUrl,
      onTap: widget.onTap,
      source: widget.mediaItem?.source,
      channels: widget.mediaItem?.channels,
      subtitle: widget.subtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.useMobileLayout;
    final double baseW = widget.baseWidth ?? ResponsiveUtils.largePosterWidth(context);

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) { if (!isMobile && mounted) _hovered.value = true; },
      onExit: (_) { if (!isMobile && mounted) _hovered.value = false; },
      onHover: (_) { if (!isMobile && !_hovered.value && mounted) _hovered.value = true; },
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: widget.onKeyEvent ?? (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter || 
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space) {
              _handleTap(context);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        onFocusChange: (focused) {
          if (!mounted) return;
          if (focused) {
            context.findRenderObject()?.showOnScreen(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
          setState(() => _focused = focused);
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, hovered, _) {
            final isActive = _focused || hovered;
            
            final String rawBanner = (widget.bannerUrl != null && widget.bannerUrl!.isNotEmpty)
                ? widget.bannerUrl!
                : (widget.mediaItem?.bannerUrl ?? '');
            final String effectiveBanner = (rawBanner.isNotEmpty) ? rawBanner : widget.posterUrl;
            
            // STRICT: Unfocused MUST use posterUrl, Focused uses effectiveBanner (backdrop)
            final String displayImage = isActive ? effectiveBanner : widget.posterUrl;

            // Prime Video TV Expandable Effect:
            // Height is strictly constant in both states: baseW * 1.5
            // Unfocused: width = baseW (Aspect Ratio 2:3)
            // Focused: width = height * (16 / 9) (Aspect Ratio 16:9)
            final double constantHeight = (baseW * 1.5).roundToDouble();

            return GestureDetector(
              onTap: () => _handleTap(context),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 2 / 3, end: isActive ? (16 / 9) : (2 / 3)),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, currentAspectRatio, child) {
                  final currentWidth = (constantHeight * currentAspectRatio).roundToDouble();
                  return Container(
                    width: currentWidth,
                    height: constantHeight,
                    margin: EdgeInsets.only(right: isActive ? 16 : 0),
                    child: child,
                  );
                },
                child: _NoScaleFocusShell(
                  active: isActive,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DisneyFocusTokens.radius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CuredNetworkImage(
                          imageUrl: ApiEndpoints.proxyImage(
                            displayImage,
                            policy: isActive ? ImageSize.banner : ImageSize.poster,
                          ),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                        ),
                        // Gradient overlay when focused to make metadata readable (Prime Video style)
                        if (isActive)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        // Title / metadata overlay at bottom when focused
                        if (isActive)
                          Positioned(
                            bottom: 12, left: 12, right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.bannerTitleFontSize(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (widget.badge != null)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.badgeColor ?? const Color(0xFF1E1E26).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10, width: 0.5),
                              ),
                              child: Text(
                                widget.badge!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
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
          },
        ),
      ),
    );
  }
}
