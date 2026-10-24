import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart' hide FocusableWideCard;
import '../../../core/utils/tv_responsive_utils.dart';
import '../../../shared/widgets/focusable_wide_card.dart';
import '../../../shared/widgets/tv_scroll.dart';

class WideContentItem {
  final String id;
  final String title;
  final String imageUrl;
  final String? logoUrl; // Senior Fix: Soporte para logo en WideCard
  final String? subtitle;
  /// Segunda línea opcional bajo el subtítulo (ej. "Quedan: X").
  final String? subtitle2;
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
    this.subtitle2,
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
  final bool? hasSubtitle;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  /// D-pad abajo sobre cualquier wide card: enfoca la última tarjeta que tuvo
  /// foco en la sección siguiente (memoria); si nunca tuvo, la primera.
  final bool Function()? onArrowDownToNext;
  /// D-pad arriba sobre cualquier wide card: igual que [onArrowDownToNext]
  /// pero hacia la sección anterior.
  final bool Function()? onArrowUpToPrev;

  const WideContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.onItemTap,
    this.hasSubtitle,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
  });

  @override
  State<WideContentRow> createState() => _WideContentRowState();
}

class _WideContentRowState extends State<WideContentRow>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  int? _focusedIndex;
  // Memoria independiente de `_focusedIndex` (que se limpia al salir de la
  // fila): permite volver a la misma tarjeta al regresar a la sección.
  int? _lastFocusedIndex;
  late List<FocusNode> _itemFocusNodes;

  @override
  void initState() {
    super.initState();
    _initFocusNodes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  void _initFocusNodes() {
    _lastFocusedIndex = null;
    _itemFocusNodes = List.generate(widget.items.length, (index) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) _lastFocusedIndex = index;
      });
      return node;
    });
  }

  @override
  void didUpdateWidget(covariant WideContentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      for (final node in _itemFocusNodes) {
        node.dispose();
      }
      _initFocusNodes();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  bool focusFirstCard() {
    if (_itemFocusNodes.isNotEmpty && _itemFocusNodes.first.canRequestFocus) {
      _itemFocusNodes.first.requestFocus();
      return true;
    }
    return false;
  }

  bool focusLastCard() {
    if (_itemFocusNodes.isNotEmpty && _itemFocusNodes.last.canRequestFocus) {
      _itemFocusNodes.last.requestFocus();
      return true;
    }
    return false;
  }

  /// Restaura la última tarjeta enfocada de la sección; si nunca tuvo foco
  /// (o la tarjeta ya no existe) cae a la primera.
  bool focusRememberedCard() {
    final int? index = _lastFocusedIndex;
    if (index != null &&
        index >= 0 &&
        index < _itemFocusNodes.length &&
        _itemFocusNodes[index].canRequestFocus) {
      _itemFocusNodes[index].requestFocus();
      return true;
    }
    return focusFirstCard();
  }

  @override
  void dispose() {
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
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
    final target = (_scrollController.offset + offset).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  /// Desplaza la fila para anclar la tarjeta enfocada en el inicio (extremo izquierdo).
  void _scrollToIndex(int index, double cardWidth) {
    if (!_scrollController.hasClients) return;
    const double spacing = 14.0;
    final double targetOffset = index * (cardWidth + spacing);
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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
      padding: const EdgeInsets.only(bottom: 12),
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
                const SizedBox(height: 4),
              ],
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool hasSubtitle = widget.hasSubtitle ?? widget.items.any((i) => i.subtitle != null && i.subtitle!.isNotEmpty);
                    return SizedBox(
                      height: TVResponsiveUtils.bannerRowHeight(
                        context,
                        hasSubtitle: hasSubtitle,
                        subtitleLines: 2,
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _updateScrollIndicators();
                          return false;
                        },
                        child: Focus(
                          canRequestFocus: false,
                          onFocusChange: (focused) {
                            if (focused && mounted) {
                              TvScroll.anchorSectionBelowTopbar(this.context);
                              TvScroll.anchorSectionBelowTopbarDeferred(this.context);
                            }
                          },
                          child: ListView.separated(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            cacheExtent: 600,
                            clipBehavior: Clip.none, 
                            scrollDirection: Axis.horizontal,
                            primary: false, 
                            padding: EdgeInsets.only(
                              left: horizontalPadding,
                              right: (MediaQuery.sizeOf(context).width - cardWidth - horizontalPadding).clamp(horizontalPadding, 2000.0),
                              top: 0,
                              bottom: 0,
                            ),
                            itemCount: widget.items.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              
                              return Align(
                                alignment: Alignment.topCenter,
                                child: FocusableWideCard(
                                  key: ValueKey(item.id),
                                  focusNode: _itemFocusNodes[index],
                                  disableAutoEnsureVisible: true,
                                  onKeyEvent: (node, event) {
                                    if (event is KeyDownEvent) {
                                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                        if (widget.onArrowDownToNext?.call() == true) return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                        if (widget.onArrowUpToPrev?.call() == true) return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && index == widget.items.length - 1) {
                                        if (widget.onArrowRightOnLast?.call() == true) return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index == 0) {
                                        if (widget.onArrowLeftOnFirst?.call() == true) return KeyEventResult.handled;
                                      }
                                    }
                                    return KeyEventResult.ignored;
                                  },
                                  title: item.title,
                                  imageUrl: item.imageUrl,
                                  logoUrl: item.logoUrl,
                                  progress: item.progress,
                                  subtitle: item.subtitle,
                                  subtitle2: item.subtitle2,
                                  rating: item.rating,
                                  badgeOverlay: item.badgeOverlay,
                                  width: cardWidth,
                                  height: cardHeight,
                                  onTap: () => widget.onItemTap(item),
                                  onDelete: item.onDelete,
                                  onFocusChanged: (focused) {
                                    if (!mounted) return;
                                    if (focused) {
                                      setState(() => _focusedIndex = index);
                                      _scrollToIndex(index, cardWidth);
                                    } else if (_focusedIndex == index) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (!mounted || _focusedIndex != index) return;
                                        setState(() => _focusedIndex = null);
                                      });
                                    }
                                  },
                                ),
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
                    bottom: 50,
                    child: ExcludeFocus(
                      excluding: !(_isHovered && _canScrollLeft),
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
                  ),
                  Positioned(
                    right: horizontalPadding - 25,
                    top: 10,
                    bottom: 50,
                    child: ExcludeFocus(
                      excluding: !(_isHovered && _canScrollRight),
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
