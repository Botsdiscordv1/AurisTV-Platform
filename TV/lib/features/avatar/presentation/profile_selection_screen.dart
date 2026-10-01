import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  ConsumerState<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends ConsumerState<ProfileSelectionScreen> {
  bool? _isEditModeOverride;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    const primaryColor = Color(0xFFEF7A1E);
    const backgroundColor = Color(0xFF0B0B0D);

    final bool initialEdit = GoRouterState.of(context).uri.queryParameters['edit'] == 'true';
    final bool _isEditMode = _isEditModeOverride ?? initialEdit;

    if (user == null) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: AurisIcon(AurisIcons.chevronLeft, color: Colors.white70, size: 24),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isEditMode ? 'Administrar perfiles' : '¿Quién está viendo ahora?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 50),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Wrap(
                  spacing: 48,
                  runSpacing: 40,
                  alignment: WrapAlignment.center,
                  children: [
                    ...user.profiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final profile = entry.value;
                      return _ProfileItem(
                        key: ValueKey('profile_${profile.id}'),
                        name: profile.name,
                        photoUrl: profile.photoUrl,
                        isEditMode: _isEditMode,
                        isMain: profile.isMain,
                        autofocus: index == 0,
                        onTap: () {
                          if (_isEditMode) {
                            ref.read(authProvider.notifier).switchProfile(profile.id);
                            context.push('/edit-profile/${profile.id}');
                          } else {
                            ref.read(authProvider.notifier).switchProfile(profile.id);
                            context.go('/');
                          }
                        },
                        onDelete: () => _showDeleteConfirmation(context, ref, profile.id, profile.name),
                      );
                    }),
                    if (user.profiles.length < 5 && !_isEditMode)
                      _AddProfileItem(
                        onTap: () => context.push('/add-profile'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 70),
              // Botón Administrar perfiles / Editar perfil
              _FocusableAdminButton(
                isEditMode: _isEditMode,
                primaryColor: primaryColor,
                onPressed: () {
                  setState(() {
                    _isEditModeOverride = !_isEditMode;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('¿Eliminar perfil?', style: TextStyle(color: Colors.white)),
        content: Text('Se perderá todo el historial y preferencias de $name.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).deleteProfile(id);
              Navigator.pop(context);
            }, 
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final bool isEditMode;
  final bool isMain;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProfileItem({
    super.key,
    required this.name,
    this.photoUrl,
    required this.isEditMode,
    required this.isMain,
    this.autofocus = false,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ProfileItem> createState() => _ProfileItemState();
}

class _ProfileItemState extends State<_ProfileItem> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
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
        child: AnimatedScale(
          scale: _hasFocus ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _hasFocus ? primaryColor : Colors.transparent,
                          width: 4,
                        ),
                        boxShadow: _hasFocus
                            ? [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                            : [],
                      ),
                      child: ClipOval(
                        child: widget.photoUrl != null
                            ? (widget.photoUrl!.startsWith('assets/')
                                ? Image.asset(widget.photoUrl!, fit: BoxFit.cover)
                                : CachedNetworkImage(imageUrl: widget.photoUrl!, fit: BoxFit.cover))
                            : Container(
                                color: Colors.white10,
                                child: AurisIcon(AurisIcons.user, color: Colors.white70, size: 65),
                              ),
                      ),
                    ),
                    if (widget.isEditMode)
                      Container(
                        width: 130,
                        height: 130,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: AurisIcon(AurisIcons.settings, color: Colors.white, size: 42),
                      ),
                    if (widget.isEditMode && !widget.isMain)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: widget.onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: AurisIcon(AurisIcons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _hasFocus || widget.isEditMode ? Colors.white : Colors.white60,
                    fontSize: 18,
                    fontWeight: _hasFocus || widget.isEditMode ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddProfileItem extends StatefulWidget {
  final VoidCallback onTap;
  const _AddProfileItem({required this.onTap});

  @override
  State<_AddProfileItem> createState() => _AddProfileItemState();
}

class _AddProfileItemState extends State<_AddProfileItem> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
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
        child: AnimatedScale(
          scale: _hasFocus ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: 140,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white10,
                    border: Border.all(
                      color: _hasFocus ? primaryColor : Colors.transparent,
                      width: 4,
                    ),
                    boxShadow: _hasFocus
                        ? [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                        : [],
                  ),
                  child: AurisIcon(AurisIcons.add, color: Colors.white70, size: 60),
                ),
                const SizedBox(height: 14),
                Text(
                  'Añadir perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _hasFocus ? Colors.white : Colors.white60,
                    fontSize: 18,
                    fontWeight: _hasFocus ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusableAdminButton extends StatefulWidget {
  final bool isEditMode;
  final Color primaryColor;
  final VoidCallback onPressed;

  const _FocusableAdminButton({
    required this.isEditMode,
    required this.primaryColor,
    required this.onPressed,
  });

  @override
  State<_FocusableAdminButton> createState() => _FocusableAdminButtonState();
}

class _FocusableAdminButtonState extends State<_FocusableAdminButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
      child: OutlinedButton(
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _hasFocus ? Colors.white : (widget.isEditMode ? widget.primaryColor : Colors.white38),
            width: _hasFocus ? 2 : 1.5,
          ),
          backgroundColor: _hasFocus ? widget.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Text(
          widget.isEditMode ? 'LISTO' : 'ADMINISTRAR PERFILES',
          style: TextStyle(
            color: _hasFocus ? Colors.white : (widget.isEditMode ? widget.primaryColor : Colors.white70),
            fontSize: 14,
            letterSpacing: 1.5,
            fontWeight: widget.isEditMode || _hasFocus ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
