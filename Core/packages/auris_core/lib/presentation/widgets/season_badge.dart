import 'package:flutter/material.dart';

/// Un badge pequeño para mostrar el número de temporada (S2, S3, etc.)
/// en overlays de tarjetas de búsqueda o recomendaciones.
class SeasonBadge extends StatelessWidget {
  final int season;
  final Color? color;

  const SeasonBadge({
    super.key,
    required this.season,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (season <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        'S$season',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
