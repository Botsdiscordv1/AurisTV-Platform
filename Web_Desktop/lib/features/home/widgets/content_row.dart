import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';

class ContentRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final SectionSeeMore? verMas;
  final double horizontalPadding;
  final void Function(MediaItem item) onItemTap;

  const ContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.verMas,
    required this.onItemTap,
    this.horizontalPadding = 48.0,
  });

  @override
  State<ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends State<ContentRow> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Mantiene la fila viva en memoria para scroll fluido
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    // Verificación inicial después del primer frame para activar la flecha derecha si hay contenido
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void didUpdateWidget(covariant ContentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalcular indicadores si la lista de ítems cambia (ej: tras carga de API)
    if (widget.items.length != oldWidget.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    final canLeft = currentScroll > 5;
    final canRight = maxScroll > currentScroll + 5;
    
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final target = (currentOffset + offset).clamp(0.0, maxScroll);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.of(context).size.width;
    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final isCompactDesktop = width >= 800 && width < 1100;
    
    final double posterHeight = ResponsiveUtils.posterHeight(context);
    final double cardWidth = ResponsiveUtils.posterWidth(context);
    final double rowHeight = ResponsiveUtils.rowHeight(context, hasInfo: false); // Senior Fix: showInfo is false in Home

    return Padding(
      padding: EdgeInsets.only(bottom: context.useMobileLayout ? 12 : 24), // Senior Fix: Ajustado para paridad con Wide
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
                        initialItems: widget.items,
                        onItemTap: widget.onItemTap,
                      ),
                    ),
                  ),
                );
              },
              child: MouseRegion(
                cursor: widget.verMas != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center, // Centrado vertical para alineación directa con el texto
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
                      SizedBox(width: isMobile ? 8 : 24), // Separación reducida en móvil para el chevron compacto
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
          const SizedBox(height: 8),
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
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 0), // Senior: Zero padding
                      itemCount: widget.items.length,
                      separatorBuilder: (_, __) => SizedBox(width: context.useMobileLayout ? 8 : 24),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return Focus(
                          onFocusChange: (focused) {
                            if (focused) {
                              Scrollable.ensureVisible(
                                context,
                                alignment: 0.5,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: SizedBox(
                            width: cardWidth,
                            child: FocusablePosterCard(
                              key: ValueKey(item.id),
                              title: item.title,
                              posterUrl: item.posterUrl,
                              rating: (item.episode == null || item.episode == 0) ? formatRating(item.rating) : null,
                              subtitle: (item.episode != null && item.episode! > 0) ? 'Episodio ${item.episode}' : null, // Senior: Ocultar año
                              showInfo: false,
                              onTap: () => widget.onItemTap(item),
                            ),
                          ),
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
                
                // Flecha Izquierda
                if (!isMobile)
                  Positioned(
                    left: horizontalPadding - 25, 
                    top: 10,
                    bottom: 90,
                    child: AnimatedOpacity(
                      opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !(_isHovered && _canScrollLeft),
                        child: Center(
                          child: NavArrow(
                            icon: Icons.arrow_back_ios_new,
                            useBackground: true,
                            enableScale: false,
                            onTap: () => _scroll(-600),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Flecha Derecha
                if (!isMobile)
                  Positioned(
                    right: horizontalPadding - 25,
                    top: 10,
                    bottom: 90,
                    child: AnimatedOpacity(
                      opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !(_isHovered && _canScrollRight),
                        child: Center(
                          child: NavArrow(
                            icon: Icons.arrow_forward_ios,
                            useBackground: true,
                            enableScale: false,
                            onTap: () => _scroll(600),
                          ),
                        ),
                      ),
                    ),
                  ),
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
              padding: EdgeInsets.only(top: widget.isMobile ? 0.0 : 2.0), // Ajuste óptico fino adaptativo
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: widget.isMobile ? 16 : 13, // Un poco más grande en móvil táctil para hit-target
                color: _isHovered ? const Color(0xFFFF7A1E) : (widget.isMobile ? Colors.white70 : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

