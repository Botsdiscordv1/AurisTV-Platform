import 'package:flutter/material.dart';
import '../../../data/models/server/episodes_response.dart';
import '../../widgets/cured_network_image.dart';

/// Barra lateral / Cola de reproducción para Web, Desktop y Tablet.
///
/// Muestra la lista de episodios siguientes y disponibles de la serie.
class WatchPlaylistSidebar extends StatelessWidget {
  const WatchPlaylistSidebar({
    super.key,
    required this.episodes,
    required this.activeEpisode,
    required this.onEpisodeSelected,
    this.title = 'A continuación',
  });

  final List<EpisodeInfo> episodes;
  final String activeEpisode;
  final ValueChanged<EpisodeInfo> onEpisodeSelected;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_play, color: Color(0xFFEF7A1E), size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${episodes.length} episodios',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: episodes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ep = episodes[index];
                final bool isActive = ep.number.toString() == activeEpisode;

                return InkWell(
                  onTap: () => onEpisodeSelected(ep),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFEF7A1E).withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? const Color(0xFFEF7A1E) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 90,
                            height: 52,
                            child: ep.thumbnail != null && ep.thumbnail!.isNotEmpty
                                ? CuredNetworkImage(
                                    imageUrl: ep.thumbnail!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.movie, color: Colors.white38, size: 20),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'E${ep.number} - ${(ep.title != null && ep.title!.isNotEmpty) ? ep.title! : "Episodio ${ep.number}"}',
                                style: TextStyle(
                                  color: isActive ? const Color(0xFFEF7A1E) : Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
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
