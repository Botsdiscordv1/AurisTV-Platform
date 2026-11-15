import 'package:flutter/material.dart';
import '../../../core/constants/auris_icons.dart';
import '../../../core/utils/string_utils.dart';
import '../../../data/models/server/episodes_response.dart';
import '../../widgets/auris_icon.dart';
import '../../widgets/cured_network_image.dart';

/// Barra lateral / Cola de reproducción para Web, Desktop y Tablet.
///
/// Muestra la lista de episodios siguientes y disponibles de la serie.
/// Estilo:
/// - Contenedor exterior: `#0F0F0F` con borde redondeado `Colors.white10`
/// - Encabezado "Episodios": `#212121` con AurisIcon(AurisIcons.episodes)
/// - Filas de episodios: Continuas sin 1px de separación entre tarjetas.
class WatchPlaylistSidebar extends StatelessWidget {
  const WatchPlaylistSidebar({
    super.key,
    required this.episodes,
    required this.activeEpisode,
    required this.onEpisodeSelected,
    this.title = 'Episodios',
  });

  final List<EpisodeInfo> episodes;
  final String activeEpisode;
  final ValueChanged<EpisodeInfo> onEpisodeSelected;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F), // Fondo del contenedor exterior #0F0F0F
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado "Episodios" con fondo #212121
          Container(
            color: const Color(0xFF212121),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                AurisIcon(
                  AurisIcons.episodes,
                  color: const Color(0xFFEF7A1E),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${episodes.length} episodios',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Episodios continua (0px de separación entre elementos)
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final ep = episodes[index];
                final bool isActive = ep.number.toString() == activeEpisode;
                final String formattedEpTitle = formatEpisodeTitle(ep.number, ep.title);

                // Duración
                String durationStr = (ep.duration != null && ep.duration!.isNotEmpty)
                    ? ep.duration!
                    : (ep.runtime != null ? '${ep.runtime} min' : '');

                if (durationStr.isEmpty) {
                  durationStr = '24 min';
                } else if (!durationStr.contains('min') && !durationStr.contains('m')) {
                  final parsed = int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (parsed != null) {
                    durationStr = '$parsed min';
                  }
                }

                // Fecha de Lanzamiento o Calidad
                String? secondaryMeta;
                if (ep.airDate != null && ep.airDate!.isNotEmpty) {
                  secondaryMeta = formatDisplayDate(ep.airDate);
                } else if (ep.quality != null && ep.quality!.isNotEmpty) {
                  secondaryMeta = ep.quality;
                }

                final String metaLine = [durationStr, secondaryMeta]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(' • ');

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onEpisodeSelected(ep),
                    borderRadius: BorderRadius.zero,
                    hoverColor: Colors.white.withValues(alpha: 0.08),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFEF7A1E).withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.zero,
                        border: isActive
                            ? const Border(
                                left: BorderSide(color: Color(0xFFEF7A1E), width: 3.5),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 124,
                              height: 70,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ep.thumbnail != null && ep.thumbnail!.isNotEmpty
                                        ? Builder(
                                            builder: (ctx) {
                                              final dpr = MediaQuery.maybeDevicePixelRatioOf(ctx) ?? 1.0;
                                              return CuredNetworkImage(
                                                imageUrl: ep.thumbnail!,
                                                fit: BoxFit.cover,
                                                memCacheWidth: (124 * dpr).round().clamp(1, 1024),
                                                memCacheHeight: (70 * dpr).round().clamp(1, 1024),
                                              );
                                            },
                                          )
                                        : Container(
                                            color: Colors.white10,
                                            child: const Icon(Icons.movie_outlined,
                                                color: Colors.white38, size: 22),
                                          ),
                                  ),
                                  if (isActive)
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF7A1E),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'VIENDO',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedEpTitle,
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFFEF7A1E)
                                        : Colors.white,
                                    fontSize: 12.5,
                                    fontWeight:
                                        isActive ? FontWeight.bold : FontWeight.w600,
                                    height: 1.25,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (metaLine.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    metaLine,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
