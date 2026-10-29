import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';

/// Ajustes > Listas añadidas > [playlistId] (Móvil).
///
/// Lista de canales con buscador; al pulsar un canal se abre el player en
/// modo directo (sin extracción) y en vivo (sin historial).
class PlaylistChannelsScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistChannelsScreen({super.key, required this.playlistId});

  /// Abre un canal en el player.
  ///
  /// Receta de reproducción directa: `source` vacío + `url` del stream (ramas
  /// direct-play de los 3 players), `category=movie` para comportamiento de
  /// peli (sin episodios), `isLive=1` (sin historial) y `skipResume=1`.
  void _openChannel(BuildContext context, PlaylistChannel channel) {
    final contentId = M3uParser.stableId(channel.url);
    final uri = Uri(
      path: '/player/$contentId',
      queryParameters: {
        'source': '',
        'url': channel.url,
        'category': 'movie',
        'title': channel.title,
        'isLive': '1',
        'skipResume': '1',
        if (channel.logo != null && channel.logo!.isNotEmpty) ...{
          'logoUrl': channel.logo!,
          'posterUrl': channel.logo!,
        },
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(playlistByIdProvider(playlistId));

    if (playlist == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Lista'),
          backgroundColor: const Color(0xFF000000),
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(
          child: Text(
            'Esta lista ya no existe',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(playlist.name),
        backgroundColor: const Color(0xFF000000),
        surfaceTintColor: Colors.transparent,
      ),
      body: PlaylistChannelsContent(
        playlist: playlist,
        onChannelTap: (channel) => _openChannel(context, channel),
      ),
    );
  }
}
