import 'package:flutter/material.dart';
import '../../../core/constants/auris_icons.dart';
import '../../widgets/auris_icon.dart';

/// Bloque de metadatos del episodio para la WatchScreen (Estilo Crunchyroll).
///
/// Muestra:
/// - Título de la Serie + Botón de Marcador/Favorito.
/// - Título y Número del Episodio.
/// - Badges: Edad ("16+"), Formato ("Sub | Dob").
/// - Fecha de Lanzamiento.
class WatchEpisodeMetadata extends StatelessWidget {
  const WatchEpisodeMetadata({
    super.key,
    required this.seriesTitle,
    required this.episodeTitle,
    required this.episodeNumber,
    this.ratingBadge = '16+',
    this.audioSubsBadge = 'Sub | Dob',
    this.releaseDate,
    this.isBookmarked = false,
    this.onBookmarkToggle,
  });

  final String seriesTitle;
  final String episodeTitle;
  final String episodeNumber;
  final String ratingBadge;
  final String audioSubsBadge;
  final String? releaseDate;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Título de la Serie + Marcador/Favorito
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                seriesTitle,
                style: TextStyle(
                  color: const Color(0xFFEF7A1E), // Naranja AurisTV
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onBookmarkToggle,
              icon: AurisIcon(
                isBookmarked ? AurisIcons.bookmarkFilled : AurisIcons.bookmark,
                color: isBookmarked ? const Color(0xFFEF7A1E) : Colors.white70,
                size: 24,
              ),
              tooltip: isBookmarked ? 'Quitar de Mi Lista' : 'Guardar en Mi Lista',
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Fila 2: Número y Título del Episodio
        Text(
          episodeNumber.isNotEmpty ? '$episodeNumber - $episodeTitle' : episodeTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),

        const SizedBox(height: 10),

        // Fila 3: Badges + Fecha de Lanzamiento
        Row(
          children: [
            // Badge de Edad (Ej. 16+)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Text(
                ratingBadge,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Badge de Audio / Subtítulos
            Row(
              children: [
                const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFFEF7A1E)),
                const SizedBox(width: 6),
                Text(
                  audioSubsBadge,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        if (releaseDate != null && releaseDate!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Lanzado el $releaseDate',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}
