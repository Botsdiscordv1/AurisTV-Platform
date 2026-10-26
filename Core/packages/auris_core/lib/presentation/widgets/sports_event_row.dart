import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import '../../auris_core.dart';

/// Fila horizontal de eventos deportivos (`ContentSports`) para el Home.
///
/// Pinta directamente los `ContentSports` originales (con `isLive`, `status`,
/// `date`, `league`, `colors`, canales decorados…) SIN pasar por `MediaItem`,
/// para no perder la metadata que envía el backend.
///
/// Se usa desde `_buildSection` cuando `section.sportsItems != null`.
class SportsEventRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ContentSports> events;
  final void Function(ContentSports event)? onEventTap;
  final double horizontalPadding;

  const SportsEventRow({
    super.key,
    required this.title,
    required this.events,
    this.subtitle,
    this.onEventTap,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = (screenWidth / 5.5).clamp(170.0, 220.0);

    return Padding(
      padding: EdgeInsets.only(bottom: context.useMobileLayout ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
            height: cardWidth / (16 / 9) + 90, // thumbnail 16:9 + 3 líneas de texto
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              physics: const ClampingScrollPhysics(),
              scrollCacheExtent: ScrollCacheExtent.pixels(600),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
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
