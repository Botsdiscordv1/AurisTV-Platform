import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/playlist_channel.dart';
import '../../data/models/user_playlist.dart';
import '../../data/providers/playlists_provider.dart';

/// Contenido del detalle de una lista: buscador + canales (Móvil y Web).
///
/// Carga los canales vía [playlistChannelsProvider] (con caché), permite
/// filtrar por nombre o grupo y notifica la selección con [onChannelTap].
/// El botón de actualizar invalida ambas cachés y vuelve a descargar.
class PlaylistChannelsContent extends ConsumerStatefulWidget {
  final UserPlaylist playlist;
  final void Function(PlaylistChannel channel) onChannelTap;

  const PlaylistChannelsContent({
    super.key,
    required this.playlist,
    required this.onChannelTap,
  });

  @override
  ConsumerState<PlaylistChannelsContent> createState() =>
      _PlaylistChannelsContentState();
}

class _PlaylistChannelsContentState extends ConsumerState<PlaylistChannelsContent> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  bool _matches(PlaylistChannel channel) {
    if (_query.isEmpty) return true;
    if (channel.title.toLowerCase().contains(_query)) return true;
    final group = channel.group;
    return group != null && group.toLowerCase().contains(_query);
  }

  Future<void> _refresh() async {
    await refreshPlaylist(ref, widget.playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(playlistChannelsProvider(widget.playlist.id));

    return Column(
      children: [
        // BUSCADOR
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Buscar en ${widget.playlist.name}…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1A1D24),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFEF7A1E)),
              ),
            ),
          ),
        ),

        // CANALES
        Expanded(
          child: channelsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
            ),
            error: (error, _) {
              final message = error is PlaylistChannelsFailure
                  ? error.message
                  : 'No se pudieron cargar los canales';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 44),
                      const SizedBox(height: 14),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF7A1E),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            data: (channels) {
              final filtered = channels.where(_matches).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      channels.isEmpty
                          ? 'Esta lista no tiene canales'
                          : 'Sin resultados para "${_searchController.text.trim()}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} ${filtered.length == 1 ? 'canal' : 'canales'}',
                            style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 19),
                          tooltip: 'Actualizar lista',
                          onPressed: _refresh,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _channelTile(filtered[index]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _channelTile(PlaylistChannel channel) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 42,
          height: 42,
          child: channel.logo != null && channel.logo!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: channel.logo!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _channelFallbackIcon(),
                  placeholder: (_, __) => _channelFallbackIcon(),
                )
              : _channelFallbackIcon(),
        ),
      ),
      title: Text(
        channel.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500),
      ),
      subtitle: channel.group != null
          ? Text(
              channel.group!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            )
          : null,
      trailing: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFFEF7A1E), size: 26),
      onTap: () => widget.onChannelTap(channel),
    );
  }

  Widget _channelFallbackIcon() {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: const Icon(Icons.tv_rounded, color: Colors.white38, size: 20),
    );
  }
}
