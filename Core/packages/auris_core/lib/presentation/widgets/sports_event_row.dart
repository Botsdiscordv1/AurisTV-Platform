import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import '../../auris_core.dart';

/// Fila horizontal de eventos deportivos (`ContentSports`) para el Home,
/// utilizando exactamente los mismos valores de padding exterior (`vw * 0.035 + 24`)
/// y separación entre tarjetas (`20px` de hueco visual) que `SportsBrandCarousel`.
class SportsEventRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ContentSports> events;
  final void Function(ContentSports event)? onEventTap;
  final double? horizontalPadding;

  const SportsEventRow({
    super.key,
    required this.title,
    required this.events,
    this.subtitle,
    this.onEventTap,
    this.horizontalPadding,
  });

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
    if (events.isEmpty) return const SizedBox.shrink();

    final double vw = MediaQuery.sizeOf(context).width;
    final double edgePad = horizontalPadding ?? (vw * 0.035 + 24);
    final double cardWidth = _cardWidth(vw);

    return Padding(
      padding: EdgeInsets.only(bottom: context.useMobileLayout ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: edgePad),
            child: Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveUtils.rowTitleFontSize(context),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: edgePad),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: cardWidth / (1.78) + 160, // Holgura ampliada para las fuentes de 14px y 16px
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: edgePad, vertical: 12),
              physics: const ClampingScrollPhysics(),
              scrollCacheExtent: ScrollCacheExtent.pixels(600),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10), // 10px de separación visual
              itemBuilder: (context, index) {
                final ev = events[index];
                return SportsCard(
                  key: ValueKey('sports_${ev.id}_$index'),
                  event: ev,
                  width: cardWidth,
                  onTap: onEventTap != null ? () => onEventTap!(ev) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
