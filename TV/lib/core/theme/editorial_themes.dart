import 'package:flutter/material.dart';
import 'package:auris_core/auris_core.dart';

class EditorialBadgeTheme {
  final Color primary;
  final Color secondary;
  final IconData icon;
  final String label;
  final List<Color> shimmerColors;

  const EditorialBadgeTheme({
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.label,
    required this.shimmerColors,
  });

  static EditorialBadgeTheme getTheme(EditorialBadge badge) {
    switch (badge) {
      case EditorialBadge.mythical:
        return EditorialBadgeTheme(
          primary: const Color(0xFFFFD700), // Gold
          secondary: const Color(0xFFFFA000), // Amber
          icon: Icons.star_rounded,
          label: 'MÍTICO',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFFFECB3).withOpacity(0.2),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.masterpiece:
        return EditorialBadgeTheme(
          primary: const Color(0xFF7C3AED), // Purple (Prestigio)
          secondary: const Color(0xFFC084FC), // Lavender
          icon: Icons.workspace_premium_rounded,
          label: 'OBRA MAESTRA',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFE9D5FF).withOpacity(0.15),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.hiddenGem:
        return EditorialBadgeTheme(
          primary: const Color(0xFF00CED1), // Turquoise (Descubrimiento)
          secondary: const Color(0xFF22D3EE), // Cyan
          icon: Icons.diamond_rounded,
          label: 'JOYA OCULTA',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFCFFAFE).withOpacity(0.3),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.essential:
        return EditorialBadgeTheme(
          primary: const Color(0xFFFF4500), // Orange Red (Potencia)
          secondary: const Color(0xFFF87171), // Red
          icon: Icons.local_fire_department_rounded,
          label: 'IMPRESCINDIBLE',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFFECACA).withOpacity(0.4),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.favorite:
        return EditorialBadgeTheme(
          primary: const Color(0xFFFF1493), // Deep Pink (Cercanía)
          secondary: const Color(0xFFF472B6), // Pink
          icon: Icons.favorite_rounded,
          label: 'FAVORITO',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFFCE7F3).withOpacity(0.3),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.awardWinner:
        return EditorialBadgeTheme(
          primary: const Color(0xFF1E90FF), // Dodger Blue (Reconocimiento)
          secondary: const Color(0xFF60A5FA), // Light Blue
          icon: Icons.emoji_events_rounded,
          label: 'PREMIADO',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFDBEAFE).withOpacity(0.3),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.classic:
        return EditorialBadgeTheme(
          primary: const Color(0xFF00A86B), // Jade (Atemporal)
          secondary: const Color(0xFF34D399), // Emerald
          icon: Icons.auto_awesome_rounded,
          label: 'CLÁSICO',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFD1FAE5).withOpacity(0.3),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.starter:
        return EditorialBadgeTheme(
          primary: const Color(0xFFADFF2F), // Green Yellow (Energía de inicio)
          secondary: const Color(0xFF32CD32), // Lime Green
          icon: Icons.rocket_launch_rounded,
          label: 'PARA EMPEZAR',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            const Color(0xFFF7FEE7).withOpacity(0.4),
            Colors.white.withOpacity(0.0),
          ],
        );
      case EditorialBadge.movieEssential:
        return EditorialBadgeTheme(
          primary: const Color(0xFFE5E7EB), // Platinum/Silver (Elegancia de cine)
          secondary: const Color(0xFF9CA3AF), // Gray
          icon: Icons.movie_filter_rounded,
          label: 'CINE CULTO',
          shimmerColors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.0),
          ],
        );
    }
  }
}
