import 'package:flutter/material.dart';
import '../../../core/utils/string_utils.dart';
import '../../widgets/cured_network_image.dart';

/// Tarjeta de navegación de episodio para la WatchScreen (Estilo Crunchyroll).
///
/// Utilizada para las secciones "SIGUIENTE EPISODIO" y "EPISODIO ANTERIOR".
class WatchNavCard extends StatelessWidget {
  const WatchNavCard({
    super.key,
    required this.sectionLabel,
    required this.episodeNumber,
    required this.episodeTitle,
    this.thumbnailUrl,
    this.duration,
    this.audioSubsBadge = 'Dob | Sub',
    this.onTap,
    this.labelFontSize = 12.0,
    this.labelFontWeight = FontWeight.w800,
    this.labelLetterSpacing = 1.2,
  });

  final String sectionLabel;
  final String episodeNumber;
  final String episodeTitle;
  final String? thumbnailUrl;
  final String? duration;
  final String audioSubsBadge;
  final VoidCallback? onTap;
  final double labelFontSize;
  final FontWeight labelFontWeight;
  final double labelLetterSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 12),
          child: Text(
            sectionLabel.toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontSize: labelFontSize,
              fontWeight: labelFontWeight,
              letterSpacing: labelLetterSpacing,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                // Miniatura 16:9 con insignia de duración
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 68,
                        child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                            ? Builder(
                                builder: (ctx) {
                                  final dpr = MediaQuery.maybeDevicePixelRatioOf(ctx) ?? 1.0;
                                  return CuredNetworkImage(
                                    imageUrl: thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: (120 * dpr).round().clamp(1, 1024),
                                    memCacheHeight: (68 * dpr).round().clamp(1, 1024),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.white10,
                                child: const Icon(Icons.movie_outlined, color: Colors.white38),
                              ),
                      ),
                      if (duration != null && duration!.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              duration!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Metadatos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (_) {
                          final int epNum = int.tryParse(episodeNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          final String displayTitle = AurisStringUtils.formatEpisodeTitle(epNum, episodeTitle);
                          return Text(
                            displayTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        audioSubsBadge,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, color: Colors.white38, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
