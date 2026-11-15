import 'package:flutter/material.dart';
import '../../../core/constants/auris_icons.dart';
import '../../../core/utils/string_utils.dart';
import '../../widgets/auris_icon.dart';

/// Bloque de metadatos del episodio para la WatchScreen (Estilo Crunchyroll).
///
/// Muestra:
/// - Título de la Serie (Opcional si WatchTopBar está visible).
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
    this.showSeriesTitle,
  });

  final String seriesTitle;
  final String episodeTitle;
  final String episodeNumber;
  final String ratingBadge;
  final String audioSubsBadge;
  final String? releaseDate;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;
  final bool? showSeriesTitle;

  @override
  Widget build(BuildContext context) {
    final bool isDesktopTablet = MediaQuery.sizeOf(context).width >= 768;
    final bool shouldShowSeriesTitle = showSeriesTitle ?? !isDesktopTablet;

    final int? epNum = int.tryParse(episodeNumber.replaceAll(RegExp(r'[^0-9]'), ''));

    final String fullEpTitle = (epNum != null && epNum > 0)
        ? AurisStringUtils.formatEpisodeTitle(epNum, episodeTitle)
        : ((episodeNumber.isNotEmpty && episodeNumber != 'Película')
            ? '$episodeNumber - $episodeTitle'
            : episodeTitle);

    final Widget bookmarkButton = IconButton(
      onPressed: onBookmarkToggle,
      icon: AurisIcon(
        isBookmarked ? AurisIcons.bookmarkFilled : AurisIcons.bookmark,
        color: isBookmarked ? const Color(0xFFEF7A1E) : Colors.white70,
        size: 24,
      ),
      tooltip: isBookmarked ? 'Quitar de Mi Lista' : 'Guardar en Mi Lista',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shouldShowSeriesTitle) ...[
          // Fila 1 (Móvil): Título Naranja de la Serie + Marcador/Favorito
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  seriesTitle,
                  style: const TextStyle(
                    color: Color(0xFFEF7A1E), // Naranja AurisTV
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              bookmarkButton,
            ],
          ),
          const SizedBox(height: 4),
          // Fila 2 (Móvil): Número y Título del Episodio
          Text(
            fullEpTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
        ] else ...[
          // Fila 1 (Desktop/Tablet): Número y Título del Episodio + Marcador/Favorito
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  fullEpTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
              ),
              bookmarkButton,
            ],
          ),
        ],

        const SizedBox(height: 10),

        // Fila 2: Badges (Clasificación + Fecha de Lanzamiento / Audio-Sub)
        Builder(
          builder: (context) {
            final bool hasReleaseDate = releaseDate != null &&
                releaseDate!.isNotEmpty &&
                releaseDate != 'N/A';

            final String displayBadgeText = hasReleaseDate
                ? (releaseDate!.toLowerCase().startsWith('lanzado')
                    ? releaseDate!
                    : 'Lanzado el $releaseDate')
                : audioSubsBadge;

            return Row(
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Badge de Fecha de Lanzamiento (o Audio / Subtítulos si no hay fecha)
                Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFFEF7A1E)),
                    const SizedBox(width: 6),
                    Text(
                      displayBadgeText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
