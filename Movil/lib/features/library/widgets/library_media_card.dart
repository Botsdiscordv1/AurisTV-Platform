import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';

class LibraryMediaCard extends StatelessWidget {
  final FavoriteItem item;
  const LibraryMediaCard({super.key, required this.item});

  String _getDisplayCategory(FavoriteItem item) {
    final source = item.source.toLowerCase();
    const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
    const animeHints = ['jkanime', 'animeav1', 'animeflv', 'aniyae', 'animelatino', 'fiuzidragon', 'tioanime', 'animed23', 'animejara', 'katanime', 'animegratis'];
    const movieHints = ['gnula', 'gnulahd'];

    if (kdramaHints.any((h) => source.contains(h))) return 'KDRAMA';
    if (animeHints.any((h) => source.contains(h))) return 'ANIME';
    if (movieHints.any((h) => source.contains(h))) {
      if (item.category.toLowerCase().contains('anime')) return 'ANIME';
      return 'Película';
    }
    final cat = item.category.toLowerCase();
    if (cat.contains('movie') || cat.contains('pelicula')) return 'Película';
    if (cat.contains('serie') || cat.contains('tv')) return 'SERIE';
    return item.category.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final uri = '/content/${Uri.encodeComponent(item.title)}?source=${Uri.encodeComponent(item.source)}&category=${Uri.encodeComponent(item.category)}&url=${Uri.encodeComponent(item.url)}&metadataTitle=${Uri.encodeComponent(item.title)}&banner=${Uri.encodeComponent(item.bannerUrl)}';
        context.push(uri);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: ApiEndpoints.proxyImage(item.posterUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (_, __) => Container(color: Colors.white10),
                  errorWidget: (_, __, ___) => Container(color: Colors.white10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          Text(_getDisplayCategory(item), style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
