import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';

/// Ajustes > Listas añadidas > [playlistId] (TV).
///
/// Canales de la lista en filas navegables con D-pad; al seleccionar uno se
/// abre el player en modo directo y en vivo (sin historial).
class PlaylistChannelsScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistChannelsScreen({super.key, required this.playlistId});

  /// Misma receta de reproducción directa que Móvil/Web: `source` vacío +
  /// `url`, `category=movie`, `isLive=1` y `skipResume=1`.
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

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          (playlist?.name ?? 'Lista').toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFEF7A1E),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: const Color(0xFF000000),
        surfaceTintColor: Colors.transparent,
      ),
      body: playlist == null
          ? const Center(
              child: Text(
                'Esta lista ya no existe',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : _ChannelList(
              playlist: playlist,
              onChannelTap: (channel) => _openChannel(context, channel),
            ),
    );
  }
}

class _ChannelList extends ConsumerStatefulWidget {
  final UserPlaylist playlist;
  final void Function(PlaylistChannel channel) onChannelTap;

  const _ChannelList({required this.playlist, required this.onChannelTap});

  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList> {
  Future<void> _refresh() async {
    await refreshPlaylist(ref, widget.playlist.id);
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(playlistChannelsProvider(widget.playlist.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CABECERA: contador + actualizar
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 16, 48, 8),
          child: channelsAsync.when(
            loading: () => const Text(
              'Cargando canales…',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            error: (error, _) => Text(
              error is PlaylistChannelsFailure
                  ? error.message
                  : 'No se pudieron cargar los canales',
              style: const TextStyle(color: Colors.redAccent, fontSize: 15),
            ),
            data: (channels) => Row(
              children: [
                Text(
                  '${channels.length} ${channels.length == 1 ? 'canal' : 'canales'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 20),
                _TvTextButton(
                  label: 'Actualizar',
                  icon: Icons.refresh_rounded,
                  onTap: _refresh,
                ),
              ],
            ),
          ),
        ),

        // CANALES
        Expanded(
          child: channelsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
            ),
            error: (error, _) => Center(
              child: _TvTextButton(
                label: 'Reintentar',
                icon: Icons.refresh_rounded,
                primary: true,
                onTap: _refresh,
              ),
            ),
            data: (channels) {
              if (channels.isEmpty) {
                return const Center(
                  child: Text(
                    'Esta lista no tiene canales',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 8),
                itemCount: channels.length,
                itemBuilder: (context, index) =>
                    _TvChannelTile(channel: channels[index], onTap: () => widget.onChannelTap(channels[index])),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TvChannelTile extends StatefulWidget {
  final PlaylistChannel channel;
  final VoidCallback onTap;

  const _TvChannelTile({required this.channel, required this.onTap});

  @override
  State<_TvChannelTile> createState() => _TvChannelTileState();
}

class _TvChannelTileState extends State<_TvChannelTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    final channel = widget.channel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: _focused ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
              border: Border.all(
                color: _focused ? primaryColor : Colors.white24,
                width: _focused ? 2.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: channel.logo != null && channel.logo!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: channel.logo!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallbackIcon(),
                            placeholder: (_, __) => _fallbackIcon(),
                          )
                        : _fallbackIcon(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (channel.group != null && channel.group!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          channel.group!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: _focused ? primaryColor : Colors.white38,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      child: const Icon(Icons.tv_rounded, color: Colors.white38, size: 20),
    );
  }
}

/// Botón de texto con foco D-pad (patrón _SettingsTVButton).
class _TvTextButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _TvTextButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_TvTextButton> createState() => _TvTextButtonState();
}

class _TvTextButtonState extends State<_TvTextButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.primary && _focused ? primaryColor : Colors.transparent,
            border: Border.all(
              color: _focused
                  ? (widget.primary ? Colors.white : primaryColor)
                  : Colors.white38,
              width: _focused ? 2.5 : 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.primary && _focused
                    ? Colors.black
                    : (_focused ? primaryColor : Colors.white70),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.primary && _focused ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
