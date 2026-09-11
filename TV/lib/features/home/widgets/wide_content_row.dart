import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../shared/widgets/focusable_wide_card.dart';
import '../../../shared/widgets/nav_arrow.dart';

class WideContentItem {
  final String id;
  final String title;
  final String imageUrl;
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
  final List<WideContentItem> items;
  final void Function(WideContentItem item) onItemTap;

  const WideContentRow({
    super.key,
    required this.title,
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

    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final cardWidth = isMobile ? ResponsiveUtils.sp(context, 280.0) : 320.0; // Reducido de 420 (sp ya escala)
    final cardHeight = isMobile ? ResponsiveUtils.sp(context, 160.0) : 180.0; // Reducido de 240

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 12 : 16), // Senior Fix: Reducido para TV
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeFocus(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: isMobile ? 18 : 20, // Reducido de 26
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    final double fadeOffset = horizontalPadding / width;
                    final double fadeSize = 40 / width;

                    return SizedBox(
                      height: isMobile ? ResponsiveUtils.sp(context, 225) : 260, // Reducido de 355
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _updateScrollIndicators();
                          return false;
                        },
                        child: ShaderMask(
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
                          child: ListView.separated(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            clipBehavior: Clip.none, 
                            scrollDirection: Axis.horizontal,
                            primary: false, // Senior Fix: Evita que el ScrollView intente capturar el foco
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 5), // Senior: Ajuste de padding vertical
                            itemCount: widget.items.length,
                            separatorBuilder: (_, __) => SizedBox(width: isMobile ? 12 : 18),
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              
                              return FocusableWideCard(
                                title: item.title,
                                imageUrl: item.imageUrl,
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
