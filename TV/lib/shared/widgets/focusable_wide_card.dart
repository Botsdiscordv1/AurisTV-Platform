import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart' hide MarqueeText;
import '../../../core/utils/tv_responsive_utils.dart';
import 'tv_focus_wrapper.dart';
import 'tv_scroll.dart';

class FocusableWideCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final String? logoUrl; // Senior Fix: Soporte para logo oficial del contenido
  final double? progress;
  final String? subtitle;
  /// Segunda línea opcional bajo el subtítulo (ej. "Quedan X" bajo
  /// "T1:E7 . Título"). Crece el área de texto solo cuando viene.
  final String? subtitle2;
  final String? rating;
  final Widget? badgeOverlay;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final double width;
  final double height;
  final ValueChanged<bool>? onFocusChanged;
  final bool forceInvisible;
  /// La copia de overlay (fila wide) es puramente visual: su foco vive en la
  /// tarjeta original, así que esta fuerza el estado seleccionado (borde,
  /// gradiente, realce) aunque el nodo no tenga foco.
  final bool forceSelected;

  const FocusableWideCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.logoUrl,
    this.onDelete,
    this.progress,
    this.subtitle,
    this.subtitle2,
    this.rating,
    this.badgeOverlay,
    this.width = 440,
    this.height = 248,
    this.onFocusChanged,
    this.forceInvisible = false,
    this.forceSelected = false,
  });

  @override
  State<FocusableWideCard> createState() => _FocusableWideCardState();
}

class _FocusableWideCardState extends State<FocusableWideCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get isSelected => widget.forceSelected || _isHovered || _isFocused;

  @override
  void dispose() {
    // Si esta tarjeta desaparece con el foco (cambio de ítems/categoría),
    // Focus nunca emite onFocusChange(false) al desmontarse: avisar a la fila
    // para que quite el overlay y no quede una copia huérfana.
    if (_isFocused) widget.onFocusChanged?.call(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.forceInvisible ? 0.0 : 1.0,
      child: Focus(
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        widget.onFocusChanged?.call(focused);
        if (focused) {
          // Scroll MÍNIMO (solo si no cabe entera) con la misma duración que
          // el glide: la fila permanece quieta en el cambio de foco normal y
          // el efecto de transición se ve nítido también en carruseles largos.
          // (El ancla vertical la dispara la FILA al recibir el foco.)
          TvScroll.ensureCardVisible(context);
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            SafeTap.run(widget.onTap);
            return KeyEventResult.handled;
          }
          // D-pad abajo desde una wide (ancha): ir al PRIMER elemento de la
          // fila de abajo en vez de caer bajo el centro de la card.
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (TvDirectionalFocus.focusFirstBelow()) {
              return KeyEventResult.handled;
            }
          }
          // D-pad arriba con la fila de arriba vacía en esta columna: saltar
          // al primero de esa fila. Si hay algo alineado, no interviene.
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (TvDirectionalFocus.focusFirstAboveIfEmpty()) {
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () => SafeTap.run(widget.onTap),
          child: SizedBox(
            width: widget.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isSelected ? [] : [],
                      border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: isSelected ? 2.0 : 0.0),
                    ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              placeholder: (context, url) => Container(color: Colors.white10),
                              errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(isSelected ? 0.7 : 0.5)],
                                      stops: const [0.6, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
                              Positioned(
                                bottom: 16, left: 12,
                                // Caja + imagen con geometría idéntica antes y
                                // después de cargar (sin esto el logo aparece
                                // centrado y salta a bottomLeft al resolver).
                                child: SizedBox(
                                  height: widget.height * 0.35,
                                  width: widget.width * 0.65,
                                  child: CachedNetworkImage(
                                    imageUrl: widget.logoUrl!,
                                    width: widget.width * 0.65,
                                    height: widget.height * 0.35,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.bottomLeft,
                                    filterQuality: FilterQuality.medium,
                                    fadeInDuration: const Duration(milliseconds: 150),
                                    placeholder: (context, url) => Container(
                                      width: widget.width * 0.65,
                                      height: widget.height * 0.35,
                                      color: Colors.white.withOpacity(0.04),
                                    ),
                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              )
                            else
                              Positioned(
                                bottom: 12, left: 12, right: 12,
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: TVResponsiveUtils.sp(context, 15),
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                ),
                              ),
                            if (widget.onDelete != null && isSelected)
                              Positioned(
                                top: 8, left: 8,
                                child: Tooltip(
                                  message: 'Eliminar de continuar viendo',
                                  child: InkWell(
                                    onTap: widget.onDelete,
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(isSelected ? 0.8 : 0.4),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(isSelected ? 0.4 : 0.1)),
                                      ),
                                      child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7), size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            if (widget.badgeOverlay != null) Positioned(top: 10, left: 10, child: widget.badgeOverlay!),

                            if (widget.progress != null && widget.progress! > 0)
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  height: 4, color: Colors.white24,
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: widget.progress!.clamp(0.0, 1.0),
                                    child: Container(decoration: const BoxDecoration(color: Color(0xFFEF7A1E), boxShadow: [BoxShadow(color: Color(0xFFEF7A1E), blurRadius: 4)])),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: TVResponsiveUtils.sp(context, 20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text.rich(
                              subtitleRichSpan(
                                widget.subtitle!,
                                TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: TVResponsiveUtils.sp(context, 13),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (widget.subtitle2 != null &&
                            widget.subtitle2!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            height: TVResponsiveUtils.sp(context, 20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text.rich(
                                subtitleRichSpan(
                                  widget.subtitle2!,
                                  TextStyle(
                                    color: Colors.white,
                                    fontSize: TVResponsiveUtils.sp(context, 13),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
