import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart' hide FocusablePosterCard;
import '../../../core/utils/tv_responsive_utils.dart';
import '../../../shared/widgets/prime_expandable_card.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../../shared/widgets/top_item.dart';

class EditorialContentRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final EditorialBadge badge;
  final bool forceTopDesign;
  final void Function(MediaItem item) onItemTap;

  const EditorialContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.badge,
    required this.onItemTap,
    this.forceTopDesign = false,
  });

  @override
  State<EditorialContentRow> createState() => _EditorialContentRowState();
}

class _EditorialContentRowState extends State<EditorialContentRow> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
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
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isMobile = false;
    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    
    final double cardWidth = TVResponsiveUtils.posterWidth(context);
    final double rowHeight = TVResponsiveUtils.rowHeight(context, hasInfo: false);

    final bool isMythical = widget.badge == EditorialBadge.mythical || widget.forceTopDesign;

    if (isMythical) {
      return _buildMythicalTopRow(isMobile, horizontalPadding);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12), // Senior Fix: Reducido drásticamente para TV
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeFocus(
            child: Padding(
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
          ),
          const SizedBox(height: 6),
          _buildStandardRow(isMobile, horizontalPadding, cardWidth, rowHeight),
        ],
      ),
    );
  }

  Widget _buildStandardRow(bool isMobile, double horizontalPadding, double cardWidth, double rowHeight) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          SizedBox(
            height: rowHeight, // Usamos la altura calculada dinámicamente
            child: _buildFadedWrapper(
              horizontalPadding: horizontalPadding,
              child: Focus(
                canRequestFocus: false,
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  primary: false, 
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 5),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => SizedBox(width: isMobile ? 12 : 16),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return SizedBox(
                      width: cardWidth,
                      child: FocusablePosterCard(
                        key: ValueKey(item.id),
                        title: item.title,
                        posterUrl: item.posterUrl,
                        rating: formatRating(item.rating),
                        subtitle: null, // Senior Fix: Ocultar año en editorial
                        showInfo: false,
                        onTap: () => widget.onItemTap(item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (!isMobile) ..._buildArrows(horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildMythicalTopRow(bool isMobile, double horizontalPadding) {
    // Senior Fix: Sincronizamos con TV Utils
    final double posterHeight = TVResponsiveUtils.posterHeight(context);
    final double rowHeight = TVResponsiveUtils.rowHeight(context, hasInfo: false);
    final double titleAreaHeight = 0; // Senior Fix: Eliminado offset ya que no hay títulos debajo
    
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16), // Senior Fix: Sincronizado
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeFocus(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 20 : 24, // Reducido de 30
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.8,
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
          ),
          const SizedBox(height: 8),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              children: [
                SizedBox(
                  height: rowHeight, // Unificado con posters estándar
                  child: _buildFadedWrapper(
                    horizontalPadding: horizontalPadding,
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      primary: false, // Senior Fix: Evita que el ScrollView intente capturar el foco
                      clipBehavior: Clip.none, 
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 0), // Senior: Zero padding
                      itemCount: widget.items.length.clamp(0, 10),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return TopItem(
                          index: index,
                          item: item,
                          height: posterHeight,
                          textOffset: 0,
                          onTap: () => widget.onItemTap(item),
                        );
                      },
                    ),
                  ),
                ),
                if (!isMobile) ..._buildArrows(horizontalPadding),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WRAPPER DE DIFUMINADO (Eliminado según requerimiento)
  Widget _buildFadedWrapper({required double horizontalPadding, required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _updateScrollIndicators();
        return false;
      },
      child: child,
    );
  }

  List<Widget> _buildArrows(double horizontalPadding) {
    return [
      Positioned(
        left: horizontalPadding - 25,
        top: 0, bottom: 60, // Ajustado para nuevo posterHeight
        child: AnimatedOpacity(
          opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !(_isHovered && _canScrollLeft),
            child: Center(
              child: NavArrow(
                icon: Icons.arrow_back_ios_new,
                useBackground: true,
                onTap: () => _scroll(-800),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: horizontalPadding - 25,
        top: 0, bottom: 60, // Ajustado para nuevo posterHeight
        child: AnimatedOpacity(
          opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !(_isHovered && _canScrollRight),
            child: Center(
              child: NavArrow(
                icon: Icons.arrow_forward_ios,
                useBackground: true,
                onTap: () => _scroll(800),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

extension on MediaItem {
  MediaItem copyWith({String? title, String? subtitle, int? year}) {
    return MediaItem(
      id: id,
      title: title ?? this.title,
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
      subtitle: subtitle ?? this.subtitle,
      rating: rating,
      year: year,
      synopsis: synopsis,
      aired: aired,
      airingAt: airingAt,
      romaji: romaji,
      english: english,
      type: type,
      source: source,
      episode: episode,
      episodes: episodes,
      editorialBadge: editorialBadge,
      trailerKey: trailerKey,
    );
  }
}
