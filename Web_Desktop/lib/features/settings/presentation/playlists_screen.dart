import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';

/// Ajustes > Listas añadidas (Web / Desktop).
///
/// Muestra las listas integradas y las del usuario; al pulsar una lista se
/// abre su detalle de canales en `/settings/listas/:playlistId`.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Listas añadidas'),
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: PlaylistListsContent(
            onOpenList: (playlist) =>
                context.go('/settings/listas/${playlist.id}'),
          ),
        ),
      ),
    );
  }
}
