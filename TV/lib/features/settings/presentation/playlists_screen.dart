import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';
import '../../search/presentation/widgets/tv_keyboard.dart';

/// Ajustes > Listas añadidas (TV).
///
/// Filas navegables con D-pad: las listas integradas y las del usuario, con
/// un botón "Añadir lista" que abre un diálogo con el TVKeyboard en modo URL.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  void _openAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _AddPlaylistTvDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playlistsProvider);
    final userLists = state.userLists;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'LISTAS AÑADIDAS',
          style: TextStyle(
            color: Color(0xFFEF7A1E),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF000000),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 48),
        children: [
          _TvFocusTile(
            label: 'Añadir lista (URL M3U / M3U8)',
            icon: Icons.playlist_add_rounded,
            primary: true,
            onTap: () => _openAddDialog(context, ref),
          ),
          const SizedBox(height: 18),
          _sectionHeader('Integradas · ${BuiltinPlaylists.all.length}'),
          for (final playlist in BuiltinPlaylists.all)
            _TvPlaylistTile(playlist: playlist),
          const SizedBox(height: 18),
          _sectionHeader('Tus listas · ${userLists.length}'),
          if (userLists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Aún no has añadido listas. Pulsa "Añadir lista" y escribe la '
                'URL de tu lista con el teclado en pantalla.',
                style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.4),
              ),
            )
          else
            for (final playlist in userLists) _TvPlaylistTile(playlist: playlist),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFEF7A1E),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Fila de lista con navegación D-pad (patrón _SettingsTVButton).
class _TvPlaylistTile extends ConsumerStatefulWidget {
  final UserPlaylist playlist;

  const _TvPlaylistTile({required this.playlist});

  @override
  ConsumerState<_TvPlaylistTile> createState() => _TvPlaylistTileState();
}

class _TvPlaylistTileState extends ConsumerState<_TvPlaylistTile> {
  bool _tileFocused = false;
  bool _deleteFocused = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Eliminar lista', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Quieres eliminar "${widget.playlist.name}" de tus listas?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(playlistsProvider.notifier).removeList(widget.playlist.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    final playlist = widget.playlist;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onFocusChange: (f) => setState(() => _tileFocused = f),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.space)) {
                  context.push('/settings/listas/${playlist.id}');
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: () => context.push('/settings/listas/${playlist.id}'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: _tileFocused ? primaryColor : Colors.white38,
                      width: _tileFocused ? 2.5 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        playlist.isBuiltIn ? Icons.tv_rounded : Icons.playlist_play_rounded,
                        color: _tileFocused ? primaryColor : Colors.white70,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              playlist.isBuiltIn
                                  ? 'Integrada · ${playlist.source}'
                                  : playlist.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (playlist.isBuiltIn)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Integrada',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!playlist.isBuiltIn) ...[
            const SizedBox(width: 12),
            Focus(
              onFocusChange: (f) => setState(() => _deleteFocused = f),
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.space)) {
                  _confirmDelete();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: _confirmDelete,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _deleteFocused ? Colors.redAccent : Colors.white38,
                      width: _deleteFocused ? 2.5 : 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: _deleteFocused ? Colors.redAccent : Colors.white54,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tecla de acción / fila genérica con foco D-pad (patrón _SettingsTVButton).
class _TvFocusTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _TvFocusTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_TvFocusTile> createState() => _TvFocusTileState();
}

class _TvFocusTileState extends State<_TvFocusTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    final bool active = _focused;

    return Focus(
      autofocus: widget.primary,
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
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 640),
          decoration: BoxDecoration(
            color: widget.primary ? primaryColor : Colors.transparent,
            border: Border.all(
              color: active ? (widget.primary ? Colors.white : primaryColor) : Colors.white38,
              width: active ? 2.5 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.primary ? Colors.black : (active ? primaryColor : Colors.white70),
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.primary ? Colors.black : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ActiveField { name, url }

/// Diálogo "Añadir lista" para TV: dos campos conmutables (Nombre / URL) y
/// TVKeyboard en modo URL escribiendo sobre el campo activo.
class _AddPlaylistTvDialog extends ConsumerStatefulWidget {
  const _AddPlaylistTvDialog();

  @override
  ConsumerState<_AddPlaylistTvDialog> createState() => _AddPlaylistTvDialogState();
}

class _AddPlaylistTvDialogState extends ConsumerState<_AddPlaylistTvDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  _ActiveField _active = _ActiveField.name;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  TextEditingController get _current =>
      _active == _ActiveField.name ? _nameController : _urlController;

  void _onKey(String key) {
    setState(() {
      final controller = _current;
      if (controller.text.length < 300) controller.text += key;
    });
  }

  void _onBackspace() {
    setState(() {
      final controller = _current;
      final text = controller.text;
      if (text.isNotEmpty) {
        controller.text = text.substring(0, text.length - 1);
      }
    });
  }

  void _onClear() {
    setState(_current.clear);
  }

  Future<void> _submit() async {
    final message = await ref.read(playlistsProvider.notifier).addList(
          name: _nameController.text,
          url: _urlController.text,
        );
    if (message != null) {
      if (mounted) setState(() => _error = message);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1D24),
      title: const Text('Añadir lista', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldBox(_ActiveField.name, 'Nombre', _nameController.text, 'Mi lista'),
            const SizedBox(height: 10),
            _fieldBox(_ActiveField.url, 'URL (.m3u / .m3u8)', _urlController.text,
                'https://ejemplo.com/lista.m3u'),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 14),
            Center(
              child: TVKeyboard(
                mode: TVKeyboardMode.url,
                onKeyTap: _onKey,
                onBackspace: _onBackspace,
                onClear: _onClear,
                currentQuery: _current.text,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF7A1E),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Añadir', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _fieldBox(_ActiveField field, String label, String value, String hint) {
    final bool active = _active == field;
    return Focus(
      autofocus: field == _ActiveField.name,
      onFocusChange: (f) {
        if (f) setState(() => _active = field);
      },
      child: GestureDetector(
        onTap: () => setState(() => _active = field),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
            border: Border.all(
              color: active ? const Color(0xFFEF7A1E) : Colors.white24,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? const Color(0xFFEF7A1E) : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isEmpty ? hint : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value.isEmpty ? Colors.white24 : Colors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
