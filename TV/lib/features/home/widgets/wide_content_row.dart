import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:auris_core/auris_core.dart' hide FocusableWideCard, FocusableTop10WideCard;
import '../../../shared/widgets/focusable_top10_wide_card.dart';
import '../../../core/utils/tv_responsive_utils.dart';
import '../../../shared/widgets/focusable_wide_card.dart';
import '../../../shared/widgets/tv_scroll.dart';

class WideContentItem {
  final String id;
  final String title;
  final String imageUrl;
  final String? logoUrl; // Senior Fix: Soporte para logo en WideCard
  final String? subtitle;
  /// Segunda linea opcional bajo el subtitulo (ej. "Quedan: X").
  final String? subtitle2;
  final String? rating;
  final double? progress;
  final Widget? badgeOverlay;
  final VoidCallback? onDelete;
  final dynamic originalItem;
  final bool isBannerFallback;

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
    this.isBannerFallback = false,
  });
}

class WideContentRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<WideContentItem> items;
  final void Function(WideContentItem item) onItemTap;
  final bool? hasSubtitle;
  final bool isTop10Wide;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  /// D-pad abajo: enfoca la ultima tarjeta con foco en la seccion siguiente.
  final bool Function()? onArrowDownToNext;
  /// D-pad arriba: igual pero hacia la seccion anterior.
  final bool Function()? onArrowUpToPrev;
  /// D-pad BACK / Escape dentro de la fila:
  /// tarjeta>0 → mueve a la primera; tarjeta 0 → llama a este callback.
  final VoidCallback? onBackToHero;

  const WideContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.onItemTap,
    this.hasSubtitle,
    this.isTop10Wide = false,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
    this.onBackToHero,
  });

  @override
  State<WideContentRow> createState() => WideContentRowState();
}

class WideContentRowState extends State<WideContentRow>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _rowKey = GlobalKey();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  /// Indice logico actualmente seleccionado con el D-PAD.
  /// El borde blanco se pinta en la posicion visual fija (primer slot);
  /// solo las tarjetas se deslizan bajo el cursor.
  int? _focusedIndex;

  /// Memoria: permite volver a la misma tarjeta al regresar a la fila.
  int? _lastFocusedIndex;

  /// Nodo unico para toda la fila - intercepta D-PAD sin ceder el foco
  /// a los nodos individuales de cada tarjeta.
  final FocusNode _rowFocusNode = FocusNode(debugLabel: 'WideRow');

  /// Nodos dummy por tarjeta: skipTraversal + !canRequestFocus para que
  /// Flutter no los incluya en la navegacion automatica.
  late List<FocusNode> _dummyNodes;

  List<FocusNode> _buildDummyNodes(int count) => List.generate(
        count,
        (_) => FocusNode(skipTraversal: true, canRequestFocus: false),
      );

  @override
  void initState() {
    super.initState();
    _dummyNodes = _buildDummyNodes(widget.items.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void didUpdateWidget(covariant WideContentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      if (_lastFocusedIndex != null && _lastFocusedIndex! >= widget.items.length) {
        _lastFocusedIndex = null;
      }
      if (_focusedIndex != null && _focusedIndex! >= widget.items.length) {
        setState(() => _focusedIndex = null);
      }
      for (final n in _dummyNodes) { n.dispose(); }
      _dummyNodes = _buildDummyNodes(widget.items.length);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
    }
  }

  // --- API publica para que el padre pida foco ---

  bool focusFirstCard() {
    if (widget.items.isEmpty) return false;
    _rowFocusNode.requestFocus();
    _setFocusedIndex(0);
    return true;
  }

  bool focusLastCard() {
    if (widget.items.isEmpty) return false;
    _rowFocusNode.requestFocus();
    _setFocusedIndex(widget.items.length - 1);
    return true;
  }

  /// Restaura la ultima tarjeta enfocada; si nunca tuvo foco cae a la primera.
  bool focusRememberedCard() {
    final int idx = (_lastFocusedIndex ?? 0).clamp(0, widget.items.length - 1);
    _rowFocusNode.requestFocus();
    _setFocusedIndex(idx);
    return true;
  }

  @override
  void dispose() {
    for (final n in _dummyNodes) { n.dispose(); }
    _rowFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- Scroll ---

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
    final target = (_scrollController.offset + offset)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// Ancla la tarjeta [index] en la posicion visual fija (padding izquierdo).
  /// El borde blanco permanece fijo; las tarjetas se desplazan debajo.
  ///
  /// Para filas top10Wide, el ancho visual de cada item incluye la parte
  /// visible del numero gigante que sobresale a la izquierda de la tarjeta:
  ///   - Rank 1   -> cardWidth * 0.18
  ///   - Rank 2-9 -> cardWidth * 0.28
  ///   - Rank 10  -> cardWidth * 0.36
  void _scrollToIndex(int index, double cardWidth) {
    if (!_scrollController.hasClients) return;
    final double gap = TVResponsiveUtils.cardGap(context);
    double targetOffset;
    if (widget.isTop10Wide) {
      // Acumulamos el offset real sumando el ancho de cada item anterior
      double offset = 0.0;
      for (int i = 0; i < index; i++) {
        final int rank = i + 1;
        final double numberVisiblePart = rank == 1
            ? cardWidth * 0.18
            : rank >= 10
                ? cardWidth * 0.36
                : cardWidth * 0.28;
        offset += numberVisiblePart + cardWidth + gap;
      }
      targetOffset = offset;
    } else {
      targetOffset = index * (cardWidth + gap);
    }
    final double maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  // --- Navegacion D-PAD ---

  void _setFocusedIndex(int index) {
    if (!mounted) return;
    setState(() => _focusedIndex = index);
    _lastFocusedIndex = index;
    final cardWidth = TVResponsiveUtils.bannerWidth(context);
    _scrollToIndex(index, cardWidth);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final current = _focusedIndex ?? 0;
    final last = widget.items.length - 1;

    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < last) {
        _setFocusedIndex(current + 1);
        return KeyEventResult.handled;
      } else {
        if (widget.onArrowRightOnLast?.call() == true) return KeyEventResult.handled;
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (current > 0) {
        _setFocusedIndex(current - 1);
        return KeyEventResult.handled;
      } else {
        if (widget.onArrowLeftOnFirst?.call() == true) return KeyEventResult.handled;
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.onArrowDownToNext?.call() == true) return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.onArrowUpToPrev?.call() == true) return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      if (current > 0) {
        _setFocusedIndex(0);
        return KeyEventResult.handled;
      } else {
        widget.onBackToHero?.call();
        return KeyEventResult.handled;
      }
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      if (_focusedIndex != null && _focusedIndex! < widget.items.length) {
        SafeTap.run(() => widget.onItemTap(widget.items[_focusedIndex!]));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.items.isEmpty) return const SizedBox.shrink();

    const isMobile = false;
    final horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    final cardWidth = TVResponsiveUtils.bannerWidth(context);
    final cardHeight = TVResponsiveUtils.bannerHeight(context);

    return Padding(
      key: _rowKey,
      padding: EdgeInsets.only(bottom: TVResponsiveUtils.sectionBottomGap(context)),
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
                            fontSize: TVResponsiveUtils.grid(context, 20),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Holgura para el anillo Disney+ (8px sobre el borde de la
                // tarjeta): el título no debe pisarse cuando la fila gana foco.
                // Prime mide 16 px entre título y tarjetas.
                SizedBox(height: TVResponsiveUtils.sectionTitleGap(context)),
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
                    final bool hasSubtitle = widget.hasSubtitle ??
                        widget.items.any(
                            (i) => i.subtitle != null && i.subtitle!.isNotEmpty);
                    return SizedBox(
                      height: widget.isTop10Wide
                          ? cardHeight + 20
                          : TVResponsiveUtils.bannerRowHeight(
                              context,
                              hasSubtitle: hasSubtitle,
                              subtitleLines: 2,
                            ),
                      child: ShaderMask(
                        shaderCallback: (Rect rect) {
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [
                              Colors.transparent,
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.03, 0.97, 1.0],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            _updateScrollIndicators();
                            return false;
                          },
                          // Nodo unico que captura todo el D-PAD de la fila
                          child: Focus(
                          focusNode: _rowFocusNode,
                          onFocusChange: (focused) {
                            if (!mounted) return;
                            if (focused) {
                              // Al entrar: restaurar la ultima tarjeta.
                              if (_focusedIndex == null) {
                                final idx = (_lastFocusedIndex ?? 0)
                                    .clamp(0, widget.items.length - 1);
                                setState(() => _focusedIndex = idx);
                                _scrollToIndex(idx, cardWidth);
                              }
                              TvScroll.anchorSectionBelowTopbar(_rowKey.currentContext ?? context);
                              TvScroll.anchorSectionBelowTopbarDeferred(_rowKey.currentContext ?? context);
                            } else {
                              // Al salir: conservar memoria, quitar borde.
                              if (_focusedIndex != null) _lastFocusedIndex = _focusedIndex;
                              setState(() => _focusedIndex = null);
                            }
                          },
                          onKeyEvent: _handleKeyEvent,
                          child: ListView.separated(
                            controller: _scrollController,
                            // NeverScrollableScrollPhysics: el scroll SOLO ocurre
                            // programaticamente (_scrollToIndex / _scroll).
                            // Esto evita que el D-PAD desplace la lista por si
                            // solo y mantiene el borde blanco visualmente fijo.
                            physics: const NeverScrollableScrollPhysics(),
                            cacheExtent: 600.0,
                            clipBehavior: Clip.none,
                            scrollDirection: Axis.horizontal,
                            primary: false,
                            padding: EdgeInsets.only(
                              left: horizontalPadding,
                              right: (MediaQuery.sizeOf(context).width -
                                      cardWidth -
                                      horizontalPadding)
                                  .clamp(horizontalPadding, 2000.0),
                              top: 0,
                              bottom: 0,
                            ),
                            itemCount: widget.items.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(width: TVResponsiveUtils.cardGap(context)),
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              final bool isSelected = _focusedIndex == index;

                              Widget cardWidget;
                              if (widget.isTop10Wide) {
                                cardWidget = FocusableTop10WideCard(
                                  key: ValueKey(item.id),
                                  rank: index + 1,
                                  title: item.title,
                                  imageUrl: item.imageUrl,
                                  logoUrl: item.logoUrl,
                                  onTap: () => widget.onItemTap(item),
                                  subtitle: item.subtitle,
                                  rating: item.rating,
                                  progress: item.progress,
                                  badgeOverlay: item.badgeOverlay,
                                  isBannerFallback: item.isBannerFallback,
                                  forceSelected: isSelected,
                                  showBorder: true,
                                  focusNode: _dummyNodes[index],
                                  width: cardWidth,
                                  height: cardHeight,
                                );
                              } else {
                                cardWidget = FocusableWideCard(
                                  key: ValueKey(item.id),
                                  focusNode: _dummyNodes[index],
                                  disableAutoEnsureVisible: true,
                                  forceSelected: isSelected,
                                  showBorder: true,
                                  title: item.title,
                                  imageUrl: item.imageUrl,
                                  logoUrl: item.logoUrl,
                                  isBannerFallback: item.isBannerFallback,
                                  progress: item.progress,
                                  subtitle: item.subtitle,
                                  subtitle2: item.subtitle2,
                                  rating: item.rating,
                                  badgeOverlay: item.badgeOverlay,
                                  width: cardWidth,
                                  height: cardHeight,
                                  onTap: () => widget.onItemTap(item),
                                  onDelete: item.onDelete,
                                );
                              }

                              return Align(
                                alignment: Alignment.centerLeft,
                                child: cardWidget,
                              );
                            },
                          ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // El marco de foco lo dibuja ahora la propia tarjeta
                // (DisneyFocusShell): anillo outline-4/outline-offset-4 en
                // #FAFAFA a 300ms que viaja con el tile al hacer scroll,
                // en lugar del marco fijo estilo Prime Video.
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
                              onTap: () => _scroll(-cardWidth * 2),
                            ),
                          ),
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
                              onTap: () => _scroll(cardWidth * 2),
                            ),
                          ),
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
