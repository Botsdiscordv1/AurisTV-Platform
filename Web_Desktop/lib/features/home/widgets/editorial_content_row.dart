import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';
import '../../../shared/widgets/prime_expandable_card.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../../shared/widgets/nav_arrow.dart';

class EditorialContentRow extends StatefulWidget {
  final String title;
  final List<MediaItem> items;
  final EditorialBadge badge;
  final void Function(MediaItem item) onItemTap;

  const EditorialContentRow({
    super.key,
    required this.title,
    required this.items,
    required this.badge,
    required this.onItemTap,
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

    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final width = MediaQuery.of(context).size.width;
    final isCompactDesktop = width >= 800 && width < 1100;
    
    final bool isMythical = widget.badge == EditorialBadge.mythical;

    if (isMythical) {
      return _buildMythicalTopRow(isMobile, horizontalPadding);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 32 : 48), // Padding unificado
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 20 : (isCompactDesktop ? 26 : 28),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildStandardRow(isMobile, horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildStandardRow(bool isMobile, double horizontalPadding) {
    return MouseRegion(
      onEnter: (_) { if (mounted) setState(() => _isHovered = true); },
      onExit: (_) { if (mounted) setState(() => _isHovered = false); },
      child: Stack(
        children: [
          SizedBox(
            height: isMobile ? ResponsiveUtils.sp(context, 250) : 355, // Senior: Reducido de 395 a 355 para Web
            child: _buildFadedWrapper(
              horizontalPadding: horizontalPadding,
              child: ListView.separated(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                cacheExtent: 600,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 5),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => SizedBox(width: isMobile ? 12 : 18),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return SizedBox(
                    width: isMobile ? ResponsiveUtils.sp(context, 140) : 200,
                    child: FocusablePosterCard(
                      key: ValueKey(item.id),
                      title: item.title,
                      posterUrl: item.posterUrl,
                      rating: formatRating(item.rating),
                      subtitle: item.subtitle,
                      onTap: () => widget.onItemTap(item),
                    ),
                  );
                },
              ),
            ),
          ),
          if (!isMobile) ..._buildArrows(horizontalPadding),
        ],
      ),
    );
  }

  Widget _buildMythicalTopRow(bool isMobile, double horizontalPadding) {
    // Senior Fix: Sincronizamos dimensiones con el resto de la app para evitar desbordes y unificar huecos
    final double posterHeight = isMobile ? ResponsiveUtils.sp(context, 210) : 310;
    final double titleAreaHeight = isMobile ? 40 : 40; // Senior: Reducido a 40 para alinear con posters estándar
    
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 32 : 48), // Gap unificado Senior
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 22 : 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.8,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 24),
          MouseRegion(
            onEnter: (_) { if (mounted) setState(() => _isHovered = true); },
            onExit: (_) { if (mounted) setState(() => _isHovered = false); },
            child: Stack(
              children: [
                SizedBox(
                  height: isMobile ? ResponsiveUtils.sp(context, 250) : 355, // Senior: Unificado con posters estándar (355px)
                  child: _buildFadedWrapper(
                    horizontalPadding: horizontalPadding,
                    child: ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      cacheExtent: 800,
                      clipBehavior: Clip.none, 
                      padding: EdgeInsets.fromLTRB(horizontalPadding, 5, horizontalPadding, 5),
                      itemCount: widget.items.length.clamp(0, 10),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return _MythicTopItem(
                          key: ValueKey('mythic_${item.id}'),
                          index: index,
                          item: item,
                          height: posterHeight,
                          textOffset: titleAreaHeight,
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

  // WRAPPER DE DIFUMINADO (Efecto Banner Home)
  Widget _buildFadedWrapper({required double horizontalPadding, required Widget child}) {
    if (!_canScrollLeft && !_canScrollRight) return child;
    
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _updateScrollIndicators();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          // El difuminado se aplica sobre el margen lateral
          final double fadeOffset = horizontalPadding / width;
          final double fadeSize = 50 / width; // Grosor del difuminado

          return ShaderMask(
            shaderCallback: (Rect rect) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  _canScrollLeft ? Colors.transparent : Colors.black,
                  Colors.black,
                  Colors.black,
                  _canScrollRight ? Colors.transparent : Colors.black,
                  Colors.transparent,
                ],
                stops: [
                  0.0,
                  fadeOffset,
                  (fadeOffset + fadeSize).clamp(0.0, 1.0),
                  (1.0 - fadeOffset - fadeSize).clamp(0.0, 1.0),
                  1.0 - fadeOffset,
                  1.0,
                ],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: child,
          );
        },
      ),
    );
  }

  List<Widget> _buildArrows(double horizontalPadding) {
    return [
      Positioned(
        left: horizontalPadding - 25,
        top: 0, bottom: 90, // Senior Fix: Centrado sobre el póster, ignorando el área de texto
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
        top: 0, bottom: 90, // Senior Fix: Centrado sobre el póster
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

class _MythicTopItem extends StatelessWidget {
  final int index;
  final MediaItem item;
  final double height;
  final double textOffset;
  final VoidCallback onTap;

  const _MythicTopItem({
    super.key,
    required this.index,
    required this.item,
    required this.height,
    required this.textOffset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobileDevice = ResponsiveUtils.isMobile(context);
    final int number = index + 1;
    final bool isDoubleDigit = number >= 10;
    final bool isNumberOne = number == 1;

    final double actualPosterHeight = height; 
    // El número mide el 90% para que el póster sea más alto
    final double dynamicNumberSize = isDoubleDigit ? actualPosterHeight * 0.8 : actualPosterHeight * 0.9;
    final double posterWidth = actualPosterHeight * 0.68;
    
    // NETFLIX PERFECT OVERLAP (Ajuste Fino al 22%)
    double numberVisiblePart;
    if (isNumberOne) {
      numberVisiblePart = posterWidth * 0.42; 
    } else if (isDoubleDigit) {
      // Senior Fix: Unificamos el solapamiento al 23% (factor 0.77) tanto en Web como en Móvil
      numberVisiblePart = posterWidth * 0.77; 
    } else {
      numberVisiblePart = posterWidth * 0.62; 
    }

    // Senior Fix: Letter spacing dinámico para evitar que los números se junten en pantallas pequeñas
    final double dynamicLetterSpacing = isDoubleDigit 
        ? (isMobileDevice ? -12.0 : -22.0) 
        : (isMobileDevice ? -8.0 : -15.0);

    return Container(
      width: numberVisiblePart + posterWidth,
      margin: const EdgeInsets.only(right: 24), // Más aire entre tarjetas
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. NÚMERO GIGANTE (Capa Inferior)
          Positioned(
            left: isDoubleDigit ? 4 : 0,
            // BASE ALINEADA AL PÓSTER
            bottom: textOffset + (isMobileDevice ? 5 : 0), 
            child: Stack(
              children: [
                // Borde gris vivo
                Text(
                  '$number',
                  style: TextStyle(
                    fontSize: dynamicNumberSize,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: dynamicLetterSpacing,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = height * 0.045
                      ..strokeJoin = StrokeJoin.round
                      ..strokeCap = StrokeCap.round
                      ..color = const Color(0xFF9E9E9E),
                  ),
                ),
                // Triple capa de relleno
                Stack(
                  children: [
                    Text(
                      '$number',
                      style: TextStyle(
                        fontSize: dynamicNumberSize,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: dynamicLetterSpacing,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = height * 0.02
                          ..strokeJoin = StrokeJoin.round
                          ..strokeCap = StrokeCap.round
                          ..color = const Color(0xFF050505),
                      ),
                    ),
                    Text(
                      '$number',
                      style: TextStyle(
                        fontSize: dynamicNumberSize,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: dynamicLetterSpacing,
                        color: const Color(0xFF050505),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 2. PÓSTER NORMAL (Foreground)
          Positioned(
            left: numberVisiblePart,
            top: 0,
            child: SizedBox(
              width: posterWidth,
              child: FocusablePosterCard(
                key: ValueKey(item.id),
                title: item.title,
                posterUrl: item.posterUrl,
                rating: formatRating(item.rating),
                subtitle: '', // Senior: Limpiamos subtítulo para que el número luzca más
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
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
