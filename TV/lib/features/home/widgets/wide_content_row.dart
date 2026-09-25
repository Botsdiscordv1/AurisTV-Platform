import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart' hide FocusableWideCard;
import '../../../core/utils/tv_responsive_utils.dart';
import '../../../shared/widgets/focusable_wide_card.dart';

class WideContentItem {
  final String id;
  final String title;
  final String imageUrl;
  final String? logoUrl; // Senior Fix: Soporte para logo en WideCard
  final String? subtitle;
  final String? rating;
  final double? progress;
  final Widget? badgeOverlay;
  final VoidCallback? onDelete;
  final dynamic originalItem;

  WideContentItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.logoUrl,
    this.subtitle,
    this.rating,
    this.progress,
    this.badgeOverlay,
    this.onDelete,
    this.originalItem,
  });
}

class WideContentRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<WideContentItem> items;
  final void Function(WideContentItem item) onItemTap;

  const WideContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.onItemTap,
  });

  @override
  State<WideContentRow> createState() => _WideContentRowState();
}

class _WideContentRowState extends State<WideContentRow> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
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
    setState(() {
      _canScrollLeft = currentScroll > 5;
      _canScrollRight = maxScroll > currentScroll + 5;
    });
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 800), curve: Curves.easeOutQuart);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.items.isEmpty) return const SizedBox.shrink();

    const isMobile = false;
    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    final cardWidth = TVResponsiveUtils.bannerWidth(context); 
    final cardHeight = TVResponsiveUtils.bannerHeight(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12), // Senior Fix: Reducido para TV
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeFocus(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: TVResponsiveUtils.rowTitleFontSize(context),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          widget.subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: TVResponsiveUtils.sp(context, 11),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      height: TVResponsiveUtils.bannerRowHeight(context) - 10, // Ajustado para TV
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _updateScrollIndicators();
                          return false;
                        },
                        child: Focus(
                          canRequestFocus: false,
                          child: ListView.separated(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            clipBehavior: Clip.none, 
                            scrollDirection: Axis.horizontal,
                            primary: false, 
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 5), 
                            itemCount: widget.items.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              
                              return FocusableWideCard(
                                title: item.title,
                                imageUrl: item.imageUrl,
                                logoUrl: item.logoUrl,
                                progress: item.progress,
                                subtitle: item.subtitle,
                                rating: item.rating,
                                badgeOverlay: item.badgeOverlay,
                                width: cardWidth,
                                height: cardHeight,
                                onTap: () => widget.onItemTap(item),
                                onDelete: item.onDelete,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }
                ),
                if (!isMobile) ...[
                  Positioned(
                    left: horizontalPadding - 25, 
                    top: 10, 
                    bottom: 80, // Ajustado para nuevo cardHeight (180px)
                    child: AnimatedOpacity(
                      opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !(_isHovered && _canScrollLeft), 
                        child: Center(
                          child: NavArrow(
                            icon: Icons.arrow_back_ios_new, 
                            useBackground: true, 
                            onTap: () => _scroll(-cardWidth * 2)
                          ),
                        )
                      ),
                    ),
                  ),
                  Positioned(
                    right: horizontalPadding - 25, 
                    top: 10, 
                    bottom: 80, // Ajustado para nuevo cardHeight
                    child: AnimatedOpacity(
                      opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !(_isHovered && _canScrollRight), 
                        child: Center(
                          child: NavArrow(
                            icon: Icons.arrow_forward_ios, 
                            useBackground: true, 
                            onTap: () => _scroll(cardWidth * 2)
                          ),
                        )
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
