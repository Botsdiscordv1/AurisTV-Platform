import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/url_utils.dart';
import '../../player/presentation/player_screen.dart';

/// Ajustes > Listas añadidas > [playlistId] (Web / Desktop).
///
/// Lista de canales con buscador; al pulsar un canal se abre el player en
/// modo directo (sin extracción) y en vivo (sin historial).
class PlaylistChannelsScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistChannelsScreen({super.key, required this.playlistId});

  /// Abre un canal en el player (diálogo a pantalla completa de Web).
  ///
  /// Receta de reproducción directa: `source` vacío + `sourceUrl` (rama
  /// direct-play), `category=movie`, `isLive` y `skipResume` para que no
  /// escriba historial ni proponga reanudar.
  void _openChannel(BuildContext context, PlaylistChannel channel) {
    final player = PlayerScreen(
      contentId: M3uParser.stableId(channel.url),
      sourceUrl: channel.url,
      source: '',
      category: 'movie',
      title: channel.title,
      logoUrl: channel.logo,
      posterUrl: channel.logo,
      isLive: true,
      skipResume: true,
    );
    UrlUtils.openPlayer(context, player);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(playlistByIdProvider(playlistId));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(playlist?.name ?? 'Lista'),
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
      ),
      body: playlist == null
          ? const Center(
              child: Text(
                'Esta lista ya no existe',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: PlaylistChannelsContent(
                  playlist: playlist,
                  onChannelTap: (channel) => _openChannel(context, channel),
                ),
              ),
            ),
    );
  }
}
