import 'package:flutter/material.dart';
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

  const WideContentRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    required this.onItemTap,
    this.hasSubtitle,
  });

  @override
  State<WideContentRow> createState() => _WideContentRowState();
}

class _WideContentRowState extends State<WideContentRow>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  int? _focusedIndex;
  // La copia de overlay arranca sin seleccionar (sin borde durante el vuelo)
  // y se selecciona al aterrizar: el realce florece con el glide, no antes.
  bool _overlaySelected = false;
  // Transición horizontal: deslizamiento de la capa de foco entre tarjetas.
  // El offset animado va de la posición previa a 0; el `left` real sigue el
  // scroll al instante para que la capa nunca se despegue de su ranura.
  late final AnimationController _glideCtrl;
  Animation<double>? _glideAnim;
  // Coreografía del realce: durante el vuelo la capa viaja sin borde; el
  // bloom del borde se dispara AL ATERRIZAR (fin del glide), no al inicio.
  int? _pendingBloomIndex;

  @override
  void initState() {
    super.initState();
    _glideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _glideCtrl.addStatusListener((status) {
      if (!mounted || status != AnimationStatus.completed) return;
      final int? i = _pendingBloomIndex;
      _pendingBloomIndex = null;
      // Solo florecer si el foco sigue en esa tarjeta al aterrizar.
      if (i != null && _focusedIndex == i) {
        setState(() => _overlaySelected = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void dispose() {
    _glideCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
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
      padding: const EdgeInsets.only(bottom: 24), // Más aire y separación generosa entre filas wide
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
              // Sin recorte: cualquier realce de la capa de foco que sobresalga
              // de la ranura no se recorta.
              clipBehavior: Clip.none,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool hasSubtitle = widget.hasSubtitle ?? widget.items.any((i) => i.subtitle != null && i.subtitle!.isNotEmpty);
                    final int subtitleLines = widget.items.any((i) => i.subtitle2 != null && i.subtitle2!.isNotEmpty) ? 2 : 1;
                    return SizedBox(
                      height: TVResponsiveUtils.bannerRowHeight(
                        context,
                        hasSubtitle: hasSubtitle,
                        subtitleLines: subtitleLines,
                      ),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _updateScrollIndicators();
                          return false;
                        },
                        child: Focus(
                          canRequestFocus: false,
                          // Foco entra a la sección -> anclarla debajo del
                          // topbar. this.context = la fila (borde superior
                          // con título); el context del builder sería el
                          // LayoutBuilder (solo el carrusel).
                          onFocusChange: (focused) {
                            if (focused && mounted) {
                              TvScroll.anchorSectionBelowTopbar(this.context);
                            }
                          },
                          child: ListView.separated(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(),
                            clipBehavior: Clip.none, 
                            scrollDirection: Axis.horizontal,
                            primary: false, 
                            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 0),
                            itemCount: widget.items.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              final bool isFocused = _focusedIndex == index;
                              
                              return Center(
                                child: FocusableWideCard(
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
                                  forceInvisible: isFocused,
                                  onFocusChanged: (focused) {
                                    if (!mounted) return;
                                    if (focused) {
                                      // La pérdida de la tarjeta anterior se
                                      // notifica ANTES que esta ganancia (y su
                                      // limpieza está diferida al cierre de
                                      // frame), así que _focusedIndex aún
                                      // apunta a la tarjeta de partida.
                                      final int? prev = _focusedIndex;
                                      setState(() {
                                        _focusedIndex = index;
                                        _overlaySelected = false;
                                      });
                                      if (prev != null &&
                                          prev != index &&
                                          prev < widget.items.length) {
                                        // Desliz desde la ranura previa a la
                                        // nueva (paso = ancho + separador).
                                        final double delta =
                                            (prev - index) * (cardWidth + 16);
                                        _glideAnim = Tween<double>(
                                          begin: delta,
                                          end: 0.0,
                                        ).animate(CurvedAnimation(
                                          parent: _glideCtrl,
                                          curve: Curves.easeOutQuart,
                                        ));
                                        _glideCtrl.forward(from: 0);
                                        // Bloom al aterrizar (status listener
                                        // del glide), NO durante el vuelo.
                                        _pendingBloomIndex = index;
                                      } else {
                                        // Entrada a la fila: capa directa,
                                        // sin vuelo ni fundido. Bloom ya en el
                                        // siguiente frame (feedback inmediato).
                                        _glideAnim = null;
                                        _pendingBloomIndex = null;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          if (!mounted ||
                                              _focusedIndex != index) {
                                            return;
                                          }
                                          setState(() =>
                                              _overlaySelected = true);
                                        });
                                      }
                                    } else if (_focusedIndex == index) {
                                      // No limpiar ya: si la pérdida y la
                                      // ganancia de la vecina ocurren en el
                                      // mismo tick, el gain debe poder leer
                                      // _focusedIndex = este índice. Si al
                                      // cierre de frame nadie lo ganó, sí se
                                      // limpió (foco fuera de la fila).
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (!mounted ||
                                            _focusedIndex != index) {
                                          return;
                                        }
                                        setState(() {
                                          _focusedIndex = null;
                                          _overlaySelected = false;
                                          _pendingBloomIndex = null;
                                        });
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
                if (_focusedIndex != null && _focusedIndex! < widget.items.length) ...[
                  AnimatedBuilder(
                    // Scroll (posición exacta) + glide (desliz entre ranuras).
                    animation: Listenable.merge(
                        [_scrollController, _glideCtrl]),
                    builder: (context, _) {
                      final index = _focusedIndex!;
                      final item = widget.items[index];
                      final double itemLeft = horizontalPadding +
                          index * (cardWidth + 16) -
                          _scrollController.offset +
                          (_glideAnim?.value ?? 0.0);
                      final Widget card = FocusableWideCard(
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
                        forceInvisible: false,
                        forceSelected: _overlaySelected,
                      );

                      return Positioned(
                        left: itemLeft,
                        top: 0,
                        bottom: 0,
                        width: cardWidth,
                        // Pura capa visual: IgnorePointer (ratón) +
                        // ExcludeFocus (D-pad) — el foco vive en la tarjeta
                        // original de la lista.
                        child: ExcludeFocus(
                          child: IgnorePointer(
                            child: Center(
                              // Fundido del contenido al cambiar de ranura
                              // (key por índice => un fundido por salto) que
                              // enmascara el cambio de póster durante el
                              // desliz. Sin glider (entrada a la fila) se
                              // pinta directo, sin parpadeo.
                              child: _glideAnim != null
                                  ? TweenAnimationBuilder<double>(
                                      key: ValueKey<int>(index),
                                      tween: Tween<double>(
                                          begin: 0.0, end: 1.0),
                                      duration: const Duration(
                                          milliseconds: 250),
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) =>
                                          Opacity(
                                              opacity: value,
                                              child: child!),
                                      child: card,
                                    )
                                  : card,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                if (!isMobile) ...[
                  Positioned(
                    left: horizontalPadding - 25,
                    top: 10,
                    bottom: 50,
                    // Excluida del D-pad cuando está oculta: invisible +
                    // enfocable = trampa de foco.
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
