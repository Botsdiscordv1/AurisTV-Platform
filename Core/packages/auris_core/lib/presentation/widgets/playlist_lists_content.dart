import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/builtin_playlists.dart';
import '../../data/models/user_playlist.dart';
import '../../data/providers/playlists_provider.dart';

/// Contenido de Ajustes > "Listas añadidas" (Móvil y Web).
///
/// Muestra las listas integradas y las del usuario, permite añadir una lista
/// nueva (diálogo nombre + URL) y eliminar las del usuario. La navegación al
/// detalle de canales se delega en [onOpenList] para que cada app use su
/// propio router.
class PlaylistListsContent extends ConsumerWidget {
  final void Function(UserPlaylist playlist) onOpenList;

  const PlaylistListsContent({super.key, required this.onOpenList});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistsProvider);
    final userLists = state.userLists;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _addTile(context, ref),
        _header('Integradas · ${BuiltinPlaylists.all.length}'),
        _card(
          children: [
            for (final playlist in BuiltinPlaylists.all)
              _playlistTile(context, ref, playlist),
          ],
        ),
        _header('Tus listas · ${userLists.length}'),
        _card(
          children: [
            if (userLists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.loading
                      ? 'Cargando tus listas…'
                      : 'Aún no has añadido listas. Pulsa "Añadir lista" '
                          'y pega la URL de tu lista M3U.',
                  style: const TextStyle(color: Colors.white54, fontSize: 13.5, height: 1.4),
                ),
              )
            else
              for (final playlist in userLists)
                _playlistTile(context, ref, playlist),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _header(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFEF7A1E),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: const Color(0xFF1A1D24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _addTile(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: const Color(0xFF1A1D24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFFEF7A1E).withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showAddDialog(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF7A1E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.playlist_add_rounded, color: Color(0xFFEF7A1E), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Añadir lista',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Agrega una lista tuya M3U / M3U8 por URL',
                        style: TextStyle(color: Colors.white54, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.add_circle_rounded, color: Color(0xFFEF7A1E), size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playlistTile(BuildContext context, WidgetRef ref, UserPlaylist playlist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          playlist.isBuiltIn ? Icons.tv_rounded : Icons.playlist_play_rounded,
          color: const Color(0xFFEF7A1E),
          size: 22,
        ),
      ),
      title: Text(
        playlist.name,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        playlist.isBuiltIn ? 'Integrada · ${playlist.source}' : playlist.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12.5),
      ),
      trailing: playlist.isBuiltIn
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Integrada',
                style: TextStyle(color: Colors.white38, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
            )
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 21),
              tooltip: 'Eliminar',
              onPressed: () => _showDeleteDialog(context, ref, playlist),
            ),
      onTap: () => onOpenList(playlist),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final message = await ref.read(playlistsProvider.notifier).addList(
                    name: nameController.text,
                    url: urlController.text,
                  );
              if (message != null) {
                setDialogState(() => error = message);
                return;
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1A1D24),
              title: const Text('Añadir lista', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      maxLength: 60,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: 'Nombre',
                        labelStyle: const TextStyle(color: Colors.white54),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFEF7A1E)),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'URL de la lista (.m3u / .m3u8)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        hintText: 'https://ejemplo.com/lista.m3u',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFEF7A1E)),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 10),
                      Text(
                        'En web, la lista debe permitir CORS. Las listas '
                        'integradas (iptv-org, Free-TV) sí lo permiten.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11.5, height: 1.3),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF7A1E),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Añadir', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    UserPlaylist playlist,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Eliminar lista', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Quieres eliminar "${playlist.name}" de tus listas?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(playlistsProvider.notifier).removeList(playlist.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
