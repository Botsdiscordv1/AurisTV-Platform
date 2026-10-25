import 'package:flutter/material.dart';
import '../../auris_core.dart';
import 'cured_network_image.dart';

/// Tarjeta visual compartida para eventos deportivos (`ContentSports`) en todas las plataformas (Móvil, TV, Web).
/// Diseño compacto estilo "Compactos" / ESPN con thumbnail 16:9 de ~200px, 5.5 tarjetas en viewport y 3 líneas de texto inferiores.
class SportsCard extends StatefulWidget {
  final ContentSports event;
  final VoidCallback? onTap;
  final ValueChanged<Map<String, dynamic>>? onChannelSelected;
  final bool isFocused;
  final double? width;
  final double? height;

  const SportsCard({
    super.key,
    required this.event,
    this.onTap,
    this.onChannelSelected,
    this.isFocused = false,
    this.width,
    this.height,
  });

  @override
  State<SportsCard> createState() => _SportsCardState();
}

class _SportsCardState extends State<SportsCard> {
  bool _localFocused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool focused = widget.isFocused || _localFocused || _hovered;
    final isLive = widget.event.viewers > 0 || (widget.event.channels.isNotEmpty);

    final leagueText = widget.event.league ?? widget.event.sportLabel ?? 'Deportes';
    final yearVal = DateTime.now().year;
    final subtitleText = '$leagueText • $yearVal';
    final dateText = isLive 
        ? 'Transmitiéndose ahora' 
        : 'Transmitido el ${DateTime.now().day} de oct. de $yearVal';

    // Ancho compacto responsivo: ~210px en desktop (5 completos + 1 medio visible = divisor 5.5)
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = widget.width ?? (screenWidth / 5.5).clamp(170.0, 220.0);

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (f) => setState(() => _localFocused = f),
        child: GestureDetector(
          onTap: widget.onTap ?? () {
            debugPrint('[SportsCard] Tapped sports card -> Opening ContentSportScreen for: "${widget.event.title}"');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ContentSportScreen(
                  event: widget.event,
                  onChannelSelected: widget.onChannelSelected,
                ),
              ),
            );
          },
          child: Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Thumbnail 16:9 pequeño con escala 1.05 al foco y borde blanco sin glow
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedScale(
                    scale: focused ? 1.0 : 0.98,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutQuint,
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutQuint,
                      padding: EdgeInsets.zero,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CuredNetworkImage(
                              imageUrl: widget.event.bannerUrl.isNotEmpty 
                                  ? widget.event.bannerUrl 
                                  : widget.event.posterUrl,
                              fit: BoxFit.cover,
                            ),
                            // Gradiente sutil inferior
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.35),
                                  ],
                                ),
                              ),
                            ),
                            // Badge VIVO / Próximamente en esquina inferior izquierda
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: isLive
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.fiber_manual_record, color: Colors.white, size: 6),
                                          SizedBox(width: 3),
                                          Text(
                                            'VIVO',
                                            style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0071EB),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'Próximamente',
                                        style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                            if (focused)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white, width: 4.0),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // 2. Línea 1: Fecha / Estado (Gris muy pequeño)
                Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                // 3. Línea 2: Título principal en negrita (hasta 2 líneas si es largo)
                Text(
                  widget.event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                // 4. Línea 3: Liga / Deporte y Año
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFA5A5AA),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
