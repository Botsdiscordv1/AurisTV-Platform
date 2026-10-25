import 'package:flutter/material.dart';
import '../../auris_core.dart';
import 'cured_network_image.dart';

/// Tarjeta visual compartida para eventos deportivos (`ContentSports`) en todas las plataformas (Móvil, TV, Web).
/// Diseñada sin TABS, con indicador visual en vivo, equipos, liga y selector de canales.
class ContentSportsCard extends StatefulWidget {
  final ContentSports event;
  final VoidCallback? onTap;
  final ValueChanged<Map<String, dynamic>>? onChannelSelected;
  final bool isFocused;

  const ContentSportsCard({
    super.key,
    required this.event,
    this.onTap,
    this.onChannelSelected,
    this.isFocused = false,
  });

  @override
  State<ContentSportsCard> createState() => _ContentSportsCardState();
}

class _ContentSportsCardState extends State<ContentSportsCard> {
  bool _localFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool focused = widget.isFocused || _localFocused;
    final isLive = widget.event.viewers > 0 || (widget.event.channels.isNotEmpty);

    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _localFocused = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: focused ? Matrix4.diagonal3Values(1.03, 1.03, 1.0) : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focused ? const Color(0xFFEF7A1E) : Colors.white24,
              width: focused ? 2.5 : 1.0,
            ),
            boxShadow: focused
                ? [const BoxShadow(color: Color(0x66EF7A1E), blurRadius: 12, spreadRadius: 2)]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Imagen de fondo (Banner o Poster)
                CuredNetworkImage(
                  imageUrl: widget.event.bannerUrl.isNotEmpty 
                      ? widget.event.bannerUrl 
                      : widget.event.posterUrl,
                  fit: BoxFit.cover,
                ),
                // Gradiente oscuro para legibilidad
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
                // Contenido de texto y badges
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header con Badge EN VIVO / Liga
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                                  SizedBox(width: 4),
                                  Text(
                                    'EN VIVO',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.event.sportLabel ?? 'Deportes',
                                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (widget.event.league != null)
                            Text(
                              widget.event.league!,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                        ],
                      ),
                      // Título y Equipos
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.event.teams.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.event.teams.join(' vs '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
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
