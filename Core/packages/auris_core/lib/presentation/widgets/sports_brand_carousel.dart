import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_endpoints.dart';
import 'disney_focus.dart';

/// Modelo de datos para las marcas o categorías deportivas (hub ESPN de Disney+).
class SportsBrandItem {
  final String id;
  final String name;
  final String logoUrl;
  final VoidCallback onTap;

  const SportsBrandItem({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.onTap,
  });
}

/// Carrusel horizontal de categorías deportivas — **clon del carrusel "Deportes"**
/// del hub ESPN de Disney+ (métricas extraídas del DOM/CSS reales vía REA,
/// 2026-10-26, viewport 1920x1080):
///
///  * Tile: flex-basis responsivo 43.75% / 29.75% (≥768) / 22.75% (≥1024) /
///    18.25% (≥1280) del ancho de pantalla, menos 5px; padding lateral 10px
///    por tile (gap visual 20px). Imagen 16:9 (`aspect-ratio: 1.78`), cover.
///  * Border-radius: `rounded-small` = **8px** (tarjeta e anillo).
///  * Hover/focus: **scale 1.03**, transición **300ms** con curva
///    `cubic-bezier(0,0,.2,1)` (Tailwind `.ease-out`) sobre `transform` y
///    `box-shadow`; anillo `outline-4 outline-offset-4` en `--colorsOnSurface`
///    (**#FAFAFA** en tema oscuro) con `transition-all` 300ms misma curva;
///    sombra dual en ≥768px
///    (`1px -20px 14px -18px rgb(0 0 0/80%), 2px 12px 13px -3px rgb(0 0 0/72%)`).
///    En Disney+ web ese efecto está declarado solo con `:hover` (no existe
///    variante `:focus`/`:focus-visible` ni `li:focus`); aquí se activa también
///    con el foco del D-pad porque en TV/táctil no hay ratón.
///  * Label: `headline-xsmall` → **14px w700** (16px ≥768), line-height 1.2,
///    a 16px (`mt-4`) de la imagen. Título: `headline-small` → 20px w700 (16px <768).
///  * Borde de fila: `calc(3.5vw+24px)` a cada lado; snap por ítem con
///    scroll-padding `calc(3.5vw+14px)`; scroll-snap mandatory, sin flechas.
///
/// El `onTap` de cada [SportsBrandItem] lo inyecta la pantalla que lo usa.
/// Los callbacks `onArrow*` (opcionales) replican el contrato de las demás
/// filas del Home para la navegación con D-pad en TV.
class SportsBrandCarousel extends StatefulWidget {
  final String? title;
  final List<SportsBrandItem> items;
  final void Function(int index)? onTileTap;
  final bool Function()? onArrowRightOnLast;
  final bool Function()? onArrowLeftOnFirst;
  final bool Function()? onArrowDownToNext;
  final bool Function()? onArrowUpToPrev;

  const SportsBrandCarousel({
    super.key,
    this.title,
    required this.items,
    this.onTileTap,
    this.onArrowRightOnLast,
    this.onArrowLeftOnFirst,
    this.onArrowDownToNext,
    this.onArrowUpToPrev,
  });

  @override
  State<SportsBrandCarousel> createState() => _SportsBrandCarouselState();
}

class _SportsBrandCarouselState extends State<SportsBrandCarousel> {
  final ScrollController _scrollCtrl = ScrollController();
  List<FocusNode> _nodes = [];
  int _hoveredIndex = -1;

  // ─── Tokens Disney+ (observados) ───────────────────────────────────────
  // Los valores de foco (escala, anillo, duración, curva) viven ahora en
  // DisneyFocusTokens: fuente única compartida con las tarjetas wide/poster.
  static const double _imgRatio = 1.78;            // aspect-ratio 1.78 / 1
  static const double _radius = DisneyFocusTokens.radius; // rounded-small
  static const double _liPadding = 10;             // px-[10px] por lado
  static const double _gapBasis = 5;               // calc(X% - 5px)
  static const double _metaGap = 16;               // mt-4 bajo la imagen
  static const Color _onSurface = DisneyFocusTokens.ringColor; // --colorsOnSurface
  static const Duration _dur = DisneyFocusTokens.duration; // duration-300
  static const Cubic _curve = DisneyFocusTokens.curve; // .ease-out = cubic-bezier(0,0,.2,1)

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.items.length, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(covariant SportsBrandCarousel old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes = List.generate(widget.items.length, (_) => FocusNode());
      _hoveredIndex = -1;
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Ancho del <li> (flex-basis) por breakpoint — mismo % que Disney+.
  double _liWidth(double vw) {
    double frac;
    if (vw >= 1280) {
      frac = 0.1825; // xl
    } else if (vw >= 1024) {
      frac = 0.2275; // lg
    } else if (vw >= 768) {
      frac = 0.2975; // md
    } else {
      frac = 0.4375; // base
    }
    return vw * frac - _gapBasis;
  }

  // Borde exterior de la fila: calc(3.5vw + 24px).
  double _edgePad(double vw) => vw * 0.035 + 24;

  // Offset de snap por ítem: el li empieza en edgePad y Disney alinea su
  // inicio con scroll-padding calc(3.5vw+14px) → delta fijo de 10px.
  double _snapOffset(double vw) => _edgePad(vw) - (vw * 0.035 + 14);

  // Scroll animado para centrar/fijar el tile enfocado (snap del siguiente ítem).
  void _scrollTo(int index) {
    if (!_scrollCtrl.hasClients) return;
    final double vw = MediaQuery.sizeOf(context).width;
    final double target =
        (_edgePad(vw) + index * _liWidth(vw) - (vw * 0.035 + 14))
            .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(target, duration: _dur, curve: _curve);
  }

  KeyEventResult _onTileKey(FocusNode node, KeyEvent ev, int index) {
    if (ev is! KeyDownEvent) return KeyEventResult.ignored;
    if (ev.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < widget.items.length - 1) {
        _nodes[index + 1].requestFocus();
        return KeyEventResult.handled;
      }
      return (widget.onArrowRightOnLast?.call() ?? false)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (ev.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        _nodes[index - 1].requestFocus();
        return KeyEventResult.handled;
      }
      return (widget.onArrowLeftOnFirst?.call() ?? false)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (ev.logicalKey == LogicalKeyboardKey.arrowDown) {
      return (widget.onArrowDownToNext?.call() ?? false)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (ev.logicalKey == LogicalKeyboardKey.arrowUp) {
      return (widget.onArrowUpToPrev?.call() ?? false)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final double vw = MediaQuery.sizeOf(context).width;
    final bool isDesktop = vw >= 768;
    final double liW = _liWidth(vw);
    final double cardW = liW - 2 * _liPadding; // imagen dentro del li
    final double cardH = cardW / _imgRatio;
    final double labelFs = isDesktop ? 16 : 14; // headline-xsmall
    final double titleFs = isDesktop ? 20 : 16; // headline-small
    // label máx 2 líneas (lh 1.2) + holgura para el anillo (8px) y scale 1.03.
    final double listH = cardH + _metaGap + labelFs * 1.2 * 2 + 26;

    return Padding(
      padding: const EdgeInsets.only(bottom: 30), // mb-[30px] del <ul>
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null && widget.title!.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _edgePad(vw)),
              child: Text(
                widget.title!,
                style: GoogleFonts.poppins(
                  color: _onSurface,
                  fontSize: titleFs,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 19), // mt-[15px] del <ul> + pt-xs (4px)
          ],
          SizedBox(
            height: listH,
            child: Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: false, // no-scrollbar
              child: ListView.builder(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: _edgePad(vw),
                  vertical: 10, // holgura del anillo/scale fuera del clip
                ),
                physics: _DisneySnapPhysics(
                  itemExtent: liW,
                  snapOffset: _snapOffset(vw),
                ),
                itemCount: widget.items.length,
                itemBuilder: (context, index) => _buildTile(
                  context,
                  index,
                  cardW: cardW,
                  cardH: cardH,
                  labelFs: labelFs,
                  isDesktop: isDesktop,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    int index, {
    required double cardW,
    required double cardH,
    required double labelFs,
    required bool isDesktop,
  }) {
    final SportsBrandItem item = widget.items[index];
    final FocusNode node = _nodes[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _liPadding), // px-[10px]
      child: GestureDetector(
        onTap: () =>
            widget.onTileTap != null ? widget.onTileTap!(index) : item.onTap(),
        child: Focus(
          focusNode: node,
          onFocusChange: (focused) {
            if (focused) _scrollTo(index);
            setState(() {});
          },
          onKeyEvent: (n, ev) => _onTileKey(n, ev, index),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = -1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tratamiento Disney+ compartido (DisneyFocusShell): scale 1.03,
                // sombra dual (>=768) y anillo outline-4/outline-offset-4 en
                // OnSurface, todo 300ms cubic-bezier(0,0,.2,1). Solo la tarjeta,
                // no el label.
                DisneyFocusShell(
                  active: _isActive(index),
                  activeShadow: isDesktop ? DisneyFocusTokens.dualShadow : null,
                  child: ClipRRect(
                          borderRadius: BorderRadius.circular(_radius),
                          child: CachedNetworkImage(
                            imageUrl:
                                ApiEndpoints.proxyImage(item.logoUrl),
                            fit: BoxFit.cover,
                            width: cardW,
                            height: cardH,
                            placeholder: (context, url) => Center(
                              child: Text(
                                item.name,
                                style: GoogleFonts.poppins(
                                  color: _onSurface.withValues(alpha: 0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                item.name,
                                style: GoogleFonts.poppins(
                                  color: _onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: _metaGap), // mt-4
                SizedBox(
                  width: cardW,
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _onSurface,
                      fontSize: labelFs,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isActive(int index) =>
      _hoveredIndex == index || _nodes[index].hasFocus;
}

/// Scroll-snap por ítem como el `snap-x snap-mandatory` de Disney+: al soltar
/// (drag, rueda o foco), la fila se asienta en el inicio del tile más cercano.
class _DisneySnapPhysics extends ScrollPhysics {
  final double itemExtent;
  final double snapOffset;

  const _DisneySnapPhysics({
    required this.itemExtent,
    required this.snapOffset,
    super.parent,
  });

  @override
  _DisneySnapPhysics applyTo(ScrollPhysics? ancestor) => _DisneySnapPhysics(
        itemExtent: itemExtent,
        snapOffset: snapOffset,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final double min = position.minScrollExtent;
    final double max = position.maxScrollExtent;
    final double offset = position.pixels;
    double target =
        ((offset - snapOffset) / itemExtent).round() * itemExtent + snapOffset;
    target = target.clamp(min, max);
    final Tolerance tol = toleranceFor(position);
    if ((target - offset).abs() < 0.5 && velocity.abs() < tol.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      offset,
      target,
      velocity,
      tolerance: tol,
    );
  }
}
