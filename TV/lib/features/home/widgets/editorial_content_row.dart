import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:auris_core/auris_core.dart' hide FocusablePosterCard;
import '../../../core/utils/tv_responsive_utils.dart';
import '../../../shared/widgets/prime_expandable_card.dart';
import '../../../shared/widgets/focusable_poster_card.dart';
import '../../../shared/widgets/top_item.dart';
import '../../../shared/widgets/tv_scroll.dart';

class EditorialContentRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final EditorialBadge badge;
  final bool forceTopDesign;
  final void Function(MediaItem item) onItemTap;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  /// D-pad abajo: salta a la sección siguiente restaurando su última tarjeta.
  final bool Function()? onArrowDownToNext;
  /// D-pad arriba: salta a la sección anterior restaurando su última tarjeta.
  final bool Function()? onArrowUpToPrev;

  const EditorialContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.badge,
    required this.onItemTap,
    this.forceTopDesign = false,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
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
  late List<FocusNode> _itemFocusNodes;
  // Última tarjeta enfocada: al volver a la sección con el D-pad se restaura.
  int? _lastFocusedIndex;

  @override
  void initState() {
    super.initState();
    _initFocusNodes();
    _scrollController.addListener(_updateScrollIndicators);
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
  void didUpdateWidget(covariant EditorialContentRow oldWidget) {
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
    for (final node in _itemFocusNodes) {
      node.dispose();
    }
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
                    style: TextStyle(
                      fontFamily: 'NetflixSans',
                      fontSize: TVResponsiveUtils.rowTitleFontSize(context), 
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE5E5E5),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        fontSize: TVResponsiveUtils.sp(context, 12),
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16), // Gap ampliado: deja respirar el pop-out del póster enfocado
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
        // Sin recorte: el pop-out del póster enfocado sobresale de la ranura.
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: rowHeight, // Usamos la altura calculada dinámicamente
            child: _buildFadedWrapper(
              horizontalPadding: horizontalPadding,
              child: Focus(
                canRequestFocus: false,
                // Foco entra a la sección -> anclarla debajo del topbar
                // (this.context = la fila, título incluido).
                onFocusChange: (focused) {
                  if (focused && mounted) {
                    TvScroll.anchorSectionBelowTopbar(this.context);
                    TvScroll.anchorSectionBelowTopbarDeferred(this.context);
                  }
                },
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  clipBehavior: Clip.none,
                  scrollDirection: Axis.horizontal,
                  primary: false, 
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 5),
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return SizedBox(
                      width: cardWidth,
                      child: FocusablePosterCard(
                        key: ValueKey(item.id),
                        focusNode: _itemFocusNodes[index],
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
                    style: TextStyle(
                      fontFamily: 'NetflixSans',
                      fontSize: TVResponsiveUtils.rowTitleFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE5E5E5),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        fontSize: TVResponsiveUtils.sp(context, 12),
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16), // Gap ampliado: deja respirar el pop-out del póster enfocado
          MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Stack(
              // Sin recorte: el pop-out del póster enfocado sobresale de la ranura.
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: rowHeight, // Unificado con posters estándar
                  child: _buildFadedWrapper(
                    horizontalPadding: horizontalPadding,
                    // Foco entra a la sección Top10 -> anclarla debajo del
                    // topbar (this.context = la fila, título incluido).
                    child: Focus(
                      canRequestFocus: false,
                      onFocusChange: (focused) {
                        if (focused && mounted) {
                          TvScroll.anchorSectionBelowTopbar(this.context);
                          TvScroll.anchorSectionBelowTopbarDeferred(this.context);
                        }
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        primary: false, // Senior Fix: Evita que el ScrollView intente capturar el foco
                        clipBehavior: Clip.none, 
                        padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 0), // Senior: Zero padding
                        itemCount: widget.items.length.clamp(0, 10),
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final int itemCount = widget.items.length.clamp(0, 10);
                          return TopItem(
                            index: index,
                            item: item,
                            height: posterHeight,
                            textOffset: 0,
                            focusNode: _itemFocusNodes[index],
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent) {
                                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                  if (widget.onArrowDownToNext?.call() == true) return KeyEventResult.handled;
                                } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                  if (widget.onArrowUpToPrev?.call() == true) return KeyEventResult.handled;
                                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && index == itemCount - 1) {
                                  if (widget.onArrowRightOnLast?.call() == true) return KeyEventResult.handled;
                                } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && index == 0) {
                                  if (widget.onArrowLeftOnFirst?.call() == true) return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            onTap: () => widget.onItemTap(item),
                          );
                        },
                      ),
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
        // Excluida del D-pad cuando está oculta: invisible + enfocable =
        // trampa de foco (el foco "desaparece" al bajar de fila).
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
                  onTap: () => _scroll(-800),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: horizontalPadding - 25,
        top: 0, bottom: 60, // Ajustado para nuevo posterHeight
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
                  onTap: () => _scroll(800),
                ),
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
