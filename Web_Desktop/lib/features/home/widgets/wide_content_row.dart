import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';
import 'package:auris_core/auris_core.dart';

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
  final SectionSeeMore? verMas;
  final void Function(WideContentItem item) onItemTap;

  const WideContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.verMas,
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
    
    final bool canLeft = currentScroll > 5;
    final bool canRight = maxScroll > currentScroll + 5;
    
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
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

    final isMobile = context.isMobile;
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final cardWidth = ResponsiveUtils.bannerWidth(context);
    final cardHeight = ResponsiveUtils.bannerHeight(context);

    // Senior Fix: Detectar si alguna tarjeta tiene subtítulo para ajustar la altura de la fila y ganar espacio vertical.
    final bool hasSubtitles = widget.items.any((item) => item.subtitle != null && item.subtitle!.isNotEmpty);
    final rowHeight = ResponsiveUtils.bannerRowHeight(context, hasSubtitle: hasSubtitles);

    return Padding(
      padding: EdgeInsets.only(bottom: context.useMobileLayout ? 12 : 24), // Senior Fix: Ajustado para paridad con Poster
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: GestureDetector(
              onTap: widget.verMas == null ? null : () {
                final params = FilterParams.fromSeeMore(widget.verMas!);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SectionGridExplorer(
                      args: SectionExplorerArgs(
                        title: widget.title,
                        baseParams: params,
                        verMas: widget.verMas,
                        initialItems: widget.items.map((wi) => wi.originalItem as MediaItem).toList(),
                        onItemTap: (m) {
                          // Senior Fix: Evitamos 'No element' buscando de forma segura o reconstruyendo al vuelo
                          final match = widget.items.firstWhereOrNull((wi) => wi.id == m.id);
                          widget.onItemTap(match ?? WideContentItem(
                            id: m.id,
                            title: m.title,
                            imageUrl: m.bannerUrl ?? m.posterUrl,
                            originalItem: m,
                          ));
                        },
                      ),
                    ),
                  ),
                );
              },
              child: MouseRegion(
                cursor: widget.verMas != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveUtils.rowTitleFontSize(context),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (widget.verMas != null) ...[
                      const SizedBox(width: 24),
                      _SeeMoreButton(
                        title: widget.title,
                        verMas: widget.verMas!,
                        isMobile: isMobile,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Text(
                widget.subtitle!,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8), // Senior: Unificado a 8px
          MouseRegion(
            onEnter: (_) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }); },
            onExit: (_) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }); },
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final double fadeOffset = horizontalPadding / width;
                    final double fadeSize = 40 / width;

                    final content = ListView.separated(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      cacheExtent: 600,
                      clipBehavior: Clip.none, 
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 0), // Senior: Unificado a 0px vertical
                      itemCount: widget.items.length,
                      separatorBuilder: (_, __) => SizedBox(width: context.useMobileLayout ? 8 : 24),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return FocusableWideCard(
                          key: ValueKey('wide_${item.id}_${item.title}'),
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
                    );

                    if (!_canScrollLeft && !_canScrollRight) {
                      return SizedBox(
                        height: rowHeight,
                        child: content,
                      );
                    }

                    return SizedBox(
                      height: rowHeight,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _updateScrollIndicators();
                          return false;
                        },
                        child: content,
                      ),
                    );
                  }
                ),
                if (!isMobile) ...[
                  Positioned(
                    left: horizontalPadding - 25, 
                    top: 10, 
                    bottom: 105, // Senior Fix: Ajustado para centrar en 240px de imagen
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
                    bottom: 105, // Senior Fix: Ajustado para centrar en 240px de imagen
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

class _SeeMoreButton extends StatefulWidget {
  final String title;
  final SectionSeeMore verMas;
  final bool isMobile;

  const _SeeMoreButton({
    required this.title,
    required this.verMas,
    required this.isMobile,
  });

  @override
  State<_SeeMoreButton> createState() => _SeeMoreButtonState();
}

class _SeeMoreButtonState extends State<_SeeMoreButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowHoverHighlight: (show) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = show); }); },
      child: MouseRegion(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!widget.isMobile) ...[
              Text(
                'Ver más',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveUtils.rowTitleFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: _isHovered ? const Color(0xFFFF7A1E) : Colors.white,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Padding(
              padding: EdgeInsets.only(top: widget.isMobile ? 0.0 : 2.0),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: widget.isMobile ? 16 : 13,
                color: _isHovered ? const Color(0xFFFF7A1E) : (widget.isMobile ? Colors.white70 : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
