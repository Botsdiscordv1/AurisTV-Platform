import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';

class LibraryMediaCard extends ConsumerWidget {
  final FavoriteItem item;
  const LibraryMediaCard({super.key, required this.item});

  void _openDetail(BuildContext context) {
    // URI completa (kind/year/type/season) + seed: sin esto el discovery
    // perdía el servidor y el detalle abría sin fuentes.
    final uri = '/content/${Uri.encodeComponent(item.title)}'
        '?source=${Uri.encodeComponent(item.source)}'
        '&category=${Uri.encodeComponent(item.category)}'
        '&url=${Uri.encodeComponent(item.url)}'
        '${item.season != null ? '&season=${item.season}' : ''}'
        '${item.year != null ? '&year=${item.year}' : ''}'
        '${item.kind != null && item.kind!.isNotEmpty ? '&kind=${Uri.encodeComponent(item.kind!)}' : ''}'
        '${item.type != null && item.type!.isNotEmpty ? '&type=${Uri.encodeComponent(item.type!)}' : ''}'
        '&metadataTitle=${Uri.encodeComponent(item.title)}&banner=${Uri.encodeComponent(item.bannerUrl)}';
    context.push(uri, extra: seedFromFavorite(item));
  }

  /// Menú long-press: ver detalles / quitar (con Deshacer). El borrado
  /// directo sin confirmar se dispara por accidente (scroll, niños, mando).
  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2D2D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white70),
              title: const Text('Ver detalles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _openDetail(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: Colors.redAccent),
              title: const Text('Quitar de Mi lista', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(favoritesProvider.notifier).toggleFavorite(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Quitado de Mi lista'),
                    action: SnackBarAction(
                      label: 'Deshacer',
                      onPressed: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(item);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: () => _showOptionsMenu(context, ref),
      child: FocusablePosterCard(
        key: ValueKey(item.url),
        title: item.title,
        posterUrl: item.posterUrl,
        showInfo: true,
        onTap: () => _openDetail(context),
      ),
    );
  }
}
