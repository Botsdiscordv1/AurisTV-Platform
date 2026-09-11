import 'package:flutter/material.dart';

/// Un badge para mostrar el número de temporada (S2, S3, etc.)
/// en la esquina de las tarjetas de búsqueda.
class SeasonBadge extends StatelessWidget {
  final int season;
  final Color? color;
  final BorderRadius? borderRadius;

  const SeasonBadge({
    super.key,
    required this.season,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (season <= 1) return const SizedBox.shrink();

    final brandOrange = const Color(0xFFEF7A1E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? brandOrange.withOpacity(0.9),
        borderRadius: borderRadius ?? const BorderRadius.only(topLeft: Radius.circular(8)),
        // Senior Pixel-Perfect Fix: Eliminamos el redondeo bottomRight para que el padre lo recorte.
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        'S$season',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
