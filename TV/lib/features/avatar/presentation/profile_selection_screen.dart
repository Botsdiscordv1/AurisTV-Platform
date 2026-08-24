import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  ConsumerState<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends ConsumerState<ProfileSelectionScreen> {
  bool _isEditMode = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    const primaryColor = Color(0xFFEF7A1E);
    const backgroundColor = Color(0xFF0B0B0D);

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
        centerTitle: true,
        leading: Navigator.canPop(context) ? const BackButton(color: Colors.white70) : null,
        title: Image.asset(
          'assets/icons/auris-tv-icon.png',
          height: 30,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
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
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 60),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Wrap(
                  spacing: 40,
                  runSpacing: 40,
                  alignment: WrapAlignment.center,
                  children: [
                    ...user.profiles.map((profile) {
                      return _ProfileItem(
                        key: ValueKey('profile_${profile.id}'),
                        name: profile.name,
                        photoUrl: profile.photoUrl,
                        isEditMode: _isEditMode,
                        isMain: profile.isMain,
                        onTap: () {
                          if (_isEditMode) {
                            ref.read(authProvider.notifier).switchProfile(profile.id);
                            context.go('/settings/avatar');
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
                        onTap: () => _showAddProfileDialog(context, ref),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
              // Botón Administrar perfiles (Control Central)
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _isEditMode ? primaryColor : Colors.white38),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  _isEditMode ? 'LISTO' : 'ADMINISTRAR PERFILES',
                  style: TextStyle(
                    color: _isEditMode ? primaryColor : Colors.white70, 
                    fontSize: 13, 
                    letterSpacing: 1,
                    fontWeight: _isEditMode ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
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

  void _showAddProfileDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo Perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nombre',
            hintStyle: TextStyle(color: Colors.white24),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFEF7A1E))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(authProvider.notifier).addProfile(name, null);
                Navigator.pop(context);
              }
            },
            child: const Text('CREAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProfileItem({
    super.key,
    required this.name,
    this.photoUrl,
    required this.isEditMode,
    required this.isMain,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ProfileItem> createState() => _ProfileItemState();
}

class _ProfileItemState extends State<_ProfileItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: _isHovered ? 1.05 : 1.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isHovered ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          image: widget.photoUrl != null
                              ? DecorationImage(
                                  image: widget.photoUrl!.startsWith('assets/')
                                      ? AssetImage(widget.photoUrl!) as ImageProvider
                                      : NetworkImage(widget.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: const Color(0xFF1A1D24),
                        ),
                        child: widget.photoUrl == null
                            ? const Icon(Icons.person, size: 60, color: Colors.white24)
                            : null,
                      ),
                      if (widget.isEditMode)
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 40),
                        ),
                    ],
                  ),
                ),
                // Botón de eliminar (Solo en modo edición y si no es el principal)
                if (widget.isEditMode && !widget.isMain)
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.name,
              style: TextStyle(
                color: _isHovered || widget.isEditMode ? Colors.white : Colors.white60,
                fontSize: 18,
                fontWeight: _isHovered || widget.isEditMode ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isHovered ? Colors.white : Colors.white10,
                  width: 2,
                ),
                color: Colors.white.withValues(alpha: _isHovered ? 0.1 : 0.05),
              ),
              child: Icon(
                Icons.add, 
                size: 50, 
                color: _isHovered ? Colors.white : Colors.white38
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Añadir',
              style: TextStyle(
                color: _isHovered ? Colors.white : Colors.white60,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
