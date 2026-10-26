import 'package:flutter/material.dart';
import '../../auris_core.dart';
import 'disney_focus.dart';

/// Tarjeta visual compartida para eventos deportivos (`ContentSports`) con el estándar exacto
/// de Disney+ (DisneyFocusShell, DisneyFocusTokens, sombras duales, escala 1.03, anillo de focus
/// y comportamiento responsive idéntico a SportsBrandCarousel).
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

  double _cardWidth(double vw) {
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
    return vw * frac - 5.0;
  }

  @override
  Widget build(BuildContext context) {
    final bool focused = widget.isFocused || _localFocused || _hovered;

    final ContentSports ev = widget.event;
    final bool isLive = ev.effectiveIsLive;
    final String statusLabel = ev.statusLabel;   // 'EN VIVO' | 'PRÓXIMO' | 'FINALIZADO'
    final bool isFinished = statusLabel == 'FINALIZADO';

    final String leagueText = ev.league ?? ev.sportLabel ?? 'Deportes';
    final String? sportLabel = (ev.sportLabel != null && ev.league != null) ? ev.sportLabel : null;
    final String subtitleText = (sportLabel != null) ? '$leagueText • $sportLabel' : leagueText;

    final String dateText = _buildDateText(ev, isLive, isFinished);

    final double vw = MediaQuery.sizeOf(context).width;
    final double cardWidth = widget.width ?? _cardWidth(vw);
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
            margin: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Thumbnail 16:9 con DisneyFocusShell idéntico a SportsBrandCarousel
                AspectRatio(
                  aspectRatio: 1.78, // 16:9 ratio (1.78)
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
                                  Colors.black.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                          ),
                          // Badge de estado
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
                const SizedBox(height: 18),
                // 2. Línea 1: Fecha / Estado
                Text(
                  dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                // 3. Línea 2: Título principal
                Text(
                  widget.event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // 5. Chips de canal
                if (channels.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final Map<String, dynamic> channel;

  const _ChannelChip({required this.channel});

  @override
  Widget build(BuildContext context) {
    final name = channel['name']?.toString() ?? 'Canal';
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF28282E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
