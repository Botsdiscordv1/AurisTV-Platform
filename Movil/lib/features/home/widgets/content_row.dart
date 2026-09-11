import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';
import '../../../shared/widgets/focusable_poster_card.dart';

class ContentRow extends StatefulWidget {
  final String title;
  final List<MediaItem> items;
  final double horizontalPadding;
  final void Function(MediaItem item) onItemTap;

  const ContentRow({
    super.key,
    required this.title,
    required this.items,
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
    final double rowHeight = ResponsiveUtils.rowHeight(context, hasInfo: true);

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 24), // Senior Fix: Reducido de 32/48 para compactar secciones
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveUtils.rowTitleFontSize(context),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 8), 
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final double fadeOffset = horizontalPadding / width;
                    final double fadeSize = 40 / width; // 40px de suavizado

                    return SizedBox(
                      height: rowHeight,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _updateScrollIndicators();
                          return false;
                        },
                        child: ListView.separated(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          cacheExtent: 1000,
                          clipBehavior: Clip.none,
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 0), // Senior: Zero padding
                          itemCount: widget.items.length,
                          separatorBuilder: (_, __) => SizedBox(width: isMobile ? 12 : 18),
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
                                  subtitle: (item.episode != null && item.episode! > 0) ? 'Episodio ${item.episode}' : null, // Senior: Ocultar año pero mantener episodios
                                  showInfo: false,
                                  onTap: () => widget.onItemTap(item),
                                ),
                              ),
                            );
                          },
                        ),
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
