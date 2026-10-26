import 'package:flutter/material.dart';
import '../../auris_core.dart';

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

    // El BACKEND calcula el estado real: usar event.isLive/status, NUNCA
    // recalcular con viewers/channels (daba falsos positivos en próximos).
    final ContentSports ev = widget.event;
    final bool isLive = ev.effectiveIsLive;
    final String statusLabel = ev.statusLabel;   // 'EN VIVO' | 'PRÓXIMO' | 'FINALIZADO'
    final bool isFinished = statusLabel == 'FINALIZADO';

    // Liga / deporte (etiqueta del backend)
    final String leagueText = ev.league ?? ev.sportLabel ?? 'Deportes';
    final String? sportLabel = (ev.sportLabel != null && ev.league != null) ? ev.sportLabel : null;
    final String subtitleText = (sportLabel != null) ? '$leagueText • $sportLabel' : leagueText;

    // Fecha/hora REAL del encuentro (del backend), no DateTime.now()
    final String dateText = _buildDateText(ev, isLive, isFinished);

    // Ancho compacto responsivo: ~210px en desktop (5 completos + 1 medio visible = divisor 5.5)
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = widget.width ?? (screenWidth / 5.5).clamp(170.0, 220.0);

    // Canales decorados (con logo/iniciales) para los chips del pie
    final List<Map<String, dynamic>> channels = ev.channels;

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
                // 1. Thumbnail 16:9 con tratamiento Disney+ (scale 1.03,
                // anillo 4px a 4px, sombra dual ≥768, 300ms cubic-bezier(0,0,.2,1))
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: DisneyFocusShell(
                    active: focused,
                    activeShadow: DisneyFocusTokens.shadowFor(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DisneyFocusTokens.radius),
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
                                    Colors.black.withValues(alpha: 0.35),
                                  ],
                                ),
                              ),
                            ),
                            // Badge de estado en esquina inferior izquierda (VIVO / PRÓXIMO / FINALIZADO)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: _StatusBadge(isLive: isLive, isFinished: isFinished),
                            ),
                          ],
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
                // 4. Línea 3: Liga / Deporte
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
                // 5. Chips de canal (logo o iniciales) — solo si hay canales
                if (channels.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: channels.take(3).map((c) => _ChannelChip(channel: c)).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Texto de fecha/estado basado en los campos REALES del backend.
  String _buildDateText(ContentSports ev, bool isLive, bool isFinished) {
    if (isLive) return 'En vivo ahora';
    final DateTime? start = ev.startsAtDate;
    if (start == null) {
      return isFinished ? 'Finalizado' : 'Próximamente';
    }
    final String hh = start.hour.toString().padLeft(2, '0');
    final String mm = start.minute.toString().padLeft(2, '0');
    final String day = start.day.toString().padLeft(2, '0');
    const List<String> months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final String mon = months[start.month - 1];
    if (isFinished) return 'Finalizado • $day $mon';
    return '$day $mon • $hh:$mm';
  }
}

/// Badge de estado compacto: VIVO (rojo) / PRÓXIMO (azul) / FINALIZADO (gris).
class _StatusBadge extends StatelessWidget {
  final bool isLive;
  final bool isFinished;

  const _StatusBadge({required this.isLive, required this.isFinished});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String text;
    if (isLive) {
      bg = const Color(0xFFE50914);
      text = 'VIVO';
    } else if (isFinished) {
      bg = const Color(0xFF66666E);
      text = 'FINAL';
    } else {
      bg = const Color(0xFF0071EB);
      text = 'PRÓXIMO';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3)),
      child: isLive
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.white, size: 6),
                const SizedBox(width: 3),
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
              ],
            )
          : Text(text, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
    );
  }
}

/// Chip de canal con logo (resuelto contra sportsBaseUrl) o fallback de iniciales.
class _ChannelChip extends StatelessWidget {
  final Map<String, dynamic> channel;

  const _ChannelChip({required this.channel});

  @override
  Widget build(BuildContext context) {
    final String name = channel['name']?.toString() ?? '';
    final String? logo = channel['logo']?.toString();
    final String initials = channel['initials']?.toString() ?? _deriveInitials(name);

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: (logo != null && logo.isNotEmpty)
          ? SizedBox(
              height: 12,
              child: CuredNetworkImage(
                imageUrl: ApiEndpoints.sportsUrl(logo),
                fit: BoxFit.contain,
              ),
            )
          : Text(
              initials,
              style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
            ),
    );
  }

  String _deriveInitials(String n) {
    final words = n.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').trim().split(RegExp(r'\s+'));
    final initials = words.map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    return initials.length > 4 ? initials.substring(0, 4) : initials;
  }
}
