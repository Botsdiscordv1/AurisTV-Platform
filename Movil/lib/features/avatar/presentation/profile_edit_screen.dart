import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final String profileId;
  const ProfileEditScreen({super.key, required this.profileId});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _nameController;
  bool _autoplayNextEpisode = true;
  bool _autoplayPreviews = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider);
      if (user != null) {
        final profile = user.profiles.firstWhere(
          (p) => p.id == widget.profileId,
          orElse: () => user.profiles.first,
        );
        _nameController.text = profile.name;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    const backgroundColor = Color(0xFF0B0B0D);
    const cardColor = Color(0xFF1A1D24);

    final user = ref.watch(authProvider);
    final profile = user?.profiles.firstWhere(
      (p) => p.id == widget.profileId,
      orElse: () => user.profiles.first,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              final newName = _nameController.text.trim();
              if (newName.isNotEmpty && profile != null) {
                ref.read(authProvider.notifier).updateProfileName(newName);
              }
              context.go('/select-profile');
            },
            child: const Text('Guardar', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Avatar con Lápiz de edición
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24, width: 2),
                              image: (profile?.photoUrl != null)
                                  ? DecorationImage(
                                      image: profile!.photoUrl!.startsWith('assets/')
                                          ? AssetImage(profile.photoUrl!) as ImageProvider
                                          : CachedNetworkImageProvider(profile.photoUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: cardColor,
                            ),
                            child: (profile?.photoUrl == null)
                                ? const Icon(Icons.person_rounded, color: Colors.white70, size: 54)
                                : null,
                          ),
                          GestureDetector(
                            onTap: () => context.push('/settings/avatar'),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 16, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Nombre del perfil (TextField único sin contenedores anidados)
                    TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF22252A),
                        hintText: 'Nombre del perfil',
                        hintStyle: const TextStyle(color: Colors.white38),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Clasificación por edad
                    _buildSettingTile(
                      icon: Icons.error_outline_rounded,
                      title: 'Clasificación por edad',
                      subtitle: 'Sin restricciones',
                      trailing: const Icon(Icons.open_in_new_rounded, color: Colors.white54, size: 20),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Clasificación por edad: Sin restricciones')),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Idioma de visualización
                    _buildSettingTile(
                      icon: Icons.language_rounded,
                      title: 'Idioma de visualización',
                      subtitle: 'Cambia el idioma del texto en todos tus dispositivos.',
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),

                    // Idiomas de audio y subtítulos
                    _buildSettingTile(
                      icon: Icons.subtitles_rounded,
                      title: 'Idiomas de audio y subtítulos',
                      subtitle: 'Elige tus idiomas preferidos para series y películas.',
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),

                    // Aspecto de los subtítulos
                    _buildSettingTile(
                      icon: Icons.format_size_rounded,
                      title: 'Aspecto de los subtítulos',
                      subtitle: 'Cambia cómo se muestran los subtítulos en teléfonos y tablets.',
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                      onTap: () => context.push('/settings'),
                    ),
                    const SizedBox(height: 12),

                    // Reproducir siguiente episodio automáticamente
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: SwitchListTile(
                        activeColor: primaryColor,
                        secondary: const Icon(Icons.next_plan_outlined, color: Colors.white70),
                        title: const Text('Reproducir siguiente episodio', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                        subtitle: const Text('En todos los dispositivos', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        value: _autoplayNextEpisode,
                        onChanged: (v) => setState(() => _autoplayNextEpisode = v),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reproducir avances automáticamente
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: SwitchListTile(
                        activeColor: primaryColor,
                        secondary: const Icon(Icons.play_circle_outline_rounded, color: Colors.white70),
                        title: const Text('Reproducir avances', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                        subtitle: const Text('En todos los dispositivos', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        value: _autoplayPreviews,
                        onChanged: (v) => setState(() => _autoplayPreviews = v),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          // Pinned Bottom Delete Profile Button
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
            color: backgroundColor,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    if (profile != null) {
                      _showDeleteDialog(context, ref, profile.id, profile.name);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                  label: const Text(
                    'Eliminar perfil',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1A1D24),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('¿Eliminar perfil?', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que quieres eliminar a $name? Se perderán todo el historial y las preferencias.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).deleteProfile(id);
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
